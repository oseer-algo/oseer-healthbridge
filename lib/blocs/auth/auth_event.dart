// lib/blocs/auth/auth_event.dart
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/sync_progress.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  onboarding,
  emailVerificationPending,
  error
}

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthInitializeEvent extends AuthEvent {
  const AuthInitializeEvent();
  @override
  String toString() => 'AuthInitializeEvent';
}

class AuthCheckStoredAuthEvent extends AuthEvent {
  const AuthCheckStoredAuthEvent();
  @override
  String toString() => 'AuthCheckStoredAuthEvent';
}

class AuthSignUpEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;
  const AuthSignUpEvent(
      {required this.name, required this.email, required this.password});
  @override
  List<Object> get props => [name, email, password];
  @override
  String toString() => 'AuthSignUpEvent';
}

class AuthLoginEvent extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginEvent({required this.email, required this.password});
  @override
  List<Object> get props => [email, password];
  @override
  String toString() => 'AuthLoginEvent';
}

class AuthSignOutEvent extends AuthEvent {
  const AuthSignOutEvent();
  @override
  String toString() => 'AuthSignOutEvent';
}

class AuthCompleteOnboardingEvent extends AuthEvent {
  const AuthCompleteOnboardingEvent();
  @override
  String toString() => 'AuthCompleteOnboardingEvent';
}

class AuthProfileConfirmedEvent extends AuthEvent {
  const AuthProfileConfirmedEvent();
  @override
  String toString() => 'AuthProfileConfirmedEvent';
}

class AuthUserUpdatedEvent extends AuthEvent {
  final User user;
  const AuthUserUpdatedEvent(this.user);
  @override
  List<Object> get props => [user];
  @override
  String toString() => 'AuthUserUpdatedEvent';
}

class AuthStateChangedEvent extends AuthEvent {
  final AuthStatus status;
  const AuthStateChangedEvent(this.status);
  @override
  List<Object> get props => [status];
  @override
  String toString() => 'AuthStateChangedEvent';
}

class AuthUserChangedEvent extends AuthEvent {
  final User? user;
  const AuthUserChangedEvent(this.user);
  @override
  List<Object?> get props => [user];
  @override
  String toString() => 'AuthUserChangedEvent';
}

class AuthNavigateToLoginEvent extends AuthEvent {
  const AuthNavigateToLoginEvent();
  @override
  String toString() => 'AuthNavigateToLoginEvent';
}

class AuthResendVerificationEvent extends AuthEvent {
  final String email;
  const AuthResendVerificationEvent(this.email);
  @override
  List<Object> get props => [email];
  @override
  String toString() => 'AuthResendVerificationEvent';
}

class AuthCheckVerificationEvent extends AuthEvent {
  final String email;
  const AuthCheckVerificationEvent(this.email);
  @override
  List<Object> get props => [email];
  @override
  String toString() => 'AuthCheckVerificationEvent';
}

// --- Permission Flow Events ---

class AuthNotificationsPermissionRequested extends AuthEvent {
  const AuthNotificationsPermissionRequested();
  @override
  String toString() => 'AuthNotificationsPermissionRequested';
}

class AuthHealthPermissionsRequested extends AuthEvent {
  const AuthHealthPermissionsRequested();
  @override
  String toString() => 'AuthHealthPermissionsRequested';
}

class AuthAppResumedEvent extends AuthEvent {
  const AuthAppResumedEvent();
  @override
  String toString() => 'AuthAppResumedEvent';
}

class AuthProceedAfterNotificationsEvent extends AuthEvent {
  final bool granted;
  const AuthProceedAfterNotificationsEvent({required this.granted});
  @override
  List<Object> get props => [granted];
  @override
  String toString() => 'AuthProceedAfterNotificationsEvent';
}

class AuthHealthPermissionsSkipped extends AuthEvent {
  const AuthHealthPermissionsSkipped();
  @override
  String toString() => 'AuthHealthPermissionsSkipped';
}

/// Fired after the user interacts with the notification permission dialog.
class AuthNotificationPermissionHandled extends AuthEvent {
  /// True if the user tapped "Enable", false if they tapped "Skip".
  final bool permissionRequested;
  const AuthNotificationPermissionHandled(this.permissionRequested);

  @override
  List<Object> get props => [permissionRequested];

  @override
  String toString() =>
      'AuthNotificationPermissionHandled(permissionRequested: $permissionRequested)';
}

/// Fired after the user interacts with the health permission dialog.
class AuthHealthPermissionHandled extends AuthEvent {
  /// True if permissions were granted, false if denied.
  final bool granted;
  const AuthHealthPermissionHandled({required this.granted});

  @override
  List<Object> get props => [granted];

  @override
  String toString() => 'AuthHealthPermissionHandled(granted: $granted)';
}

// --- Onboarding Sync Events ---

class AuthStartOnboardingSyncEvent extends AuthEvent {
  const AuthStartOnboardingSyncEvent();
  @override
  String toString() => 'AuthStartOnboardingSyncEvent';
}

class AuthOnboardingProgressUpdated extends AuthEvent {
  final SyncProgress progress;
  const AuthOnboardingProgressUpdated(this.progress);
  @override
  List<Object> get props => [progress];
  @override
  String toString() => 'AuthOnboardingProgressUpdated(progress: $progress)';
}

/// Fired when the app is resumed via a deeplink that signifies a successful
/// web-based authentication or connection handoff. This tells the AuthBloc
/// to bypass the standard initialization sequence.
class AuthBypassInitialization extends AuthEvent {
  const AuthBypassInitialization();

  @override
  String toString() => 'AuthBypassInitialization';
}

/// Fired by the ConnectionBloc when a secure connection is successfully
/// established, signaling the AuthBloc to begin the data sync process.
class AuthConnectionEstablishedEvent extends AuthEvent {
  const AuthConnectionEstablishedEvent();

  @override
  String toString() => 'AuthConnectionEstablishedEvent';
}

/// Fired when the app resumes from a web handoff and needs to finalize the connection
class AuthHandoffFinalizationRequested extends AuthEvent {
  const AuthHandoffFinalizationRequested();

  @override
  String toString() => 'AuthHandoffFinalizationRequested';
}

/// Fired to check for pending tasks that failed during onboarding
class AuthCheckPendingTasksEvent extends AuthEvent {
  const AuthCheckPendingTasksEvent();

  @override
  String toString() => 'AuthCheckPendingTasksEvent';
}

/// Fired when historical sync (Phase 2) is started
class HistoricalSyncStarted extends AuthEvent {
  const HistoricalSyncStarted();

  @override
  String toString() => 'HistoricalSyncStarted';
}

/// NEW: Fired when ConnectionBloc reports that priority sync is complete
class AuthPrioritySyncCompleteEvent extends AuthEvent {
  const AuthPrioritySyncCompleteEvent();

  @override
  String toString() => 'AuthPrioritySyncCompleteEvent';
}
