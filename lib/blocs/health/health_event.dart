// lib/blocs/health/health_event.dart

import 'package:equatable/equatable.dart';

import '../../models/user_profile.dart';

/// Simplified Health Events - Basic health operations only
/// Removed complex Digital Twin orchestration events
abstract class HealthEvent extends Equatable {
  const HealthEvent();

  @override
  List<Object?> get props => [];
}

/// Check current health permissions status
class CheckHealthPermissionsEvent extends HealthEvent {
  const CheckHealthPermissionsEvent();

  @override
  String toString() => 'CheckHealthPermissionsEvent';
}

/// Request health permissions from the user
class RequestHealthPermissionsEvent extends HealthEvent {
  const RequestHealthPermissionsEvent();

  @override
  String toString() => 'RequestHealthPermissionsEvent';
}

/// Sync health data to the platform
class SyncHealthDataEvent extends HealthEvent {
  final bool isManual;
  final String? requestId;

  const SyncHealthDataEvent({
    this.isManual = false,
    this.requestId,
  });

  @override
  List<Object?> get props => [isManual, requestId];

  @override
  String toString() =>
      'SyncHealthDataEvent { isManual: $isManual, requestId: $requestId }';
}

/// Generate a connection token with profile data
class GenerateConnectionTokenEvent extends HealthEvent {
  final Map<String, dynamic> profileData;

  const GenerateConnectionTokenEvent({required this.profileData});

  @override
  List<Object?> get props => [profileData];

  @override
  String toString() =>
      'GenerateConnectionTokenEvent { profileData: $profileData }';
}

/// Update user profile
class ProfileUpdatedEvent extends HealthEvent {
  final UserProfile profile;

  const ProfileUpdatedEvent({required this.profile});

  @override
  List<Object?> get props => [profile];

  @override
  String toString() => 'ProfileUpdatedEvent { profile: $profile }';
}

/// Check profile completion status
class CheckProfileStatusEvent extends HealthEvent {
  const CheckProfileStatusEvent();

  @override
  String toString() => 'CheckProfileStatusEvent';
}

/// Load profile from storage
class LoadProfileEvent extends HealthEvent {
  const LoadProfileEvent();

  @override
  String toString() => 'LoadProfileEvent';
}

/// Extract profile data from health services (iOS only)
class ExtractProfileDataEvent extends HealthEvent {
  const ExtractProfileDataEvent();

  @override
  String toString() => 'ExtractProfileDataEvent';
}

/// Send heartbeat event
class SendHeartbeatEvent extends HealthEvent {
  const SendHeartbeatEvent();

  @override
  String toString() => 'SendHeartbeatEvent';
}
