// lib/managers/health_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/helper_models.dart';
import '../models/user_profile.dart';
import '../models/sync_progress.dart';
import '../services/api_service.dart' as api;
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'health_permission_manager.dart';

const double _fetchWeight = 0.25; // 25%
const double _processWeight = 0.05; // 5%
const double _uploadWeight = 0.70; // 70%

class SyncState {
  final int totalDaysToSync;
  final int chunkSizeInDays;
  final int lastCompletedChunk;

  SyncState({
    required this.totalDaysToSync,
    required this.chunkSizeInDays,
    this.lastCompletedChunk = -1,
  });

  Map<String, dynamic> toJson() => {
        'totalDaysToSync': totalDaysToSync,
        'chunkSizeInDays': chunkSizeInDays,
        'lastCompletedChunk': lastCompletedChunk,
      };

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
        totalDaysToSync: json['totalDaysToSync'] as int,
        chunkSizeInDays: json['chunkSizeInDays'] as int,
        lastCompletedChunk: json['lastCompletedChunk'] as int,
      );

  SyncState copyWith({int? lastCompletedChunk}) {
    return SyncState(
      totalDaysToSync: totalDaysToSync,
      chunkSizeInDays: chunkSizeInDays,
      lastCompletedChunk: lastCompletedChunk ?? this.lastCompletedChunk,
    );
  }
}

class ProcessedData {
  final List<Map<String, dynamic>> metrics;
  final List<Map<String, dynamic>> activities;

  ProcessedData({required this.metrics, required this.activities});
}

class HealthManager {
  final Health _health;
  final api.ApiService _apiService;
  final SharedPreferences _prefs;
  final DeviceInfoPlugin _deviceInfo;
  final NotificationService _notificationService;

  static const MethodChannel _channel =
      MethodChannel('com.oseerapp.healthbridge/health');

  HealthAuthStatus? _healthAuthStatus;
  DateTime? _lastSyncTime;
  String? _deviceId;

  String? _deviceBrand;
  String? _deviceModel;
  String? _deviceOsVersion;

  List<String> _cachedGrantedPermissions = [];
  DateTime? _lastPermissionCheck;

  // Add cancellation support
  bool _syncCancelled = false;

  // Add property for last sync message
  String? lastSyncMessage;

  // Create a public StreamController for progress updates.
  final _progressController = StreamController<SyncProgress>.broadcast();

  // Expose the stream for widgets to listen to.
  Stream<SyncProgress> get onboardingSyncProgressStream =>
      _progressController.stream;

  HealthManager({
    required Health health,
    required api.ApiService apiService,
    required SharedPreferences prefs,
    required DeviceInfoPlugin deviceInfo,
    required NotificationService notificationService,
  })  : _health = health,
        _apiService = apiService,
        _prefs = prefs,
        _deviceInfo = deviceInfo,
        _notificationService = notificationService {
    _initialize();
  }

  api.ApiService get apiService => _apiService;

