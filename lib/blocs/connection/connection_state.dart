// File path: lib/blocs/connection/connection_state.dart

import 'package:equatable/equatable.dart';

/// Connection status enum
enum ConnectionStatus {
  /// Initial state, unknown connection status
  initial,

  /// Currently attempting to connect
  connecting,

  /// Successfully connected
  connected,

  /// Disconnected from the service
  disconnected,

  /// Error state when connection fails
  error,
}

/// Connection state class
class ConnectionState extends Equatable {
  /// Current connection status
  final ConnectionStatus status;

  /// User ID if connected
  final String? userId;

  /// Device name if connected
  final String? deviceName;

  /// Last time data was synced with the server
  final DateTime? lastSyncTime;

  /// Error message if there was an error during connection
  final String? errorMessage;

  /// Whether the system is currently retrying a failed connection
  final bool isRetrying;

  const ConnectionState({
    this.status = ConnectionStatus.initial,
    this.userId,
    this.deviceName,
    this.lastSyncTime,
    this.errorMessage,
    this.isRetrying = false,
  });

  /// Factory for creating the initial state
  factory ConnectionState.initial() {
    return const ConnectionState();
  }

  /// Creates a copy of this state with the given fields replaced
  ConnectionState copyWith({
    ConnectionStatus? status,
    String? userId,
    String? deviceName,
    DateTime? lastSyncTime,
    String? errorMessage,
    bool? isRetrying,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
      isRetrying: isRetrying ?? this.isRetrying,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userId,
        deviceName,
        lastSyncTime,
        errorMessage,
        isRetrying,
      ];
}
