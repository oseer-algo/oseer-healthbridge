// File path: lib/blocs/connection/connection_event.dart

import 'package:equatable/equatable.dart';

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// Event to check connection status
class CheckConnectionStatusEvent extends ConnectionEvent {}

/// Event to connect with code
class ConnectWithCodeEvent extends ConnectionEvent {
  final String code;

  const ConnectWithCodeEvent(this.code);

  @override
  List<Object?> get props => [code];
}

/// Event to process deep link
class ProcessDeepLinkEvent extends ConnectionEvent {
  final Uri uri;

  const ProcessDeepLinkEvent(this.uri);

  @override
  List<Object?> get props => [uri];
}

/// Event to disconnect device
class DisconnectEvent extends ConnectionEvent {}

/// Event to refresh connection
class RefreshConnectionEvent extends ConnectionEvent {}
