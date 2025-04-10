// File path: lib/blocs/health/health_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../services/logger_service.dart';
import '../../utils/constants.dart';
import '../../managers/health_manager.dart';
import '../../managers/token_manager.dart';
import '../../models/helper_models.dart';
import '../../models/user_profile.dart';
import '../../utils/health_connect_debugger.dart';
import 'health_event.dart';
import 'health_state.dart';

class HealthBloc extends Bloc<HealthEvent, HealthState> {
  final HealthManager healthManager;
  final TokenManager tokenManager;
  final SharedPreferences prefs;
  final HealthConnectDebugger _debugger = HealthConnectDebugger();

  HealthBloc({
    required this.healthManager,
    required this.tokenManager,
    required this.prefs,
  }) : super(const HealthInitial()) {
    on<CheckHealthPermissionsEvent>(_onCheckHealthPermissions);
    on<RequestHealthPermissionsEvent>(_onRequestHealthPermissions);
    on<RevokeHealthPermissionsEvent>(_onRevokeHealthPermissions);
    on<SyncHealthDataEvent>(_onSyncHealthData);
    on<RunHealthDiagnosticsEvent>(_onRunHealthDiagnostics);
    on<GenerateConnectionTokenEvent>(_onGenerateConnectionToken);
    on<ValidateConnectionTokenEvent>(_onValidateConnectionToken);

    // Profile-related event handlers
    on<ProfileUpdatedEvent>(_onProfileUpdated);
    on<CheckProfileStatusEvent>(_onCheckProfileStatus);
    on<LoadProfileEvent>(_onLoadProfile);

    // New handlers for profile data extraction
    on<ExtractProfileDataEvent>(_onExtractProfileData);
    on<ProfileDataExtractedEvent>(_onProfileDataExtracted);
    on<ProfileDataExtractionFailedEvent>(_onProfileDataExtractionFailed);
  }

