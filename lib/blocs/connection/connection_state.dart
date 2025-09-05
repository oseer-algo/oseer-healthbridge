// lib/blocs/connection/connection_state.dart

import 'package:equatable/equatable.dart';
import '../../models/realtime_status.dart';
import '../../models/sync_progress.dart';

/// Connection status enumeration
enum ConnectionStatus {
  /// Initial state, not yet determined
  initial,

  /// Token has been generated but not yet validated
  tokenGenerated,

  /// Successfully connected to web platform
  connected,

  /// Not connected to web platform (no token or disconnected)
  disconnected,

  /// Connection error occurred
  error,

  /// Currently connecting to web platform
  connecting,

  /// Currently disconnecting from web platform
  disconnecting,

  /// User is authenticated but needs to generate a token
  needsToken,

  /// Sync intro/anticipation phase (15-second pause)
  syncIntro,

  /// Currently syncing data
  syncing,

  /// Data uploaded, backend is processing
  processing,

  /// Priority sync has completed
  prioritySyncComplete,

  /// Historical sync is ready to start after insufficient data
  historicalSyncReady,

  /// Historical sync is running in background
  historicalSyncInProgress,

  /// Sync failed due to network error
  syncFailed,

  /// Insufficient data for analysis
  syncInsufficientData,
}

/// Wellness phases
enum WellnessPhase {
  notStarted,
  intro,
  bodyPrep,
  digitalTwin,
  complete,
}

/// Connection state class for the ConnectionBloc
class ConnectionState extends Equatable {
  /// Current connection status
  final ConnectionStatus status;

  /// Current connection token (if any)
  final String? token;

  /// Last sync timestamp
  final DateTime? lastSyncTime;

  /// Token expiry date
  final DateTime? tokenExpiryDate;

  /// Token generation date
  final DateTime? tokenGenerationDate;

  /// Connection error message
  final String? errorMessage;

  /// Device ID used for connection
  final String? deviceId;

  /// User ID
  final String? userId;

  /// Device name
  final String? deviceName;

  /// Flag indicating whether connection is being retried
  final bool isRetrying;

  /// Flag indicating whether a sync is in progress
  final bool isSyncing;

  /// Flag indicating whether device is offline
  final bool isOffline;

  /// Flag indicating whether sync is enabled
  final bool isSyncEnabled;

  /// Flag indicating whether sync is needed
  final bool needsSync;

  /// Current sync progress (0.0 to 1.0)
  final double? syncProgress;

  /// Web session token for dashboard access
  final String? webSessionToken;

  /// Web auth deep link for auto-login
  final String? webAuthDeepLink;

  /// Current wellness phase
  final WellnessPhase wellnessPhase;

  /// Body preparedness assessment progress (0.0 to 1.0)
  final double bodyPrepProgress;

  /// Flag indicating if body prep is ready
  final bool bodyPrepReady;

  /// Time when body prep was completed
  final DateTime? bodyPrepReadyTime;

  /// Digital twin days processed
  final int digitalTwinDaysProcessed;

  /// Estimated completion time for current phase
  final DateTime? estimatedPhaseCompletion;

  /// Current activity description
  final String? currentActivity;

  /// Granular status of the real-time connection from the service
  final RealtimeStatus realtimeStatus;

  /// The current reconnect attempt number
  final int reconnectAttempt;

  /// True when a token is generated and we are waiting for web validation
  final bool isAwaitingWebValidation;

  /// Detailed sync progress data
  final SyncProgress? syncProgressData;

  /// Default constructor
  const ConnectionState({
    this.status = ConnectionStatus.initial,
    this.token,
    this.lastSyncTime,
    this.tokenExpiryDate,
    this.tokenGenerationDate,
    this.errorMessage,
    this.deviceId,
    this.userId,
    this.deviceName,
    this.isRetrying = false,
    this.isSyncing = false,
    this.isOffline = false,
    this.isSyncEnabled = true,
    this.needsSync = false,
    this.syncProgress,
    this.webSessionToken,
    this.webAuthDeepLink,
    this.wellnessPhase = WellnessPhase.notStarted,
    this.bodyPrepProgress = 0.0,
    this.bodyPrepReady = false,
    this.bodyPrepReadyTime,
    this.digitalTwinDaysProcessed = 0,
    this.estimatedPhaseCompletion,
    this.currentActivity,
    this.realtimeStatus = RealtimeStatus.disconnected,
    this.reconnectAttempt = 0,
    this.isAwaitingWebValidation = false,
    this.syncProgressData,
  });

