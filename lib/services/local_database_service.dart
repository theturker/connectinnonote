import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

/// Local Database Service - Hive ile offline data yönetimi
/// 
/// Bu servis tüm notları local'de saklar ve hızlı erişim sağlar.
/// Offline-first yaklaşımının temel taşıdır.
class LocalDatabaseService {
  static const String _notesBoxName = 'notes';
  static const String _syncQueueBoxName = 'sync_queue';
  
  Box<Note>? _notesBox;
  Box<Map>? _syncQueueBox;

  /// Hive'ı başlat ve box'ları aç
  Future<void> init() async {
    try {
      // Hive'ı initialize et
      await Hive.initFlutter();
      
      // Note adapter'ını kaydet (sadece bir kez)
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NoteAdapter());
      }
      
      // Box'ları aç
      _notesBox = await Hive.openBox<Note>(_notesBoxName);
      _syncQueueBox = await Hive.openBox<Map>(_syncQueueBoxName);
      
      print('✅ Local Database initialized');
      print('📦 Notes count: ${_notesBox?.length ?? 0}');
      print('🔄 Sync queue count: ${_syncQueueBox?.length ?? 0}');
    } catch (e) {
      print('❌ Local Database initialization error: $e');
      rethrow;
    }
  }

  /// Tüm notları getir (silinen hariç)
  List<Note> getAllNotes({String? userId}) {
    try {
      if (_notesBox == null) {
        print('⚠️ Notes box not initialized');
        return [];
      }
      
      var notes = _notesBox!.values.where((note) => 
        !note.isDeleted && (userId == null || note.userId == userId)
      ).toList();
      
      // En son güncellenen üstte
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return notes;
    } catch (e) {
      print('❌ Get all notes error: $e');
      return [];
    }
  }

  /// ID'ye göre not getir
  Note? getNoteById(String noteId) {
    try {
      if (_notesBox == null) return null;
      
      return _notesBox!.values.firstWhere(
        (note) => note.id == noteId && !note.isDeleted,
        orElse: () => Note(
          id: '',
          title: '',
          content: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userId: '',
        ),
      );
    } catch (e) {
      print('❌ Get note by ID error: $e');
      return null;
    }
  }

  /// Not ekle veya güncelle
  Future<void> saveNote(Note note) async {
    try {
      if (_notesBox == null) {
        print('⚠️ Notes box not initialized');
        return;
      }
      
      // Note'u key olarak ID kullanarak kaydet
      await _notesBox!.put(note.id, note);
      
      print('✅ Note saved to local DB: ${note.id}');
    } catch (e) {
      print('❌ Save note error: $e');
      rethrow;
    }
  }

  /// Not sil (soft delete)
  Future<void> deleteNote(String noteId) async {
    try {
      if (_notesBox == null) {
        print('⚠️ Notes box not initialized');
        return;
      }
      
      final note = getNoteById(noteId);
      if (note != null && note.id.isNotEmpty) {
        // Soft delete - isDeleted flag'ini set et
        final deletedNote = note.copyWith(
          isDeleted: true,
          needsSync: true,
          updatedAt: DateTime.now(),
        );
        
        await _notesBox!.put(noteId, deletedNote);
        print('✅ Note soft deleted: $noteId');
      }
    } catch (e) {
      print('❌ Delete note error: $e');
      rethrow;
    }
  }

  /// Notu kalıcı olarak sil (hard delete)
  Future<void> hardDeleteNote(String noteId) async {
    try {
      if (_notesBox == null) {
        print('⚠️ Notes box not initialized');
        return;
      }
      
      await _notesBox!.delete(noteId);
      print('✅ Note hard deleted: $noteId');
    } catch (e) {
      print('❌ Hard delete note error: $e');
      rethrow;
    }
  }

  /// Sync gereksinimi olan notları getir
  List<Note> getNotesNeedingSync({String? userId}) {
    try {
      if (_notesBox == null) return [];
      
      return _notesBox!.values.where((note) => 
        note.needsSync && (userId == null || note.userId == userId)
      ).toList();
    } catch (e) {
      print('❌ Get notes needing sync error: $e');
      return [];
    }
  }

  /// Sync queue'ya işlem ekle
  Future<void> addToSyncQueue(Map<String, dynamic> syncData) async {
    try {
      if (_syncQueueBox == null) {
        print('⚠️ Sync queue box not initialized');
        return;
      }
      
      final queueItem = {
        ...syncData,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await _syncQueueBox!.add(queueItem);
      print('✅ Added to sync queue: ${syncData['type']}');
    } catch (e) {
      print('❌ Add to sync queue error: $e');
      rethrow;
    }
  }

  /// Sync queue'dan tüm işlemleri getir
  List<Map<String, dynamic>> getSyncQueue() {
    try {
      if (_syncQueueBox == null) return [];
      
      return _syncQueueBox!.values.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    } catch (e) {
      print('❌ Get sync queue error: $e');
      return [];
    }
  }

  /// Sync queue'yu temizle
  Future<void> clearSyncQueue() async {
    try {
      if (_syncQueueBox == null) {
        print('⚠️ Sync queue box not initialized');
        return;
      }
      
      await _syncQueueBox!.clear();
      print('✅ Sync queue cleared');
    } catch (e) {
      print('❌ Clear sync queue error: $e');
      rethrow;
    }
  }

  /// Sync queue'dan belirli bir item'ı sil
  Future<void> removeFromSyncQueue(int index) async {
    try {
      if (_syncQueueBox == null) {
        print('⚠️ Sync queue box not initialized');
        return;
      }
      
      await _syncQueueBox!.deleteAt(index);
      print('✅ Removed from sync queue: index $index');
    } catch (e) {
      print('❌ Remove from sync queue error: $e');
      rethrow;
    }
  }

  /// Tüm local verileri temizle (logout için)
  Future<void> clearAllData() async {
    try {
      await _notesBox?.clear();
      await _syncQueueBox?.clear();
      print('✅ All local data cleared');
    } catch (e) {
      print('❌ Clear all data error: $e');
      rethrow;
    }
  }

  /// Box'ları kapat
  Future<void> close() async {
    try {
      await _notesBox?.close();
      await _syncQueueBox?.close();
      print('✅ Local Database closed');
    } catch (e) {
      print('❌ Close database error: $e');
    }
  }

  /// Database istatistikleri
  Map<String, int> getStats() {
    return {
      'totalNotes': _notesBox?.length ?? 0,
      'activeNotes': getAllNotes().length,
      'syncQueueSize': _syncQueueBox?.length ?? 0,
      'needsSyncCount': getNotesNeedingSync().length,
    };
  }
}

