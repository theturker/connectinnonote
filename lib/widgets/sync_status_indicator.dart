import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sync_manager.dart';
import '../services/connectivity_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Sync Status Indicator - Senkronizasyon durumunu gösteren widget
/// 
/// Offline/online durumu ve sync progress'i gösterir
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final syncManager = Get.find<SyncManager>();
    final connectivity = Get.find<ConnectivityService>();

    return Obx(() {
      // Sync durumu
      if (syncManager.isSyncing) {
        return _buildSyncingIndicator(syncManager);
      }

      // Offline durumu
      if (!connectivity.isOnline) {
        return _buildOfflineIndicator();
      }

      // Online ve idle - gösterme
      return const SizedBox.shrink();
    });
  }

  /// Senkronizasyon devam ediyor göstergesi
  Widget _buildSyncingIndicator(SyncManager syncManager) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => Text(
            'Senkronize ediliyor... (${syncManager.syncProgress}/${syncManager.totalSyncItems})',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          )),
        ],
      ),
    );
  }

  /// Offline durumu göstergesi
  Widget _buildOfflineIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text(
            'Offline Mode',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Sync Button - Manuel sync tetikleme butonu
class FloatingSyncButton extends StatelessWidget {
  const FloatingSyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final syncManager = Get.find<SyncManager>();
    final connectivity = Get.find<ConnectivityService>();

    return Obx(() {
      // Offline ise gösterme
      if (!connectivity.isOnline) {
        return const SizedBox.shrink();
      }

      // Sync devam ediyorsa gösterme
      if (syncManager.isSyncing) {
        return const SizedBox.shrink();
      }

      // Sync gerekmeyen notlar varsa butonu göster
      return FloatingActionButton(
        mini: true,
        backgroundColor: AppColors.primary.withOpacity(0.9),
        onPressed: () async {
          await syncManager.manualSync();
        },
        child: const Icon(
          Icons.sync,
          color: Colors.white,
          size: 20,
        ),
      );
    });
  }
}

