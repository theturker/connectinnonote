import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/note.dart';
import '../constants/app_colors.dart';
import '../services/local_database_service.dart';
import '../services/sync_manager.dart';
import '../services/connectivity_service.dart';

/// Note Controller - Offline-First yaklaşımla not yönetimi
/// 
/// Bu controller tüm not işlemlerini önce local DB'de yapar,
/// sonra arka planda Firebase'e senkronize eder.
class NoteController extends GetxController {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  final SyncManager _syncManager = Get.find<SyncManager>();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();
  
  final RxList<Note> _notes = <Note>[].obs;
  final RxString _searchQuery = ''.obs;
  final RxBool _isLoading = false.obs;
  final RxString _currentUserId = ''.obs;
  final RxBool _showFavoritesOnly = false.obs;
  
  // Silinen notlar için geri alma özelliği
  final Rx<Note?> _lastDeletedNote = Rx<Note?>(null);

  // Getters
  List<Note> get notes => _notes;
  String get searchQuery => _searchQuery.value;
  bool get isLoading => _isLoading.value;
  String get currentUserId => _currentUserId.value;
  bool get showFavoritesOnly => _showFavoritesOnly.value;
  Note? get lastDeletedNote => _lastDeletedNote.value;
  bool get isOnline => _connectivity.isOnline;

  @override
  void onInit() {
    super.onInit();
    
    // Connectivity değişikliklerini dinle
    ever(_connectivity.isOnlineRx, (isOnline) {
      if (isOnline) {
        print('🔄 Online - Syncing notes...');
        _syncManager.syncAll();
      }
    });
  }

  // Filtrelenmiş notlar (arama sonuçları)
  List<Note> get filteredNotes {
    List<Note> notes = _notes;
    
    // Favori filtresi
    if (_showFavoritesOnly.value) {
      notes = notes.where((note) => note.isFavorite).toList();
    }
    
    // Arama filtresi
    if (_searchQuery.value.isNotEmpty) {
      notes = notes.where((note) {
        return note.title.toLowerCase().contains(_searchQuery.value.toLowerCase()) ||
               note.content.toLowerCase().contains(_searchQuery.value.toLowerCase());
      }).toList();
    }
    
    // Favori notları üstte sırala
    notes.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    return notes;
  }

  // Favori notlar
  List<Note> get favoriteNotes {
    return _notes.where((note) => note.isFavorite).toList();
  }

  /// Kullanıcı ID'sini ayarla ve notları yükle
  Future<void> setUserId(String userId) async {
    _currentUserId.value = userId;
    await loadNotes();
  }