  /// Initial state factory
  factory ConnectionState.initial() {
    return const ConnectionState(
      status: ConnectionStatus.initial,
      wellnessPhase: WellnessPhase.notStarted,
      realtimeStatus: RealtimeStatus.disconnected,
      isAwaitingWebValidation: false,
    );
  }

  /// Connected state factory
  factory ConnectionState.connected({
    required String token,
    DateTime? lastSyncTime,
    DateTime? tokenExpiryDate,
    DateTime? tokenGenerationDate,
    String? deviceId,
    String? userId,
    String? deviceName,
    bool isSyncing = false,
    bool isSyncEnabled = true,
    bool needsSync = false,
    double? syncProgress,
    WellnessPhase wellnessPhase = WellnessPhase.notStarted,
    double bodyPrepProgress = 0.0,
    bool bodyPrepReady = false,
    DateTime? bodyPrepReadyTime,
    int digitalTwinDaysProcessed = 0,
    DateTime? estimatedPhaseCompletion,
  }) {
    return ConnectionState(
      status: ConnectionStatus.connected,
      token: token,
      lastSyncTime: lastSyncTime,
      tokenExpiryDate: tokenExpiryDate,
      tokenGenerationDate: tokenGenerationDate,
      deviceId: deviceId,
      userId: userId,
      deviceName: deviceName,
      isSyncing: isSyncing,
      isSyncEnabled: isSyncEnabled,
      needsSync: needsSync,
      syncProgress: syncProgress,
      wellnessPhase: wellnessPhase,
      bodyPrepProgress: bodyPrepProgress,
      bodyPrepReady: bodyPrepReady,
      bodyPrepReadyTime: bodyPrepReadyTime,
      digitalTwinDaysProcessed: digitalTwinDaysProcessed,
      estimatedPhaseCompletion: estimatedPhaseCompletion,
    );
  }

  /// Token generated state factory
  factory ConnectionState.tokenGenerated({
    required String token,
    DateTime? tokenExpiryDate,
    DateTime? tokenGenerationDate,
    String? deviceId,
    String? userId,
    String? deviceName,
    bool isSyncEnabled = true,
  }) {
    return ConnectionState(
      status: ConnectionStatus.tokenGenerated,
      token: token,
      tokenExpiryDate: tokenExpiryDate,
      tokenGenerationDate: tokenGenerationDate,
      deviceId: deviceId,
      userId: userId,
      deviceName: deviceName,
      isSyncEnabled: isSyncEnabled,
    );
  }

  /// Disconnected state factory
  factory ConnectionState.disconnected({
    bool isSyncEnabled = true,
  }) {
    return ConnectionState(
      status: ConnectionStatus.disconnected,
      isSyncEnabled: isSyncEnabled,
    );
  }

  /// Error state factory
  factory ConnectionState.error(String message) {
    return ConnectionState(
      status: ConnectionStatus.error,
      errorMessage: message,
    );
  }

  /// Insufficient data state factory
  factory ConnectionState.insufficientData({
    String? message,
    DateTime? lastSyncTime,
  }) {
    return ConnectionState(
      status: ConnectionStatus.syncInsufficientData,
      errorMessage: message ??
          'Insufficient data for analysis. Please ensure you\'ve been wearing your device.',
      lastSyncTime: lastSyncTime,
    );
  }

  /// Historical sync ready state factory
  factory ConnectionState.historicalSyncReady({
    String? message,
    DateTime? lastSyncTime,
  }) {
    return ConnectionState(
      status: ConnectionStatus.historicalSyncReady,
      errorMessage: message,
      lastSyncTime: lastSyncTime,
    );
  }

  /// Helper to determine if there's a valid connection
  bool get isConnected => status == ConnectionStatus.connected;

