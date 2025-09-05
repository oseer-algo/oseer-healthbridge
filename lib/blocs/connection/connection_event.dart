// lib/blocs/connection/connection_event.dart
import 'package:equatable/equatable.dart';
import '../../models/realtime_status.dart';
import '../../models/sync_progress.dart';
import '../../models/helper_models.dart' show SyncType;
import './connection_state.dart' show WellnessPhase;

/// Base event for the ConnectionBloc
abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// Check the current connection status
class CheckConnectionStatusEvent extends ConnectionEvent {
  const CheckConnectionStatusEvent();
}

/// Connect with a verification code
class ConnectWithCodeEvent extends ConnectionEvent {
  final String code;

  const ConnectWithCodeEvent(this.code);

  @override
  List<Object> get props => [code];
}

/// Process a deep link for connection
class ProcessDeepLinkEvent extends ConnectionEvent {
  final Uri uri;

  const ProcessDeepLinkEvent(this.uri);

  @override
  List<Object> get props => [uri];
}

/// Process wellness deep link returning from web dashboard
class ProcessWellnessDeepLinkEvent extends ConnectionEvent {
  final Uri uri;
  final String? sessionToken;

  const ProcessWellnessDeepLinkEvent({
    required this.uri,
    this.sessionToken,
  });

  @override
  List<Object?> get props => [uri, sessionToken];
}

/// Generate a new token
class GenerateNewTokenEvent extends ConnectionEvent {
  final bool clearExisting;

  const GenerateNewTokenEvent({this.clearExisting = false});

  @override
  List<Object> get props => [clearExisting];
}

/// Generate web auth token for dashboard access
class GenerateWebAuthTokenEvent extends ConnectionEvent {
  final String userId;
  final String? purpose;

  const GenerateWebAuthTokenEvent({
    required this.userId,
    this.purpose,
  });

  @override
  List<Object?> get props => [userId, purpose];
}

/// Refresh the connection state
class RefreshConnectionEvent extends ConnectionEvent {
  const RefreshConnectionEvent();
}

/// Disconnect from the service
class DisconnectEvent extends ConnectionEvent {
  const DisconnectEvent();
}

/// Token has expired
class TokenExpiredEvent extends ConnectionEvent {
  const TokenExpiredEvent();
}

/// Connection established via web platform
class ConnectionEstablishedViaWebEvent extends ConnectionEvent {
  final String userId;
  final String deviceId;
  final String? requestId;

  const ConnectionEstablishedViaWebEvent({
    required this.userId,
    required this.deviceId,
    this.requestId,
  });

  @override
  List<Object?> get props => [userId, deviceId, requestId];
}

/// Connection established via web platform with permanent token
class ConnectionEstablishedViaWebWithTokenEvent extends ConnectionEvent {
  final String userId;
  final String deviceId;
  final String connectionToken;
  final String? requestId;

  const ConnectionEstablishedViaWebWithTokenEvent({
    required this.userId,
    required this.deviceId,
    required this.connectionToken,
    this.requestId,
  });

  @override
  List<Object?> get props => [userId, deviceId, connectionToken, requestId];
}

/// Perform a sync operation
class PerformSyncEvent extends ConnectionEvent {
  final String? requestId;
  final SyncType syncType;

  const PerformSyncEvent({
    this.requestId,
    this.syncType = SyncType.priority,
  });

  @override
  List<Object?> get props => [requestId, syncType];
}

/// Mark token as used/viewed
class MarkTokenAsUsedEvent extends ConnectionEvent {
  const MarkTokenAsUsedEvent();
}

/// App resumed from background
class AppResumedEvent extends ConnectionEvent {
  final bool isInOnboardingProcess;

  const AppResumedEvent({this.isInOnboardingProcess = false});

  @override
  List<Object> get props => [isInOnboardingProcess];
}

/// Set sync enabled/disabled
class SetSyncEnabledEvent extends ConnectionEvent {
  final bool enabled;

  const SetSyncEnabledEvent({required this.enabled});

  @override
  List<Object> get props => [enabled];
}

/// Trigger sync operation
class TriggerSyncEvent extends ConnectionEvent {
  final bool forceFullSync;
  final bool isBackground;

