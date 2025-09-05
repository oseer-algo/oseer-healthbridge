// lib/blocs/health/health_state.dart
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart'; // Add for date formatting

import '../../models/helper_models.dart';
import '../../models/user_profile.dart';
import '../../models/sync_progress.dart';

enum RequestStatus { initial, loading, success, failure }

enum SyncStatus { initial, syncing, success, failure }

enum ProfileStatus { initial, incomplete, complete }

abstract class HealthState extends Equatable {
  const HealthState();
  @override
  List<Object?> get props => [];
}

class HealthInitial extends HealthState {
  const HealthInitial();
}

class HealthLoading extends HealthState {
  final String? message;
  const HealthLoading({this.message});
  @override
  List<Object?> get props => [message];
}

class HealthError extends HealthState {
  final String message;
  final String? error;
  const HealthError({required this.message, this.error});
  @override
  List<Object?> get props => [message, error];
}

class HealthPermissionsChecked extends HealthState {
  final HealthAuthStatus authStatus;
  final RequestStatus requestStatus;
  final ProfileStatus profileStatus;
  final UserProfile? profile;

  const HealthPermissionsChecked({
    required this.authStatus,
    this.requestStatus = RequestStatus.initial,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
  });

  bool get hasBasicPermissions =>
      authStatus.status == HealthPermissionStatus.granted ||
      authStatus.status == HealthPermissionStatus.partiallyGranted;

  bool get hasCriticalPermissions {
    final criticalPermissions = ['weight', 'height', 'steps', 'sleep_asleep'];
    return criticalPermissions.every(
        (permission) => authStatus.grantedPermissions.contains(permission));
  }

  @override
  List<Object?> get props =>
      [authStatus, requestStatus, profileStatus, profile];
}

class HealthDataSynced extends HealthState {
  final HealthAuthStatus authStatus;
  final SyncStatus syncStatus;
  final DateTime? lastSyncTime;
  final ProfileStatus profileStatus;
  final UserProfile? profile;
  final String? errorMessage;
  final SyncProgress? syncProgress;

  const HealthDataSynced({
    required this.authStatus,
    required this.syncStatus,
    this.lastSyncTime,
    this.profileStatus = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
    this.syncProgress,
  });

  // **FIX**: ADDED THE MISSING COPYWITH METHOD.
  HealthDataSynced copyWith({
    HealthAuthStatus? authStatus,
    SyncStatus? syncStatus,
    DateTime? lastSyncTime,
    ProfileStatus? profileStatus,
    UserProfile? profile,
    String? errorMessage,
    SyncProgress? syncProgress,
  }) {
    return HealthDataSynced(
      authStatus: authStatus ?? this.authStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      profileStatus: profileStatus ?? this.profileStatus,
      profile: profile ?? this.profile,
      errorMessage: errorMessage ?? this.errorMessage,
      syncProgress: syncProgress ?? this.syncProgress,
    );
  }

  bool get isSyncSuccessful => syncStatus == SyncStatus.success;
  bool get isSyncing => syncStatus == SyncStatus.syncing;

  String get syncStatusDescription {
    switch (syncStatus) {
      case SyncStatus.initial:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return syncProgress?.currentActivity ?? 'Syncing health data...';
      case SyncStatus.success:
        return 'Sync completed successfully';
      case SyncStatus.failure:
        return 'Sync failed';
    }
  }

  String? get lastSyncDescription {
    if (lastSyncTime == null) return null;
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime!);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  List<Object?> get props => [
        authStatus,
        syncStatus,
        lastSyncTime,
        profileStatus,
        profile,
        errorMessage,
        syncProgress
      ];
}

class TokenGenerated extends HealthState {
  final String token;
  final String userId;
  final String deviceId;
  final UserProfile? profile;
  final bool isLocalToken;
  final DateTime? expiresAt;

  const TokenGenerated({
    required this.token,
    required this.userId,
    required this.deviceId,
    this.profile,
    this.isLocalToken = false,
    this.expiresAt,
  });

  String get formattedToken {
    if (token.length >= 8) {
      return '${token.substring(0, 4).toUpperCase()}/${token.substring(4, 8).toUpperCase()}';
    }
    return token.toUpperCase();
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  List<Object?> get props =>
      [token, userId, deviceId, profile, isLocalToken, expiresAt];
}

class ProfileUpdated extends HealthState {
  final UserProfile profile;
  final bool isComplete;
  const ProfileUpdated({required this.profile, required this.isComplete});
  @override
  List<Object?> get props => [profile, isComplete];
}

class ProfileChecked extends HealthState {
  final ProfileStatus status;
  final UserProfile? profile;
  const ProfileChecked({required this.status, this.profile});
  @override
  List<Object?> get props => [status, profile];
}

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
