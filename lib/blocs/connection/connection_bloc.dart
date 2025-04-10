// File path: lib/blocs/connection/connection_bloc.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../managers/health_manager.dart';
import '../../managers/token_manager.dart';
import '../../services/api_service.dart';
import '../../services/logger_service.dart';
import '../../utils/constants.dart';
import 'connection_event.dart';
import 'connection_state.dart';

export 'connection_event.dart';
export 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  final HealthManager healthManager;
  final ApiService apiService;
  final SharedPreferences prefs;
  final TokenManager tokenManager;

  // For retry mechanism
  int _connectionAttempts = 0;
  Timer? _retryTimer;

  ConnectionBloc({
    required this.healthManager,
    required this.apiService,
    required this.prefs,
    required this.tokenManager,
  }) : super(ConnectionState.initial()) {
    on<CheckConnectionStatusEvent>(_onCheckConnectionStatus);
    on<ConnectWithCodeEvent>(_onConnectWithCode);
    on<ProcessDeepLinkEvent>(_onProcessDeepLink);
    on<DisconnectEvent>(_onDisconnect);
    on<RefreshConnectionEvent>(_onRefreshConnection);

    // Check connection status on initialization
    add(CheckConnectionStatusEvent());
  }

  Future<void> _onCheckConnectionStatus(
    CheckConnectionStatusEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      // Check if we have a userId and token
      final userId = prefs.getString(OseerConstants.keyUserId);
      final token = tokenManager.getCurrentToken();
      final deviceName = prefs.getString('device_name') ?? 'Android Device';

      if (userId != null && token != null && !tokenManager.isTokenExpired()) {
        // Try to validate the connection with the server
        try {
          final isValid = await tokenManager.validateToken(token);
          if (isValid) {
            // Update last sync time
            final lastSyncStr = prefs.getString(OseerConstants.keyLastSync);
            final lastSync =
                lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

            emit(state.copyWith(
              status: ConnectionStatus.connected,
              userId: userId,
              deviceName: deviceName,
              lastSyncTime: lastSync,
              errorMessage: null,
            ));

            return;
          }
        } catch (e) {
          OseerLogger.warning(
              'Failed to validate token, assuming disconnected', e);
          // Continue to disconnected state
        }
      }

      // Not connected
      emit(state.copyWith(
        status: ConnectionStatus.disconnected,
        userId: null,
        deviceName: null,
        errorMessage: null,
      ));
    } catch (e) {
      OseerLogger.error('Error checking connection status', e);
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Failed to check connection status: ${e.toString()}',
      ));
    }
  }

  Future<void> _onConnectWithCode(
    ConnectWithCodeEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      // Reset retry counter if this is a new connection attempt
      _connectionAttempts = 0;

      // Show connecting status
      emit(state.copyWith(
        status: ConnectionStatus.connecting,
        errorMessage: null,
      ));

      // Parse the code (format: userId/token)
      final parts = event.code.split('/');
      if (parts.length != 2) {
        emit(state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Invalid code format. Should be userId/token',
        ));
        return;
      }

      final userId = parts[0];
      final token = parts[1];

      // Validate the token
      final isValid = await tokenManager.validateToken(token);
      if (!isValid) {
        emit(state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: 'Invalid connection code. Please try again.',
        ));
        return;
      }

      // Store the user ID
      await prefs.setString(OseerConstants.keyUserId, userId);

      // Store the token (even though tokenManager already does this)
      await prefs.setString(OseerConstants.keyConnectionToken, token);

      // Set the device name
      final deviceName =
          'Android Device'; // In a real app, get this dynamically
      await prefs.setString('device_name', deviceName);

      // Update last sync time
      final now = DateTime.now();
      await prefs.setString(OseerConstants.keyLastSync, now.toIso8601String());

      // Connection successful
      emit(state.copyWith(
        status: ConnectionStatus.connected,
        userId: userId,
        deviceName: deviceName,
        lastSyncTime: now,
        errorMessage: null,
      ));

      OseerLogger.info('Successfully connected to Oseer service');
    } catch (e) {
      OseerLogger.error('Error connecting with code', e);

      // Increment connection attempts
      _connectionAttempts++;

      if (_connectionAttempts < OseerConstants.maxConnectionRetries) {
        // Retry after delay with exponential backoff
        final delaySeconds =
            OseerConstants.connectionRetryDelay.inSeconds * _connectionAttempts;

        OseerLogger.info(
            'Retrying connection in $delaySeconds seconds (attempt $_connectionAttempts)');

        _retryTimer?.cancel();
        _retryTimer = Timer(
          Duration(seconds: delaySeconds),
          () => add(ConnectWithCodeEvent(event.code)),
        );

        emit(state.copyWith(
          status: ConnectionStatus.error,
          errorMessage:
              'Connection error. Retrying in $delaySeconds seconds...',
          isRetrying: true,
        ));
      } else {
        // Max retries reached
        emit(state.copyWith(
          status: ConnectionStatus.error,
          errorMessage:
              'Failed to connect after $_connectionAttempts attempts: ${e.toString()}',
          isRetrying: false,
        ));

        // Reset for next attempt
        _connectionAttempts = 0;
      }
    }
  }

  Future<void> _onProcessDeepLink(
    ProcessDeepLinkEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      OseerLogger.info('Processing deep link: ${event.uri}');
      emit(state.copyWith(
        status: ConnectionStatus.connecting,
        errorMessage: null,
      ));

      // Extract path segments
      final pathSegments = event.uri.pathSegments;
      if (pathSegments.isEmpty) {
        OseerLogger.warning('Deep link has no path segments');
        return;
      }

      // Check if the path contains connect
      if (pathSegments[0] == 'connect') {
        // Extract query parameters
        final queryParams = event.uri.queryParameters;
        final userId = queryParams['userId'];
        final token = queryParams['token'];

        if (userId == null || token == null) {
          emit(state.copyWith(
            status: ConnectionStatus.disconnected,
            errorMessage: 'Invalid deep link parameters',
          ));
          return;
        }

        // Validate the token
        final isValid = await tokenManager.validateToken(token);

        if (!isValid) {
          emit(state.copyWith(
            status: ConnectionStatus.disconnected,
            errorMessage: 'Invalid connection token',
          ));
          return;
        }

        // Save the user ID
        await prefs.setString(OseerConstants.keyUserId, userId);

        // Get device ID and name
        final deviceId = await healthManager.getDeviceId();
        const deviceName = 'Android Device';

        // Update last sync time
        final now = DateTime.now();
        await prefs.setString(
            OseerConstants.keyLastSync, now.toIso8601String());

        // Emit connected state
        emit(ConnectionState(
          status: ConnectionStatus.connected,
          userId: userId,
          deviceName: deviceName,
          lastSyncTime: now,
        ));

        OseerLogger.info(
            'Connected successfully via deep link, user ID: $userId');
      }
    } catch (e) {
      OseerLogger.error('Error processing deep link', e);
      emit(state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Failed to process deep link: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDisconnect(
    DisconnectEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    try {
      OseerLogger.info('Disconnecting device...');

      // Clear the token and connection data
      await tokenManager.clearToken();

      // We don't clear user ID to make reconnection easier

      // Emit disconnected state
      emit(const ConnectionState(status: ConnectionStatus.disconnected));

      OseerLogger.info('Device disconnected successfully');

      // Provide haptic feedback for disconnection
      HapticFeedback.mediumImpact();
    } catch (e) {
      OseerLogger.error('Error disconnecting device', e);
      emit(state.copyWith(
        errorMessage: 'Failed to disconnect device: ${e.toString()}',
      ));

      // Provide haptic feedback for error
      HapticFeedback.vibrate();
    }
  }

  Future<void> _onRefreshConnection(
    RefreshConnectionEvent event,
    Emitter<ConnectionState> emit,
  ) async {
    // Just re-check connection status
    add(CheckConnectionStatusEvent());
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel();
    return super.close();
  }
}
