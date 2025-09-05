// lib/blocs/auth/auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../models/user_profile.dart';
import '../../models/helper_models.dart';
import '../../models/sync_progress.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  final String? message;
  const AuthLoading({this.message});

  @override
  List<Object?> get props => [message];
}

// --- PERMISSION STATES ---
class AuthNeedsNotificationsPermission extends AuthState {
  const AuthNeedsNotificationsPermission();
}

class AuthNeedsHealthPermissions extends AuthState {
  const AuthNeedsHealthPermissions();
}

class AuthStatePermissionDenied extends AuthState {
  final String message;
  const AuthStatePermissionDenied(this.message);

  @override
  List<Object> get props => [message];
}

// --- EXISTING STATES ---
class AuthHealthPermissionsRequired extends AuthState {
  final HealthPermissionStatus availabilityStatus;
  final String message;

  const AuthHealthPermissionsRequired({
    this.availabilityStatus = HealthPermissionStatus.denied,
    this.message = 'Essential health permissions are required to proceed.',
  });

  @override
  List<Object?> get props => [availabilityStatus, message];
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user.id];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthOnboarding extends AuthState {
  final User user;
  const AuthOnboarding(this.user);

  @override
  List<Object> get props => [user.id];
}

class AuthProfileConfirmationRequired extends AuthState {
  final User user;
  final UserProfile? userProfile;

  const AuthProfileConfirmationRequired(this.user, {this.userProfile});

  @override
  List<Object?> get props => [user.id, userProfile];
}

class AuthProfileSyncing extends AuthState {
  final User user;
  final String? message;

  const AuthProfileSyncing(this.user, {this.message});

  @override
  List<Object?> get props => [user.id, message];
}

class AuthProfileSyncFailed extends AuthState {
  final User user;
  final String error;
  final bool canRetry;
  final int retryCount;

  const AuthProfileSyncFailed(
    this.user,
    this.error, {
    this.canRetry = true,
    this.retryCount = 0,
  });

  @override
  List<Object> get props => [user.id, error, canRetry, retryCount];
}

class AuthEmailVerificationPending extends AuthState {
  final String email;
  const AuthEmailVerificationPending(this.email);

  @override
  List<Object> get props => [email];
}

class AuthEmailAlreadyExists extends AuthState {
  final String email;
  const AuthEmailAlreadyExists(this.email);

  @override
  List<Object> get props => [email];
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});

  @override
  List<Object> get props => [message];
}

class AuthNavigateToLogin extends AuthState {
  const AuthNavigateToLogin();
}

/// The user is authenticated and their profile is complete.
/// They now need to establish the HealthBridge connection.
/// The UI should navigate to the TokenScreen.
class AuthNeedsConnection extends AuthState {
  final User user;
  const AuthNeedsConnection(this.user);

  @override
  List<Object> get props => [user.id];
}

class AuthOnboardingIntro extends AuthState {
  const AuthOnboardingIntro();
}

class AuthOnboardingComplete extends AuthState {
  final User user;
  const AuthOnboardingComplete(this.user);

  @override
  List<Object> get props => [user.id];
}

// State for the two-phase onboarding sync
class AuthOnboardingSyncInProgress extends AuthState {
  final SyncProgress progress;
  const AuthOnboardingSyncInProgress(this.progress);

  @override
  List<Object> get props => [progress];
}

// State for when the app is handling a deeplink handoff
class AuthHandoffInProgress extends AuthState {
  const AuthHandoffInProgress();

  @override
  List<Object?> get props => [];
}

// State for when priority sync (Phase 1) is complete
class AuthPrioritySyncComplete extends AuthState {
  final User user;
  const AuthPrioritySyncComplete(this.user);

  @override
  List<Object> get props => [user.id];
}

// State for when user needs to see welcome screen
class AuthNeedsWelcome extends AuthState {
  const AuthNeedsWelcome();
}

// State for when historical sync (Phase 2) is in progress
class AuthHistoricalSyncInProgress extends AuthState {
  final SyncProgress progress;
  const AuthHistoricalSyncInProgress(this.progress);

  @override
  List<Object> get props => [progress];
}
