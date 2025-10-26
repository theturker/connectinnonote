import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Connectivity Service - Internet bağlantı durumunu yönetir
/// 
/// Bu servis internet bağlantısını dinler ve değişiklikleri bildirir.
/// Offline-first yaklaşımda kritik bir rol oynar.
class ConnectivityService extends GetxController {
  final Connectivity _connectivity = Connectivity();
  final RxBool _isOnline = false.obs;
  final Rx<ConnectivityResult> _connectionStatus = ConnectivityResult.none.obs;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Internet bağlantısı var mı?
  bool get isOnline => _isOnline.value;
  
  /// Internal getter for reactive access (for GetX ever)
  RxBool get isOnlineRx => _isOnline;
  
  /// Bağlantı durumu
  ConnectivityResult get connectionStatus => _connectionStatus.value;
  
  /// Bağlantı tipi (wifi, mobile, vb.)
  String get connectionType {
    switch (_connectionStatus.value) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobil Veri';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      default:
        return 'Bağlantı Yok';
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _listenToConnectivityChanges();
  }

  /// İlk bağlantı durumunu kontrol et
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('❌ Connectivity check error: $e');
      _isOnline.value = false;
    }
  }

  /// Bağlantı değişikliklerini dinle
  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _updateConnectionStatus(result);
      },
      onError: (error) {
        print('❌ Connectivity stream error: $error');
        _isOnline.value = false;
      },
    );
  }

  /// Bağlantı durumunu güncelle
  void _updateConnectionStatus(ConnectivityResult result) {
    _connectionStatus.value = result;
    
    // None dışındaki her şey online kabul edilir
    final wasOnline = _isOnline.value;
    _isOnline.value = result != ConnectivityResult.none;
    
    // Durum değişti mi?
    if (wasOnline != _isOnline.value) {
      if (_isOnline.value) {
        print('📡 Connection: Online ($connectionType)');
        _onConnectionRestored();
      } else {
        print('📡 Connection: Offline');
        _onConnectionLost();
      }
    }
  }

  /// Bağlantı geri geldiğinde
  void _onConnectionRestored() {
    // Sync manager'a haber ver (event bus kullanılabilir)
    Get.find<ConnectivityService>().update();
    
    // UI'a bildir
    Get.snackbar(
      '🌐 Bağlantı Sağlandı',
      'İnternet bağlantısı geri geldi. Senkronizasyon başlıyor...',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      colorText: Colors.white,
      icon: const Icon(Icons.cloud_done, color: Colors.white),
    );
  }

  /// Bağlantı kaybolduğunda
  void _onConnectionLost() {
    // UI'a bildir
    Get.snackbar(
      '📵 Bağlantı Kesildi',
      'Offline modda çalışıyorsunuz. Veriler local\'de saklanacak.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      icon: const Icon(Icons.cloud_off, color: Colors.white),
    );
  }

  /// Manuel bağlantı kontrolü
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isOnline.value;
    } catch (e) {
      print('❌ Manual connectivity check error: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  /// Debug bilgisi
  void printStatus() {
    print('📡 Connectivity Status:');
    print('  - Online: $_isOnline');
    print('  - Type: $connectionType');
    print('  - Status: $_connectionStatus');
  }
}

