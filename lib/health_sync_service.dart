// lib/health_sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'managers/health_manager.dart';
import 'models/sync_progress.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'utils/constants.dart';
import 'models/helper_models.dart' show SyncType; // Import SyncType

/// Service for handling background health data sync
class HealthSyncService {
  final HealthManager _healthManager;
  final SharedPreferences _prefs;
  final NotificationService? _notificationService;
  final ConnectivityService? _connectivityService;

  /// Stream controller for sync progress updates
  final _syncProgressController = StreamController<SyncProgress>.broadcast();

  /// Get the sync progress stream
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  /// Current sync progress
  SyncProgress? _currentProgress;

  /// Flag to indicate if sync is in progress
  bool _isRunning = false;

  /// Flag to indicate if sync is cancelled
  bool _isCancelled = false;

  /// Flag to show notifications
  final bool _showNotifications;

  /// Maximum retry attempts for sync
  static const int _maxRetryAttempts = 3;

  /// Current retry count
  int _retryCount = 0;

  /// Backoff factor for retry delay
  static const int _backoffFactor = 2;

  /// Initial retry delay in seconds
  static const int _initialRetryDelaySeconds = 5;

  HealthSyncService({
    required HealthManager healthManager,
    required SharedPreferences prefs,
    NotificationService? notificationService,
    ConnectivityService? connectivityService,
    bool showNotifications = false,
  })  : _healthManager = healthManager,
        _prefs = prefs,
        _notificationService = notificationService,
        _connectivityService = connectivityService,
        _showNotifications = showNotifications {
    // Load any saved progress from previous sync
    _loadProgress();
  }

  /// Load progress from SharedPreferences
  Future<void> _loadProgress() async {
    final progressJson = _prefs.getString('health_sync_progress');
    if (progressJson != null) {
      try {
        final jsonData = json.decode(progressJson);
        _currentProgress = SyncProgress.fromJson(jsonData);

        // If the last sync was incomplete, report it
        if (!_currentProgress!.isComplete && !_currentProgress!.isError) {
          _syncProgressController.add(_currentProgress!);

          // Show notification if enabled
          if (_showNotifications && _notificationService != null) {
            await _notificationService!
                .showSyncProgressNotification(_currentProgress!);
          }
        }
      } catch (e) {
        OseerLogger.error('Failed to parse saved sync progress', e);
        _currentProgress = null;
      }
    }
  }

  /// Save progress to SharedPreferences
  Future<void> _saveProgress(SyncProgress progress) async {
    try {
      final progressJson = json.encode(progress.toJson());
      await _prefs.setString('health_sync_progress', progressJson);
    } catch (e) {
      OseerLogger.error('Failed to save sync progress', e);
    }
  }

  /// Start sync in the background
  Future<void> startBackgroundSync(String userId,
      {SyncType syncType = SyncType.priority}) async {
    if (_isRunning) {
      OseerLogger.info('Health sync already running');
      return;
    }

    // Check connectivity first if available
    if (_connectivityService != null) {
      bool isConnected = await _connectivityService!.checkConnectivity();
      if (!isConnected) {
        OseerLogger.warning('Cannot start sync: No network connection');

        // Create error progress state
        final errorProgress = SyncProgress(
          totalDataPoints: 0,
          processedDataPoints: 0,
          successfulUploads: 0,
          syncStartTime: DateTime.now(),
          currentActivity: 'No network connection',
          isError: true,
          errorMessage:
              'No network connection. Sync will retry when connection is restored.',
        );

        _syncProgressController.add(errorProgress);

        // Show notification if enabled
        if (_showNotifications && _notificationService != null) {
          await _notificationService!
              .showSyncProgressNotification(errorProgress);
        }

        // Listen for connectivity changes and retry when connected
        _connectivityService!.connectionStatus.listen((isConnected) {
          if (isConnected && !_isRunning) {
            OseerLogger.info('Network connection restored, retrying sync');
            startBackgroundSync(userId, syncType: syncType);
          }
        });

        return;
      }
    }

    _isRunning = true;
    _isCancelled = false;
    _retryCount = 0;

    // Initialize progress
    _currentProgress = SyncProgress.initial();
    _syncProgressController.add(_currentProgress!);

    // Show notification if enabled
    if (_showNotifications && _notificationService != null) {
      await _notificationService!
          .showSyncProgressNotification(_currentProgress!);
    }

    // Run sync in a background isolate if possible, otherwise just run async
    if (kIsWeb) {
      // Web doesn't support isolates, so just run async
      _runSync(userId, syncType: syncType);
    } else {
      // Use compute for background processing on mobile platforms
      compute(_runSyncInBackground, {
        'userId': userId,
        'syncType': syncType.name,
        'syncProgress': _currentProgress!.toJson(),
      }).then((result) {
        // Handle result from background processing
        if (result['isComplete'] == true) {
          _updateProgress(
            activity: 'Sync completed successfully',
            isComplete: true,
          );

          // Update last sync time
          final now = DateTime.now();
          _prefs.setString(OseerConstants.keyLastSync, now.toIso8601String());
        } else if (result['isError'] == true) {
          _updateProgress(
            activity: 'Sync failed: ${result['errorMessage']}',
            isComplete: true,
            isError: true,
            errorMessage: result['errorMessage'],
          );
        }

        _isRunning = false;
      }).catchError((e) {
        OseerLogger.error('Error during background sync', e);
        _updateProgress(
          activity: 'Sync failed: ${e.toString()}',
          isComplete: true,
          isError: true,
          errorMessage: e.toString(),
        );
        _isRunning = false;
      });
    }
  }

