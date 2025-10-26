import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/app_colors.dart';
import 'controllers/auth_controller.dart';
import 'controllers/note_controller.dart';
import 'services/local_database_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_manager.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 1. Firebase'i başlat
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // 2. Local Database'i başlat
    print('💾 Initializing Local Database...');
    final localDb = LocalDatabaseService();
    await localDb.init();
    print('✅ Local Database initialized');
    
    // 3. Servisleri GetX'e kaydet
    print('🔧 Setting up services...');
    
    // Local DB'yi dependency olarak kaydet
    Get.put(localDb, permanent: true);
    
    // Connectivity Service
    Get.put(ConnectivityService(), permanent: true);
    
    // Sync Manager (localDb ve connectivity'ye bağımlı)
    Get.put(
      SyncManager(
        Get.find<LocalDatabaseService>(),
        Get.find<ConnectivityService>(),
      ),
      permanent: true,
    );
    
    print('✅ Services initialized');
    
    // 4. Uygulamayı başlat
    runApp(const MyApp());
  } catch (e) {
    print('❌ Initialization error: $e');
    // Hata durumunda bile uygulamayı başlat
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller'ları başlat
    Get.put(AuthController());
    Get.put(NoteController());
    
    return GetMaterialApp(
      title: 'ConnectInNote',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      getPages: [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/home', page: () => const HomeScreen()),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
