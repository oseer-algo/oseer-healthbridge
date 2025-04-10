// File path: lib/blocs/health/health_state.dart

import 'package:equatable/equatable.dart';

import '../../models/helper_models.dart';
import '../../models/user_profile.dart';

// Base health state
abstract class HealthState extends Equatable {
  const HealthState();

  @override
  List<Object?> get props => [];
}

// Initial state
class HealthInitial extends HealthState {
  const HealthInitial();
}

// Loading state
class HealthLoading extends HealthState {
  final String message;

  const HealthLoading({this.message = 'Loading...'});

  @override
  List<Object?> get props => [message];
}

// Health permissions checked state
class HealthPermissionsChecked extends HealthState {
  final HealthAuthStatus authStatus;
  final RequestStatus requestStatus;
  final ProfileStatus profileStatus;
  final UserProfile? profile;
  final String? message;

  const HealthPermissionsChecked({
    required this.authStatus,
    this.requestStatus = RequestStatus.initial,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
    this.message,
  });

  @override
  List<Object?> get props =>
      [authStatus, requestStatus, profileStatus, profile, message];

  // Create a copy with updated fields
  HealthPermissionsChecked copyWith({
    HealthAuthStatus? authStatus,
    RequestStatus? requestStatus,
    ProfileStatus? profileStatus,
    UserProfile? profile,
    String? message,
  }) {
    return HealthPermissionsChecked(
      authStatus: authStatus ?? this.authStatus,
      requestStatus: requestStatus ?? this.requestStatus,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
      message: message ?? this.message,
    );
  }
}

// Health data synced state
class HealthDataSynced extends HealthState {
  final HealthAuthStatus authStatus;
  final SyncStatus syncStatus;
  final DateTime? lastSyncTime;
  final ProfileStatus profileStatus;
  final UserProfile? profile;

  const HealthDataSynced({
    required this.authStatus,
    this.syncStatus = SyncStatus.initial,
    this.lastSyncTime,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
  });

  @override
  List<Object?> get props =>
      [authStatus, syncStatus, lastSyncTime, profileStatus, profile];

  // Create a copy with updated fields
  HealthDataSynced copyWith({
    HealthAuthStatus? authStatus,
    SyncStatus? syncStatus,
    DateTime? lastSyncTime,
    ProfileStatus? profileStatus,
    UserProfile? profile,
  }) {
    return HealthDataSynced(
      authStatus: authStatus ?? this.authStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
    );
  }
}

// Token generated state
class TokenGenerated extends HealthState {
  final String token;
  final String userId;
  final String deviceId;
  final UserProfile? profile;

  const TokenGenerated({
    required this.token,
    required this.userId,
    required this.deviceId,
    this.profile,
  });

  @override
  List<Object?> get props => [token, userId, deviceId, profile];
}

// Token validated state
class TokenValidated extends HealthState {
  final String token;
  final String userId;
  final UserProfile? profile;

  const TokenValidated({
    required this.token,
    required this.userId,
    this.profile,
  });

  @override
  List<Object?> get props => [token, userId, profile];
}

// Profile updated state
class ProfileUpdated extends HealthState {
  final UserProfile profile;
  final bool isComplete;

  const ProfileUpdated({
    required this.profile,
    this.isComplete = true,
  });

  @override
  List<Object?> get props => [profile, isComplete];
}

// Profile checked state
class ProfileChecked extends HealthState {
  final ProfileStatus status;
  final UserProfile? profile;
  final String? message;

  const ProfileChecked({
    required this.status,
    this.profile,
    this.message,
  });

  @override
  List<Object?> get props => [status, profile, message];
}

// New states for profile data extraction
class ProfileDataExtracting extends HealthState {
  const ProfileDataExtracting();
}

class ProfileDataExtracted extends HealthState {
  final UserProfile profile;

  const ProfileDataExtracted({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class ProfileDataExtractionFailed extends HealthState {
  final String error;

  const ProfileDataExtractionFailed({required this.error});

  @override
  List<Object?> get props => [error];
}

// Error state
class HealthError extends HealthState {
  final String message;
  final String error;

  const HealthError({
    required this.message,
    required this.error,
  });

  @override
  List<Object?> get props => [message, error];
}

// Profile status to track profile completion
enum ProfileStatus { initial, incomplete, complete }

// Health request status to track async operations
enum HealthRequestStatus { initial, loading, success, failure }