  const TriggerSyncEvent({
    this.forceFullSync = false,
    this.isBackground = false,
  });

  @override
  List<Object> get props => [forceFullSync, isBackground];
}

/// Update connection metrics
class UpdateConnectionMetricsEvent extends ConnectionEvent {
  final String metricType;
  final Map<String, dynamic> metricData;

  const UpdateConnectionMetricsEvent({
    required this.metricType,
    required this.metricData,
  });

  @override
  List<Object> get props => [metricType, metricData];
}

/// Update wellness phase status
class UpdateWellnessPhaseEvent extends ConnectionEvent {
  final WellnessPhase phase;
  final double? bodyPrepProgress;
  final bool? bodyPrepReady;
  final DateTime? bodyPrepReadyTime;

  const UpdateWellnessPhaseEvent({
    required this.phase,
    this.bodyPrepProgress,
    this.bodyPrepReady,
    this.bodyPrepReadyTime,
  });

  @override
  List<Object?> get props =>
      [phase, bodyPrepProgress, bodyPrepReady, bodyPrepReadyTime];
}

/// Check token status on server (pull mechanism)
class CheckTokenStatusOnServer extends ConnectionEvent {
  final String token;

  const CheckTokenStatusOnServer({required this.token});

  @override
  List<Object> get props => [token];
}

/// Fired when the app is resumed via the post-connection success deeplink.
/// This tells the ConnectionBloc to stop polling and finalize its state.
class ConnectionEstablishedViaDeeplink extends ConnectionEvent {
  const ConnectionEstablishedViaDeeplink();
}

/// Server processing completed event
class ServerProcessingCompleted extends ConnectionEvent {
  final String requestId;

  const ServerProcessingCompleted({required this.requestId});

  @override
  List<Object> get props => [requestId];
}

/// Fired when the RealtimeSyncService status changes.
class RealtimeStatusChangedEvent extends ConnectionEvent {
  final RealtimeStatus status;

  const RealtimeStatusChangedEvent(this.status);

  @override
  List<Object> get props => [status];
}

/// Sync progress update event
class SyncProgressUpdatedEvent extends ConnectionEvent {
  final SyncProgress progress;

  const SyncProgressUpdatedEvent(this.progress);

  @override
  List<Object> get props => [progress];
}

/// Trigger historical sync event - allows UI to manually trigger Phase 2
// FIX: Add userId to the event to ensure it's available when the event is handled.
class TriggerHistoricalSyncEvent extends ConnectionEvent {
  final String userId;

  const TriggerHistoricalSyncEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// User pressed "Connect to Web" button
class ConnectToWebPressed extends ConnectionEvent {
  const ConnectToWebPressed();
}

/// Launch Wellness Hub event
class LaunchWellnessHubEvent extends ConnectionEvent {
  const LaunchWellnessHubEvent();

  @override
  String toString() => 'LaunchWellnessHubEvent';
}

/// Retry a failed sync operation
class RetrySyncEvent extends ConnectionEvent {
  final SyncType syncType;

  const RetrySyncEvent({required this.syncType});

  @override
  List<Object?> get props => [syncType];
}

/// Sync analysis completed event (from backend)
class SyncAnalysisCompletedEvent extends ConnectionEvent {
  // **FIX: Add properties to carry the data from Realtime**
  final String status;
  final Map<String, dynamic> results;

  const SyncAnalysisCompletedEvent(
      {required this.status, required this.results});

  @override
  List<Object?> get props => [status, results];
}

/// Finalize handoff connection event
class FinalizeHandoffConnection extends ConnectionEvent {
  const FinalizeHandoffConnection();

  @override
  String toString() => 'FinalizeHandoffConnection';
}

/// Event for handling handoff timeout
class HandoffTimedOut extends ConnectionEvent {
  const HandoffTimedOut();

  @override
  String toString() => 'HandoffTimedOut';
}

/// NEW: Event to proactively check handoff status via API
class CheckHandoffStatusOnResume extends ConnectionEvent {
  const CheckHandoffStatusOnResume();

  @override
  String toString() => 'CheckHandoffStatusOnResume';
}
