// lib/blocs/connection/connection_bloc.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import '../../managers/health_manager.dart';
import '../../managers/user_manager.dart';
import '../../services/api_service.dart' as app_api;
import '../../services/background_sync_service.dart';
import '../../services/logger_service.dart';
import '../../services/notification_service.dart';
import '../../services/realtime_sync_service.dart';
import '../../services/toast_service.dart';
import '../../utils/constants.dart';
import '../../models/helper_models.dart' as helper;
import '../../models/sync_progress.dart';
import '../../models/realtime_status.dart';
import './connection_event.dart';
import './connection_state.dart';

export 'connection_event.dart';
export 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final HealthManager healthManager;
  final app_api.ApiService apiService;
  final SharedPreferences prefs;
  final UserManager userManager;
  final BackgroundSyncService? backgroundSyncService;
  final NotificationService? notificationService;
  RealtimeSyncService? realtimeSyncService;

  StreamSubscription? _realtimeStatusSubscription;
  StreamSubscription? _syncProgressSubscription;
  Timer? _retryTimer;
  Timer? _handoffTimeoutTimer;
  Timer? _handoffCheckTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  bool _isSyncLocked = false;
  PerformSyncEvent? _currentSyncEvent;

  ConnectionBloc({
    required this.healthManager,
    required this.apiService,
    required this.prefs,
    required this.userManager,
    this.backgroundSyncService,
    this.notificationService,
    this.realtimeSyncService,
  }) : super(const ConnectionState(status: ConnectionStatus.disconnected)) {
    if (realtimeSyncService != null) {
      listenToRealtime();
    }

    _syncProgressSubscription =
        healthManager.onboardingSyncProgressStream.listen((progress) {
      add(SyncProgressUpdatedEvent(progress));
    });

    on<ConnectToWebPressed>(_onConnectToWebPressed);
    on<LaunchWellnessHubEvent>(_onLaunchWellnessHub);
    on<ConnectionEstablishedViaWebWithTokenEvent>(
        _onConnectionEstablishedViaWebWithToken);
    on<PerformSyncEvent>(_onPerformSync);
    on<SyncProgressUpdatedEvent>(_onSyncProgressUpdated);
    on<TriggerHistoricalSyncEvent>(_onTriggerHistoricalSync);
    on<RealtimeStatusChangedEvent>(_onRealtimeStatusChanged);
    on<ConnectionEstablishedViaDeeplink>(_onConnectionEstablishedViaDeeplink);
    on<RetrySyncEvent>(_onRetrySync);
    on<DisconnectEvent>(_onDisconnect);
    on<SyncAnalysisCompletedEvent>(_onSyncAnalysisCompleted);
    on<FinalizeHandoffConnection>(_onFinalizeHandoffConnection);
    on<ConnectionEstablishedViaWebEvent>(_onConnectionEstablishedViaWeb);
    on<ServerProcessingCompleted>(_onServerProcessingCompleted);
    on<HandoffTimedOut>(_onHandoffTimedOut);
    on<CheckHandoffStatusOnResume>(_onCheckHandoffStatusOnResume);
  }

  void listenToRealtime() {
    OseerLogger.info("ConnectionBloc setting up realtime listener");
    _realtimeStatusSubscription?.cancel();
    _realtimeStatusSubscription =
        realtimeSyncService?.statusStream.listen((status) {
      add(RealtimeStatusChangedEvent(status));
      if (status == RealtimeStatus.error) {
        emit(state.copyWith(
            status: ConnectionStatus.error,
            errorMessage: realtimeSyncService?.lastError ??
                'Realtime connection failed.'));
      }
    });
  }

  Future<void> _onFinalizeHandoffConnection(
    FinalizeHandoffConnection event,
    Emitter<ConnectionState> emit,
  ) async {
    OseerLogger.info('🔗 Finalizing handoff connection...');
    emit(state.copyWith(
      status: ConnectionStatus.connecting,
      isAwaitingWebValidation: true,
      errorMessage: null,
    ));

    _handoffCheckTimer?.cancel();
    _handoffCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.isAwaitingWebValidation ||
          state.status == ConnectionStatus.connecting) {
        add(const CheckHandoffStatusOnResume());
      } else {
        timer.cancel();
      }
    });

    _handoffTimeoutTimer?.cancel();
    _handoffTimeoutTimer = Timer(const Duration(minutes: 2), () {
      _handoffCheckTimer?.cancel();
      add(const HandoffTimedOut());
    });
  }

  Future<void> _onCheckHandoffStatusOnResume(
      CheckHandoffStatusOnResume event, Emitter<ConnectionState> emit) async {
    if (!state.isAwaitingWebValidation &&
        state.status != ConnectionStatus.connecting) {
      return;
    }

    OseerLogger.info(
        '🔍 [Self-Healing] Checking handoff status with server...');
    try {
      final deviceId = await healthManager.getDeviceId();
      if (deviceId == null) return;

      final response = await apiService
          .postWithRetry('/auth/check-handoff-status', {'deviceId': deviceId});

      if (response['success'] == true && response['status'] == 'completed') {
        OseerLogger.info(
            '✅ [Self-Healing] Handoff was already complete. Finalizing connection.');

        final userId = userManager.getUserId()!;

        add(ConnectionEstablishedViaWebWithTokenEvent(
          userId: userId,
          deviceId: deviceId,
          connectionToken: response['connectionToken'],
        ));
      } else {
        OseerLogger.info(
            '🧘 [Self-Healing] Handoff is still pending. Continuing to poll...');
      }
    } catch (e) {
      OseerLogger.error('[Self-Healing] Failed to check handoff status', e);
    }
  }

  Future<void> _onConnectionEstablishedViaWebWithToken(
      ConnectionEstablishedViaWebWithTokenEvent event,
      Emitter<ConnectionState> emit) async {
    OseerLogger.info('✅ Connection confirmed via realtime with token');

    _handoffTimeoutTimer?.cancel();
    _handoffCheckTimer?.cancel();

    await prefs.setBool(OseerConstants.keyIsConnected, true);
    await prefs.setString(
        OseerConstants.keyConnectionToken, event.connectionToken);

    emit(state.copyWith(
      status: ConnectionStatus.connected,
      userId: event.userId,
      deviceId: event.deviceId,
      isAwaitingWebValidation: false,
    ));

    OseerLogger.info('Starting Phase 1 sync after successful connection...');
    add(const PerformSyncEvent(syncType: helper.SyncType.priority));
  }

  Future<void> _onHandoffTimedOut(
    HandoffTimedOut event,
    Emitter<ConnectionState> emit,
  ) async {
    OseerLogger.warning('Handoff timed out after 2 minutes');
    _handoffTimeoutTimer?.cancel();
    _handoffCheckTimer?.cancel();

    if (state.isAwaitingWebValidation) {
      emit(state.copyWith(
        status: ConnectionStatus.error,
        isAwaitingWebValidation: false,
        errorMessage: 'Connection timed out. Please try again.',
      ));
    }
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel();
    _handoffTimeoutTimer?.cancel();
    _handoffCheckTimer?.cancel();
    _realtimeStatusSubscription?.cancel();
    _syncProgressSubscription?.cancel();
    return super.close();
  }

  Future<void> _onConnectToWebPressed(
      ConnectToWebPressed event, Emitter<ConnectionState> emit) async {
    OseerLogger.info("🌐 User initiating web connection");
    emit(state.copyWith(isAwaitingWebValidation: true, errorMessage: null));

    try {
      final deviceId = await healthManager.getDeviceId();
      if (deviceId == null) throw Exception('Device ID is missing');

      await prefs.setBool(OseerConstants.keyAwaitingWebHandoff, true);

      OseerLogger.info("Generating handoff token for web connection...");

      final handoffToken = await apiService.generateHandoffToken(
        deviceId: deviceId,
        purpose: 'link',
      );

      if (handoffToken == null)
        throw Exception('Failed to generate handoff token');

      final handoffUrl = Uri.parse(
          '${OseerConstants.webAppBaseUrl}/auth/handoff?token=$handoffToken');

      if (!await launchUrl(handoffUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser');
      }

      OseerLogger.info('🚀 Browser launched for handoff');
    } catch (e, s) {
      OseerLogger.error('❌ Failed to initiate handoff', e, s);
      await prefs.remove(OseerConstants.keyAwaitingWebHandoff);
      emit(state.copyWith(
        isAwaitingWebValidation: false,
        errorMessage: 'Connection failed. Please try again.',
      ));
    }
  }

  Future<void> _onConnectionEstablishedViaDeeplink(
    ConnectionEstablishedViaDeeplink event,
    Emitter<ConnectionState> emit,
  ) async {
    OseerLogger.info('🔗 Deep Link received - connection flow continuing');
  }

  Future<void> _onConnectionEstablishedViaWeb(
    ConnectionEstablishedViaWebEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    OseerLogger.info('✅ Connection established via web (without token)');
    emit(state.copyWith(
      status: ConnectionStatus.connected,
      userId: event.userId,
      deviceId: event.deviceId,
      isAwaitingWebValidation: false,
    ));
  }

  Future<void> _onLaunchWellnessHub(
      LaunchWellnessHubEvent event, Emitter<ConnectionState> emit) async {
    OseerLogger.info('🚀 Launching Wellness Hub');

    if (state.status == ConnectionStatus.prioritySyncComplete) {
      OseerLogger.info('Starting Phase 2 background sync');

      final userId = userManager.getUserId();
      if (userId != null && backgroundSyncService != null) {
        await backgroundSyncService!.enqueueHistoricalSync(userId);
      }

      emit(state.copyWith(
          status: ConnectionStatus.historicalSyncInProgress,
          wellnessPhase: WellnessPhase.digitalTwin));
    }

    try {
      final deviceId = await healthManager.getDeviceId();
      if (deviceId == null) {
        throw Exception('Device ID missing');
      }

      final handoffToken = await apiService.generateHandoffToken(
        deviceId: deviceId,
        purpose: 'login',
      );

      if (handoffToken == null) {
        throw Exception('Failed to generate login token');
      }

      final url = Uri.parse(
          '${OseerConstants.webAppBaseUrl}/auth/handoff?token=$handoffToken&redirect_target=/dashboard');

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser');
      }
    } catch (e, s) {
      OseerLogger.error('❌ Failed to launch Wellness Hub', e, s);
      ToastService.error('Could not open Wellness Hub');
    }
  }

  Future<void> _onPerformSync(
      PerformSyncEvent event, Emitter<ConnectionState> emit) async {
    _retryTimer?.cancel();
    _retryTimer = null;

    if (_isSyncLocked) {
      OseerLogger.warning(
          "Sync already in progress, ignoring new request for ${event.syncType.name}");
      return;
    }

    _isSyncLocked = true;
    _currentSyncEvent = event;
    _retryCount = 0;

    OseerLogger.info("⚡️ Starting ${event.syncType.name} sync (lock acquired)");

    try {
      await _performSyncWithRetry(event, emit);
    } catch (e, s) {
      OseerLogger.error("Unhandled error in sync", e, s);
      emit(state.copyWith(
        status: ConnectionStatus.syncFailed,
        isSyncing: false,
        errorMessage: 'Sync failed unexpectedly. Please try again.',
      ));
    } finally {
      _isSyncLocked = false;
      _currentSyncEvent = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      OseerLogger.info("🔓 Sync lock released for ${event.syncType.name}");
    }
  }

  Future<void> _performSyncWithRetry(
      PerformSyncEvent event, Emitter<ConnectionState> emit) async {
    try {
      final userId = state.userId ?? userManager.getUserId();
      final deviceId = state.deviceId ?? await healthManager.getDeviceId();

      if (userId == null || deviceId == null) {
        throw Exception('Missing userId or deviceId');
      }

      if (event.syncType == helper.SyncType.priority && _retryCount == 0) {
        emit(state.copyWith(
            status: ConnectionStatus.syncIntro,
            isSyncing: true,
            wellnessPhase: WellnessPhase.intro,
            errorMessage: null));

        notificationService?.showNotification(
          title: "Wellness Analysis Starting",
          message: "Preparing your Body Preparedness assessment...",
        );

        await Future.delayed(const Duration(seconds: 8));
      }

      emit(state.copyWith(
          status: ConnectionStatus.syncing,
          isSyncing: true,
          wellnessPhase: event.syncType == helper.SyncType.priority
              ? WellnessPhase.bodyPrep
              : WellnessPhase.digitalTwin,
          errorMessage: null));

      final bool syncSuccess = await healthManager.syncHealthData(
        syncType: event.syncType,
        onProgress: (progress) {
          add(SyncProgressUpdatedEvent(progress));
        },
      );

      // FIXED: Handle insufficient data case properly
      if (!syncSuccess) {
        // Check if the failure was due to insufficient data
        if (healthManager.lastSyncMessage != null &&
            healthManager.lastSyncMessage!.contains("Insufficient")) {
          OseerLogger.info(
              'Phase 1 failed due to insufficient data. Emitting HistoricalSyncReady.');
          emit(state.copyWith(
            status: ConnectionStatus.historicalSyncReady,
            isSyncing: false,
            errorMessage: healthManager.lastSyncMessage,
          ));
        } else {
          // It was a different kind of failure (e.g., network)
          emit(state.copyWith(
            status: ConnectionStatus.syncFailed,
            isSyncing: false,
            errorMessage:
                healthManager.lastSyncMessage ?? "A sync error occurred.",
          ));
        }
        return; // Stop the process here
      }

      emit(state.copyWith(
          status: ConnectionStatus.processing,
          isSyncing: false,
          wellnessPhase: WellnessPhase.bodyPrep));

      OseerLogger.info('✅ Data upload complete - triggering backend analysis');

      final bool orchestrationSuccess =
          await apiService.triggerSyncOrchestration(event.syncType.name);

      if (!orchestrationSuccess) {
        throw app_api.ApiException(
          statusCode: 500,
          message: 'Failed to start analysis. Retrying...',
          type: app_api.ApiExceptionType.serverError,
        );
      }

      OseerLogger.info(
          '✅ Backend analysis triggered. Waiting for Realtime confirmation...');

      notificationService?.showNotification(
        title: "Processing Your Data",
        message: "Analyzing your wellness metrics...",
      );

      final now = DateTime.now();
      await prefs.setString(
          OseerConstants.keyLastSync, now.toUtc().toIso8601String());

      if (event.syncType == helper.SyncType.priority) {
        OseerLogger.info(
            'Phase 1 sync complete. Preparing for Phase 2 initialization...');

        try {
          await apiService.invokeFunction('initialize-historical-sync', {});
          OseerLogger.info('✅ Historical sync state initialized');

          await prefs.remove('phase2_initialization_failed');
          await prefs.remove('phase2_retry_count');

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
        } catch (e, s) {
          OseerLogger.error(
            "Failed to initialize historical sync (non-critical).",
            e,
            s,
          );

          await prefs.setBool('phase2_initialization_failed', true);
          final retryCount = prefs.getInt('phase2_retry_count') ?? 0;
          await prefs.setInt('phase2_retry_count', retryCount);

          ToastService.info(
              'Initial sync complete. Full history will sync in background.');
        }

        OseerLogger.info('Waiting for backend analysis to complete...');
      } else {
        emit(state.copyWith(isSyncing: false, lastSyncTime: now));
      }
    } on app_api.ApiException catch (e) {
      OseerLogger.error('API error during sync', e);
      await _handleSyncError(e, event, emit);
    } catch (e, s) {
      OseerLogger.error('Unexpected error during sync', e, s);
      await _handleSyncError(
          app_api.ApiException(
            statusCode: 500,
            message: 'Sync failed unexpectedly',
            type: app_api.ApiExceptionType.unknown,
          ),
          event,
          emit);
    }
  }

  Future<void> _handleSyncError(
    app_api.ApiException error,
    PerformSyncEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _retryCount++;

    if (_retryCount <= _maxRetries &&
        (error.type == app_api.ApiExceptionType.networkError ||
            error.type == app_api.ApiExceptionType.timeout ||
            error.type == app_api.ApiExceptionType.serverError)) {
      final baseDelay =
          _baseRetryDelay.inMilliseconds * pow(2, _retryCount - 1);
      final jitter = Random().nextInt(1000);
      final delay = Duration(milliseconds: baseDelay.toInt() + jitter);

      OseerLogger.info(
          'Retrying sync ${_retryCount}/$_maxRetries in ${delay.inSeconds}s');

      emit(state.copyWith(
        status: ConnectionStatus.syncing,
        errorMessage:
            'Connection issue. Retrying... (${_retryCount}/$_maxRetries)',
      ));

      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (_currentSyncEvent != null && _isSyncLocked) {
          _performSyncWithRetry(_currentSyncEvent!, emit);
        }
      });
    } else {
      OseerLogger.error('Sync failed after $_retryCount attempts');
      emit(state.copyWith(
        status: ConnectionStatus.syncFailed,
        isSyncing: false,
        errorMessage: error.message,
      ));

      notificationService?.showNotification(
        title: "Sync Failed",
        message: "Please check your connection and try again.",
      );
    }
  }

  Future<void> _onRetrySync(
    RetrySyncEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    _retryCount = 0;
    add(PerformSyncEvent(syncType: event.syncType));
  }

  void _onSyncProgressUpdated(
      SyncProgressUpdatedEvent event, Emitter<ConnectionState> emit) {
    emit(state.copyWith(
      isSyncing: !event.progress.isComplete && !event.progress.isError,
      syncProgressData: event.progress,
    ));

    final isSyncingOrProcessing = state.status == ConnectionStatus.syncing ||
        state.status == ConnectionStatus.syncIntro ||
        state.status == ConnectionStatus.processing ||
        state.status == ConnectionStatus.historicalSyncInProgress;

    if (isSyncingOrProcessing) {
      notificationService?.showSyncProgressNotification(event.progress);
    }
  }

  // FIXED: Enhanced trigger historical sync to handle direct triggering
  Future<void> _onTriggerHistoricalSync(
      TriggerHistoricalSyncEvent event, Emitter<ConnectionState> emit) async {
    OseerLogger.info("Triggering historical sync directly.");
    // FIX: Use the userId passed directly from the event.
    final userId = event.userId;

    if (backgroundSyncService != null) {
      emit(state.copyWith(
        status: ConnectionStatus.historicalSyncInProgress,
        wellnessPhase: WellnessPhase.digitalTwin,
        isSyncing: true,
      ));
      await backgroundSyncService!.enqueueHistoricalSync(userId);
      OseerLogger.info(
          "Historical sync background task enqueued for user $userId.");

      // IMPROVEMENT: Also trigger a foreground sync attempt to give immediate feedback.
      // The background task will still run as a fallback.
      add(const PerformSyncEvent(syncType: helper.SyncType.historical));
    } else {
      OseerLogger.error(
          "Could not enqueue historical sync: backgroundSyncService is null.");
      emit(state.copyWith(
        status: ConnectionStatus.error,
        isSyncing: false,
        errorMessage: "Unable to start historical sync. Please try again.",
      ));
    }
  }

  void _onRealtimeStatusChanged(
      RealtimeStatusChangedEvent event, Emitter<ConnectionState> emit) {
    OseerLogger.info("Realtime status: ${event.status}");
    emit(state.copyWith(realtimeStatus: event.status));
  }

  Future<void> _onServerProcessingCompleted(
      ServerProcessingCompleted event, Emitter<ConnectionState> emit) async {
    OseerLogger.info(
        'Server processing completed for request: ${event.requestId}');
  }

  Future<void> _onDisconnect(
    DisconnectEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    OseerLogger.info('Disconnecting from web');

    _retryTimer?.cancel();
    _retryTimer = null;
    _handoffTimeoutTimer?.cancel();
    _handoffTimeoutTimer = null;
    _handoffCheckTimer?.cancel();
    _handoffCheckTimer = null;

    await prefs.remove(OseerConstants.keyIsConnected);
    await prefs.remove(OseerConstants.keyConnectionToken);

    _isSyncLocked = false;
    _currentSyncEvent = null;

    realtimeSyncService?.unsubscribe();

    emit(ConnectionState.disconnected());
  }

  Future<void> _onSyncAnalysisCompleted(
      SyncAnalysisCompletedEvent event, Emitter<ConnectionState> emit) async {
    try {
      final status = event.status;
      final data = event.results;

      if (status == 'completed') {
        final now = DateTime.now();
        emit(state.copyWith(
            status: ConnectionStatus.prioritySyncComplete,
            isSyncing: false,
            lastSyncTime: now,
            wellnessPhase: WellnessPhase.complete));

        OseerLogger.info('✅ Body Preparedness analysis completed successfully');

        notificationService?.showSyncCompleteNotification(
          title: "Analysis Complete!",
          message: "Your Body Preparedness score is ready. Tap to view.",
        );

        final score = data['overall_body_preparedness_score'];
        if (score != null) {
          OseerLogger.info('Body Preparedness Score: $score/15');
        }
      } else if (status == 'insufficient_data') {
        emit(state.copyWith(
            status: ConnectionStatus.syncInsufficientData,
            errorMessage:
                "We couldn't find enough recent wellness data. Please ensure you've been wearing your device for at least 48 hours with sleep tracking enabled."));

        OseerLogger.warning('⚠️ Insufficient data for analysis');

        notificationService?.showSyncErrorNotification(
          title: "More Data Needed",
          message: "Please wear your device for longer and try again.",
          canRetry: false,
        );
      } else {
        emit(state.copyWith(
            status: ConnectionStatus.syncFailed,
            errorMessage: "An error occurred during analysis."));

        OseerLogger.error('❌ Analysis failed with status: $status');

        notificationService?.showSyncErrorNotification(
          title: "Analysis Failed",
          message: "An error occurred during analysis. Please try again later.",
        );
      }
    } catch (e) {
      OseerLogger.error("Failed to process sync completion event", e);
      emit(state.copyWith(
          status: ConnectionStatus.syncFailed,
          errorMessage: "Could not verify analysis results."));
    }
  }
}