  /// Helper to determine if token has been generated but not yet validated
  bool get hasToken =>
      status == ConnectionStatus.tokenGenerated ||
      status == ConnectionStatus.connected;

  /// Create a copy of this state with some changed fields
  ConnectionState copyWith({
    ConnectionStatus? status,
    String? token,
    DateTime? lastSyncTime,
    DateTime? tokenExpiryDate,
    DateTime? tokenGenerationDate,
    String? errorMessage,
    String? deviceId,
    String? userId,
    String? deviceName,
    bool? isRetrying,
    bool? isSyncing,
    bool? isOffline,
    bool? isSyncEnabled,
    bool? needsSync,
    double? syncProgress,
    String? webSessionToken,
    String? webAuthDeepLink,
    WellnessPhase? wellnessPhase,
    double? bodyPrepProgress,
    bool? bodyPrepReady,
    DateTime? bodyPrepReadyTime,
    int? digitalTwinDaysProcessed,
    DateTime? estimatedPhaseCompletion,
    String? currentActivity,
    RealtimeStatus? realtimeStatus,
    int? reconnectAttempt,
    bool? isAwaitingWebValidation,
    SyncProgress? syncProgressData,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      token: token ?? this.token,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      tokenExpiryDate: tokenExpiryDate ?? this.tokenExpiryDate,
      tokenGenerationDate: tokenGenerationDate ?? this.tokenGenerationDate,
      errorMessage: errorMessage,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      isRetrying: isRetrying ?? this.isRetrying,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      needsSync: needsSync ?? this.needsSync,
      syncProgress: syncProgress ?? this.syncProgress,
      webSessionToken: webSessionToken ?? this.webSessionToken,
      webAuthDeepLink: webAuthDeepLink ?? this.webAuthDeepLink,
      wellnessPhase: wellnessPhase ?? this.wellnessPhase,
      bodyPrepProgress: bodyPrepProgress ?? this.bodyPrepProgress,
      bodyPrepReady: bodyPrepReady ?? this.bodyPrepReady,
      bodyPrepReadyTime: bodyPrepReadyTime ?? this.bodyPrepReadyTime,
      digitalTwinDaysProcessed:
          digitalTwinDaysProcessed ?? this.digitalTwinDaysProcessed,
      estimatedPhaseCompletion:
          estimatedPhaseCompletion ?? this.estimatedPhaseCompletion,
      currentActivity: currentActivity ?? this.currentActivity,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      isAwaitingWebValidation:
          isAwaitingWebValidation ?? this.isAwaitingWebValidation,
      syncProgressData: syncProgressData ?? this.syncProgressData,
    );
  }

  @override
  List<Object?> get props => [
        status,
        token,
        lastSyncTime,
        tokenExpiryDate,
        tokenGenerationDate,
        errorMessage,
        deviceId,
        userId,
        deviceName,
        isRetrying,
        isSyncing,
        isOffline,
        isSyncEnabled,
        needsSync,
        syncProgress,
        webSessionToken,
        webAuthDeepLink,
        wellnessPhase,
        bodyPrepProgress,
        bodyPrepReady,
        bodyPrepReadyTime,
        digitalTwinDaysProcessed,
        estimatedPhaseCompletion,
        currentActivity,
        realtimeStatus,
        reconnectAttempt,
        isAwaitingWebValidation,
        syncProgressData,
      ];

  @override
  String toString() {
    return 'ConnectionState{status: $status, hasToken: ${token != null}, ' +
        'lastSync: ${lastSyncTime?.toIso8601String() ?? "none"}, ' +
        'tokenExpiry: ${tokenExpiryDate?.toIso8601String() ?? "none"}, ' +
        'isSyncing: $isSyncing, isOffline: $isOffline, ' +
        'isSyncEnabled: $isSyncEnabled, needsSync: $needsSync, ' +
        'wellnessPhase: $wellnessPhase, bodyPrepReady: $bodyPrepReady, ' +
        'realtimeStatus: $realtimeStatus, reconnectAttempt: $reconnectAttempt, ' +
        'isAwaitingWebValidation: $isAwaitingWebValidation, ' +
        'currentActivity: $currentActivity}';
  }
}