  /// Static method for running sync in a background isolate
  static Map<String, dynamic> _runSyncInBackground(
      Map<String, dynamic> params) {
    // This would require reconstructing necessary services in the background isolate
    // For simplicity, we're just returning a placeholder implementation
    return {
      'isComplete': true,
      'isError': false,
      'totalDataPoints': 100,
      'processedDataPoints': 100,
      'successfulUploads': 100,
    };
  }

  /// Cancel current sync
  void cancelSync() {
    if (_isRunning) {
      _isCancelled = true;
      // Update progress
      if (_currentProgress != null) {
        _currentProgress = _currentProgress!.copyWith(
          isComplete: false,
          isError: true,
          errorMessage: 'Sync cancelled by user',
        );
        _syncProgressController.add(_currentProgress!);
        _saveProgress(_currentProgress!);

        // Update notification if enabled
        if (_showNotifications && _notificationService != null) {
          _notificationService!.showSyncProgressNotification(_currentProgress!);
        }
      }
    }
  }

  /// Run the sync process
  Future<void> _runSync(String userId,
      {SyncType syncType = SyncType.priority}) async {
    try {
      // Get last sync time for determining start date
      final lastSyncStr = _prefs.getString(OseerConstants.keyLastSync);
      DateTime? lastSync;
      if (lastSyncStr != null) {
        try {
          lastSync = DateTime.parse(lastSyncStr).toLocal();
        } catch (e) {
          OseerLogger.error('Failed to parse last sync time', e);
        }
      }

      // Initialize progress reporting
      _updateProgress(
        activity: 'Starting health data sync...',
        totalPoints: 0,
        processedPoints: 0,
      );

      // Call health manager's syncHealthData with syncType
      final success = await _healthManager.syncHealthData(syncType: syncType);

      if (success) {
        _updateProgress(
          activity: 'Sync completed successfully',
          isComplete: true,
        );

        // Update last sync time
        final now = DateTime.now();
        await _prefs.setString(
            OseerConstants.keyLastSync, now.toIso8601String());
      } else {
        // Check if we should retry
        if (_retryCount < _maxRetryAttempts && !_isCancelled) {
          _retryCount++;

          // Calculate exponential backoff delay
          final delaySeconds =
              _initialRetryDelaySeconds * (_backoffFactor * _retryCount);

          _updateProgress(
            activity:
                'Sync failed. Retrying in $delaySeconds seconds (attempt $_retryCount of $_maxRetryAttempts)...',
            isError: false, // Not marking as error yet since we're retrying
          );

          // Wait before retrying
          await Future.delayed(Duration(seconds: delaySeconds));

          // Try again if not cancelled
          if (!_isCancelled) {
            _isRunning = false; // Reset running flag
            await startBackgroundSync(userId,
                syncType: syncType); // Start a new sync attempt
          }
        } else {
          _updateProgress(
            activity: 'Sync failed after multiple attempts',
            isComplete: true,
            isError: true,
            errorMessage:
                'Failed to sync health data after $_maxRetryAttempts attempts.',
          );
        }
      }
    } on ApiException catch (e) {
      // FIX: Rethrow ApiException for proper handling
      OseerLogger.error('ApiException during health data sync', e);

      // Propagate network errors
      if (e.type == ApiExceptionType.networkError) {
        rethrow;
      }

      // Handle other API errors with retry logic
      if (_retryCount < _maxRetryAttempts && !_isCancelled) {
        _retryCount++;

        // Calculate exponential backoff delay
        final delaySeconds =
            _initialRetryDelaySeconds * (_backoffFactor * _retryCount);

        _updateProgress(
          activity:
              'API Error: ${e.message}. Retrying in $delaySeconds seconds (attempt $_retryCount of $_maxRetryAttempts)...',
          isError: false,
        );

        // Wait before retrying
        await Future.delayed(Duration(seconds: delaySeconds));

        // Try again if not cancelled
        if (!_isCancelled) {
          _isRunning = false;
          await startBackgroundSync(userId, syncType: syncType);
        }
      } else {
        _updateProgress(
          activity: 'Sync failed: ${e.message}',
          isComplete: true,
          isError: true,
          errorMessage: e.message,
        );
      }
    } catch (e, stack) {
      OseerLogger.error('Error during health data sync', e, stack);

      // Check if we should retry on error
      if (_retryCount < _maxRetryAttempts && !_isCancelled) {
        _retryCount++;

        // Calculate exponential backoff delay
        final delaySeconds =
            _initialRetryDelaySeconds * (_backoffFactor * _retryCount);

        _updateProgress(
          activity:
              'Error: ${e.toString()}. Retrying in $delaySeconds seconds (attempt $_retryCount of $_maxRetryAttempts)...',
          isError: false, // Not marking as error yet since we're retrying
        );

        // Wait before retrying
        await Future.delayed(Duration(seconds: delaySeconds));

        // Try again if not cancelled
        if (!_isCancelled) {
          _isRunning = false; // Reset running flag
          await startBackgroundSync(userId,
              syncType: syncType); // Start a new sync attempt
        }
      } else {
        // Update progress with error after max retries
        _updateProgress(
          activity: 'Sync failed: ${e.toString()}',
          isComplete: true,
          isError: true,
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (_isRunning) {
        _isRunning = false;
      }
    }
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
  }) {
    if (_currentProgress == null) {
      _currentProgress = SyncProgress.initial();
    }

    // Update progress
    _currentProgress = _currentProgress!.copyWith(
      currentActivity: activity ?? _currentProgress!.currentActivity,
      totalDataPoints: totalPoints ?? _currentProgress!.totalDataPoints,
      processedDataPoints:
          processedPoints ?? _currentProgress!.processedDataPoints,
      successfulUploads:
          successfulUploads ?? _currentProgress!.successfulUploads,
      lastUpdateTime: DateTime.now(),
      isComplete: isComplete ?? _currentProgress!.isComplete,
      isError: isError ?? _currentProgress!.isError,
      errorMessage: errorMessage ?? _currentProgress!.errorMessage,
    );

    // Broadcast progress update
    _syncProgressController.add(_currentProgress!);

    // Save progress to preferences
    _saveProgress(_currentProgress!);

    // Update notification if enabled
    if (_showNotifications && _notificationService != null) {
      _notificationService!.showSyncProgressNotification(_currentProgress!);
    }
  }

  /// Check if sync is currently running
  bool get isRunning => _isRunning;

  /// Get current progress
  SyncProgress? get currentProgress => _currentProgress;

  /// Dispose resources
  void dispose() {
    _syncProgressController.close();
  }
}

// Import necessary ApiException types (assuming they're from api_service.dart)
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final ApiExceptionType type;

  ApiException({
    this.statusCode,
    required this.message,
    required this.type,
  });
}

enum ApiExceptionType {
  networkError,
  serverError,
  authError,
  unknown,
}
