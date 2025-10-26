import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'note_controller.dart';

class AuthController extends GetxController {
  final RxBool _isLoading = false.obs;
  final RxBool _isLoggedIn = false.obs;
  final RxString _currentUserId = ''.obs;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isLoading => _isLoading.value;
  bool get isLoggedIn => _isLoggedIn.value;
  String get currentUserId => _currentUserId.value;

  @override
  void onInit() {
    super.onInit();
    
    // Önce local session kontrolü yap (offline için)
    _checkLocalSession();
    
    // Firebase Auth durumunu dinle
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _isLoggedIn.value = true;
        _currentUserId.value = user.uid;
        // Local'e kaydet
        _saveLocalSession(user.uid, user.email ?? '');
        // NoteController'a kullanıcı ID'sini gönder
        try {
          final noteController = Get.find<NoteController>();
          noteController.setUserId(_currentUserId.value);
        } catch (e) {
          print('NoteController henüz hazır değil: $e');
        }
      } else {
        // Offline ise local session'ı koru
        _checkLocalSession();
      }
    });
  }
  
  // Local session kontrolü (offline için)
  Future<void> _checkLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      final savedEmail = prefs.getString('user_email');
      
      if (savedUserId != null && savedEmail != null) {
        print('✅ Local session bulundu: $savedEmail');
        _isLoggedIn.value = true;
        _currentUserId.value = savedUserId;
        
        // NoteController'a bildir
        try {
          final noteController = Get.find<NoteController>();
          noteController.setUserId(_currentUserId.value);
        } catch (e) {
          print('NoteController henüz hazır değil: $e');
        }
        
        // Home ekranına yönlendir
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Get.currentRoute == '/login') {
            Get.offAllNamed('/home');
          }
        });
      }
    } catch (e) {
      print('Local session kontrolü hatası: $e');
    }
  }
  
  // Local session'ı kaydet
  Future<void> _saveLocalSession(String userId, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_email', email);
      print('✅ Local session kaydedildi');
    } catch (e) {
      print('Local session kaydetme hatası: $e');
    }
  }
  
  // Local session'ı temizle
  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      print('✅ Local session temizlendi');
    } catch (e) {
      print('Local session temizleme hatası: $e');
    }
  }

  // Remember me kontrolü
  Future<void> _checkRememberedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberedEmail = prefs.getString('remembered_email');
      final rememberedPassword = prefs.getString('remembered_password');
      
      if (rememberedEmail != null && rememberedPassword != null) {
        print('🔥 Hatırlanan kullanıcı bulundu: $rememberedEmail');
        // Otomatik giriş yap
        await login(rememberedEmail, rememberedPassword, rememberMe: true);
      }
    } catch (e) {
      print('🔥 Hatırlanan kullanıcı kontrolü hatası: $e');
    }
  }

  // Remember me bilgilerini kaydet
  Future<void> _saveRememberMe(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_email', email);
      await prefs.setString('remembered_password', password);
      print('🔥 Remember me bilgileri kaydedildi');
    } catch (e) {
      print('🔥 Remember me kaydetme hatası: $e');
    }
  }

  // Remember me bilgilerini temizle
  Future<void> _clearRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
      print('🔥 Remember me bilgileri temizlendi');
    } catch (e) {
      print('🔥 Remember me temizleme hatası: $e');
    }
  }

  // Login işlemi
  Future<void> login(String email, String password, {bool rememberMe = false}) async {
    try {
      _isLoading.value = true;
      print('🔥 Login başladı: $email');
      
      // Firebase Auth ile giriş
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('🔥 Firebase giriş başarılı: ${userCredential.user?.uid}');
      
      if (userCredential.user != null) {
        // Local session'ı kaydet (offline için)
        await _saveLocalSession(userCredential.user!.uid, email);
        
        // Remember me işaretliyse bilgileri kaydet
        if (rememberMe) {
          await _saveRememberMe(email, password);
        }
        
        Get.snackbar(
          'Başarılı',
          'Giriş yapıldı!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // Ana sayfaya yönlendirme
        Get.offAllNamed('/home');
        print('🔥 Ana ekrana yönlendirildi');
      }
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: ${e.code} - ${e.message}');
      String errorMessage = 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu email adresi ile kayıtlı kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
          errorMessage = 'Hatalı şifre.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz email adresi.';
          break;
        case 'user-disabled':
          errorMessage = 'Bu hesap devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          errorMessage = 'Çok fazla başarısız deneme. Lütfen daha sonra tekrar deneyin.';
          break;
      }
      
      Get.snackbar(
        'Hata',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      print('🔥 Genel hata: $e');
      
      // Eğer Firebase giriş başarılı olduysa (type cast hatası olsa bile) başarılı say
      if (e.toString().contains('PigeonUserDetails')) {
        print('🔥 Firebase giriş başarılı ama type cast hatası, başarılı sayılıyor');
        
        // Local session'ı kaydet
        final user = _auth.currentUser;
        if (user != null) {
          await _saveLocalSession(user.uid, email);
        }
        
        // Remember me işaretliyse bilgileri kaydet
        if (rememberMe) {
          await _saveRememberMe(email, password);
        }
        
        Get.snackbar(
          'Başarılı',
          'Giriş yapıldı!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // Ana sayfaya yönlendirme
        Get.offAllNamed('/home');
        print('🔥 Ana ekrana yönlendirildi');
      } else {
        Get.snackbar(
          'Hata',
          'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      _isLoading.value = false;
    }
  }

  // Register işlemi
  Future<void> register(String name, String email, String password, {bool rememberMe = false}) async {
    _isLoading.value = true;
    
    try {
      print('🔥 Register başladı: $email');
      
      // Firebase Auth ile kayıt
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('🔥 Firebase kayıt başarılı: ${userCredential.user?.uid}');
      
      // Local session'ı kaydet (offline için)
      await _saveLocalSession(userCredential.user!.uid, email);
      
      // Remember me işaretliyse bilgileri kaydet
      if (rememberMe) {
        await _saveRememberMe(email, password);
      }
      
      // Firebase kayıt başarılı oldu
      Get.snackbar(
        'Başarılı',
        'Hesabınız oluşturuldu! Giriş yapabilirsiniz.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      print('🔥 Başarılı mesajı gösterildi');
      
      // Ana ekrana yönlendirme
      Get.offAllNamed('/home');
      
      print('🔥 Ana ekrana yönlendirildi');
      
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: ${e.code} - ${e.message}');
      
      String errorMessage = 'Kayıt oluşturulamadı. Lütfen bilgilerinizi kontrol edin.';
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf. Daha güçlü bir şifre seçin.';
          break;
        case 'email-already-in-use':
          errorMessage = 'Bu email adresi zaten kullanımda.';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz email adresi.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/şifre ile kayıt şu anda devre dışı.';
          break;
      }
      
      Get.snackbar(
        'Hata',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      print('🔥 Genel hata: $e');
      
      // Eğer Firebase kayıt başarılı olduysa (type cast hatası olsa bile) başarılı say
      if (e.toString().contains('PigeonUserDetails')) {
        print('🔥 Firebase kayıt başarılı ama type cast hatası, başarılı sayılıyor');
        
        // Local session'ı kaydet
        final user = _auth.currentUser;
        if (user != null) {
          await _saveLocalSession(user.uid, email);
        }
        
        // Remember me işaretliyse bilgileri kaydet
        if (rememberMe) {
          await _saveRememberMe(email, password);
        }
        
        Get.snackbar(
          'Başarılı',
          'Hesabınız oluşturuldu! Giriş yapabilirsiniz.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // Ana ekrana yönlendirme
        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          'Hata',
          'Kayıt oluşturulamadı. Lütfen bilgilerinizi kontrol edin.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      _isLoading.value = false;
    }
  }

  // Logout işlemi
  Future<void> logout() async {
    try {
      await _auth.signOut();
      // Remember me bilgilerini temizle
      await _clearRememberMe();
      // Local session'ı temizle
      await _clearLocalSession();
      
      // State'i temizle
      _isLoggedIn.value = false;
      _currentUserId.value = '';
      
      Get.snackbar(
        'Çıkış',
        'Başarıyla çıkış yapıldı',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.info,
        colorText: Colors.white,
      );
      // Login ekranına yönlendirme
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar(
        'Hata',
        'Çıkış yapılırken bir hata oluştu',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }
}
