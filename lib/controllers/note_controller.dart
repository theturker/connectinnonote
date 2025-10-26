import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../models/note.dart';
import '../constants/app_colors.dart';

class NoteController extends GetxController {
  final RxList<Note> _notes = <Note>[].obs;
  final RxString _searchQuery = ''.obs;
  final RxBool _isLoading = false.obs;
  final RxString _currentUserId = ''.obs;
  final RxBool _showFavoritesOnly = false.obs;
  
  // Silinen notlar için geri alma özelliği
  final RxList<Note> _deletedNotes = <Note>[].obs;
  final Rx<Note?> _lastDeletedNote = Rx<Note?>(null);
  
  // Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Getters
  List<Note> get notes => _notes;
  String get searchQuery => _searchQuery.value;
  bool get isLoading => _isLoading.value;
  String get currentUserId => _currentUserId.value;
  bool get showFavoritesOnly => _showFavoritesOnly.value;
  Note? get lastDeletedNote => _lastDeletedNote.value;

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
      return b.updatedAt.compareTo(a.updatedAt); // En son güncellenen üstte
    });
    
    return notes;
  }

  // Favori notlar
  List<Note> get favoriteNotes {
    return _notes.where((note) => note.isFavorite).toList();
  }

  // Kullanıcı ID'sini ayarla
  Future<void> setUserId(String userId) async {
    _currentUserId.value = userId;
    await _loadNotes(); // Kullanıcı değiştiğinde notları yükle
  }

  // Notları Firestore'dan yükle
  Future<void> _loadNotes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Kullanıcı giriş yapmamış');
        _addWelcomeNote();
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .orderBy('updatedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        _addWelcomeNote();
        return;
      }

      _notes.value = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Firestore document ID'sini ekle
        return Note.fromJson(data);
      }).toList();

      print('Firestore\'dan ${_notes.length} not yüklendi');
    } catch (e) {
      print('Notlar yüklenirken hata: $e');
      _addWelcomeNote();
    }
  }

  // Notları Firestore'a kaydet (artık kullanılmıyor, her işlem ayrı ayrı Firestore'a kaydediliyor)
  Future<void> _saveNotes() async {
    // Bu metod artık kullanılmıyor, her CRUD işlemi ayrı ayrı Firestore'a kaydediliyor
    print('_saveNotes çağrıldı ama artık kullanılmıyor');
  }

  // Hoş geldiniz notunu ekle
  void _addWelcomeNote() {
    final welcomeNote = Note(
      id: 'welcome_device',
      title: 'Hoş Geldiniz',
      content: 'ConnectInNote uygulamasına hoş geldiniz! Bu uygulama ile notlarınızı kolayca yönetebilirsiniz.',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isFavorite: true,
      userId: 'device',
    );
    
    _notes.add(welcomeNote);
    _saveNotes();
  }

  // Arama sorgusunu güncelle
  void updateSearchQuery(String query) {
    _searchQuery.value = query;
  }

  // Arama sorgusunu temizle
  void clearSearch() {
    _searchQuery.value = '';
  }

  // Favori filtresini değiştir
  void toggleFavoritesFilter() {
    _showFavoritesOnly.value = !_showFavoritesOnly.value;
  }

  // Favori filtresini kapat
  void clearFavoritesFilter() {
    _showFavoritesOnly.value = false;
  }

  // Not ekleme
  Future<void> addNote(String title, String content) async {
    try {
      _isLoading.value = true;
      
      print('🔥 addNote başladı: $title');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('🔥 Hata: Kullanıcı giriş yapmamış');
        throw Exception('Kullanıcı giriş yapmamış');
      }

      print('🔥 Kullanıcı ID: ${user.uid}');

      final noteData = {
        'title': title,
        'content': content,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'isFavorite': false,
        'userId': user.uid,
      };

      print('🔥 Firestore\'a kaydediliyor...');

      // Firestore'a kaydet
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .add(noteData);

      print('🔥 Firestore\'a kaydedildi. Document ID: ${docRef.id}');

      // Local listeye ekle
      final newNote = Note(
        id: docRef.id,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: user.uid,
      );
      
      _notes.add(newNote);
      _notes.refresh();
      
      print('🔥 Local listeye eklendi. Toplam not sayısı: ${_notes.length}');
      
      Get.snackbar(
        'Başarılı',
        'Not başarıyla eklendi',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('🔥 Not eklenirken hata: $e');
      Get.snackbar(
        'Hata',
        'Not eklenirken bir hata oluştu: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Not güncelleme
  Future<void> updateNote(String noteId, String title, String content) async {
    try {
      _isLoading.value = true;
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final noteData = {
        'title': title,
        'content': content,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Firestore'da güncelle
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .doc(noteId)
          .update(noteData);

      // Local listeyi güncelle
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex != -1) {
        final updatedNote = _notes[noteIndex].copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );
        _notes[noteIndex] = updatedNote;
        _notes.refresh();
        
        Get.snackbar(
          'Başarılı',
          'Not başarıyla güncellendi',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('Not güncellenirken hata: $e');
      Get.snackbar(
        'Hata',
        'Not güncellenirken bir hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Not silme (geri alma özelliği ile)
  Future<void> deleteNote(String noteId) async {
    try {
      _isLoading.value = true;
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      // Silinecek notu bul
      final noteToDelete = _notes.firstWhere((note) => note.id == noteId);
      
      // Firestore'dan sil
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .doc(noteId)
          .delete();
      
      // Local listeden çıkar
      _notes.removeWhere((note) => note.id == noteId);
      
      // Silinen notu geri alma için sakla
      _deletedNotes.add(noteToDelete);
      _lastDeletedNote.value = noteToDelete;
      
      // Geri alma snackbar'ı göster
      Get.snackbar(
        'Not Silindi',
        'Not başarıyla silindi',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            _undoDelete();
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
    } catch (e) {
      print('Not silinirken hata: $e');
      Get.snackbar(
        'Hata',
        'Not silinirken bir hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Silinen notu geri alma
  Future<void> _undoDelete() async {
    try {
      if (_lastDeletedNote.value != null) {
        final user = _auth.currentUser;
        if (user == null) {
          throw Exception('Kullanıcı giriş yapmamış');
        }

        final note = _lastDeletedNote.value!;
        
        // Firestore'a geri ekle
        final noteData = {
          'title': note.title,
          'content': note.content,
          'createdAt': Timestamp.fromDate(note.createdAt),
          'updatedAt': Timestamp.fromDate(note.updatedAt),
          'isFavorite': note.isFavorite,
          'userId': user.uid,
        };

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(note.id)
            .set(noteData);

        // Local listeye geri ekle
        _notes.add(note);
        _notes.refresh();
        
        // Silinen notlar listesinden çıkar
        _deletedNotes.remove(note);
        _lastDeletedNote.value = null;
        
        Get.snackbar(
          'Geri Alındı',
          'Not başarıyla geri alındı',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('Not geri alınırken hata: $e');
      Get.snackbar(
        'Hata',
        'Not geri alınırken bir hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Manuel geri alma (dışarıdan çağrılabilir)
  Future<void> undoLastDelete() async {
    await _undoDelete();
  }

  // Favori durumunu değiştirme
  Future<void> toggleFavorite(String noteId) async {
    try {
      _isLoading.value = true;
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı giriş yapmamış');
      }

      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex != -1) {
        final note = _notes[noteIndex];
        final updatedNote = note.copyWith(
          isFavorite: !note.isFavorite,
          updatedAt: DateTime.now(),
        );

        // Firestore'da güncelle
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(noteId)
            .update({
          'isFavorite': updatedNote.isFavorite,
          'updatedAt': Timestamp.fromDate(updatedNote.updatedAt),
        });

        // Local listeyi güncelle
        _notes[noteIndex] = updatedNote;
        _notes.refresh();
        
        final message = updatedNote.isFavorite ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı';
        Get.snackbar(
          'Başarılı',
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('Favori durumu değiştirilirken hata: $e');
      Get.snackbar(
        'Hata',
        'Favori durumu değiştirilirken bir hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Tüm notları temizle
  void clearAllNotes() {
    _notes.clear();
    _searchQuery.value = '';
  }
}
