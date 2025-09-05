// lib/main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/health/health_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'managers/health_manager.dart';
import 'managers/token_manager.dart';
import 'managers/user_manager.dart';
import 'services/api_service.dart' as app_api;
import 'services/auth_service.dart';
import 'services/logger_service.dart';
import 'services/toast_service.dart';
import 'services/secure_storage_service.dart';
import 'services/biometric_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/realtime_sync_service.dart';
import 'services/background_isolate_handler.dart';
import 'services/background_sync_service.dart';
import 'utils/constants.dart';
import 'utils/error_handler.dart';
import 'models/helper_models.dart' as helper;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Initialize logging for the background isolate
    await OseerLogger.init(Level.debug);
    OseerLogger.info("🚀 WorkManager task executing: $taskName");

    if (taskName != OseerConstants.backgroundTaskHistoricalSync) {
      OseerLogger.info("Unknown task: $taskName. Ignoring.");
      return Future.value(true);
    }

    try {
      // Initialize all required services in the isolate
      await BackgroundIsolateHandler.initialize();

      final healthManager = BackgroundIsolateHandler.getHealthManager();
      final apiService = BackgroundIsolateHandler.getApiService();
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString(OseerConstants.keyUserId);
      final deviceId = prefs.getString(OseerConstants.keyDeviceId);

      if (userId == null || deviceId == null) {
        OseerLogger.error(
            "WorkManager: Missing userId or deviceId. Cannot proceed with sync.");
        // Cancel the periodic task since we can't proceed without user context
        await Workmanager().cancelByUniqueName("oseer-historical-sync-monitor");
        return Future.value(true);
      }

      // Fetch the current sync state from the backend (single source of truth)
      OseerLogger.info("📊 Fetching sync state for user $userId");

      Map<String, dynamic>? syncState;
      try {
        final profileResponse = await apiService.getUserProfile(userId);
        final metadata =
            profileResponse['metadata'] as Map<String, dynamic>? ?? {};
        syncState = metadata['historical_sync'] as Map<String, dynamic>?;
      } catch (e) {
        OseerLogger.error("Failed to fetch sync state from backend", e);
        return Future.value(false); // Retry later
      }

      // Check if sync is initialized and not complete
      if (syncState == null) {
        OseerLogger.info(
            "Historical sync not initialized. Cancelling periodic task.");
        await Workmanager().cancelByUniqueName("oseer-historical-sync-monitor");
        return Future.value(true);
      }

      final status = syncState['status'] as String?;
      if (status == 'completed') {
        OseerLogger.info(
            "✅ Historical sync already completed. Cancelling periodic task.");
        await Workmanager().cancelByUniqueName("oseer-historical-sync-monitor");
        return Future.value(true);
      }

      final int currentChunk = syncState['current_chunk'] as int? ?? -1;
      final int totalChunks = syncState['total_chunks'] as int? ?? 13;
      final int nextChunk = currentChunk + 1;

      if (nextChunk >= totalChunks) {
        OseerLogger.info("🎉 All chunks processed. Historical sync complete!");
        await Workmanager().cancelByUniqueName("oseer-historical-sync-monitor");
        return Future.value(true);
      }

      // Check for retry backoff
      final int retryCount = syncState['retry_count'] as int? ?? 0;
      if (retryCount > 0) {
        final lastUpdated = syncState['last_updated'] as String?;
        if (lastUpdated != null) {
          final lastUpdateTime = DateTime.parse(lastUpdated);
          final timeSinceLastAttempt =
              DateTime.now().difference(lastUpdateTime);
          final backoffMinutes = min(30, pow(2, retryCount).toInt());
          final backoffDuration = Duration(minutes: backoffMinutes);

          if (timeSinceLastAttempt < backoffDuration) {
            OseerLogger.info(
                "⏳ Backoff active (retry #$retryCount). Next attempt in ${backoffDuration - timeSinceLastAttempt}");
            return Future.value(
                true); // Skip this execution, try again next period
          }
        }
      }

      OseerLogger.info("📊 Processing chunk #$nextChunk of $totalChunks");

      // Perform the actual health data sync for this chunk
      bool syncSuccess = false;
      try {
        syncSuccess = await healthManager.syncHealthData(
          syncType: helper.SyncType.historical,
          chunkIndex: nextChunk,
        );
      } catch (e, s) {
        OseerLogger.error("Exception during chunk #$nextChunk sync", e, s);
        syncSuccess = false;
      }

      if (!syncSuccess) {
        OseerLogger.warning(
            "Chunk #$nextChunk sync failed. Will retry in next period.");

        // Update retry count in backend
        try {
          await apiService.put('/user/profile/metadata', {
            'historical_sync.retry_count': retryCount + 1,
            'historical_sync.last_updated': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          OseerLogger.error("Failed to update retry count", e);
        }

        return Future.value(
            true); // Don't fail the task, just skip this execution
      }

      // Notify the backend of successful chunk completion
      OseerLogger.info("✅ Chunk #$nextChunk synced. Notifying backend...");

      try {
        await apiService.notifyChunkComplete(
          chunkIndex: nextChunk,
          totalChunks: totalChunks,
          userId: userId,
          deviceId: deviceId,
        );

        OseerLogger.info("✅ Backend acknowledged chunk #$nextChunk");

        if (nextChunk + 1 >= totalChunks) {
          OseerLogger.info(
              "🎉 Final chunk complete! Digital Twin processing triggered.");

          // Mark local completion
          await prefs.setBool(OseerConstants.keyHistoricalSyncComplete, true);
          await prefs.setString(
            OseerConstants.keyHistoricalSyncCompletedAt,
            DateTime.now().toIso8601String(),
          );

          // Cancel the periodic task
          await Workmanager()
              .cancelByUniqueName("oseer-historical-sync-monitor");

          // Show completion notification
          try {
            final notificationService = NotificationService();
            await notificationService.initialize();
            await notificationService.showSyncCompleteNotification(
              title: 'Digital Twin Ready! 🎉',
              message:
                  'Your 90-day wellness profile is complete. Tap to view your insights.',
              duration: Duration(seconds: 10),
            );
          } catch (e) {
            OseerLogger.warning("Failed to show completion notification: $e");
          }
        }
      } catch (e) {
        OseerLogger.error("Failed to notify backend of chunk completion", e);
        // Data is uploaded but notification failed - this is recoverable
        // The next execution will see the updated state and continue
      }

      return Future.value(true);
    } catch (e, s) {
      OseerLogger.error("🔥 Unhandled error in background task", e, s);
      return Future.value(false); // Let WorkManager retry based on its policy
    }
  });
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);

      // 1. Load core dependencies
      try {
        await dotenv.load(fileName: ".env");
        debugPrint('✅ Loaded .env file successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to load .env file: $e. Using fallback values.');
      }

      final prefs = await SharedPreferences.getInstance();
      await OseerLogger.init(kDebugMode ? Level.debug : Level.info);
      OseerLogger.info(
          '🚀 Starting app: ${OseerConstants.appName} v${OseerConstants.appVersion}');

      // Initialize WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      OseerLogger.info('✅ WorkManager initialized');

      await Supabase.initialize(
        url: OseerConstants.supabaseUrl,
        anonKey: OseerConstants.supabaseAnonKey,
        debug: kDebugMode,
        authOptions:
            const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      );
      OseerLogger.info('✅ Supabase initialized');

      final navigatorKey = GlobalKey<NavigatorState>();
      ToastService.init(navigatorKey);
      ErrorHandler.init();

      // 2. Create services
      final apiService = app_api.ApiService(prefs);
      final health = Health();
      final deviceInfo = DeviceInfoPlugin();
      final connectivityService = ConnectivityService();
      final notificationService = NotificationService();
      final secureStorage = SecureStorageService();
      final biometricService = BiometricService(secureStorage: secureStorage);

      final healthManager = HealthManager(
        health: health,
        apiService: apiService,
        prefs: prefs,
        deviceInfo: deviceInfo,
        notificationService: notificationService,
      );

      final deviceId = await healthManager.getDeviceId();
      OseerLogger.info('✅ Device ID established in main: $deviceId');

      // 3. Create Managers
      final userManager = UserManager(prefs, apiService);
      final tokenManager = TokenManager(prefs: prefs);
      final authService = AuthService(
        prefs: prefs,
        secureStorage: secureStorage,
        apiService: apiService,
        biometricService: biometricService,
      );

      await connectivityService.initialize();
      await notificationService.initialize();

      // FIX: Instantiate BackgroundSyncService BEFORE the BLoCs that need it.
      final backgroundSyncService = BackgroundSyncService(
        healthManager: healthManager,
        prefs: prefs,
        notificationService: notificationService,
      );
      OseerLogger.info('✅ BackgroundSyncService initialized');

      // 4. The AuthBloc is created
      final authBloc = AuthBloc(
        authService: authService,
        userManager: userManager,
        prefs: prefs,
        apiService: apiService,
        tokenManager: tokenManager,
        notificationService: notificationService,
        healthManager: healthManager,
        backgroundSyncService: backgroundSyncService, // <-- INJECT THE SERVICE
      );

      // 5. The ConnectionBloc is created
      final connectionBloc = ConnectionBloc(
        healthManager: healthManager,
        apiService: apiService,
        prefs: prefs,
        userManager: userManager,
        backgroundSyncService: backgroundSyncService, // <-- INJECT THE SERVICE
        notificationService: notificationService,
        realtimeSyncService: null,
      );

      // 6. BLoCs are linked
      authBloc.setConnectionBloc(connectionBloc);

      // 7. Realtime service is created and linked
      final realtimeSyncService = RealtimeSyncService(
        supabaseClient: Supabase.instance.client,
        prefs: prefs,
        healthManager: healthManager,
        dispatchConnectionEvent: (event) => connectionBloc.add(event),
        authBloc: authBloc,
        connectivityService: connectivityService,
      );

      connectionBloc.realtimeSyncService = realtimeSyncService;
      connectionBloc.listenToRealtime();
      realtimeSyncService.listenToAuthChanges();

      // 8. Create HealthBloc
      final healthBloc = HealthBloc(
        healthManager: healthManager,
        tokenManager: tokenManager,
        userManager: userManager,
        prefs: prefs,
        connectionBloc: connectionBloc,
        connectivityService: connectivityService,
        notificationService: notificationService,
      );

      // 9. Check for incomplete historical sync on startup
      await _checkAndResumeHistoricalSync(apiService, prefs);

      // 10. REMOVED: The initialization event is now dispatched from app.dart
      // authBloc.add(const AuthInitializeEvent()); // <-- REMOVED TO FIX RACE CONDITION

      OseerLogger.info('✅ All services and BLoCs initialized, starting app');

      // 11. The App is run with all providers
      runApp(
        MultiProvider(
          providers: [
            Provider<SharedPreferences>.value(value: prefs),
            Provider<app_api.ApiService>.value(value: apiService),
            Provider<AuthService>.value(value: authService),
            Provider<TokenManager>.value(value: tokenManager),
            ChangeNotifierProvider<UserManager>.value(value: userManager),
            Provider<HealthManager>.value(value: healthManager),
            Provider<Health>.value(value: health),
            Provider<SecureStorageService>.value(value: secureStorage),
            Provider<BiometricService>.value(value: biometricService),
            Provider<DeviceInfoPlugin>.value(value: deviceInfo),
            Provider<RealtimeSyncService>.value(value: realtimeSyncService),
            Provider<ConnectivityService>.value(value: connectivityService),
            Provider<NotificationService>.value(value: notificationService),
            Provider<BackgroundSyncService>.value(value: backgroundSyncService),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ConnectionBloc>.value(value: connectionBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<HealthBloc>.value(value: healthBloc),
            ],
            child: OseerApp(navigatorKey: navigatorKey),
          ),
        ),
      );
    },
    (error, stack) {
      OseerLogger.fatal('Unhandled error caught by Zone', error, stack);
    },
  );
}

