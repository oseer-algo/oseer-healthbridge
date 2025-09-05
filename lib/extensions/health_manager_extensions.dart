// lib/extensions/health_manager_extensions.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../managers/health_manager.dart';
import '../models/sync_progress.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

/// Helper class for managing sync progress
class HealthManagerSyncHelper {
  /// Stream controller for sync progress updates
  static final StreamController<SyncProgress> _syncProgressController =
      StreamController<SyncProgress>.broadcast();

  /// Current sync progress
  static SyncProgress? _currentProgress;

  /// Get the sync progress stream
  static Stream<SyncProgress> get syncProgressStream =>
      _syncProgressController.stream;

  /// Update progress and send to stream
  static void updateProgress(SyncProgress progress) {
    _currentProgress = progress;
    if (!_syncProgressController.isClosed) {
      _syncProgressController.add(progress);
    }
  }

  /// Dispose resources
  static void dispose() {
    _syncProgressController.close();
  }
}

/// Extension methods for HealthManager to provide progress tracking functionality
extension HealthManagerExtensions on HealthManager {
  /// Sync health data with progress reporting
  Future<bool> syncWellnessDataWithProgress({
    DateTime? fromDate,
    NotificationService? notificationService,
    bool showNotifications = false,
    SharedPreferences? prefs,
  }) async {
    // Initialize progress tracking
    HealthManagerSyncHelper._currentProgress = SyncProgress.initial();
    HealthManagerSyncHelper.updateProgress(
        HealthManagerSyncHelper._currentProgress!);

    // Show initial notification if needed
    if (showNotifications && notificationService != null) {
      await notificationService.showSyncProgressNotification(
          HealthManagerSyncHelper._currentProgress!);
    }

    try {
      // Get the time range for sync
      final startDate = fromDate ?? _getDefaultStartDate();
      final endDate = DateTime.now();

      // Update progress
      _updateProgress(
        activity: 'Retrieving health data...',
        prefs: prefs,
        notificationService: showNotifications ? notificationService : null,
      );

      // Call the correct method name
      final result = await syncHealthData();

      // Simulate progress updates since the base method doesn't support callbacks
      _updateProgress(
        totalPoints: 100,
        processedPoints: 100,
        activity: 'Processing health data...',
        prefs: prefs,
        notificationService: showNotifications ? notificationService : null,
      );

      if (result) {
        // Update final progress
        _updateProgress(
          activity: 'Sync completed successfully',
          isComplete: true,
          prefs: prefs,
          notificationService: showNotifications ? notificationService : null,
        );

        // Update last sync time
        if (prefs != null) {
          final now = DateTime.now();
          await prefs.setString(
              OseerConstants.keyLastSync, now.toIso8601String());
        }

        return true;
      } else {
        // Update error progress
        _updateProgress(
          activity: 'Sync failed',
          isComplete: true,
          isError: true,
          errorMessage: 'Failed to sync health data.',
          prefs: prefs,
          notificationService: showNotifications ? notificationService : null,
        );
        return false;
      }
    } catch (e, stack) {
      OseerLogger.error('Error syncing health data with progress', e, stack);

      // Update error progress
      _updateProgress(
        activity: 'Sync error',
        isComplete: true,
        isError: true,
        errorMessage: e.toString(),
        prefs: prefs,
        notificationService: showNotifications ? notificationService : null,
      );
      return false;
    }
  }

  /// Start background sync process
  Future<bool> startBackgroundSync(
      {String? userId,
      SharedPreferences? prefs,
      NotificationService? notificationService}) async {
    // This is an extension method we're adding to HealthManager
    // to support background sync requested in onboarding_screen.dart
    OseerLogger.info('Starting background sync via extension...');

    try {
      // Simply call our progress-tracking sync method
      return await syncWellnessDataWithProgress(
        fromDate: DateTime.now().subtract(const Duration(days: 90)),
        showNotifications: notificationService != null,
        notificationService: notificationService,
        prefs: prefs,
      );
    } catch (e, stack) {
      OseerLogger.error('Error starting background sync', e, stack);
      return false;
    }
  }

  /// Get default start date (90 days ago)
  DateTime _getDefaultStartDate() {
    final now = DateTime.now();
    return now.subtract(const Duration(days: 90));
  }

  /// Update sync progress
  void _updateProgress({
    String? activity,
    int? totalPoints,
    int? processedPoints,
    int? successfulUploads,
    bool? isComplete,
    bool? isError,
    String? errorMessage,
    SharedPreferences? prefs,
    NotificationService? notificationService,
  }) {
    if (HealthManagerSyncHelper._currentProgress == null) {
      HealthManagerSyncHelper._currentProgress = SyncProgress.initial();
    }

    // Update progress
    HealthManagerSyncHelper._currentProgress =
        HealthManagerSyncHelper._currentProgress!.copyWith(
      currentActivity: activity,
      totalDataPoints: totalPoints ??
          HealthManagerSyncHelper._currentProgress!.totalDataPoints,
      processedDataPoints: processedPoints ??
          HealthManagerSyncHelper._currentProgress!.processedDataPoints,
      successfulUploads: successfulUploads ??
          HealthManagerSyncHelper._currentProgress!.successfulUploads,
      lastUpdateTime: DateTime.now(),
      isComplete:
          isComplete ?? HealthManagerSyncHelper._currentProgress!.isComplete,
      isError: isError ?? HealthManagerSyncHelper._currentProgress!.isError,
      errorMessage: errorMessage,
    );

    // Broadcast progress update
    HealthManagerSyncHelper.updateProgress(
        HealthManagerSyncHelper._currentProgress!);

    // Save progress to preferences if provided
    if (prefs != null) {
      _saveProgress(prefs, HealthManagerSyncHelper._currentProgress!);
    }

    // Update notification if enabled
    if (notificationService != null) {
      notificationService.showSyncProgressNotification(
          HealthManagerSyncHelper._currentProgress!);
    }
  }

  /// Save progress to SharedPreferences
  Future<void> _saveProgress(
      SharedPreferences prefs, SyncProgress progress) async {
    try {
      final progressJson = progress.toJson();
      await prefs.setString('health_sync_progress', progressJson.toString());
    } catch (e) {
      OseerLogger.error('Failed to save sync progress', e);
    }
  }
}
