// lib/blocs/health/health_bloc.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../services/logger_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../managers/health_manager.dart';
import '../../managers/token_manager.dart';
import '../../managers/user_manager.dart';
import '../../models/helper_models.dart' as helper;
import '../../models/user_profile.dart';
import '../../models/sync_progress.dart';
import '../../blocs/connection/connection_bloc.dart';
import '../../blocs/connection/connection_event.dart';
import 'health_state.dart';
import 'health_event.dart';

class HealthBloc extends Bloc<HealthEvent, HealthState> {
  final HealthManager healthManager;
  final TokenManager tokenManager;
  final UserManager userManager;
  final SharedPreferences prefs;
  final Uuid _uuid = const Uuid();
  final ConnectionBloc connectionBloc;
  final ConnectivityService? connectivityService;
  final NotificationService? notificationService;

  HealthBloc({
    required this.healthManager,
    required this.tokenManager,
    required this.userManager,
    required this.prefs,
    required this.connectionBloc,
    this.connectivityService,
    this.notificationService,
  }) : super(const HealthInitial()) {
    on<CheckHealthPermissionsEvent>(_onCheckHealthPermissions);
    on<RequestHealthPermissionsEvent>(_onRequestHealthPermissions);
    on<SyncHealthDataEvent>(_onSyncHealthData);
    // REMOVED: on<GenerateConnectionTokenEvent>(_onGenerateConnectionToken);
    on<ProfileUpdatedEvent>(_onProfileUpdated);
    on<CheckProfileStatusEvent>(_onCheckProfileStatus);
    on<LoadProfileEvent>(_onLoadProfile);
    on<ExtractProfileDataEvent>(_onExtractProfileData);
    on<SendHeartbeatEvent>(_onSendHeartbeat);
  }

  Future<void> _onCheckHealthPermissions(
      CheckHealthPermissionsEvent event, Emitter<HealthState> emit) async {
    OseerLogger.info('🔍 Checking wellness permissions');
    try {
      final helper.HealthAuthStatus authStatus =
          await healthManager.checkWellnessPermissions();
      final profileStatus = userManager.isProfileComplete()
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;
      final profile = userManager.getUserProfileObject();
      emit(HealthPermissionsChecked(
          authStatus: authStatus,
          profileStatus: profileStatus,
          profile: profile));
    } catch (e, s) {
      OseerLogger.error('❌ Error checking permissions', e, s);
      emit(HealthError(
          message: 'Failed to check permissions', error: e.toString()));
    }
  }

  Future<void> _onRequestHealthPermissions(
      RequestHealthPermissionsEvent event, Emitter<HealthState> emit) async {
    OseerLogger.info('🔄 Requesting wellness permissions');
    try {
      final authStatus = await healthManager.requestWellnessPermissions();
      final profileStatus = userManager.isProfileComplete()
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;
      final profile = userManager.getUserProfileObject();
      emit(HealthPermissionsChecked(
          authStatus: authStatus,
          requestStatus: RequestStatus.success,
          profileStatus: profileStatus,
          profile: profile));
    } catch (e, s) {
      OseerLogger.error('❌ Error requesting permissions', e, s);
      emit(HealthError(
          message: "Permission request failed", error: e.toString()));
    }
  }