  /// Notları local DB'den yükle
  Future<void> loadNotes() async {
    try {
      _isLoading.value = true;
      
      print('📖 Loading notes from local DB...');
      
      // Local DB'den notları al
      final localNotes = _localDb.getAllNotes(userId: _currentUserId.value);
      _notes.value = localNotes;
      
      print('✅ Loaded ${_notes.length} notes from local DB');
      
      // Arka planda Firebase'den sync et
      if (_connectivity.isOnline) {
        _syncManager.syncFromFirebase().then((_) {
          // Sync sonrası tekrar yükle
          final updatedNotes = _localDb.getAllNotes(userId: _currentUserId.value);
          _notes.value = updatedNotes;
          print('✅ Notes refreshed from Firebase');
        });
      } else {
        print('⚠️ Offline - Showing cached notes');
      }
    } catch (e) {
      print('❌ Error loading notes: $e');
      Get.snackbar(
        'Hata',
        'Notlar yüklenirken hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Arama sorgusunu güncelle
  void updateSearchQuery(String query) {
    _searchQuery.value = query;
  }

  /// Arama sorgusunu temizle
  void clearSearch() {
    _searchQuery.value = '';
  }

  /// Favori filtresini değiştir
  void toggleFavoritesFilter() {
    _showFavoritesOnly.value = !_showFavoritesOnly.value;
  }

  /// Favori filtresini kapat
  void clearFavoritesFilter() {
    _showFavoritesOnly.value = false;
  }

  /// Not ekleme (Offline-First)
  Future<void> addNote(String title, String content) async {
    try {
      print('📝 Adding note (offline-first)...');
      
      // Benzersiz ID oluştur
      final noteId = '${_currentUserId.value}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Yeni not oluştur
      final newNote = Note(
        id: noteId,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: _currentUserId.value,
        needsSync: true, // Sync gerekiyor işaretle
      );
      
      // 1. ÖNCE LOCAL DB'YE KAYDET (Hızlı!)
      await _localDb.saveNote(newNote);
      print('✅ Note saved to local DB');
      
      // 2. LOCAL LİSTEYİ GÜNCELLE (UI anında güncellenir)
      _notes.add(newNote);
      _notes.refresh();
      
      // 3. KULLANICIYA BİLDİR (Anında feedback)
      Get.snackbar(
        'Başarılı',
        _connectivity.isOnline 
            ? 'Not kaydedildi ve senkronize ediliyor...' 
            : 'Not kaydedildi (Offline)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      // 4. ARKA PLANDA FIREBASE'E GÖNDER (Async)
      if (_connectivity.isOnline) {
        _syncManager.syncNote(newNote).catchError((error) {
          print('⚠️ Background sync failed: $error');
          // Hata durumunda needsSync true kaldığı için sonra sync olacak
        });
      } else {
        print('⚠️ Offline - Note will sync when online');
      }
      
      print('✅ Note add completed');
    } catch (e) {
      print('❌ Error adding note: $e');
      Get.snackbar(
        'Hata',
        'Not eklenirken hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }

  /// Not güncelleme (Offline-First)
  Future<void> updateNote(String noteId, String title, String content) async {
    try {
      print('✏️ Updating note (offline-first)...');
      
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        throw Exception('Not bulunamadı');
      }
      
      // Güncellenmiş not
      final updatedNote = _notes[noteIndex].copyWith(
        title: title,
        content: content,
        updatedAt: DateTime.now(),
        needsSync: true, // Sync gerekiyor
      );
      
      // 1. LOCAL DB'YE KAYDET
      await _localDb.saveNote(updatedNote);
      print('✅ Note updated in local DB');
      
      // 2. LOCAL LİSTEYİ GÜNCELLE
      _notes[noteIndex] = updatedNote;
      _notes.refresh();
      
      // 3. KULLANICIYA BİLDİR
      Get.snackbar(
        'Başarılı',
        _connectivity.isOnline 
            ? 'Not güncellendi ve senkronize ediliyor...' 
            : 'Not güncellendi (Offline)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      // 4. ARKA PLANDA SYNC
      if (_connectivity.isOnline) {
        _syncManager.syncNote(updatedNote).catchError((error) {
          print('⚠️ Background sync failed: $error');
        });
      }
      
      print('✅ Note update completed');
    } catch (e) {
      print('❌ Error updating note: $e');
      Get.snackbar(
        'Hata',
        'Not güncellenirken hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }

  /// Not silme (Offline-First + Undo)
  Future<void> deleteNote(String noteId) async {
    try {
      print('🗑️ Deleting note (offline-first)...');
      
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        throw Exception('Not bulunamadı');
      }
      
      final noteToDelete = _notes[noteIndex];
      
      // 1. SOFT DELETE - LOCAL DB'DE İŞARETLE
      final deletedNote = noteToDelete.copyWith(
        isDeleted: true,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      
      await _localDb.saveNote(deletedNote);
      print('✅ Note marked as deleted in local DB');
      
      // 2. LOCAL LİSTEDEN ÇIKAR
      _notes.removeAt(noteIndex);
      _notes.refresh();
      
      // 3. GERİ ALMA İÇİN SAKLA
      _lastDeletedNote.value = noteToDelete;
      
      // 4. UNDO SNACKBAR GÖSTER
      Get.snackbar(
        'Not Silindi',
        _connectivity.isOnline 
            ? 'Not silindi ve senkronize ediliyor...' 
            : 'Not silindi (Offline)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            undoDelete();
            Get.closeCurrentSnackbar();
          },
          child: const Text(
            'GERİ AL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      
      // 5. ARKA PLANDA SYNC
      if (_connectivity.isOnline) {
        _syncManager.syncNote(deletedNote).catchError((error) {
          print('⚠️ Background sync failed: $error');
        });
      }
      
      print('✅ Note delete completed');
    } catch (e) {
      print('❌ Error deleting note: $e');
      Get.snackbar(
        'Hata',
        'Not silinirken hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }

  /// Silmeyi geri al
  Future<void> undoDelete() async {
    try {
      if (_lastDeletedNote.value == null) return;
      
      final note = _lastDeletedNote.value!;
      
      // 1. RESTORE NOTE
      final restoredNote = note.copyWith(
        isDeleted: false,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      
      await _localDb.saveNote(restoredNote);
      print('✅ Note restored in local DB');
      
      // 2. LOCAL LİSTEYE GERİ EKLE
      _notes.add(restoredNote);
      _notes.refresh();
      
      // 3. CLEAR LAST DELETED
      _lastDeletedNote.value = null;
      
      // 4. BİLDİR
      Get.snackbar(
        'Geri Alındı',
        'Not geri yüklendi',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      // 5. SYNC
      if (_connectivity.isOnline) {
        _syncManager.syncNote(restoredNote);
      }
    } catch (e) {
      print('❌ Error undoing delete: $e');
    }
  }

  /// Favori durumunu değiştir (Offline-First)
  Future<void> toggleFavorite(String noteId) async {
    try {
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) return;
      
      final note = _notes[noteIndex];
      final updatedNote = note.copyWith(
        isFavorite: !note.isFavorite,
        needsSync: true,
        updatedAt: DateTime.now(),
      );
      
      // 1. LOCAL DB'YE KAYDET
      await _localDb.saveNote(updatedNote);
      
      // 2. LOCAL LİSTEYİ GÜNCELLE
      _notes[noteIndex] = updatedNote;
      _notes.refresh();
      
      // 3. FEEDBACK
      final message = updatedNote.isFavorite ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı';
      Get.snackbar(
        'Başarılı',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
      
      // 4. SYNC
      if (_connectivity.isOnline) {
        _syncManager.syncNote(updatedNote);
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
    }
  }

  /// Manuel senkronizasyon tetikle
  Future<void> manualSync() async {
    await _syncManager.manualSync();
    await loadNotes();
  }

  /// Tüm notları temizle (logout için)
  void clearAllNotes() {
    _notes.clear();
    _searchQuery.value = '';
    _lastDeletedNote.value = null;
  }

  /// Debug bilgisi
  void printStats() {
    final stats = _syncManager.getStats();
    print('📊 Note Controller Stats:');
    print('  - Local notes: ${_notes.length}');
    print('  - Active notes: ${stats['activeNotes']}');
    print('  - Needs sync: ${stats['needsSyncCount']}');
    print('  - Is syncing: ${stats['isSyncing']}');
    print('  - Is online: ${stats['isOnline']}');
  }
}