// Helper function to check and resume incomplete historical sync
Future<void> _checkAndResumeHistoricalSync(
  app_api.ApiService apiService,
  SharedPreferences prefs,
) async {
  try {
    final userId = prefs.getString(OseerConstants.keyUserId);
    if (userId == null) return;

    OseerLogger.info('Checking for incomplete historical sync...');

    final profileResponse = await apiService.getUserProfile(userId);
    final metadata = profileResponse['metadata'] as Map<String, dynamic>? ?? {};
    final syncState = metadata['historical_sync'] as Map<String, dynamic>?;

    if (syncState != null && syncState['status'] == 'in_progress') {
      final currentChunk = syncState['current_chunk'] as int? ?? -1;
      final totalChunks = syncState['total_chunks'] as int? ?? 0;

      if (currentChunk < totalChunks - 1) {
        OseerLogger.info(
            '📊 Resuming incomplete historical sync from chunk ${currentChunk + 1}/$totalChunks');

        // Schedule the periodic monitor task
        await Workmanager().registerPeriodicTask(
          "oseer-historical-sync-monitor",
          OseerConstants.backgroundTaskHistoricalSync,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
          existingWorkPolicy: ExistingWorkPolicy.keep,
        );

        OseerLogger.info('✅ Historical sync monitor scheduled');
      }
    }
  } catch (e) {
    OseerLogger.warning('Failed to check historical sync status: $e');
    // Non-critical - app can continue
  }
}
