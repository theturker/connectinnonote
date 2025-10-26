import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/note.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';

/// Sync Manager - Local DB ile Firebase arasında senkronizasyon yönetir
/// 
/// Bu servis offline-first yaklaşımının beynidir.
/// Local değişiklikleri Firebase'e gönderir ve Firebase değişiklerini local'e alır.
class SyncManager extends GetxController {
  final LocalDatabaseService _localDb;
  final ConnectivityService _connectivity;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final RxBool _isSyncing = false.obs;
  final RxInt _syncProgress = 0.obs;
  final RxInt _totalSyncItems = 0.obs;
  final RxString _lastSyncTime = ''.obs;
  
  Timer? _periodicSyncTimer;
  StreamSubscription<User?>? _authSubscription;

  /// Constructor
  SyncManager(this._localDb, this._connectivity);

  /// Sync durumu
  bool get isSyncing => _isSyncing.value;
  int get syncProgress => _syncProgress.value;
  int get totalSyncItems => _totalSyncItems.value;
  String get lastSyncTime => _lastSyncTime.value;

  @override
  void onInit() {
    super.onInit();
    _startPeriodicSync();
    _listenToConnectivity();
    _listenToAuth();
  }

  /// Periyodik sync başlat (her 30 saniyede)
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_connectivity.isOnline && !_isSyncing.value) {
          await syncAll();
        }
      },
    );
  }

  /// Bağlantı değişikliklerini dinle
  void _listenToConnectivity() {
    ever(_connectivity.isOnlineRx, (isOnline) async {
      if (isOnline && !_isSyncing.value) {
        print('🔄 Connection restored, starting sync...');
        await syncAll();
      }
    });
  }

  /// Auth değişikliklerini dinle
  void _listenToAuth() {
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null && _connectivity.isOnline) {
        print('🔄 User logged in, syncing from Firebase...');
        await syncFromFirebase();
      }
    });
  }

  /// Tüm değişiklikleri senkronize et
  Future<void> syncAll() async {
    if (_isSyncing.value) {
      print('⚠️ Sync already in progress');
      return;
    }

    if (!_connectivity.isOnline) {
      print('⚠️ No internet connection, skipping sync');
      return;
    }

    try {
      _isSyncing.value = true;
      print('🔄 Starting full sync...');

      // 1. Local değişiklikleri Firebase'e gönder
      await _syncLocalToFirebase();

      // 2. Firebase'den güncellemeleri al
      await syncFromFirebase();

      _lastSyncTime.value = DateTime.now().toIso8601String();
      print('✅ Full sync completed');
    } catch (e) {
      print('❌ Sync error: $e');
      rethrow;
    } finally {
      _isSyncing.value = false;
      _syncProgress.value = 0;
      _totalSyncItems.value = 0;
    }
  }

  /// Local değişiklikleri Firebase'e gönder
  Future<void> _syncLocalToFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        return;
      }

      // Sync gereksinimi olan notları al
      final notesToSync = _localDb.getNotesNeedingSync(userId: user.uid);
      
      if (notesToSync.isEmpty) {
        print('✅ No local changes to sync');
        return;
      }

      _totalSyncItems.value = notesToSync.length;
      print('🔄 Syncing ${notesToSync.length} notes to Firebase...');

      for (var i = 0; i < notesToSync.length; i++) {
        final note = notesToSync[i];
        _syncProgress.value = i + 1;

        try {
          if (note.isDeleted) {
            // Silinmiş not - Firebase'den sil
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('notes')
                .doc(note.id)
                .delete();
            
            // Local'den de hard delete
            await _localDb.hardDeleteNote(note.id);
            print('✅ Deleted from Firebase: ${note.id}');
          } else {
            // Güncellenmiş veya yeni not - Firebase'e kaydet
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('notes')
                .doc(note.id)
                .set(note.toFirestore());
            
            // needsSync flag'ini kaldır
            final syncedNote = note.copyWith(needsSync: false);
            await _localDb.saveNote(syncedNote);
            
            print('✅ Synced to Firebase: ${note.id}');
          }
        } catch (e) {
          print('❌ Error syncing note ${note.id}: $e');
          // Hata durumunda devam et
        }
      }

      print('✅ Local to Firebase sync completed');
    } catch (e) {
      print('❌ Local to Firebase sync error: $e');
      rethrow;
    }
  }

  /// Firebase'den güncellemeleri al
  Future<void> syncFromFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        return;
      }

      if (!_connectivity.isOnline) {
        print('⚠️ No internet connection');
        return;
      }

      print('🔄 Syncing from Firebase...');

      // Firebase'den tüm notları al
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .orderBy('updatedAt', descending: true)
          .get();

      print('📥 Received ${snapshot.docs.length} notes from Firebase');

      // Local DB'yi güncelle
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          
          final firebaseNote = Note.fromJson(data);
          final localNote = _localDb.getNoteById(doc.id);

          // Local'de yok veya Firebase daha güncel ise kaydet
          if (localNote == null || 
              localNote.id.isEmpty ||
              firebaseNote.updatedAt.isAfter(localNote.updatedAt)) {
            
            // needsSync false olarak işaretle (Firebase'den geldi)
            final noteToSave = firebaseNote.copyWith(needsSync: false);
            await _localDb.saveNote(noteToSave);
            
            print('✅ Updated from Firebase: ${doc.id}');
          }
        } catch (e) {
          print('❌ Error processing note ${doc.id}: $e');
        }
      }

      print('✅ Firebase to local sync completed');
    } catch (e) {
      print('❌ Firebase to local sync error: $e');
      rethrow;
    }
  }

  /// Belirli bir notu senkronize et
  Future<void> syncNote(Note note) async {
    if (!_connectivity.isOnline) {
      print('⚠️ No internet, note will sync when online');
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        return;
      }

      if (note.isDeleted) {
        // Silinmiş not
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(note.id)
            .delete();
        
        await _localDb.hardDeleteNote(note.id);
      } else {
        // Normal not
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(note.id)
            .set(note.toFirestore());
        
        final syncedNote = note.copyWith(needsSync: false);
        await _localDb.saveNote(syncedNote);
      }

      print('✅ Note synced: ${note.id}');
    } catch (e) {
      print('❌ Error syncing note: $e');
      rethrow;
    }
  }

  /// Manuel sync tetikle
  Future<void> manualSync() async {
    if (!_connectivity.isOnline) {
      Get.snackbar(
        'Bağlantı Yok',
        'Senkronizasyon için internet bağlantısı gerekli',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.snackbar(
      'Senkronizasyon',
      'Senkronizasyon başlatılıyor...',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
    );

    await syncAll();

    Get.snackbar(
      'Başarılı',
      'Senkronizasyon tamamlandı',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// Sync durumunu sıfırla
  void resetSyncStatus() {
    _isSyncing.value = false;
    _syncProgress.value = 0;
    _totalSyncItems.value = 0;
  }

  /// İstatistikler
  Map<String, dynamic> getStats() {
    final dbStats = _localDb.getStats();
    return {
      ...dbStats,
      'isSyncing': _isSyncing.value,
      'syncProgress': _syncProgress.value,
      'totalSyncItems': _totalSyncItems.value,
      'lastSyncTime': _lastSyncTime.value,
      'isOnline': _connectivity.isOnline,
    };
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _authSubscription?.cancel();
    super.onClose();
  }
}