  Future<void> _onSyncHealthData(
      SyncHealthDataEvent event, Emitter<HealthState> emit) async {
    OseerLogger.info('🔄 Starting wellness data sync...');

    final currentState = state;
    helper.HealthAuthStatus currentAuth;
    ProfileStatus currentProfileStatus;
    UserProfile? currentProfile;
    DateTime? lastSync;

    if (currentState is HealthPermissionsChecked) {
      currentAuth = currentState.authStatus;
      currentProfileStatus = currentState.profileStatus;
      currentProfile = currentState.profile;
    } else if (currentState is HealthDataSynced) {
      currentAuth = currentState.authStatus;
      currentProfileStatus = currentState.profileStatus;
      currentProfile = currentState.profile;
      lastSync = currentState.lastSyncTime;
    } else {
      currentAuth = await healthManager.checkWellnessPermissions();
      currentProfileStatus = userManager.isProfileComplete()
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;
      currentProfile = userManager.getUserProfileObject();
    }

    lastSync ??=
        DateTime.tryParse(prefs.getString(OseerConstants.keyLastSync) ?? '');

    emit(HealthDataSynced(
      authStatus: currentAuth,
      syncStatus: SyncStatus.syncing,
      lastSyncTime: lastSync,
      profileStatus: currentProfileStatus,
      profile: currentProfile,
      syncProgress: SyncProgress.initial(),
    ));

    try {
      final bool syncResult = await healthManager.syncHealthData(
        syncType: event.isManual
            ? helper.SyncType.historical
            : helper.SyncType.priority,
      );

      final syncTime = DateTime.now();

      final latestState = state;
      if (latestState is HealthDataSynced) {
        emit(latestState.copyWith(
            syncStatus: syncResult ? SyncStatus.success : SyncStatus.failure,
            lastSyncTime: syncResult ? syncTime : latestState.lastSyncTime,
            errorMessage: syncResult
                ? null
                : "Sync failed. Please check permissions and network."));
      }

      if (syncResult) {
        await prefs.setString(
            OseerConstants.keyLastSync, syncTime.toUtc().toIso8601String());
      }
    } catch (e, s) {
      OseerLogger.error('❌ Error in _onSyncHealthData', e, s);
      final latestState = state;
      if (latestState is HealthDataSynced) {
        // **FIX**: Safe cast before calling copyWith
        emit(latestState.copyWith(
          syncStatus: SyncStatus.failure,
          errorMessage: 'An unexpected error occurred during sync.',
        ));
      }
    }
  }

  // REMOVED: _onGenerateConnectionToken method - no longer needed

  Future<void> _onProfileUpdated(
      ProfileUpdatedEvent event, Emitter<HealthState> emit) async {
    OseerLogger.info('👤 Profile update event received');
    emit(const HealthLoading(message: 'Updating profile...'));
    try {
      final bool success = await userManager.updateUserProfile(event.profile);
      final updatedProfile =
          userManager.getUserProfileObject() ?? event.profile;
      emit(ProfileUpdated(
          profile: updatedProfile, isComplete: updatedProfile.isComplete()));
    } catch (e, s) {
      OseerLogger.error('❌ Error processing profile update', e, s);
      emit(HealthError(message: 'Failed to save profile', error: e.toString()));
    }
  }

  Future<void> _onCheckProfileStatus(
      CheckProfileStatusEvent event, Emitter<HealthState> emit) async {
    final isComplete = userManager.isProfileComplete();
    final profile = userManager.getUserProfileObject();
    emit(ProfileChecked(
        status: isComplete ? ProfileStatus.complete : ProfileStatus.incomplete,
        profile: profile));
  }

  Future<void> _onLoadProfile(
      LoadProfileEvent event, Emitter<HealthState> emit) async {
    final profile = userManager.getUserProfileObject();
    if (profile != null) {
      emit(ProfileUpdated(profile: profile, isComplete: profile.isComplete()));
    } else {
      emit(const ProfileChecked(status: ProfileStatus.incomplete));
    }
  }

  Future<void> _onExtractProfileData(
      ExtractProfileDataEvent event, Emitter<HealthState> emit) async {
    OseerLogger.info('🧬 Extracting profile data event received');
    if (Platform.isAndroid) {
      emit(const ProfileDataExtractionFailed(
          error: 'Profile data extraction not supported on Android.'));
      return;
    }
    emit(const ProfileDataExtracting());
    try {
      final extractedProfile = await healthManager.extractUserProfileData();
      if (extractedProfile != null) {
        emit(ProfileDataExtracted(profile: extractedProfile));
      } else {
        emit(const ProfileDataExtractionFailed(
            error: 'No new profile data found in health service.'));
      }
    } catch (e, s) {
      OseerLogger.error('❌ Error extracting profile data', e, s);
      emit(ProfileDataExtractionFailed(
          error: 'Extraction failed: ${e.toString()}'));
    }
  }

  Future<void> _onSendHeartbeat(
      SendHeartbeatEvent event, Emitter<HealthState> emit) async {
    try {
      await healthManager.apiService.sendHeartbeat();
    } catch (e) {
      OseerLogger.warning('Failed to send heartbeat: $e');
    }
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