  Future<void> _initialize() async {
    final lastSyncStr = _prefs.getString(OseerConstants.keyLastSync);
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr)?.toLocal();
    }
    await getDeviceId();
    await _loadDeviceInfo();
    OseerLogger.debug(
        'HealthManager initialized. Device: $_deviceBrand $_deviceModel, OS: $_deviceOsVersion');
  }

  Future<void> _loadDeviceInfo() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceBrand = androidInfo.brand;
        _deviceModel = androidInfo.model;
        _deviceOsVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceBrand = 'Apple';
        _deviceModel = iosInfo.model;
        _deviceOsVersion = iosInfo.systemVersion;
      }
    } catch (e, s) {
      OseerLogger.error('Failed to load device information', e, s);
    }
  }

  Future<String?> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    _deviceId = _prefs.getString(OseerConstants.keyDeviceId);
    if (_deviceId == null) {
      OseerLogger.info('Device ID not found, generating new one.');
      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          _deviceId = 'android-${androidInfo.id}';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          _deviceId = 'ios-${iosInfo.identifierForVendor}';
        } else {
          _deviceId = 'unknown-${const Uuid().v4()}';
        }
      } catch (e) {
        OseerLogger.error(
            'Could not get native device ID, generating UUID.', e);
        _deviceId = 'generated-${const Uuid().v4()}';
      }
      await _prefs.setString(OseerConstants.keyDeviceId, _deviceId!);
    }
    return _deviceId!;
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_deviceBrand == null ||
        _deviceModel == null ||
        _deviceOsVersion == null) {
      await _loadDeviceInfo();
    }

    return {
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'model': _deviceModel ?? 'Unknown Model',
      'brand': _deviceBrand ?? 'Unknown Brand',
      'osVersion': _deviceOsVersion ?? 'Unknown Version',
    };
  }

  Future<HealthAuthStatus> checkWellnessPermissions(
      {bool useCache = true}) async {
    final result = await HealthPermissionManager.checkPermissions();
    return _adaptPermissionResult(result);
  }

  Future<HealthAuthStatus> requestWellnessPermissions(
      {int retryCount = 0}) async {
    final result = await HealthPermissionManager.requestPermissions();
    return _adaptPermissionResult(result);
  }

  HealthAuthStatus _adaptPermissionResult(HealthPermissionResult result) {
    switch (result) {
      case HealthPermissionResult.granted:
        return const HealthAuthStatus(
            status: HealthPermissionStatus.granted, grantedPermissions: []);
      case HealthPermissionResult.partiallyGranted:
        return const HealthAuthStatus(
            status: HealthPermissionStatus.partiallyGranted,
            grantedPermissions: []);
      case HealthPermissionResult.denied:
        return const HealthAuthStatus(
            status: HealthPermissionStatus.denied, grantedPermissions: []);
      case HealthPermissionResult.notAvailable:
        return const HealthAuthStatus(
            status: HealthPermissionStatus.unavailable, grantedPermissions: []);
      case HealthPermissionResult.error:
      default:
        return const HealthAuthStatus(
            status: HealthPermissionStatus.error, grantedPermissions: []);
    }
  }

  List<HealthDataType> _getHistoricalDataTypes() {
    return HealthPermissionManager.allRequestedTypes;
  }

  List<HealthDataType> _getBodyPrepDataTypes() {
    if (Platform.isIOS) {
      return [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.WORKOUT,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
      ];
    } else {
      return [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.WORKOUT,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
      ];
    }
  }

  List<HealthDataType> _getCriticalHealthDataTypes() {
    return [
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
    ];
  }

  Future<Map<String, dynamic>> _checkHealthServicesAvailable() async {
    if (kIsWeb || !Platform.isAndroid)
      return {
        'availability': 'not_available',
        'installed': false,
        'supported': false
      };
    try {
      final result =
          await _channel.invokeMethod('checkHealthConnectAvailability');
      return Map<String, dynamic>.from(result as Map);
    } catch (e, s) {
      OseerLogger.error('Error invoking checkHealthConnectAvailability', e, s);
      return {
        'availability': 'error',
        'installed': false,
        'supported': false,
        'error': e.toString()
      };
    }
  }

  Future<bool> openHealthConnectInstallation() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod('installHealthConnect') as bool? ??
          false;
    } catch (e, s) {
      OseerLogger.error('Error invoking native installHealthConnect', e, s);
      return false;
    }
  }

  Future<bool> openHealthConnectSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod('openHealthConnectSettings')
              as bool? ??
          false;
    } catch (e, s) {
      OseerLogger.error(
          'Error invoking native openHealthConnectSettings', e, s);
      return false;
    }
  }

  Future<void> debugHealthDataAvailability() async {
    OseerLogger.info('--- STARTING HEALTH DATA AVAILABILITY DEBUG ---');
    final now = DateTime.now();
    final ranges = [
      const Duration(hours: 48),
      const Duration(days: 7),
      const Duration(days: 30)
    ];

    final typesToDebug = Platform.isIOS
        ? [
            HealthDataType.HEART_RATE,
            HealthDataType.HEART_RATE_VARIABILITY_SDNN,
            HealthDataType.SLEEP_SESSION,
            HealthDataType.STEPS,
          ]
        : [
            HealthDataType.HEART_RATE,
            HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
            HealthDataType.SLEEP_SESSION,
            HealthDataType.STEPS,
          ];

    for (final type in typesToDebug) {
      OseerLogger.info('--- Checking for ${type.name} ---');
      for (final range in ranges) {
        try {
          final data = await _health.getHealthDataFromTypes(
            startTime: now.subtract(range),
            endTime: now,
            types: [type],
          );
          OseerLogger.info(
              ' -> Last ${range.inDays > 0 ? '${range.inDays} days' : '${range.inHours} hours'}: Found ${data.length} data points.');
        } catch (e) {
          OseerLogger.error(
              ' -> Error fetching for last ${range.inDays} days: $e');
        }
      }
    }
    OseerLogger.info('--- FINISHED HEALTH DATA AVAILABILITY DEBUG ---');
  }

  Future<UserProfile?> extractUserProfileData() async {
    OseerLogger.warning(
        'Profile data extraction is limited on ${Platform.operatingSystem}.');
    if (kIsWeb) return null;
    try {
      final userId = _prefs.getString(OseerConstants.keyUserId);
      if (userId == null) return null;
      final name = _prefs.getString(OseerConstants.keyUserName) ?? '';
      final email = _prefs.getString(OseerConstants.keyUserEmail) ?? '';
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      double? weight, height;
      if (await _health.hasPermissions([HealthDataType.WEIGHT]) ?? false) {
        final data = await _health.getHealthDataFromTypes(
            startTime: oneYearAgo,
            endTime: now,
            types: [HealthDataType.WEIGHT]);
        if (data.isNotEmpty) {
          final value = data.last.value;
          if (value is NumericHealthValue)
            weight = value.numericValue.toDouble();
        }
      }
      if (await _health.hasPermissions([HealthDataType.HEIGHT]) ?? false) {
        final data = await _health.getHealthDataFromTypes(
            startTime: oneYearAgo,
            endTime: now,
            types: [HealthDataType.HEIGHT]);
        if (data.isNotEmpty) {
          final value = data.last.value;
          if (value is NumericHealthValue) {
            height = value.numericValue.toDouble();
            if (height < 3) height *= 100;
          }
        }
      }
      return UserProfile(
          userId: userId,
          name: name,
          email: email,
          weight: weight,
          height: height);
    } catch (e, s) {
      OseerLogger.error('Error extracting user profile data', e, s);
      return null;
    }
  }

  Future<void> _saveSyncState(SyncState state) async {
    await _prefs.setString(
        OseerConstants.keyHistoricalSyncState, json.encode(state.toJson()));
    OseerLogger.info(
        'Sync state saved. Last completed chunk: ${state.lastCompletedChunk}');
  }

  SyncState _loadSyncState() {
    final stateJson = _prefs.getString(OseerConstants.keyHistoricalSyncState);
    if (stateJson != null) {
      try {
        final decoded = json.decode(stateJson);
        OseerLogger.info('Loaded previous sync state: $decoded');
        return SyncState.fromJson(decoded);
      } catch (e) {
        OseerLogger.warning("Could not parse sync state, starting over.", e);
      }
    }
    OseerLogger.info('No previous sync state found, creating new one.');
    return SyncState(totalDaysToSync: 90, chunkSizeInDays: 7);
  }

  Future<void> performOnboardingSync() async {
    _syncCancelled = false;
    var progress = SyncProgress.initial().copyWith(
      currentActivity: 'Your wellness assessment will begin shortly...',
    );
    _progressController.add(progress);
    await _notificationService.showSyncProgressNotification(progress);

    await Future.delayed(const Duration(seconds: 15));
    if (_syncCancelled) {
      _handleCancellation(progress, 'pre-sync');
      return;
    }

    // --- PHASE 1: 48-Hour Sync ---
    bool bodyPrepSyncComplete =
        _prefs.getBool(OseerConstants.keyBodyPrepSyncComplete) ?? false;
    if (!bodyPrepSyncComplete) {
      OseerLogger.info(
          '[Onboarding Sync Phase 1] Starting 48-hour data sync...');
      progress = progress.copyWith(
          currentPhase: 'bodyPrep',
          currentActivity: 'Phase 1: Syncing recent wellness data...');
      _progressController.add(progress);
      await _notificationService.showSyncProgressNotification(progress);

      bool success = await _runSyncForTimeRange(
        startTime: DateTime.now().subtract(const Duration(hours: 48)),
        endTime: DateTime.now(),
        syncType: SyncType.priority,
        onProgress: (syncProgress) {
          _progressController.add(syncProgress);
        },
      );

      if (!success) {
        _handleSyncFailure(
            "Failed to sync recent data. The process will try again later.");
        return;
      }
      await _prefs.setBool(OseerConstants.keyBodyPrepSyncComplete, true);
      OseerLogger.info('[Onboarding Sync] Phase 1 complete.');
    } else {
      OseerLogger.info('[Onboarding Sync Phase 1] Already complete, skipping.');
    }

    // --- PHASE 2: 90-Day Historical Sync (Chunked & Resumable) ---
    SyncState syncState = _loadSyncState();
    final int totalChunks =
        (syncState.totalDaysToSync / syncState.chunkSizeInDays).ceil();
    final int startChunk = syncState.lastCompletedChunk + 1;

    if (startChunk >= totalChunks) {
      OseerLogger.info(
          '[Onboarding Sync Phase 2] All historical chunks already synced.');
    } else {
      progress = progress.copyWith(
        currentPhase: 'digitalTwin',
        bodyPrepProgress: 1.0,
        currentActivity: 'Beginning historical data sync...',
        digitalTwinDaysProcessed: startChunk * syncState.chunkSizeInDays,
      );
      _progressController.add(progress);
      await _notificationService.showSyncProgressNotification(progress);

      for (int i = startChunk; i < totalChunks; i++) {
        if (_syncCancelled) {
          _handleCancellation(progress, 'historical-sync-chunk-$i');
          return;
        }

        final daysFromEnd = i * syncState.chunkSizeInDays;
        final chunkEndDate =
            DateTime.now().subtract(Duration(days: daysFromEnd));
        final chunkStartDate =
            chunkEndDate.subtract(Duration(days: syncState.chunkSizeInDays));
        final daysProcessed = (i + 1) * syncState.chunkSizeInDays;

        progress = progress.copyWith(
          digitalTwinProgress: (i + 1) / totalChunks,
          digitalTwinDaysProcessed: daysProcessed > syncState.totalDaysToSync
              ? syncState.totalDaysToSync
              : daysProcessed,
          currentActivity:
              'Syncing historical data: Week ${i + 1} of $totalChunks...',
        );
        _progressController.add(progress);
        await _notificationService.showSyncProgressNotification(progress);

        OseerLogger.info(
            '[Onboarding Sync] Syncing chunk ${i + 1}/$totalChunks: From $chunkStartDate to $chunkEndDate');

        bool success = await _runSyncForTimeRange(
          startTime: chunkStartDate,
          endTime: chunkEndDate,
          syncType: SyncType.historical,
          onProgress: (syncProgress) {
            _progressController.add(syncProgress);
          },
        );

        if (!success) {
          _handleSyncFailure(
              "A network error occurred. The sync will resume automatically when the app is restarted.");
          return;
        }

        await _saveSyncState(syncState.copyWith(lastCompletedChunk: i));
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    OseerLogger.info('[Onboarding Sync] All phases complete.');

    progress = progress.copyWith(
        isComplete: true,
        currentPhase: 'complete',
        digitalTwinProgress: 1.0,
        digitalTwinDaysProcessed: syncState.totalDaysToSync,
        currentActivity:
            'Data sync complete! We\'ll notify you when your reports are ready.');
    _progressController.add(progress);

    await _prefs.setBool(OseerConstants.keyOnboardingComplete, true);
    await _prefs.setBool(OseerConstants.keyHistoricalSyncComplete, true);
    await _notificationService.dismissSyncNotifications();
    HapticFeedback.heavyImpact();

    await _notificationService.showSyncCompleteNotification(
      title: 'Wellness Data Synced!',
      message: 'Your foundational analysis is now being prepared.',
      duration: DateTime.now().difference(progress.syncStartTime!),
    );
  }

  void _handleCancellation(SyncProgress progress, String context) {
    OseerLogger.info('[$context] Sync cancelled by user.');
    _progressController.add(
        progress.copyWith(currentActivity: 'Sync Cancelled', isError: true));
    _notificationService.dismissSyncNotifications();
  }

  void _handleSyncFailure(String errorMessage) {
    lastSyncMessage = errorMessage;
    final errorProgress = SyncProgress(
      isError: true,
      errorMessage: errorMessage,
      currentPhase: 'error',
      currentActivity: 'Sync failed',
      bodyPrepProgress: 0.0,
      digitalTwinDaysProcessed: 0,
    );
    _progressController.add(errorProgress);
    _notificationService.showSyncProgressNotification(errorProgress);
    HapticFeedback.heavyImpact();
  }

  Future<bool> _runSyncForTimeRange({
    required DateTime startTime,
    required DateTime endTime,
    required SyncType syncType,
    required void Function(SyncProgress) onProgress,
  }) async {
    final bool isPhase1 = syncType == SyncType.priority;

    // At the very beginning of the method
    var progress = SyncProgress(
      currentPhase: isPhase1 ? 'bodyPrep' : 'digitalTwin',
      currentActivity: 'Preparing to sync...',
      bodyPrepProgress: isPhase1 ? 0.0 : 1.0,
      digitalTwinProgress: 0.0,
      syncStartTime: DateTime.now(),
      stage: SyncStage.fetching, // ADD THIS
    );
    onProgress(progress);

    await Future.delayed(const Duration(seconds: 2));

    // --- PRE-FLIGHT CHECK ---
    progress = progress.copyWith(
      currentActivity: 'Checking for new data...',
      stage: SyncStage.fetching,
    );
    onProgress(progress);

    // 1. Fetching Data (25% of the progress)
    progress = progress.copyWith(
      currentActivity: 'Fetching data from your device...',
      bodyPrepProgress: isPhase1 ? _fetchWeight * 0.1 : 1.0,
    );
    onProgress(progress); // ADD THIS

    final typesToFetch =
        isPhase1 ? _getBodyPrepDataTypes() : _getHistoricalDataTypes();
    final allData = await _fetchHealthDataForTypes(typesToFetch,
        startDate: startTime, endDate: endTime);
    final allActivities = await _fetchActivities(startTime, endTime);

    // Report metrics found
    final Map<String, bool> metricsFound = {
      'hrv': allData['HEART_RATE_VARIABILITY_RMSSD']?.isNotEmpty == true ||
          allData['HEART_RATE_VARIABILITY_SDNN']?.isNotEmpty == true,
      'rhr': allData['RESTING_HEART_RATE']?.isNotEmpty == true,
      'sleep': allData['SLEEP_ASLEEP']?.isNotEmpty == true ||
          allData['SLEEP_SESSION']?.isNotEmpty == true,
      'activity': allActivities.isNotEmpty,
      'steps': allData['STEPS']?.isNotEmpty == true,
    };

    // CRITICAL CHECK: Validate data BEFORE uploading
    if (isPhase1) {
      final hrvFound = metricsFound['hrv'] == true;
      final rhrFound = metricsFound['rhr'] == true;
      final sleepFound = metricsFound['sleep'] == true;

      if (!hrvFound || !rhrFound || !sleepFound) {
        final errorMsg =
            "Insufficient recent wellness data found. Oseer needs at least 48 hours of sleep, resting heart rate, and HRV data to provide an accurate score.";
        lastSyncMessage = errorMsg;
        OseerLogger.warning(errorMsg);
        onProgress(SyncProgress.error(errorMsg));
        return false; // Fail fast
      }
    }

    progress = progress.copyWith(
      bodyPrepProgress: isPhase1 ? _fetchWeight : 1.0,
      metricsFound: metricsFound,
      stage: SyncStage.processing, // ADD THIS
      currentActivity: 'Processing health data...',
    );
    onProgress(progress); // ADD THIS

    // 2. Processing Data (5% of the progress)
    progress = progress.copyWith(
        currentActivity: 'Processing health data...',
        stage: SyncStage.processing,
        bodyPrepProgress:
            isPhase1 ? _fetchWeight + (_processWeight * 0.5) : 1.0);
    onProgress(progress);

    if (allData.values.every((list) => list.isEmpty) && allActivities.isEmpty) {
      OseerLogger.info('No new data to upload in time range.');
      return true;
    }

    final userId = _prefs.getString(OseerConstants.keyUserId);
    final deviceId = _deviceId;

    if (userId == null || deviceId == null) {
      OseerLogger.error(
          "Cannot process health data: Missing userId or deviceId.");
      return false;
    }

    final processed = _processHealthData(allData, allActivities);
    final totalDataPoints =
        processed.metrics.length + processed.activities.length;

    progress = progress.copyWith(
        bodyPrepProgress: isPhase1 ? _fetchWeight + _processWeight : 1.0,
        totalDataPoints: totalDataPoints,
        stage: SyncStage.uploading); // ADD THIS
    onProgress(progress); // ADD THIS

    // 3. Uploading Data (70% of the progress)
    progress = progress.copyWith(stage: SyncStage.uploading); // Set stage

    const int uploadChunkSize = 200; // Smaller chunk for more updates
    int totalUploaded = 0;

    try {
      // Upload metrics
      for (int i = 0; i < processed.metrics.length; i += uploadChunkSize) {
        if (_syncCancelled) return false;
        final chunk = processed.metrics.sublist(
            i,
            (i + uploadChunkSize > processed.metrics.length)
                ? processed.metrics.length
                : i + uploadChunkSize);

        OseerLogger.info('Uploading metrics chunk: ${chunk.length} records');

        final success = await _apiService.sendHealthDataBatch(
            chunk, 'raw_health_data_staging');
        if (!success) throw Exception('Failed to upload metrics chunk.');

        totalUploaded += chunk.length;

        // **FIX: More frequent progress updates**
        onProgress(progress.copyWith(
            currentActivity:
                'Uploading metrics (${totalUploaded}/${totalDataPoints})...',
            bodyPrepProgress: isPhase1
                ? (_fetchWeight + _processWeight) +
                    (_uploadWeight * (totalUploaded / totalDataPoints))
                : 1.0,
            processedDataPoints: totalUploaded));
      }

      // Upload activities
      for (int i = 0; i < processed.activities.length; i += uploadChunkSize) {
        if (_syncCancelled) return false;
        final chunk = processed.activities.sublist(
            i,
            (i + uploadChunkSize > processed.activities.length)
                ? processed.activities.length
                : i + uploadChunkSize);

        OseerLogger.info('Uploading activities chunk: ${chunk.length} records');

        final success = await _apiService.sendHealthDataBatch(
            chunk, 'raw_activities_staging');
        if (!success) throw Exception('Failed to upload activities chunk.');

        totalUploaded += chunk.length;

        // **FIX: More frequent progress updates**
        onProgress(progress.copyWith(
            currentActivity:
                'Uploading activities (${totalUploaded}/${totalDataPoints})...',
            bodyPrepProgress: isPhase1
                ? (_fetchWeight + _processWeight) +
                    (_uploadWeight * (totalUploaded / totalDataPoints))
                : 1.0,
            processedDataPoints: totalUploaded));
      }

      // --- After successful upload ---
      progress = progress.copyWith(
        currentActivity: 'Analyzing your data...',
        stage: SyncStage.analyzing,
        bodyPrepProgress: isPhase1 ? 0.95 : 1.0,
      );
      onProgress(progress); // ADD THIS

      await Future.delayed(const Duration(seconds: 1));
      if (_syncCancelled) return false;

      await _apiService.sendHeartbeat();
      await _prefs.setString(
          OseerConstants.keyLastSync, DateTime.now().toUtc().toIso8601String());

      await Future.delayed(const Duration(milliseconds: 500));

      // At the very end of a successful sync
      progress = progress.copyWith(
        bodyPrepProgress: 1.0,
        currentActivity: 'Sync complete!',
        isComplete: true, // Mark as complete
      );
      onProgress(progress); // ADD THIS

      return true;
    } catch (e) {
      OseerLogger.error('Error during data upload stage', e);
      return false;
    }
  }

  Future<bool> syncHealthData({
    SyncType syncType = SyncType.priority,
    int? chunkIndex,
    void Function(SyncProgress)? onProgress,
  }) async {
    final logPrefix = '[HealthManager.syncHealthData]';
    OseerLogger.info(
        '$logPrefix Starting sync for type: ${syncType.name}, chunk: ${chunkIndex ?? 'N/A'}');

    final progressCallback = onProgress ?? (progress) {};

    try {
      if (syncType == SyncType.historical) {
        if (chunkIndex == null) {
          OseerLogger.error(
              '$logPrefix Historical sync requires a chunkIndex.');
          return false;
        }

        final syncState = _loadSyncState();
        final daysFromEnd = chunkIndex * syncState.chunkSizeInDays;
        final chunkEndDate =
            DateTime.now().subtract(Duration(days: daysFromEnd));
        final chunkStartDate =
            chunkEndDate.subtract(Duration(days: syncState.chunkSizeInDays));

        if (daysFromEnd >= syncState.totalDaysToSync) {
          OseerLogger.info(
              '$logPrefix All historical chunks are complete. Stopping chain.');
          await _prefs.setBool(OseerConstants.keyHistoricalSyncComplete, true);
          return true;
        }

        OseerLogger.info(
            '$logPrefix Processing historical chunk ${chunkIndex + 1}: $chunkStartDate to $chunkEndDate');

        final success = await _runSyncForTimeRange(
          startTime: chunkStartDate,
          endTime: chunkEndDate,
          syncType: syncType,
          onProgress: progressCallback,
        );

        if (success) {
          await _saveSyncState(
              syncState.copyWith(lastCompletedChunk: chunkIndex));
        }
        return success;
      } else {
        return await _runSyncForTimeRange(
          startTime: DateTime.now().subtract(const Duration(hours: 48)),
          endTime: DateTime.now(),
          syncType: syncType,
          onProgress: progressCallback,
        );
      }
    } catch (e, s) {
      OseerLogger.error('$logPrefix CRITICAL SYNC FAILURE', e, s);
      return false;
    }
  }

  Future<Map<String, List<HealthDataPoint>>> _fetchHealthDataForTypes(
      List<HealthDataType> typesToFetch,
      {required DateTime startDate,
      required DateTime endDate}) async {
    final result = <String, List<HealthDataPoint>>{};
    for (final typeEnum in typesToFetch) {
      try {
        final List<HealthDataPoint> typeData =
            await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: endDate,
          types: [typeEnum],
        );
        result[typeEnum.name] = typeData;

        if (typeData.isEmpty) {
          if ([
            HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
            HealthDataType.HEART_RATE_VARIABILITY_SDNN,
            HealthDataType.SLEEP_SESSION
          ].contains(typeEnum)) {
            OseerLogger.warning(
                'Fetched 0 points for CRITICAL metric: ${typeEnum.name}. This may indicate no data exists on the device for the selected time range.');
          }
        } else {
          OseerLogger.info(
              'Fetched ${typeData.length} points for ${typeEnum.name}');
        }
      } catch (e, s) {
        OseerLogger.error(
            'Failed to fetch data for type: ${typeEnum.name}', e, s);
        result[typeEnum.name] = [];
      }
    }
    return result;
  }

  Future<List<HealthDataPoint>> _fetchActivities(
      DateTime startDate, DateTime endDate) async {
    try {
      final workoutData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.WORKOUT],
      );
      return workoutData;
    } catch (e, s) {
      OseerLogger.error('Failed to fetch activities', e, s);
      return [];
    }
  }

  String _standardizeActivityType(HealthWorkoutActivityType type) {
    final Map<String, String> knownTypeMappings = {
      'WALKING': 'Walking',
      'RUNNING': 'Running',
      'CYCLING': 'Cycling',
      'ELLIPTICAL': 'Elliptical',
      'ROWER': 'Rowing',
      'STAIR_STEPPER': 'Stair Climbing',
      'HIKING': 'Hiking',
      'SWIMMING': 'Swimming',
      'WHEELCHAIR': 'Wheelchair',
      'OTHER': 'General Activity',
      'AMERICAN_FOOTBALL': 'American Football',
      'ARCHERY': 'Archery',
      'AUSTRALIAN_FOOTBALL': 'Australian Football',
      'BADMINTON': 'Badminton',
      'BASEBALL': 'Baseball',
      'BASKETBALL': 'Basketball',
      'BOWLING': 'Bowling',
      'BOXING': 'Boxing',
      'CLIMBING': 'Climbing',
      'CRICKET': 'Cricket',
      'CROSS_COUNTRY_SKIING': 'Cross Country Skiing',
      'CROSS_TRAINING': 'Cross Training',
      'CURLING': 'Curling',
      'DANCING': 'Dancing',
      'DISC_SPORTS': 'Disc Sports',
      'DOWNHILL_SKIING': 'Downhill Skiing',
      'EQUESTRIAN_SPORTS': 'Equestrian Sports',
      'FENCING': 'Fencing',
      'FISHING': 'Fishing',
      'FUNCTIONAL_STRENGTH_TRAINING': 'Functional Training',
      'GOLF': 'Golf',
      'GYMNASTICS': 'Gymnastics',
      'HANDBALL': 'Handball',
      'HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
      'HOCKEY': 'Hockey',
      'HUNTING': 'Hunting',
      'JUMP_ROPE': 'Jump Rope',
      'KICKBOXING': 'Kickboxing',
      'LACROSSE': 'Lacrosse',
      'MARTIAL_ARTS': 'Martial Arts',
      'MIND_AND_BODY': 'Mind and Body',
      'PADDLE_SPORTS': 'Paddle Sports',
      'PILATES': 'Pilates',
      'PLAY': 'Play',
      'RACQUETBALL': 'Racquetball',
      'ROCK_CLIMBING': 'Rock Climbing',
      'RUGBY': 'Rugby',
      'SAILING': 'Sailing',
      'SKATING': 'Skating',
      'SKATING_SPORTS': 'Skating Sports',
      'SNOWBOARDING': 'Snowboarding',
      'SNOWSPORTS': 'Snow Sports',
      'SOCCER': 'Soccer',
      'SOFTBALL': 'Softball',
      'SQUASH': 'Squash',
      'STAIR_CLIMBING': 'Stair Climbing',
      'STRENGTH_TRAINING': 'Strength Training',
      'SURFING': 'Surfing',
      'TABLE_TENNIS': 'Table Tennis',
      'TAI_CHI': 'Tai Chi',
      'TENNIS': 'Tennis',
      'TRACK_AND_FIELD': 'Track and Field',
      'TRADITIONAL_STRENGTH_TRAINING': 'Traditional Strength Training',
      'VOLLEYBALL': 'Volleyball',
      'WATER_FITNESS': 'Water Fitness',
      'WATER_POLO': 'Water Polo',
      'WATER_SPORTS': 'Water Sports',
      'WRESTLING': 'Wrestling',
      'YOGA': 'Yoga',
    };

    final enumName = type.toString().split('.').last;

    if (knownTypeMappings.containsKey(enumName)) {
      return knownTypeMappings[enumName]!;
    }

    String formatted = enumName
        .replaceAll('WORKOUT_TYPE_', '')
        .replaceAll('WORKOUT_', '')
        .replaceAll('ACTIVITY_TYPE_', '')
        .replaceAll('ACTIVITY_', '')
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ')
        .trim();

    if (formatted.isEmpty) {
      return 'Unknown Activity';
    }

    OseerLogger.info(
        'Unknown workout type encountered: $enumName -> $formatted');

    return formatted;
  }

  ProcessedData _processHealthData(
      Map<String, List<HealthDataPoint>> healthDataMap,
      List<HealthDataPoint> activities) {
    final List<Map<String, dynamic>> metricRecords = [];
    final List<Map<String, dynamic>> activityRecords = [];
    final userId = _prefs.getString(OseerConstants.keyUserId);
    final deviceId = _deviceId;

    if (userId == null || deviceId == null) {
      OseerLogger.error(
          "Cannot process health data: Missing userId or deviceId.");
      return ProcessedData(metrics: [], activities: []);
    }

    healthDataMap.forEach((_, dataPoints) {
      for (final point in dataPoints) {
        if (point.type == HealthDataType.WORKOUT) continue;
        if (point.dateFrom.isAfter(point.dateTo)) continue;

        if (point.dateFrom
            .isAfter(DateTime.now().add(const Duration(hours: 1)))) {
          OseerLogger.warning('Skipping future-dated health point',
              {'date': point.dateFrom.toIso8601String()});
          continue;
        }

        String dataTypeName = point.type.name;
        if (Platform.isIOS &&
            point.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
          dataTypeName = 'HEART_RATE_VARIABILITY_RMSSD';
        }

        final record = <String, dynamic>{
          'user_id': userId,
          'device_id': deviceId,
          'data_type': dataTypeName,
          'unit': point.unit.name,
          'timestamp_from': point.dateFrom.toUtc().toIso8601String(),
          'timestamp_to': point.dateTo.toUtc().toIso8601String(),
          'source_name': point.sourceName,
          'source': point.sourceId,
          'metadata': {
            'device_brand': _deviceBrand,
            'device_model': _deviceModel,
            'device_os_version': _deviceOsVersion,
            'platform': Platform.operatingSystem,
          }
        };

        final value = point.value;
        if (value is NumericHealthValue) {
          final numericVal = value.numericValue.toDouble();

          if (point.type == HealthDataType.HEART_RATE &&
              (numericVal < 30 || numericVal > 220)) {
            OseerLogger.warning(
                'Skipping suspicious heart rate value: $numericVal');
            continue;
          }

          if ((point.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
                  point.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) &&
              (numericVal < 0 || numericVal > 300)) {
            OseerLogger.warning('Skipping suspicious HRV value: $numericVal');
            continue;
          }

          record['value_numeric'] = numericVal;
        } else {
          record['value_text'] = value.toString();
        }
        metricRecords.add(record);
      }
    });

    for (final point in activities) {
      if (point.value is WorkoutHealthValue) {
        final workout = point.value as WorkoutHealthValue;

        final durationInMinutes =
            point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        if (durationInMinutes < 0) {
          OseerLogger.warning("Skipping workout with negative duration.");
          continue;
        }

        activityRecords.add({
          'user_id': userId,
          'device_id': deviceId,
          'start_time': point.dateFrom.toUtc().toIso8601String(),
          'end_time': point.dateTo.toUtc().toIso8601String(),
          'activity_type':
              _standardizeActivityType(workout.workoutActivityType),
          'duration_minutes': durationInMinutes,
          'total_distance_meters': workout.totalDistance,
          'total_energy_burned_kcal': workout.totalEnergyBurned,
          'source': point.sourceId,
          'source_name': point.sourceName,
          'metadata': {
            'device_brand': _deviceBrand,
            'device_model': _deviceModel,
            'device_os_version': _deviceOsVersion,
            'platform': Platform.operatingSystem,
          }
        });
      }
    }

    OseerLogger.info(
        'Processed ${metricRecords.length} metric points and ${activityRecords.length} activity points.');
    return ProcessedData(metrics: metricRecords, activities: activityRecords);
  }

  String? _getMetricColumnName(HealthDataType type) {
    const Map<HealthDataType, String> map = {
      HealthDataType.HEART_RATE: 'heart_rate',
      HealthDataType.RESTING_HEART_RATE: 'resting_heart_rate',
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'hrv',
      HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv',
      HealthDataType.STEPS: 'steps',
      HealthDataType.ACTIVE_ENERGY_BURNED: 'active_energy_burned',
      HealthDataType.BASAL_ENERGY_BURNED: 'basal_energy_burned',
      HealthDataType.SLEEP_ASLEEP: 'sleep_duration',
      HealthDataType.SLEEP_DEEP: 'sleep_duration',
      HealthDataType.SLEEP_REM: 'sleep_duration',
      HealthDataType.SLEEP_LIGHT: 'sleep_duration',
      HealthDataType.SLEEP_SESSION: 'sleep_duration',
      HealthDataType.SLEEP_AWAKE: 'sleep_duration',
      HealthDataType.WEIGHT: 'weight',
      HealthDataType.HEIGHT: 'height',
      HealthDataType.BODY_TEMPERATURE: 'temperature',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
      HealthDataType.DISTANCE_DELTA: 'distance_meters',
      HealthDataType.DISTANCE_WALKING_RUNNING: 'distance_meters',
      HealthDataType.FLIGHTS_CLIMBED: 'flights_climbed',
      HealthDataType.BODY_FAT_PERCENTAGE: 'body_fat_percentage',
      HealthDataType.BODY_WATER_MASS: 'body_water_mass',
      HealthDataType.LEAN_BODY_MASS: 'lean_body_mass',
      HealthDataType.BLOOD_GLUCOSE: 'blood_glucose',
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'blood_pressure_systolic',
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'blood_pressure_diastolic',
      HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
      HealthDataType.WATER: 'water',
      HealthDataType.TOTAL_CALORIES_BURNED: 'total_energy_burned_kcal',
    };
    return map[type];
  }

  void cancelSync() {
    _syncCancelled = true;
  }

  SyncState loadSyncState() {
    return _loadSyncState();
  }

  void dispose() {
    _progressController.close();
  }
}
