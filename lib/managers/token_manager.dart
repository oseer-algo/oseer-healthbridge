// File path: lib/managers/token_manager.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

/// Manages user connection tokens
class TokenManager {
  final ApiService _apiService;
  final SharedPreferences _prefs;

  /// Creates a new token manager
  TokenManager(this._apiService, this._prefs);

  /// Generate a new connection token
  Future<String> generateToken(Map<String, dynamic> profileData) async {
    try {
      final userId = profileData['userId'] as String;
      final deviceId = profileData['deviceId'] as String;

      OseerLogger.info('🔑 Generating connection token for user: $userId');
      OseerLogger.info('📱 Device ID: $deviceId');

      // Log profile information
      final userName = profileData['name'] as String?;
      final userEmail = profileData['email'] as String?;

      if (userName != null && userName.isNotEmpty) {
        OseerLogger.info(
            '👤 Using provided profile: Name=$userName, Email=$userEmail');
      } else {
        OseerLogger.warning('Profile missing name, using defaults');
      }

      // Generate the token using API service
      final result = await _apiService.generateToken(profileData);

      // Success handling
      final token = result['token'];
      final expiresAt = result['expiresAt'];

      // Save token information
      await _saveTokenInfo(token, expiresAt);

      OseerLogger.info('✅ Token generated: ${token.substring(0, 4)}...');
      OseerLogger.info('⏱️ Token expires at: $expiresAt');
      OseerLogger.info('📊 Token length: ${token.length} characters');

      return token;
    } catch (e) {
      OseerLogger.error('Failed to generate token', e);
      rethrow;
    }
  }

  /// Save token information
  Future<void> _saveTokenInfo(String token, String expiresAt) async {
    // Save token and expiry date to preferences
    await _prefs.setString(OseerConstants.keyConnectionToken, token);
    await _prefs.setString(OseerConstants.keyTokenExpiry, expiresAt);
    await _prefs.setBool('is_connected', true);

    // Format and save the formatted token
    final formattedToken = _formatToken(token);
    await _prefs.setString('formatted_token', formattedToken);
  }

  /// Format token for display (groups of 4 characters)
  String _formatToken(String token) {
    // Clean the token (remove any non-alphanumeric characters)
    final cleanToken = token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    // Format in groups of 4
    final StringBuffer formattedToken = StringBuffer();
    for (int i = 0; i < cleanToken.length; i += 4) {
      final end = (i + 4 < cleanToken.length) ? i + 4 : cleanToken.length;
      formattedToken.write(cleanToken.substring(i, end));
      if (end < cleanToken.length) {
        formattedToken.write('-');
      }
    }

    return formattedToken.toString();
  }

  /// Get the current connection token
  String? getCurrentToken() {
    try {
      final token = _prefs.getString(OseerConstants.keyConnectionToken);

      if (token == null || token.isEmpty) {
        OseerLogger.info('🔍 No token found in storage');
        return null;
      }

      // Check if token is expired
      if (isTokenExpired()) {
        OseerLogger.warning('🔍 Token found but expired');
        return null;
      }

      return token;
    } catch (e) {
      OseerLogger.error('Error retrieving token', e);
      return null;
    }
  }

  /// Get formatted token for display
  String getFormattedToken() {
    try {
      // Try to get the pre-formatted token
      final formattedToken = _prefs.getString('formatted_token');
      if (formattedToken != null && formattedToken.isNotEmpty) {
        return formattedToken;
      }

      // If not available, get the raw token and format it
      final token = getCurrentToken();
      if (token == null || token.isEmpty) {
        OseerLogger.info('🔍 No token available to format');
        return '';
      }

      return _formatToken(token);
    } catch (e) {
      OseerLogger.error('Error formatting token', e);
      return '';
    }
  }

  /// Get token expiry date
  DateTime? getTokenExpiryDate() {
    try {
      final expiryDate = _prefs.getString(OseerConstants.keyTokenExpiry);

      if (expiryDate == null || expiryDate.isEmpty) {
        OseerLogger.info('⏱️ No token expiry date found');
        return null;
      }

      final parsedDate = DateTime.parse(expiryDate);
      OseerLogger.info('📅 Token expiry date: $expiryDate');
      return parsedDate;
    } catch (e) {
      OseerLogger.error('Error getting token expiry date', e);
      return null;
    }
  }

  /// Check if token is expired
  bool isTokenExpired() {
    try {
      final expiryDate = getTokenExpiryDate();

      if (expiryDate == null) {
        return true;
      }

      final now = DateTime.now();

      return now.isAfter(expiryDate);
    } catch (e) {
      OseerLogger.error('Error checking token expiry', e);
      return true;
    }
  }

  /// Validate a connection token with the API
  Future<bool> validateToken(String token) async {
    try {
      OseerLogger.info('Validating token with API server');
      final result = await _apiService.validateToken(token);
      return result['valid'] == true;
    } catch (e) {
      OseerLogger.error('Error validating token', e);
      return false;
    }
  }

  /// Revoke the current token
  Future<bool> clearToken() async {
    try {
      await _prefs.remove(OseerConstants.keyConnectionToken);
      await _prefs.remove(OseerConstants.keyTokenExpiry);
      await _prefs.remove('formatted_token');
      await _prefs.setBool('is_connected', false);

      OseerLogger.info('🔑 Token revoked successfully');
      return true;
    } catch (e) {
      OseerLogger.error('Error revoking token', e);
      return false;
    }
  }

  /// Check if user profile is complete
  bool isProfileComplete() {
    try {
      final name = _prefs.getString(OseerConstants.keyUserName);
      final email = _prefs.getString(OseerConstants.keyUserEmail);
      final isComplete =
          _prefs.getBool(OseerConstants.keyProfileComplete) ?? false;

      return (name != null &&
              name.isNotEmpty &&
              email != null &&
              email.isNotEmpty) ||
          isComplete;
    } catch (e) {
      OseerLogger.error('Error checking profile completion', e);
      return false;
    }
  }

  /// Get user profile object from SharedPreferences
  UserProfile? getUserProfileObject() {
    try {
      final name = _prefs.getString(OseerConstants.keyUserName);
      final email = _prefs.getString(OseerConstants.keyUserEmail);

      if (name == null || email == null || name.isEmpty || email.isEmpty) {
        return null;
      }

      return UserProfile(
        name: name,
        email: email,
        phone: _prefs.getString(OseerConstants.keyUserPhone),
        age: _prefs.getInt(OseerConstants.keyUserAge),
        gender: _prefs.getString(OseerConstants.keyUserGender),
        height: _prefs.getDouble(OseerConstants.keyUserHeight),
        weight: _prefs.getDouble(OseerConstants.keyUserWeight),
        activityLevel: _prefs.getString(OseerConstants.keyUserActivityLevel),
      );
    } catch (e) {
      OseerLogger.error('Error getting user profile', e);
      return null;
    }
  }
}
