//lib/services/realtime_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' show pow;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, Logger;

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/connection/connection_event.dart';
import '../managers/health_manager.dart';
import '../services/logger_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../models/realtime_status.dart';

typedef DispatchConnectionEventCallback = void Function(ConnectionEvent event);

class RealtimeSyncService {
  final SupabaseClient _supabaseClient;
  final SharedPreferences _prefs;
  final HealthManager _healthManager;
  final DispatchConnectionEventCallback _dispatchConnectionEvent;
  final AuthBloc _authBloc;
  final ConnectivityService _connectivityService;

  RealtimeChannel? _syncChannel;
  RealtimeChannel? _bodyPrepChannel;
  StreamSubscription? _connectivitySubscription;

  // State management
  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();
  Stream<RealtimeStatus> get statusStream => _statusController.stream;
  RealtimeStatus _currentStatus = RealtimeStatus.disconnected;
  String? _lastError;
  String? get lastError => _lastError;
  int get reconnectAttempts => _reconnectAttempts;

  String? _currentUserId;
  String? _currentDeviceId;
  Timer? _heartbeatTimer;
  Timer? _connectionTimeoutTimer;
  StreamSubscription<AuthState>? _authBlocSubscription;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 15);

  // Track connection diagnostics
  DateTime? _lastSubscriptionTime;
  DateTime? _lastBroadcastTime;
  DateTime? _lastHeartbeatTime;
  int _broadcastsReceived = 0;

  // Prevent duplicate subscriptions
  bool _isSubscribing = false;

  RealtimeSyncService({
    required SupabaseClient supabaseClient,
    required SharedPreferences prefs,
    required HealthManager healthManager,
    required DispatchConnectionEventCallback dispatchConnectionEvent,
    required AuthBloc authBloc,
    required ConnectivityService connectivityService,
  })  : _supabaseClient = supabaseClient,
        _prefs = prefs,
        _healthManager = healthManager,
        _dispatchConnectionEvent = dispatchConnectionEvent,
        _authBloc = authBloc,
        _connectivityService = connectivityService {
    initialize();
  }

  void _updateStatus(RealtimeStatus newStatus, {String? error}) {
    if (_currentStatus == newStatus && error == null) return;
    _currentStatus = newStatus;
    _lastError = error;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
    OseerLogger.info('RealtimeSyncService status updated to: $newStatus');
  }

  Future<void> initialize() async {
    OseerLogger.info(
        'RealtimeSyncService: Service created and awaiting auth state.');
    _logConnectionDiagnostics();

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivityService.connectionStatus.listen((isConnected) {
      if (isConnected &&
          _currentStatus != RealtimeStatus.subscribed &&
          _currentUserId != null &&
          _currentDeviceId != null) {
        OseerLogger.info(
            "Network connection restored. Attempting to re-subscribe to realtime events.");
        subscribe();
      }
    });
  }

  /// Auth-aware connection management
  void listenToAuthChanges() {
    OseerLogger.info('RealtimeSyncService: Setting up auth state listener');
    _authBlocSubscription?.cancel();
    _authBlocSubscription = _authBloc.stream.listen((authState) async {
      OseerLogger.info(
          'RealtimeSyncService received auth state: ${authState.runtimeType}');

      // Connect for any authenticated state
      if (authState is AuthAuthenticated ||
          authState is AuthOnboardingSyncInProgress ||
          authState is AuthProfileConfirmationRequired ||
          authState is AuthPrioritySyncComplete ||
          authState is AuthHistoricalSyncInProgress ||
          authState is AuthOnboarding) {
        User? user;
        if (authState is AuthAuthenticated) {
          user = authState.user;
        } else if (authState is AuthOnboardingSyncInProgress) {
          // Get user from AuthBloc's current user
          user = _authBloc.state is AuthOnboardingSyncInProgress
              ? (_supabaseClient.auth.currentUser)
              : null;
        } else if (authState is AuthProfileConfirmationRequired) {
          user = authState.user;
        } else if (authState is AuthPrioritySyncComplete) {
          user = authState.user;
        } else if (authState is AuthOnboarding) {
          user = authState.user;
        }

        final userId = user?.id ?? _supabaseClient.auth.currentUser?.id;
        final deviceId = await _healthManager.getDeviceId();

        if (userId != null &&
            deviceId != null &&
            userId.isNotEmpty &&
            deviceId.isNotEmpty) {
          // Check if we need to subscribe or update
          if (_currentStatus != RealtimeStatus.subscribed ||
              _currentUserId != userId ||
              _currentDeviceId != deviceId) {
            if (_currentStatus != RealtimeStatus.disconnected) {
              OseerLogger.info(
                  'User/device changed or not connected. Re-subscribing.');
              await unsubscribe();
            }

            // Set credentials BEFORE subscribing
            _currentUserId = userId;
            _currentDeviceId = deviceId;
            _reconnectAttempts = 0;

            OseerLogger.info(
                'Auto-subscribing for user $userId, device $deviceId');
            await subscribe();
            _subscribeToBodyPrepUpdates(userId);
          } else {
            OseerLogger.info(
                'Already subscribed for user $userId and device $deviceId');
          }
        } else {
          OseerLogger.warning('Missing userId or deviceId in auth state');
        }
      } else if (authState is AuthUnauthenticated) {
        OseerLogger.info('User unauthenticated - unsubscribing from realtime');
        await unsubscribe();
        _currentUserId = null;
        _currentDeviceId = null;
      }
    });
  }

  void _subscribeToBodyPrepUpdates(String userId) {
    if (_bodyPrepChannel != null) {
      _supabaseClient.removeChannel(_bodyPrepChannel!);
      _bodyPrepChannel = null;
    }

    _bodyPrepChannel =
        _supabaseClient.channel('body-preparedness-user-$userId');

    _bodyPrepChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'body_preparedness',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord['user_id'] == userId) {
          final status = newRecord['status'] as String?;
          OseerLogger.info(
              'Received body_preparedness update via Realtime: status=$status');

          if (status == 'completed' ||
              status == 'failed' ||
              status == 'insufficient_data') {
            // **FIX: Pass the entire record in the event**
            _dispatchConnectionEvent(SyncAnalysisCompletedEvent(
              status: status!,
              results: newRecord,
            ));
          }
        }
      },
    );

    _bodyPrepChannel!.subscribe((status, [error]) {
      OseerLogger.info(
          'Body Preparedness subscription status: $status. Error: $error');
    });
  }

  Future<void> subscribe() async {
    // Prevent duplicate subscription attempts
    if (_isSubscribing) {
      OseerLogger.info(
          'Subscription already in progress, skipping duplicate call');
      return;
    }

    OseerLogger.info('RealtimeSyncService: Subscribe method called');
    OseerLogger.info('- Current userId: $_currentUserId');
    OseerLogger.info('- Current deviceId: $_currentDeviceId');
    OseerLogger.info('- Current status: $_currentStatus');

    // Guard against missing credentials
    if (_currentUserId == null || _currentDeviceId == null) {
      OseerLogger.warning(
          'RealtimeSyncService: Cannot subscribe - credentials not yet available');
      _updateStatus(RealtimeStatus.disconnected,
          error: "Awaiting authentication");
      return;
    }

    // Guard against duplicate subscriptions
    if (_currentStatus == RealtimeStatus.subscribed ||
        _currentStatus == RealtimeStatus.connecting) {
      OseerLogger.info(
          'Already subscribed or connecting - skipping duplicate subscription');
      return;
    }

    // Check network connectivity
    if (!_connectivityService.isConnected) {
      OseerLogger.warning(
          "No network connection. Deferring realtime subscription.");
      _updateStatus(RealtimeStatus.disconnected,
          error: 'No network connection');
      return;
    }

    // Check Supabase host reachability
    final canReachSupabase = await _connectivityService
        .canReachHost('oxvhffqnenhtyypzpcam.supabase.co');
    if (!canReachSupabase) {
      OseerLogger.error(
          "DNS lookup for Supabase failed. Realtime connection is not possible.");
      _updateStatus(RealtimeStatus.error,
          error: 'Cannot connect to Oseer services.');
      return;
    }

    _isSubscribing = true;

    try {
      _updateStatus(RealtimeStatus.connecting);

      // --- THE CRITICAL FIX ---
      // REMOVE the 'realtime:' prefix. The Supabase client library adds it automatically.
      final channelName = 'device-sync-$_currentDeviceId';
      OseerLogger.info(
          '🔌 RealtimeSyncService: Creating channel: $channelName');

      // Log Supabase auth state
      final currentUser = _supabaseClient.auth.currentUser;
      final currentSession = _supabaseClient.auth.currentSession;
      OseerLogger.info('Supabase auth state:');
      OseerLogger.info('- Current user ID: ${currentUser?.id}');
      OseerLogger.info('- Has session: ${currentSession != null}');
      OseerLogger.info('- Session expires at: ${currentSession?.expiresAt}');

      // Create channel with keepalive configuration
      _syncChannel = _supabaseClient.channel(
        channelName,
        opts: const RealtimeChannelConfig(
          self: true,
          ack: true,
        ),
      );

      OseerLogger.info('Channel created with config: self=true, ack=true');

      // Listen for sync request inserts
      _syncChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'sync_requests',
        callback: (payload) {
          final newRecord = payload.newRecord;
          OseerLogger.info(
              'RealtimeSyncService: Received DB INSERT: ${jsonEncode(newRecord)}');

          final requestType = newRecord['request_type'] as String?;

          if (requestType == 'device_link_established') {
            OseerLogger.info('CONNECTION ESTABLISHED (via DB trigger)!');
            final userId = newRecord['user_id'] as String?;
            final deviceId = newRecord['device_id'] as String?;
            final requestId = newRecord['id'] as String?;

            if (userId != null &&
                deviceId != null &&
                requestId != null &&
                deviceId == _currentDeviceId) {
              _dispatchConnectionEvent(ConnectionEstablishedViaWebEvent(
                userId: userId,
                deviceId: deviceId,
                requestId: requestId,
              ));
            } else {
              OseerLogger.warning(
                  'Device ID mismatch or missing data. Event DeviceID: $deviceId, App DeviceID: $_currentDeviceId');
            }
          } else if (requestType == 'health_sync' || requestType == null) {
            OseerLogger.info('Received "health_sync" request from DB.');
            final requestId = newRecord['id'] as String?;
            final status = newRecord['status'] as String?;

            if (requestId != null && status == 'pending') {
              _dispatchConnectionEvent(PerformSyncEvent(requestId: requestId));
            }
          } else {
            OseerLogger.warning(
                'Unhandled DB INSERT request_type: $requestType');
          }
        },
      );

      OseerLogger.info('PostgreSQL INSERT listener registered');

      // Listen for sync request updates
      _syncChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'sync_requests',
        callback: (payload) {
          OseerLogger.debug(
              'RealtimeSyncService: Sync request updated (DB): ${jsonEncode(payload.newRecord)}');
          _handleSyncRequestUpdate(payload);
        },
      );

      OseerLogger.info('PostgreSQL UPDATE listener registered');

      // Listen for connection_established broadcast
      _syncChannel!.onBroadcast(
        event: 'connection_established',
        callback: (payload) {
          _lastBroadcastTime = DateTime.now();
          _broadcastsReceived++;
          OseerLogger.info(
              '[BROADCAST|RECEIVED] "connection_established" event!');
          OseerLogger.debug(
              '[BROADCAST|RAW] Complete payload: ${jsonEncode(payload)}');

          try {
            Map<String, dynamic>? eventData;

            if (payload is Map<String, dynamic>) {
              if (payload.containsKey('payload') && payload['payload'] is Map) {
                eventData = payload['payload'] as Map<String, dynamic>;
              } else if (payload.containsKey('data') &&
                  payload['data'] is Map) {
                eventData = payload['data'] as Map<String, dynamic>;
              } else {
                eventData = payload;
              }
            }

            OseerLogger.debug(
                '[BROADCAST|PARSED] Event data: ${jsonEncode(eventData)}');

            if (eventData != null) {
              final userId = eventData['userId'] as String? ??
                  eventData['user_id'] as String? ??
                  eventData['userID'] as String?;
              final deviceId = eventData['deviceId'] as String? ??
                  eventData['device_id'] as String? ??
                  eventData['deviceID'] as String?;
              final connectionToken = eventData['connectionToken'] as String? ??
                  eventData['connection_token'] as String? ??
                  eventData['token'] as String?;
              final requestId = eventData['requestId'] as String? ??
                  eventData['request_id'] as String? ??
                  eventData['requestID'] as String?;

              OseerLogger.debug(
                  '[BROADCAST|DATA] userId=$userId, deviceId=$deviceId, token=${connectionToken?.substring(0, 8) ?? "null"}..., requestId=$requestId');

              if (userId != null &&
                  deviceId != null &&
                  connectionToken != null &&
                  requestId != null) {
                if (deviceId == _currentDeviceId) {
                  OseerLogger.info(
                      '[BROADCAST|MATCH] Connection established for this device. Dispatching event.');
                  _dispatchConnectionEvent(
                      ConnectionEstablishedViaWebWithTokenEvent(
                    userId: userId,
                    deviceId: deviceId,
                    connectionToken: connectionToken,
                    requestId: requestId,
                  ));
                } else {
                  OseerLogger.warning(
                      '[BROADCAST|MISMATCH] Device ID mismatch. Event DeviceID: $deviceId, App DeviceID: $_currentDeviceId');
                }
              } else {
                OseerLogger.warning(
                    '[BROADCAST|INCOMPLETE] Missing required fields in broadcast data.');
              }
            } else {
              OseerLogger.warning(
                  '[BROADCAST|ERROR] Could not parse event data from payload.');
            }
          } catch (e, stack) {
            OseerLogger.error(
                '[BROADCAST|EXCEPTION] Failed to process broadcast payload',
                e,
                stack);
          }
        },
      );

      OseerLogger.info(
          "Direct 'connection_established' broadcast listener registered.");

      // Add sync_complete listener
      _syncChannel!.onBroadcast(
        event: 'sync_complete',
        callback: (payload) {
          OseerLogger.info(
              '[BROADCAST] Received "sync_complete" event from server!');
          _handleSyncComplete(payload);
        },
      );

      OseerLogger.info("Direct 'sync_complete' broadcast listener registered.");

      // Subscribe with status handling
      OseerLogger.info('Calling subscribe() on channel...');
      _syncChannel!.subscribe((status, [error]) {
        OseerLogger.info('');
        OseerLogger.info('========== SUBSCRIPTION STATUS CHANGE ==========');
        OseerLogger.info('Status: $status');
        OseerLogger.info('Error: $error');
        OseerLogger.info('================================================');
        OseerLogger.info('');

        if (status == RealtimeSubscribeStatus.subscribed) {
          _lastSubscriptionTime = DateTime.now();
          _reconnectAttempts = 0;
          _connectionTimeoutTimer?.cancel();
          _startHeartbeat();
          _updateStatus(RealtimeStatus.subscribed);

          OseerLogger.info('SUCCESSFULLY SUBSCRIBED TO REALTIME EVENTS');
          OseerLogger.info('Channel topic: ${_syncChannel?.topic}');
          OseerLogger.info('Channel params: ${_syncChannel?.params}');
          _logConnectionDiagnostics();
        } else if (status == RealtimeSubscribeStatus.channelError) {
          _stopHeartbeat();
          _lastError = error?.toString() ?? 'Channel error occurred';

          if (error.toString().contains("SocketException") ||
              error.toString().contains("Failed host lookup")) {
            OseerLogger.error('RealtimeSyncService: Network Error', error);
            _updateStatus(RealtimeStatus.networkError, error: _lastError);
          } else {
            OseerLogger.error(
                'RealtimeSyncService: Channel error occurred', error);
            _updateStatus(RealtimeStatus.error, error: _lastError);
          }
          _logConnectionDiagnostics();
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _scheduleReconnect();
          }
        } else if (status == RealtimeSubscribeStatus.closed) {
          _stopHeartbeat();
          _lastError = 'Channel was closed.';
          OseerLogger.warning('RealtimeSyncService: Channel closed');
          _updateStatus(RealtimeStatus.disconnected, error: _lastError);
          _logConnectionDiagnostics();
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _scheduleReconnect();
          }
        } else if (status == RealtimeSubscribeStatus.timedOut) {
          _stopHeartbeat();
          _lastError = 'Subscription timed out';
          OseerLogger.warning('RealtimeSyncService: Subscription timed out');
          _updateStatus(RealtimeStatus.error, error: _lastError);
          _logConnectionDiagnostics();
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _scheduleReconnect();
          }
        }
      });

      // Set connection timeout
      _connectionTimeoutTimer = Timer(_connectionTimeout, () {
        if (_currentStatus != RealtimeStatus.subscribed &&
            _reconnectAttempts < _maxReconnectAttempts) {
          OseerLogger.warning(
              'RealtimeSyncService: Connection timeout reached (${_connectionTimeout.inSeconds}s)');
          _logConnectionDiagnostics();
          _scheduleReconnect();
        }
      });

      OseerLogger.info(
          'Connection timeout timer set for ${_connectionTimeout.inSeconds}s');
    } catch (e, stack) {
      OseerLogger.error(
          'RealtimeSyncService: Error subscribing to channel', e, stack);
      _updateStatus(RealtimeStatus.error, error: e.toString());
      _logConnectionDiagnostics();
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    } finally {
      _isSubscribing = false;
    }
  }

  void _logConnectionDiagnostics() {
    OseerLogger.info('');
    OseerLogger.info('========== CONNECTION DIAGNOSTICS ==========');
    OseerLogger.info('Service State:');
    OseerLogger.info('- Current status: $_currentStatus');
    OseerLogger.info('- User ID: $_currentUserId');
    OseerLogger.info('- Device ID: $_currentDeviceId');
    OseerLogger.info(
        '- Reconnect attempts: $_reconnectAttempts / $_maxReconnectAttempts');
    OseerLogger.info('');
    OseerLogger.info('Channel State:');
    OseerLogger.info('- Channel exists: ${_syncChannel != null}');
    OseerLogger.info('- Channel topic: ${_syncChannel?.topic}');
    OseerLogger.info('');
    OseerLogger.info('Timing:');
    OseerLogger.info('- Last subscription: $_lastSubscriptionTime');
    OseerLogger.info('- Last broadcast: $_lastBroadcastTime');
    OseerLogger.info('- Last heartbeat: $_lastHeartbeatTime');
    OseerLogger.info('- Broadcasts received: $_broadcastsReceived');
    OseerLogger.info('');
    OseerLogger.info('Supabase Auth:');
    OseerLogger.info('- User ID: ${_supabaseClient.auth.currentUser?.id}');
    OseerLogger.info(
        '- Has session: ${_supabaseClient.auth.currentSession != null}');
    OseerLogger.info(
        '- Session expires: ${_supabaseClient.auth.currentSession?.expiresAt}');
    OseerLogger.info('=============================================');
    OseerLogger.info('');
  }

  void _handleSyncRequestUpdate(PostgresChangePayload payload) {
    try {
      final newData = payload.newRecord;
      if (newData.isEmpty) return;

      final requestId = newData['id'] as String?;
      final status = newData['status'] as String?;

      OseerLogger.debug(
          'Sync request updated - ID: $requestId, Status: $status');

      if (status == 'cancelled') {
        OseerLogger.info('Sync request cancelled: $requestId');
      }
    } catch (e, stack) {
      OseerLogger.error('Error handling sync request update', e, stack);
    }
  }

  void _handleSyncComplete(Map<String, dynamic> payload) {
    try {
      final eventPayload = payload['payload'] as Map<String, dynamic>?;
      final status = eventPayload?['status'] as String?;
      final requestId = eventPayload?['requestId'] as String?;

      OseerLogger.info(
          'Processing sync_complete: Status="$status", RequestID="$requestId"');

      if (status == 'success' && requestId != null) {
        _dispatchConnectionEvent(
            ServerProcessingCompleted(requestId: requestId));
      }
    } catch (e, s) {
      OseerLogger.error("Error handling 'sync_complete' payload", e, s);
    }
  }

  Future<void> updateSyncRequestStatus(
    String requestId,
    String status, {
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      OseerLogger.info('Updating sync request $requestId to status: $status');

      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (errorMessage != null) {
        updateData['error_message'] = errorMessage;
      }

      if (metadata != null) {
        updateData['metadata'] = jsonEncode(metadata);
      }

      await _supabaseClient
          .from('sync_requests')
          .update(updateData)
          .eq('id', requestId);

      OseerLogger.debug('Sync request status updated');
    } catch (e, stack) {
      OseerLogger.error('Error updating sync request status', e, stack);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();

    OseerLogger.info(
        'Starting heartbeat timer (interval: ${_heartbeatInterval.inSeconds}s)');

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_currentStatus == RealtimeStatus.subscribed && _syncChannel != null) {
        try {
          _lastHeartbeatTime = DateTime.now();
          _syncChannel!.sendBroadcastMessage(
            event: 'heartbeat',
            payload: {
              'timestamp': DateTime.now().toIso8601String(),
              'device_id': _currentDeviceId,
              'broadcasts_received': _broadcastsReceived,
            },
          );
          OseerLogger.debug('Heartbeat sent at $_lastHeartbeatTime');
        } catch (e) {
          OseerLogger.warning('Failed to send heartbeat: $e');
        }
      }
    });
  }

  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      OseerLogger.info('Stopping heartbeat timer');
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      OseerLogger.error(
          'Max reconnect attempts reached ($_maxReconnectAttempts)');
      _updateStatus(RealtimeStatus.error,
          error: "Failed to connect after multiple attempts.");
      _logConnectionDiagnostics();
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: pow(2, _reconnectAttempts).toInt());

    _updateStatus(RealtimeStatus.retrying);

    OseerLogger.info(
        'Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');

    Timer(delay, () async {
      OseerLogger.info('Executing scheduled reconnect...');
      if (_currentStatus != RealtimeStatus.subscribed &&
          _currentUserId != null &&
          _currentDeviceId != null) {
        await unsubscribe();
        await Future.delayed(const Duration(milliseconds: 500));
        await subscribe();
      }
    });
  }

  Future<void> unsubscribe() async {
    try {
      OseerLogger.info('Unsubscribing from realtime events...');

      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;

      _stopHeartbeat();

      if (_syncChannel != null) {
        await _syncChannel!.unsubscribe();
        _syncChannel = null;
      }

      if (_bodyPrepChannel != null) {
        await _supabaseClient.removeChannel(_bodyPrepChannel!);
        _bodyPrepChannel = null;
      }

      _updateStatus(RealtimeStatus.disconnected);
      OseerLogger.info('Unsubscribed from realtime events');
      _logConnectionDiagnostics();
    } catch (e, stack) {
      OseerLogger.error('Error during unsubscribe', e, stack);
    }
  }

  bool get isSubscribed => _currentStatus == RealtimeStatus.subscribed;
  String? get currentUserId => _currentUserId;
  String? get currentDeviceId => _currentDeviceId;

  void dispose() {
    OseerLogger.info('RealtimeSyncService: Disposing service');
    _authBlocSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
    unsubscribe();
  }
}
