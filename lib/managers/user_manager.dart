// lib/managers/user_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/helper_models.dart' hide ApiException, ApiExceptionType;
import '../models/user_profile.dart';
import '../services/api_service.dart' as api;
import '../services/logger_service.dart';
import '../utils/constants.dart';

class UserManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  final api.ApiService _apiService;

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastProfileSyncTime;
  bool _hasProfileChanged = false;
  bool _isProfileSyncInProgress = false;
  bool _isProfileLoaded = false;

  // Completer for async profile loading
  Completer<void>? _profileLoadCompleter;

  // Retry mechanism
  int _syncRetryCount = 0;
  static const int _maxSyncRetries = 3;
  Timer? _retryTimer;

  UserManager(
    this._prefs,
    this._apiService,
  ) {
    // Initialize profile loading immediately
    _initializeProfileLoading();
  }

  // Getters
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasUserProfile => _userProfile != null;
  DateTime? get lastProfileSyncTime => _lastProfileSyncTime;
  bool get hasProfileChanged => _hasProfileChanged;
  bool get isProfileSyncInProgress => _isProfileSyncInProgress;
  bool get isProfileLoaded => _isProfileLoaded;

  // --- START OF NEW METHOD TO ADD ---
  /// Returns the current user's ID from the loaded profile, if available.
  String? getUserId() {
    return _userProfile?.userId;
  }
  // --- END OF NEW METHOD TO ADD ---

  /// Wait for profile to be loaded from storage
  Future<void> awaitProfileLoad() async {
    if (_isProfileLoaded) return;

    // If completer exists, wait for it
    if (_profileLoadCompleter != null && !_profileLoadCompleter!.isCompleted) {
      await _profileLoadCompleter!.future;
    }
  }

  /// Initialize profile loading from preferences
  Future<void> _initializeProfileLoading() async {
    _profileLoadCompleter = Completer<void>();

    try {
      await _loadProfileFromPrefs();
      _isProfileLoaded = true;
      OseerLogger.info('UserManager initialized with profile loading complete');

      // Complete the completer
      if (_profileLoadCompleter != null &&
          !_profileLoadCompleter!.isCompleted) {
        _profileLoadCompleter!.complete();
      }
    } catch (e, stack) {
      OseerLogger.error(
          'Error initializing UserManager profile loading', e, stack);
      _isProfileLoaded = true;

      // Complete with error but don't throw
      if (_profileLoadCompleter != null &&
          !_profileLoadCompleter!.isCompleted) {
        _profileLoadCompleter!.complete();
      }
    }
  }

  /// Load user profile from SharedPreferences on initialization
  Future<void> _loadProfileFromPrefs() async {
    final userId = _prefs.getString(OseerConstants.keyUserId);
    if (userId == null || userId.isEmpty) {
      OseerLogger.debug('No user ID found in preferences');
      _userProfile = null;
      // Notify listeners even when no profile
      _notifyListeners();
      return;
    }

    // Try loading full profile from JSON string first
    final profileJson = _prefs.getString('userProfileJson');
    if (profileJson != null) {
      try {
        final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
        _userProfile = UserProfile.fromJson(profileMap);
        OseerLogger.debug(
            'Loaded profile from JSON string: ${_userProfile?.name}');

        // Get last sync time
        final lastSyncTimeString = _prefs.getString('lastProfileSyncTime');
        if (lastSyncTimeString != null) {
          try {
            _lastProfileSyncTime = DateTime.parse(lastSyncTimeString);
            OseerLogger.debug(
                'Last profile sync time: ${_lastProfileSyncTime?.toIso8601String()}');
          } catch (e) {
            OseerLogger.warning('Failed to parse last profile sync time: $e');
          }
        }

        // Update profile completion flags for consistency
        if (_userProfile != null) {
          await _updateProfileCompletionFlags();
        }

        // Notify listeners after successful load
        _notifyListeners();
        return;
      } catch (e) {
        OseerLogger.warning(
            'Failed to load profile from JSON string, falling back to individual keys: $e');
        // Clear potentially corrupted JSON
        await _prefs.remove('userProfileJson');
      }
    }

    // Fallback to individual keys if JSON loading fails or isn't present
    await _loadProfileFromIndividualKeys(userId);
  }

  /// Load profile from individual SharedPreferences keys (legacy support)
  Future<void> _loadProfileFromIndividualKeys(String userId) async {
    OseerLogger.debug('Loading profile from individual keys...');

    final name = _prefs.getString(OseerConstants.keyUserName);
    final email = _prefs.getString(OseerConstants.keyUserEmail);
    final phone = _prefs.getString(OseerConstants.keyUserPhone);
    final age = _prefs.getInt(OseerConstants.keyUserAge);
    final gender = _prefs.getString(OseerConstants.keyUserGender);
    final height = _prefs.getDouble(OseerConstants.keyUserHeight);
    final weight = _prefs.getDouble(OseerConstants.keyUserWeight);
    final activityLevel = _prefs.getString(OseerConstants.keyUserActivityLevel);
    final deviceId = _prefs.getString(OseerConstants.keyDeviceId);
    final platformType = _prefs.getString('platform_type');
    final deviceModel = _prefs.getString('device_model');
    final osVersion = _prefs.getString('os_version');

    if (name != null && email != null) {
      _userProfile = UserProfile(
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        deviceId: deviceId,
        platformType: platformType,
        deviceModel: deviceModel,
        osVersion: osVersion,
      );
      OseerLogger.debug('Loaded profile from preferences: ${name}');

      // Update profile completion flags for consistency
      await _updateProfileCompletionFlags();

      // Save as JSON for faster future loads
      await _saveProfileToJsonPrefs();
    } else {
      OseerLogger.warning(
          'Could not load profile from individual keys - name or email missing.');
      _userProfile = null;
    }

    _notifyListeners();
  }

  /// Update profile completion flags based on current profile state
  Future<void> _updateProfileCompletionFlags() async {
    if (_userProfile != null) {
      final isComplete = _userProfile!.isComplete();
      OseerLogger.debug('Profile completion status: $isComplete');

      await _prefs.setBool(OseerConstants.keyProfileComplete, isComplete);
      await _prefs.setBool(OseerConstants.keyOnboardingComplete, isComplete);
      OseerLogger.debug('Profile completion flags updated to: $isComplete');
    }
  }

  /// Enhanced notification method with state change tracking
  void _notifyListeners() {
    _hasProfileChanged = true;

    // Use microtask to ensure notification happens after current frame
    Future.microtask(() {
      notifyListeners();

      // Reset change flag after listeners process
      Future.delayed(const Duration(milliseconds: 100), () {
        _hasProfileChanged = false;
      });
    });
  }

  /// Saves the current UserProfile object to SharedPreferences as a JSON string
  Future<void> _saveProfileToJsonPrefs() async {
    if (_userProfile == null) {
      OseerLogger.warning('Attempted to save null profile to JSON prefs.');
      await _prefs.remove('userProfileJson');
      return;
    }

    try {
      final profileJson = jsonEncode(_userProfile!.toJson());
      await _prefs.setString('userProfileJson', profileJson);
      OseerLogger.debug(
          'Saved profile as JSON string to preferences: ${_userProfile!.name}');

      // Save sync timestamp
      final now = DateTime.now();
      await _prefs.setString('lastProfileSyncTime', now.toIso8601String());
      _lastProfileSyncTime = now;

      // Update completion flags based on profile state
      await _updateProfileCompletionFlags();

      // Also save to individual keys for compatibility
      await _saveProfileToPrefs(_userProfile!);
    } catch (e) {
      OseerLogger.error('Failed to encode or save profile JSON: $e');
      rethrow;
    }
  }

  /// Saves the current UserProfile object to SharedPreferences (individual keys - for compatibility)
  Future<void> _saveProfileToPrefs(UserProfile profile) async {
    OseerLogger.debug(
        'Saving profile to preferences (individual keys): ${profile.name}');

    try {
      await _prefs.setString(OseerConstants.keyUserId, profile.userId);
      await _prefs.setString(OseerConstants.keyUserName, profile.name);
      await _prefs.setString(OseerConstants.keyUserEmail, profile.email);

      // Handle optional fields
      if (profile.phone != null) {
        await _prefs.setString(OseerConstants.keyUserPhone, profile.phone!);
      } else {
        await _prefs.remove(OseerConstants.keyUserPhone);
      }

      if (profile.age != null) {
        await _prefs.setInt(OseerConstants.keyUserAge, profile.age!);
      } else {
        await _prefs.remove(OseerConstants.keyUserAge);
      }

      if (profile.gender != null) {
        await _prefs.setString(OseerConstants.keyUserGender, profile.gender!);
      } else {
        await _prefs.remove(OseerConstants.keyUserGender);
      }

      if (profile.height != null) {
        await _prefs.setDouble(OseerConstants.keyUserHeight, profile.height!);
      } else {
        await _prefs.remove(OseerConstants.keyUserHeight);
      }

      if (profile.weight != null) {
        await _prefs.setDouble(OseerConstants.keyUserWeight, profile.weight!);
      } else {
        await _prefs.remove(OseerConstants.keyUserWeight);
      }

      if (profile.activityLevel != null) {
        await _prefs.setString(
            OseerConstants.keyUserActivityLevel, profile.activityLevel!);
      } else {
        await _prefs.remove(OseerConstants.keyUserActivityLevel);
      }

      if (profile.deviceId != null) {
        await _prefs.setString(OseerConstants.keyDeviceId, profile.deviceId!);
      } else {
        await _prefs.remove(OseerConstants.keyDeviceId);
      }

      // Save additional device fields
      if (profile.platformType != null) {
        await _prefs.setString('platform_type', profile.platformType!);
      } else {
        await _prefs.remove('platform_type');
      }

      if (profile.deviceModel != null) {
        await _prefs.setString('device_model', profile.deviceModel!);
      } else {
        await _prefs.remove('device_model');
      }

      if (profile.osVersion != null) {
        await _prefs.setString('os_version', profile.osVersion!);
      } else {
        await _prefs.remove('os_version');
      }

      // Update completion flags
      await _updateProfileCompletionFlags();

      OseerLogger.info(
          'Profile saved to individual preference keys successfully');
    } catch (e, stack) {
      OseerLogger.error(
          'Error saving profile to individual preference keys', e, stack);
      rethrow;
    }
  }

  /// Sets the user profile locally and saves it with enhanced notification
  Future<void> setUserProfile(UserProfile profile,
      {bool saveJson = true}) async {
    // Validate the profile has a userId
    if (profile.userId.isEmpty) {
      OseerLogger.error('Cannot set user profile: userId is empty');
      throw Exception('Cannot save user profile with empty userId');
    }

    final bool profileChanged = _userProfile?.userId != profile.userId ||
        _userProfile?.name != profile.name ||
        _userProfile?.email != profile.email ||
        _userProfile?.isComplete() != profile.isComplete();

    _userProfile = profile;
    OseerLogger.info('User profile set locally: ${profile.name}');

    try {
      // Save using preferred JSON method
      if (saveJson) {
        await _saveProfileToJsonPrefs();
      }
      // Also save individual keys for compatibility
      await _saveProfileToPrefs(profile);

      // Always notify listeners when profile is set
      _notifyListeners();
    } catch (e, stack) {
      OseerLogger.error('Error saving user profile', e, stack);
      rethrow;
    }
  }

  /// Fixed updateUserProfile with resilient API handling
  Future<bool> updateUserProfile(UserProfile updatedProfile) async {
    if (updatedProfile.userId.isEmpty) {
      _errorMessage = 'Cannot update profile: User ID is missing.';
      OseerLogger.error(_errorMessage!);
      _notifyListeners();
      return false;
    }

    OseerLogger.info(
        'Updating user profile for userId: ${updatedProfile.userId}');
    _setLoadingState(true, clearError: true);

    try {
      // Optimistically update the local state for a responsive UI
      _userProfile = updatedProfile;
      await _saveProfileToJsonPrefs(); // This now saves to both JSON and individual keys
      _notifyListeners();

      OseerLogger.info('Calling API to update user profile...');
      final response = await _apiService.updateUser(
          updatedProfile.userId, updatedProfile.toJson());

      if (response['success'] == true) {
        OseerLogger.info('✅ Profile updated successfully on server.');
        _setLoadingState(false);
        return true;
      } else {
        _errorMessage = response['error'] as String? ??
            'Failed to update profile on server.';
        OseerLogger.error('Server failed to update profile: $_errorMessage');
        _setLoadingState(false);
        return false;
      }
    } on api.ApiException catch (e, stackTrace) {
      _errorMessage = e.message;
      OseerLogger.error('API Exception updating profile', e, stackTrace);
      _setLoadingState(false);
      return false;
    } catch (e, s) {
      _errorMessage = 'An unexpected error occurred while saving profile.';
      OseerLogger.error('Unexpected error updating profile', e, s);
      _setLoadingState(false);
      return false;
    }
  }

  /// Extract profile from API response with improved field mapping
  UserProfile? _extractProfileFromApiResponse(
      Map<String, dynamic> response, String userId) {
    OseerLogger.debug('Extracting profile from API response...');
    OseerLogger.debug('Raw API response: ${jsonEncode(response)}');

    try {
      // Look for profile data in various locations
      Map<String, dynamic>? profileData;

      // Check if response has a 'data' field
      if (response['data'] is Map) {
        profileData = Map<String, dynamic>.from(response['data']);
        OseerLogger.debug('Found profile data in "data" field');
      }
      // Check if profile fields are at root level
      else if (response.containsKey('id') || response.containsKey('email')) {
        profileData = Map<String, dynamic>.from(response);
        OseerLogger.debug('Found profile data at root level');
      }
      // Check for nested user object
      else if (response['user'] is Map) {
        profileData = Map<String, dynamic>.from(response['user']);
        OseerLogger.debug('Found profile data in "user" field');
      }

      if (profileData == null) {
        OseerLogger.error(
            'Could not find profile data in API response structure');
        return null;
      }

      // Extract userId with multiple fallbacks
      final extractedUserId = profileData['userId']?.toString() ??
          profileData['user_id']?.toString() ??
          profileData['id']?.toString() ??
          userId;

      // Extract basic fields with null safety
      final name = profileData['name']?.toString();
      final email = profileData['email']?.toString();

      if (name == null || email == null || name.isEmpty || email.isEmpty) {
        OseerLogger.error(
            'Profile data missing required fields (name or email)');
        OseerLogger.debug('Extracted - name: $name, email: $email');
        return null;
      }

      // Extract optional fields with better parsing
      final phone = profileData['phone']?.toString();

      // Handle age - could be in profile data or metadata
      final age =
          _parseNumeric(profileData['age'] ?? profileData['metadata']?['age'])
              ?.toInt();

      // Handle gender - check multiple possible locations
      final gender = profileData['gender']?.toString() ??
          profileData['metadata']?['gender']?.toString();

      // Handle height - with validation
      final heightValue = _parseNumeric(
              profileData['height'] ?? profileData['metadata']?['height'])
          ?.toDouble();
      final height =
          (heightValue != null && heightValue >= 50 && heightValue <= 250)
              ? heightValue
              : null;

      // Handle weight - with validation
      final weightValue = _parseNumeric(
              profileData['weight'] ?? profileData['metadata']?['weight'])
          ?.toDouble();
      final weight =
          (weightValue != null && weightValue >= 20 && weightValue <= 500)
              ? weightValue
              : null;

      // Handle activityLevel - check both camelCase and snake_case
      final activityLevel = profileData['activityLevel']?.toString() ??
          profileData['activity_level']?.toString() ??
          profileData['metadata']?['activityLevel']?.toString() ??
          profileData['metadata']?['activity_level']?.toString();

      // Extract device info
      final deviceId = profileData['deviceId']?.toString() ??
          profileData['device_id']?.toString() ??
          profileData['metadata']?['deviceId']?.toString() ??
          profileData['metadata']?['device_id']?.toString() ??
          profileData['metadata']?['initial_device_id']?.toString();

      final platformType = profileData['platformType']?.toString() ??
          profileData['platform_type']?.toString() ??
          profileData['metadata']?['platformType']?.toString() ??
          profileData['metadata']?['platform_type']?.toString();

      final deviceModel = profileData['deviceModel']?.toString() ??
          profileData['device_model']?.toString() ??
          profileData['metadata']?['deviceModel']?.toString() ??
          profileData['metadata']?['device_model']?.toString();

      final osVersion = profileData['osVersion']?.toString() ??
          profileData['os_version']?.toString() ??
          profileData['metadata']?['osVersion']?.toString() ??
          profileData['metadata']?['os_version']?.toString();

      // Create profile object
      final profile = UserProfile(
        userId: extractedUserId,
        name: name,
        email: email,
        phone: phone,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        deviceId: deviceId,
        platformType: platformType,
        deviceModel: deviceModel,
        osVersion: osVersion,
      );

      OseerLogger.info('Successfully extracted profile from API response');
      OseerLogger.debug('Extracted profile: ${profile.toJson()}');

      return profile;
    } catch (e, stack) {
      OseerLogger.error('Error extracting profile from API response', e, stack);
      return null;
    }
  }

  /// Helper to parse numeric values with improved handling
  num? _parseNumeric(dynamic value) {
    if (value == null) return null;

    // Already a number
    if (value is int || value is double) return value;

    // Try to parse string
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      try {
        // Try integer first
        if (!trimmed.contains('.')) {
          return int.parse(trimmed);
        }
        // Parse as double
        return double.parse(trimmed);
      } catch (_) {
        OseerLogger.debug('Failed to parse numeric value: $value');
        return null;
      }
    }

    OseerLogger.debug(
        'Unexpected type for numeric value: ${value.runtimeType}');
    return null;
  }

  // Fixed fetchUserProfileFromServer with resilient error handling
  Future<bool> fetchUserProfileFromServer() async {
    final userId =
        _userProfile?.userId ?? _prefs.getString(OseerConstants.keyUserId);
    if (userId == null || userId.isEmpty) {
      OseerLogger.warning(
          "Cannot fetch profile from server: No user ID available.");
      return false;
    }

    if (_isProfileSyncInProgress) {
      OseerLogger.info(
          'Profile sync already in progress, skipping duplicate request.');
      return false; // Not an error, just already happening.
    }

    _isProfileSyncInProgress = true;
    _setLoadingState(true, clearError: true);
    OseerLogger.info('Fetching user profile from server for $userId');

    try {
      final response = await _apiService.getUserProfile(userId);

      if (response['success'] == true) {
        final extractedProfile =
            _extractProfileFromApiResponse(response, userId);
        if (extractedProfile != null) {
          _userProfile = extractedProfile;
          await _saveProfileToJsonPrefs();
          OseerLogger.info(
              '✅ Successfully fetched and updated local profile from server.');
          _notifyListeners();
          return true; // Success!
        } else {
          throw Exception(
              'Failed to parse a valid profile from the server response.');
        }
      } else {
        throw api.ApiException(
          statusCode: 404,
          message: response['error'] ?? 'Server returned a failure response.',
          type: api.ApiExceptionType.notFound,
        );
      }
    } catch (e, s) {
      _errorMessage =
          'Could not load your profile from the server. Please check your connection.';
      OseerLogger.error('Error fetching/processing server profile', e, s);
      return false;
    } finally {
      _isProfileSyncInProgress = false;
      _setLoadingState(false);
    }
  }

  /// Schedule a profile sync retry with exponential backoff
  void _scheduleSyncRetry() {
    _syncRetryCount++;
    final delay = Duration(seconds: _syncRetryCount * 2); // Exponential backoff

    OseerLogger.info(
        'Scheduling profile sync retry $_syncRetryCount of $_maxSyncRetries in ${delay.inSeconds} seconds');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      fetchUserProfileFromServer();
    });
  }

  /// Manually retry profile sync from server
  Future<bool> retryProfileSync() async {
    _syncRetryCount = 0; // Reset retry count for manual retry
    _retryTimer?.cancel();
    return await fetchUserProfileFromServer();
  }

  /// Helper method to set loading state and notify listeners
  void _setLoadingState(bool loading, {bool clearError = false}) {
    if (_isLoading != loading || (clearError && _errorMessage != null)) {
      _isLoading = loading;
      if (clearError) {
        _errorMessage = null;
      }
      _notifyListeners();
    }
  }

  /// SIMPLIFIED: Get basic user status
  Map<String, dynamic> getComprehensiveStatus() {
    return {
      // Profile status
      'hasProfile': _userProfile != null,
      'isProfileComplete': isProfileComplete(),
      'lastProfileSyncTime': _lastProfileSyncTime?.toIso8601String(),
      'profileSyncInProgress': _isProfileSyncInProgress,
      'profileSyncRetryCount': _syncRetryCount,

      // General status
      'isLoading': _isLoading,
      'errorMessage': _errorMessage,
      'isProfileLoaded': _isProfileLoaded,
    };
  }

  /// Clears the user profile from state and storage
  Future<void> clearUserProfile() async {
    OseerLogger.info('Clearing user profile');

    _userProfile = null;
    _lastProfileSyncTime = null;
    _errorMessage = null;
    _isLoading = false;
    _isProfileSyncInProgress = false;
    _isProfileLoaded = false;
    _profileLoadCompleter = null;
    _syncRetryCount = 0;
    _retryTimer?.cancel();

    // Clear JSON representation first
    await _prefs.remove('userProfileJson');
    await _prefs.remove('lastProfileSyncTime');

    // Clear completion flags
    await _prefs.remove(OseerConstants.keyProfileComplete);
    await _prefs.remove(OseerConstants.keyOnboardingComplete);

    // Clear individual keys
    await _prefs.remove(OseerConstants.keyUserId);
    await _prefs.remove(OseerConstants.keyUserName);
    await _prefs.remove(OseerConstants.keyUserEmail);
    await _prefs.remove(OseerConstants.keyUserPhone);
    await _prefs.remove(OseerConstants.keyUserAge);
    await _prefs.remove(OseerConstants.keyUserGender);
    await _prefs.remove(OseerConstants.keyUserHeight);
    await _prefs.remove(OseerConstants.keyUserWeight);
    await _prefs.remove(OseerConstants.keyUserActivityLevel);
    await _prefs.remove(OseerConstants.keyDeviceId);
    await _prefs.remove('platform_type');
    await _prefs.remove('device_model');
    await _prefs.remove('os_version');

    _notifyListeners();
  }

  /// Checks if the profile is complete based on UserProfile logic
  bool isProfileComplete() {
    final isComplete = _userProfile?.isComplete() ?? false;
    OseerLogger.debug('isProfileComplete check: $isComplete');
    return isComplete;
  }

  /// Checks if the profile has required health info based on UserProfile logic
  bool hasRequiredProfileData() {
    return _userProfile?.hasRequiredHealthInfo() ?? false;
  }

  /// Returns the UserProfile object, if available
  UserProfile? getUserProfileObject() {
    return _userProfile;
  }

  // === Additional Methods for Auth Functionality ===

  /// Checks if user is authenticated (has a user profile)
  bool isUserAuthenticated() {
    return _userProfile != null && _userProfile!.userId.isNotEmpty;
  }

  /// Alias for setUserProfile to match AuthBloc naming
  Future<void> saveUserProfileLocally(UserProfile profile) async {
    await setUserProfile(profile);
  }

  /// Alias for clearUserProfile to match AuthBloc naming
  Future<void> clearUserData() async {
    await clearUserProfile();
  }

  /// SIMPLIFIED: Check if the profile needs to be synced from server
  bool shouldSyncFromServer() {
    // If we have no profile, definitely sync
    if (_userProfile == null) {
      OseerLogger.debug('Should sync: No profile exists');
      return true;
    }

    // If profile is incomplete, try to sync
    if (!_userProfile!.isComplete()) {
      OseerLogger.debug('Should sync: Profile is incomplete');
      return true;
    }

    // If we have never synced, definitely sync
    if (_lastProfileSyncTime == null) {
      OseerLogger.debug('Should sync: Never synced before');
      return true;
    }

    // If last sync was more than 1 hour ago, sync again
    final now = DateTime.now();
    final syncThreshold = Duration(hours: 1);
    final shouldSync = now.difference(_lastProfileSyncTime!) > syncThreshold;

    if (shouldSync) {
      OseerLogger.debug(
          'Should sync: Last sync was ${now.difference(_lastProfileSyncTime!).inMinutes} minutes ago');
    } else {
      OseerLogger.debug(
          'Should not sync: Recent sync (${now.difference(_lastProfileSyncTime!).inMinutes} minutes ago)');
    }

    return shouldSync;
  }

  /// Force a profile sync regardless of timing
  Future<bool> forceSyncFromServer() async {
    OseerLogger.info('Forcing profile sync from server');
    _lastProfileSyncTime = null; // Reset sync time to force sync
    _syncRetryCount = 0; // Reset retry count
    return await fetchUserProfileFromServer();
  }

  /// Get profile sync status information
  Map<String, dynamic> getProfileSyncStatus() {
    return {
      'hasProfile': _userProfile != null,
      'isComplete': isProfileComplete(),
      'lastSyncTime': _lastProfileSyncTime?.toIso8601String(),
      'shouldSync': shouldSyncFromServer(),
      'isLoading': _isLoading,
      'errorMessage': _errorMessage,
      'syncInProgress': _isProfileSyncInProgress,
      'isProfileLoaded': _isProfileLoaded,
      'syncRetryCount': _syncRetryCount,
      'maxSyncRetries': _maxSyncRetries,
    };
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