  /// Check wellness permissions
  Future<void> _onCheckHealthPermissions(
    CheckHealthPermissionsEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔍 Checking wellness permissions');
      emit(const HealthLoading(message: 'Checking wellness permissions...'));

      // Check wellness permissions
      final authStatus = await healthManager.checkWellnessPermissions();

      // Log permissions
      OseerLogger.info(
          '🏥 Wellness permissions status: ${authStatus.status.toString()}');
      OseerLogger.info(
          '🏥 Granted permissions: ${authStatus.grantedPermissions.join(", ")}');

      // Check profile status for a complete state
      final isProfileComplete = tokenManager.isProfileComplete();
      final profileStatus =
          isProfileComplete ? ProfileStatus.complete : ProfileStatus.incomplete;
      final profile = tokenManager.getUserProfileObject();

      // Emit new state
      emit(HealthPermissionsChecked(
        authStatus: authStatus,
        profileStatus: profileStatus,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error checking wellness permissions', e);
      emit(HealthError(
        message: 'Failed to check wellness permissions',
        error: e.toString(),
      ));
    }
  }

  /// Request wellness permissions
  Future<void> _onRequestHealthPermissions(
    RequestHealthPermissionsEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      // Start with current state if available
      HealthAuthStatus currentAuthStatus;

      // Safely check for the current state and handle different state types
      if (state is HealthPermissionsChecked) {
        currentAuthStatus = (state as HealthPermissionsChecked).authStatus;
      } else if (state is HealthDataSynced) {
        currentAuthStatus = (state as HealthDataSynced).authStatus;
      } else {
        // Default empty auth status if we don't have a valid state
        currentAuthStatus = const HealthAuthStatus(
          status: HealthPermissionStatus.denied,
          grantedPermissions: [],
        );
      }

      // Emit loading state but preserve current auth status
      emit(HealthPermissionsChecked(
        authStatus: currentAuthStatus,
        requestStatus: RequestStatus.loading,
      ));

      OseerLogger.info('🔄 Requesting wellness permissions');

      // Request permissions
      final authStatus = await healthManager.requestWellnessPermissions();

      // Log new permissions
      OseerLogger.info(
          '✅ Wellness permissions granted: ${authStatus.status.toString()}');
      OseerLogger.info(
          '📋 Granted permissions: ${authStatus.grantedPermissions.join(", ")}');

      // Get current profile status for the state
      final isProfileComplete = tokenManager.isProfileComplete();
      final profileStatus =
          isProfileComplete ? ProfileStatus.complete : ProfileStatus.incomplete;
      final profile = tokenManager.getUserProfileObject();

      // Emit new state
      emit(HealthPermissionsChecked(
        authStatus: authStatus,
        requestStatus: RequestStatus.success,
        profileStatus: profileStatus,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error requesting Wellness Connect permissions', e);

      // Create a safe auth status for error state
      final errorAuthStatus = HealthAuthStatus(
        status: HealthPermissionStatus.denied,
        grantedPermissions: [],
        message: 'Error requesting permissions: ${e.toString()}',
      );

      emit(HealthPermissionsChecked(
        authStatus: errorAuthStatus,
        requestStatus: RequestStatus.failure,
      ));
    }
  }

  /// Revoke wellness permissions
  Future<void> _onRevokeHealthPermissions(
    RevokeHealthPermissionsEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔄 Revoking wellness permissions');
      emit(const HealthLoading(message: 'Revoking wellness permissions...'));

      // Just check wellness permissions since we don't have a direct revoke method
      // User will need to go to system settings to actually revoke
      final authStatus = await healthManager.checkWellnessPermissions();

      // Log the current status
      OseerLogger.info(
          'ℹ️ Current wellness permissions status: ${authStatus.status}');
      OseerLogger.info(
          'ℹ️ Please go to system settings to revoke wellness permissions');

      // Get current profile status for the state
      final isProfileComplete = tokenManager.isProfileComplete();
      final profileStatus =
          isProfileComplete ? ProfileStatus.complete : ProfileStatus.incomplete;
      final profile = tokenManager.getUserProfileObject();

      // Emit new state
      emit(HealthPermissionsChecked(
        authStatus: authStatus,
        profileStatus: profileStatus,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error with wellness permissions', e);
      emit(HealthError(
        message: 'Failed to handle wellness permissions',
        error: e.toString(),
      ));
    }
  }

  /// Sync wellness data
  Future<void> _onSyncHealthData(
    SyncHealthDataEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      // Get current auth status
      HealthAuthStatus authStatus;

      if (state is HealthPermissionsChecked) {
        authStatus = (state as HealthPermissionsChecked).authStatus;
      } else if (state is HealthDataSynced) {
        authStatus = (state as HealthDataSynced).authStatus;
      } else {
        // If we don't have permissions info, check them first
        authStatus = await healthManager.checkWellnessPermissions();
      }

      // Check if we have the necessary permissions
      if (authStatus.status == HealthPermissionStatus.denied ||
          authStatus.status == HealthPermissionStatus.unavailable) {
        OseerLogger.warning('⚠️ Cannot sync wellness data: No permissions');
        emit(HealthDataSynced(
          authStatus: authStatus,
          syncStatus: SyncStatus.failure,
        ));
        return;
      }

      // Show loading state if requested
      if (event.showLoading) {
        emit(const HealthLoading(message: 'Syncing wellness data...'));
      }

      OseerLogger.info('🔄 Starting wellness data sync');

      // Sync data
      final syncResult = await healthManager.syncWellnessData();

      // Handle bool or other return types
      final success =
          syncResult == true || (syncResult is bool && syncResult == true);
      final syncTime = DateTime.now();

      // Save last sync time
      await prefs.setString(
          OseerConstants.keyLastSync, syncTime.toIso8601String());

      // Log result
      if (success) {
        OseerLogger.info('✅ Wellness data synced successfully');
      } else {
        OseerLogger.warning('⚠️ Wellness data sync completed with warnings');
      }

      // Get current profile status for the state
      final isProfileComplete = tokenManager.isProfileComplete();
      final profileStatus =
          isProfileComplete ? ProfileStatus.complete : ProfileStatus.incomplete;
      final profile = tokenManager.getUserProfileObject();

      // Emit new state
      emit(HealthDataSynced(
        authStatus: authStatus,
        syncStatus: success ? SyncStatus.success : SyncStatus.failure,
        lastSyncTime: syncTime,
        profileStatus: profileStatus,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error syncing wellness data', e);
      emit(HealthError(
        message: 'Failed to sync wellness data',
        error: e.toString(),
      ));
    }
  }

  /// Run wellness diagnostics
  Future<void> _onRunHealthDiagnostics(
    RunHealthDiagnosticsEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔍 Running wellness diagnostics');
      emit(const HealthLoading(message: 'Running wellness diagnostics...'));

      // Run diagnostics
      final results = await runDiagnostics();

      // Keep the current state but add a log of the diagnostics
      OseerLogger.info('✅ Wellness diagnostics completed');
      OseerLogger.info('📊 Diagnostics results: $results');

      // Restore previous state
      if (state is HealthLoading) {
        // Run permissions check if we were in loading state
        final authStatus = await healthManager.checkWellnessPermissions();

        // Get current profile status for the state
        final isProfileComplete = tokenManager.isProfileComplete();
        final profileStatus = isProfileComplete
            ? ProfileStatus.complete
            : ProfileStatus.incomplete;
        final profile = tokenManager.getUserProfileObject();

        emit(HealthPermissionsChecked(
          authStatus: authStatus,
          profileStatus: profileStatus,
          profile: profile,
        ));
      }
    } catch (e) {
      OseerLogger.error('❌ Error running wellness diagnostics', e);
      emit(HealthError(
        message: 'Failed to run wellness diagnostics',
        error: e.toString(),
      ));
    }
  }

  /// Generate connection token
  Future<void> _onGenerateConnectionToken(
    GenerateConnectionTokenEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔑 Generating connection token');
      emit(const HealthLoading(message: 'Generating connection token...'));

      // Get or generate user ID
      final userId = event.userId ?? prefs.getString(OseerConstants.keyUserId);
      final finalUserId = userId ?? const Uuid().v4();

      // Store user ID if it's new
      if (userId == null) {
        await prefs.setString(OseerConstants.keyUserId, finalUserId);
        OseerLogger.info('👤 Generated new user ID: $finalUserId');
      }

      // Get or generate device ID
      String deviceId = await healthManager.getDeviceId();
      OseerLogger.info('📱 Generated new device ID: $deviceId');

      // Get profile (either from event or from token manager)
      final profile = event.profile ?? tokenManager.getUserProfileObject();

      // Ensure we have a profile before generating a token
      if (profile == null) {
        throw Exception('Profile information required to generate a token');
      }

      // Generate token with profile data
      final profileData = {
        'userId': finalUserId,
        'deviceId': deviceId,
        'name': profile.name,
        'email': profile.email,
      };

      final token = await tokenManager.generateToken(profileData);

      OseerLogger.info('✅ Token generation successful');

      // Emit new state
      emit(TokenGenerated(
        token: token,
        userId: finalUserId,
        deviceId: deviceId,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error generating token', e);
      emit(HealthError(
        message: 'Failed to generate connection token',
        error: e.toString(),
      ));
    }
  }

  /// Validate connection token
  Future<void> _onValidateConnectionToken(
    ValidateConnectionTokenEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔍 Validating connection token');
      emit(const HealthLoading(message: 'Validating connection token...'));

      // Get or use provided user ID
      final userId = event.userId ?? prefs.getString(OseerConstants.keyUserId);
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Validate token
      final isValid = await tokenManager.validateToken(event.token);

      if (isValid) {
        OseerLogger.info('✅ Token validation successful');

        // Get profile from token manager (might have been updated during validation)
        final profile = tokenManager.getUserProfileObject();

        emit(TokenValidated(
          token: event.token,
          userId: userId,
          profile: profile,
        ));
      } else {
        OseerLogger.warning('⚠️ Token validation failed');
        emit(HealthError(
          message: 'Token validation failed',
          error: 'The provided token is invalid or expired',
        ));
      }
    } catch (e) {
      OseerLogger.error('❌ Error validating token', e);
      emit(HealthError(
        message: 'Failed to validate connection token',
        error: e.toString(),
      ));
    }
  }

  /// Handle profile updates
  Future<void> _onProfileUpdated(
    ProfileUpdatedEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('👤 Updating user profile');
      emit(const HealthLoading(message: 'Updating profile...'));

      // Store profile data in preferences
      await _saveUserProfile(
        name: event.profile.name,
        email: event.profile.email,
        phone: event.profile.phone,
        age: event.profile.age,
        gender: event.profile.gender,
        height: event.profile.height,
        weight: event.profile.weight,
        activityLevel: event.profile.activityLevel,
      );

      // Mark profile as complete
      await prefs.setBool(OseerConstants.keyProfileComplete, true);

      // Log success
      OseerLogger.info('✅ Profile updated successfully');

      // Get current wellness permissions
      final authStatus = await healthManager.checkWellnessPermissions();

      // Emit new state with updated profile
      emit(ProfileUpdated(
        profile: event.profile,
        isComplete: true,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error updating profile', e);
      emit(HealthError(
        message: 'Failed to update profile',
        error: e.toString(),
      ));
    }
  }

  /// Check profile status
  Future<void> _onCheckProfileStatus(
    CheckProfileStatusEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('🔍 Checking profile status');

      // Get profile completion status
      final isComplete = tokenManager.isProfileComplete();
      final profile = tokenManager.getUserProfileObject();

      // Log result
      OseerLogger.info(
          '📋 Profile status: ${isComplete ? 'Complete' : 'Incomplete'}');

      // Emit new state
      emit(ProfileChecked(
        status: isComplete ? ProfileStatus.complete : ProfileStatus.incomplete,
        profile: profile,
      ));
    } catch (e) {
      OseerLogger.error('❌ Error checking profile status', e);
      emit(HealthError(
        message: 'Failed to check profile status',
        error: e.toString(),
      ));
    }
  }

  /// Load user profile
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info('📂 Loading user profile');
      emit(const HealthLoading(message: 'Loading profile...'));

      // Get profile from token manager
      final profile = tokenManager.getUserProfileObject();
      final isComplete = tokenManager.isProfileComplete();

      if (profile != null) {
        OseerLogger.info('✅ Profile loaded: ${profile.name}');
        emit(ProfileUpdated(
          profile: profile,
          isComplete: isComplete,
        ));
      } else {
        OseerLogger.info('⚠️ No profile found or incomplete');
        emit(ProfileChecked(
          status: ProfileStatus.incomplete,
          message: 'Profile is incomplete or not found',
        ));
      }
    } catch (e) {
      OseerLogger.error('❌ Error loading profile', e);
      emit(HealthError(
        message: 'Failed to load profile',
        error: e.toString(),
      ));
    }
  }

  /// Extract profile data from wellness platform
  Future<void> _onExtractProfileData(
    ExtractProfileDataEvent event,
    Emitter<HealthState> emit,
  ) async {
    try {
      OseerLogger.info(
          'Starting extraction of profile data from wellness platform');
      emit(const ProfileDataExtracting());

      // Call health manager to extract profile data
      final extractedProfile = await healthManager.extractUserProfileData();

      if (extractedProfile != null) {
        // Only emit extracted profile if it has actual data
        bool hasUsefulData = extractedProfile.height != null ||
            extractedProfile.weight != null ||
            extractedProfile.age != null ||
            extractedProfile.activityLevel != null;

        if (hasUsefulData ||
            (extractedProfile.name.isNotEmpty &&
                extractedProfile.email.isNotEmpty)) {
          OseerLogger.info('Successfully extracted profile data');

          // If we only have partial data, make sure we keep name and email if they exist
          if (!hasUsefulData && extractedProfile.name.isEmpty) {
            // Try to get existing user info from preferences
            final name = prefs.getString(OseerConstants.keyUserName);
            final email = prefs.getString(OseerConstants.keyUserEmail);

            if (name != null &&
                name.isNotEmpty &&
                email != null &&
                email.isNotEmpty) {
              // Create a copy with the existing name and email
              final updatedProfile = UserProfile(
                name: name,
                email: email,
                phone: extractedProfile.phone,
                height: extractedProfile.height,
                weight: extractedProfile.weight,
                age: extractedProfile.age,
                gender: extractedProfile.gender,
                activityLevel: extractedProfile.activityLevel,
              );

              emit(ProfileDataExtracted(profile: updatedProfile));
            } else {
              emit(ProfileDataExtracted(profile: extractedProfile));
            }
          } else {
            emit(ProfileDataExtracted(profile: extractedProfile));
          }
        } else {
          OseerLogger.warning('Extracted profile contained no useful data');
          emit(const ProfileDataExtractionFailed(
            error:
                'No useful profile data could be extracted from your wellness platform',
          ));
        }
      } else {
        OseerLogger.warning('No profile data could be extracted');
        emit(const ProfileDataExtractionFailed(
          error: 'Unable to extract profile data from your wellness platform',
        ));
      }
    } catch (e) {
      OseerLogger.error('Error extracting profile data', e);
      emit(ProfileDataExtractionFailed(
        error: 'Failed to extract profile data: ${e.toString()}',
      ));
    }
  }

  /// Handle extracted profile data
  void _onProfileDataExtracted(
    ProfileDataExtractedEvent event,
    Emitter<HealthState> emit,
  ) {
    emit(ProfileDataExtracted(profile: event.profile));
  }

  /// Handle profile data extraction failure
  void _onProfileDataExtractionFailed(
    ProfileDataExtractionFailedEvent event,
    Emitter<HealthState> emit,
  ) {
    emit(ProfileDataExtractionFailed(error: event.error));
  }

  /// Run wellness diagnostics
  Future<Map<String, dynamic>> runDiagnostics() async {
    try {
      OseerLogger.info('🔍 Running comprehensive wellness diagnostics');
      return await _debugger.runDiagnostics();
    } catch (e) {
      OseerLogger.error('❌ Error running diagnostics', e);
      return {'error': e.toString()};
    }
  }

  /// Save user profile to shared preferences
  Future<bool> _saveUserProfile({
    required String name,
    required String email,
    String? phone,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
  }) async {
    try {
      await prefs.setString(OseerConstants.keyUserName, name);
      await prefs.setString(OseerConstants.keyUserEmail, email);

      if (phone != null && phone.isNotEmpty) {
        await prefs.setString(OseerConstants.keyUserPhone, phone);
      }

      if (age != null) {
        await prefs.setInt(OseerConstants.keyUserAge, age);
      }

      if (gender != null && gender.isNotEmpty) {
        await prefs.setString(OseerConstants.keyUserGender, gender);
      }

      if (height != null) {
        await prefs.setDouble(OseerConstants.keyUserHeight, height);
      }

      if (weight != null) {
        await prefs.setDouble(OseerConstants.keyUserWeight, weight);
      }

      if (activityLevel != null && activityLevel.isNotEmpty) {
        await prefs.setString(
            OseerConstants.keyUserActivityLevel, activityLevel);
      }

      await prefs.setBool(OseerConstants.keyProfileComplete, true);

      return true;
    } catch (e) {
      OseerLogger.error('Error saving user profile', e);
      return false;
    }
  }
}
