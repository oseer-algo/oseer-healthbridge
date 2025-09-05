// lib/services/background_sync_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:health/health.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../managers/health_manager.dart';
import '../models/sync_progress.dart';
import '../models/helper_models.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import '../services/connection_persistence_service.dart';
import '../services/api_service.dart';
import '../services/background_isolate_handler.dart';
import '../utils/constants.dart';

const String _syncPortName = 'oseer.health.sync.port';
const String _historicalSyncTaskName = 'historical-sync-task';

class BackgroundSyncService {
  static const String _syncTaskName = 'oseer.health.sync.background';

  final HealthManager _healthManager;
  final SharedPreferences _prefs;
  final NotificationService _notificationService;
  final ConnectionPersistenceService? _connectionPersistence;

  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  SyncProgress? _currentProgress;
  SyncProgress? get currentProgress => _currentProgress;
  bool _isSyncEnabled = true;
  DateTime? _lastSync;

  BackgroundSyncService({
    required HealthManager healthManager,
    required SharedPreferences prefs,
    required NotificationService notificationService,
    ConnectionPersistenceService? connectionPersistence,
  })  : _healthManager = healthManager,
        _prefs = prefs,
        _notificationService = notificationService,
        _connectionPersistence = connectionPersistence {
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    _isSyncEnabled = _prefs.getBool('health_sync_enabled') ?? true;
    final lastSyncStr = _prefs.getString(OseerConstants.keyLastSync);
    if (lastSyncStr != null) {
      _lastSync = DateTime.tryParse(lastSyncStr);
    }
  }

  static Future<void> initialize() async {
    if (!kIsWeb) {
      await Workmanager()
          .initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    }
  }

  Future<bool> scheduleSync(
      {required String userId, bool forceFullSync = false}) async {
    if (kIsWeb || !_isSyncEnabled) return false;
    final taskId = '${_syncTaskName}_$userId';
    await Workmanager().registerOneOffTask(
      taskId,
      _syncTaskName,
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'userId': userId, 'forceFullSync': forceFullSync},
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    return true;
  }

  Future<void> enqueueHistoricalSync(String userId) async {
    if (kIsWeb) return;

    final uniqueTaskName = 'historical-90-day-sync-$userId';
    OseerLogger.info('Enqueuing historical sync task: $uniqueTaskName');

    // Check if iOS and use iOS-specific background task if available
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For iOS, we need to use BGTaskScheduler instead of WorkManager
      // This would require native iOS implementation
      OseerLogger.warning('iOS background sync not fully implemented yet');
      // TODO: Implement iOS BGTaskScheduler
      return;
    }

    // Android implementation
    await Workmanager().registerOneOffTask(
      uniqueTaskName,
      _historicalSyncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresCharging: true, // Good practice for long tasks
      ),
      inputData: {'userId': userId, 'chunkIndex': 0}, // Start with chunk 0
      existingWorkPolicy:
          ExistingWorkPolicy.keep, // Don't restart if already running
    );
  }

  Future<bool> cancelSync() async {
    if (kIsWeb) return false;
    final userId = _prefs.getString(OseerConstants.keyBackgroundSyncUserId);
    if (userId == null) return false;
    await Workmanager().cancelByUniqueName('${_syncTaskName}_$userId');
    await _notificationService.dismissSyncNotifications();
    _isRunning = false;
    return true;
  }

  Future<bool> startForegroundSync(String userId,
      {bool forceFullSync = false}) async {
    if (_isRunning) return true;
    _isRunning = true;

    try {
      final initialProgress = SyncProgress.initial()
          .copyWith(currentActivity: 'Starting health data sync...');
      _currentProgress = initialProgress;
      _syncProgressController.add(initialProgress);
      await _notificationService.showSyncProgressNotification(initialProgress);

      final result = await _healthManager.syncHealthData(
        syncType: forceFullSync ? SyncType.historical : SyncType.priority,
      );

      if (result) {
        final now = DateTime.now();
        await _prefs.setString(
            OseerConstants.keyLastSync, now.toUtc().toIso8601String());
        _lastSync = now;

        final completeProgress = SyncProgress(
          currentPhase: 'complete',
          currentActivity: 'Sync complete',
          isComplete: true,
          bodyPrepProgress: 1.0,
        );
        _currentProgress = completeProgress;
        _syncProgressController.add(completeProgress);
        await _notificationService
            .showSyncProgressNotification(completeProgress);
      }

      _isRunning = false;
      return result;
    } catch (e) {
      OseerLogger.error('Error in foreground sync', e);
      final errorProgress = SyncProgress.error(e.toString());
      _currentProgress = errorProgress;
      _syncProgressController.add(errorProgress);
      await _notificationService.showSyncProgressNotification(errorProgress);
      _isRunning = false;
      return false;
    }
  }

  Future<void> setSyncEnabled(bool enabled) async {
    _isSyncEnabled = enabled;
    await _prefs.setBool('health_sync_enabled', enabled);
  }

  void dispose() {
    _syncProgressController.close();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // We must initialize all services here because this runs in a separate isolate.
    await BackgroundIsolateHandler.initialize();

    final healthManager = BackgroundIsolateHandler.getHealthManager();
    final prefs = await SharedPreferences.getInstance();

    if (taskName == _historicalSyncTaskName) {
      OseerLogger.info('Background Worker: Starting historical sync task.');

      try {
        final int currentChunk = inputData?['chunkIndex'] as int? ?? 0;
        OseerLogger.info('Background Worker: Processing chunk #$currentChunk');

        // Perform the sync for this specific chunk
        final bool success = await healthManager.syncHealthData(
          syncType: SyncType.historical,
          chunkIndex: currentChunk,
        );

        if (!success) {
          OseerLogger.error(
              'Background Worker: Sync for chunk #$currentChunk failed. The chain will be broken and will retry later.');
          return Future.value(false); // Indicate failure to WorkManager
        }

        // --- THIS IS THE CHAINING LOGIC ---
        final syncState = healthManager.loadSyncState();
        final int nextChunk = currentChunk + 1;
        final int totalChunks =
            (syncState.totalDaysToSync / syncState.chunkSizeInDays).ceil();

        if (nextChunk < totalChunks) {
          // More chunks to process, enqueue the next one.
          final nextTaskName = "oseer-historical-sync-task-$nextChunk";
          OseerLogger.info(
              'Background Worker: Chunk #$currentChunk complete. Enqueuing next task: $nextTaskName');

          await Workmanager().registerOneOffTask(
            nextTaskName,
            _historicalSyncTaskName,
            initialDelay:
                const Duration(seconds: 30), // Small delay between chunks
            inputData: <String, dynamic>{'chunkIndex': nextChunk},
            constraints: Constraints(
              networkType: NetworkType.connected,
              requiresBatteryNotLow: true,
            ),
            existingWorkPolicy: ExistingWorkPolicy.keep,
          );
        } else {
          // All chunks are done.
          OseerLogger.info(
              'Background Worker: All historical sync chunks have been completed successfully!');
          await prefs.setBool(OseerConstants.keyHistoricalSyncComplete, true);
          // Optionally send a final notification
          final notificationService = NotificationService();
          await notificationService.initialize();
          await notificationService.showSyncCompleteNotification(
            title: 'Digital Twin Ready!',
            message:
                'Your 90-day wellness profile is complete and ready to view.',
            duration: Duration(seconds: 5),
          );
        }

        return Future.value(true);
      } catch (e, s) {
        OseerLogger.error(
            'Background Worker: Unhandled exception during historical sync',
            e,
            s);
        return Future.value(false); // Indicate failure
      }
    }

    return Future.value(true);
  });
}
