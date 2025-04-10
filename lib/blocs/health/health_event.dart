// File path: lib/blocs/health/health_event.dart

import 'package:equatable/equatable.dart';

import '../../models/user_profile.dart';

abstract class HealthEvent extends Equatable {
  const HealthEvent();

  @override
  List<Object?> get props => [];
}

class CheckHealthPermissionsEvent extends HealthEvent {
  const CheckHealthPermissionsEvent();
}

class RequestHealthPermissionsEvent extends HealthEvent {
  const RequestHealthPermissionsEvent();
}

class RevokeHealthPermissionsEvent extends HealthEvent {
  const RevokeHealthPermissionsEvent();
}

class SyncHealthDataEvent extends HealthEvent {
  final bool showLoading;

  const SyncHealthDataEvent({this.showLoading = true});

  @override
  List<Object?> get props => [showLoading];
}

class RunHealthDiagnosticsEvent extends HealthEvent {
  const RunHealthDiagnosticsEvent();
}

class GenerateConnectionTokenEvent extends HealthEvent {
  final String? userId;
  final UserProfile? profile;

  const GenerateConnectionTokenEvent({
    this.userId,
    this.profile,
  });

  @override
  List<Object?> get props => [userId, profile];
}

class ValidateConnectionTokenEvent extends HealthEvent {
  final String token;
  final String? userId;

  const ValidateConnectionTokenEvent({
    required this.token,
    this.userId,
  });

  @override
  List<Object?> get props => [token, userId];
}

// New events for profile handling
class ProfileUpdatedEvent extends HealthEvent {
  final UserProfile profile;

  const ProfileUpdatedEvent({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class CheckProfileStatusEvent extends HealthEvent {
  const CheckProfileStatusEvent();
}

class LoadProfileEvent extends HealthEvent {
  const LoadProfileEvent();
}

// New events for auto-extraction of profile data
class ExtractProfileDataEvent extends HealthEvent {
  const ExtractProfileDataEvent();
}

class ProfileDataExtractedEvent extends HealthEvent {
  final UserProfile profile;

  const ProfileDataExtractedEvent({required this.profile});

  @override
  List<Object?> get props => [profile];
}

class ProfileDataExtractionFailedEvent extends HealthEvent {
  final String error;

  const ProfileDataExtractionFailedEvent({required this.error});

  @override
  List<Object?> get props => [error];
}
