// File path: lib/utils/constants.dart

import 'package:flutter/material.dart';
import 'dart:math'; // Imported for Random
import 'package:shared_preferences/shared_preferences.dart'; // Added import for SharedPreferences

/// Constants used throughout the app
class OseerConstants {
  // --- App Information ---
  static const String appName = "Oseer WellnessBridge";
  static const String appVersion = "1.0.2"; // Updated version number

  // --- API Configuration ---
  static const String apiBaseUrl = 'https://demo.oseerapp.com/api';
  // Timeouts in milliseconds for Dio
  static const Duration apiConnectTimeout = Duration(seconds: 30);
  static const Duration apiReceiveTimeout = Duration(seconds: 30);

  // --- Web App URLs ---
  static const String webAppUrl = 'https://demo.oseerapp.com';
  static const String webConnectUrl =
      'https://demo.oseerapp.com/onboarding/connect-device';

  // --- Token Generation & Formatting ---
  static const String tokenChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int tokenLength = 24; // Required length for tokens
  static const int tokenGroupSize = 4; // For display formatting
  static const int localTokenExpiryMinutes = 30; // Expiry for fallback tokens

  // --- Supabase Fallback (If API fails) ---
  // Consider using environment variables for URLs and keys
  static const String supabaseUrl =
      'https://oxvhffqnenhtyypzpcam.supabase.co/functions/v1';
  static const String processWellnessDataEndpoint =
      '$supabaseUrl/process-wellness-data';
  static const String runAlgorithmEndpoint = '$supabaseUrl/run-algorithm';

  // --- Development & Feature Flags ---
  // Use kDebugMode or environment variables for better control
  static const bool allowLocalTokenFallback =
      true; // WARNING: Set to false in production
  static const bool syncFallbackTokens =
      true; // If true, attempt syncing fallback tokens (potentially complex)
  static const bool verboseLogging =
      true; // WARNING: Set to false in production

  // --- SharedPreferences Keys ---
  static const String keyUserId = 'user_id';
  static const String keyDeviceId = 'device_id';
  static const String keyLastSync = 'last_sync';
  static const String keyConnectionToken = 'connection_token';
  static const String keyTokenExpiry = 'token_expiry';
  static const String keyLastLoginDate = 'last_login_date';
  static const String keyWellnessPermissionsGranted =
      'wellness_permissions_granted';
  // Profile Keys
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserAge = 'user_age';
  static const String keyUserGender = 'user_gender';
  static const String keyUserHeight = 'user_height';
  static const String keyUserWeight = 'user_weight';
  static const String keyUserActivityLevel = 'user_activity_level';
  static const String keyProfileComplete = 'profile_complete';

  // --- Deep Linking ---
  static const String deepLinkScheme = 'wellnessbridge';

  // --- UI & Animations ---
  static const Duration shortAnimDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimDuration = Duration(milliseconds: 400);
  static const Duration longAnimDuration = Duration(milliseconds: 600);

  // --- Network & Sync Settings ---
  static const int maxConnectionRetries = 3;
  static const Duration connectionRetryDelay = Duration(seconds: 2);
  static const Duration syncFrequency =
      Duration(hours: 6); // Default sync interval
  static const Duration minSyncInterval =
      Duration(minutes: 30); // Minimum time between syncs
  static const int maxWellnessDataHistoryDays =
      30; // How far back to fetch wellness data

  /// Formats a token string with separators for display purposes.
  /// Example: ABCDEFGH12345678 devient ABCD-EFGH-1234-5678
  static String formatTokenForDisplay(String token) {
    // Remove any non-alphanumeric characters and ensure uppercase
    final String cleanToken =
        token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    if (cleanToken.isEmpty) {
      return ''; // Return empty if the cleaned token is empty
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < cleanToken.length; i++) {
      buffer.write(cleanToken[i]);
      // Add a hyphen after every group of characters, except after the last group
      if ((i + 1) % tokenGroupSize == 0 && i != cleanToken.length - 1) {
        buffer.write('-');
      }
    }
    return buffer.toString();
  }

  /// Cleans and standardizes a token string
  static String cleanToken(String token) {
    return token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }

  /// Generates a cryptographically secure random token.
  /// Uses `Random.secure()` for better randomness.
  static String generateSecureToken() {
    final Random secureRandom = Random.secure();
    return List.generate(
      tokenLength,
      (_) => tokenChars[secureRandom.nextInt(tokenChars.length)],
    ).join();
  }

  /// Get profile completion status from SharedPreferences
  static Future<bool> isProfileComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nameExists = prefs.getString(keyUserName)?.isNotEmpty ?? false;
      final emailExists = prefs.getString(keyUserEmail)?.isNotEmpty ?? false;
      final markedComplete = prefs.getBool(keyProfileComplete) ?? false;

      return (nameExists && emailExists) || markedComplete;
    } catch (e) {
      return false;
    }
  }
}

/// Color Palette for the Oseer App
class OseerColors {
  // Primary Brand Colors (from design guidelines)
  static const Color primary = Color(0xFF47B58E); // Main accent color
  static const Color secondary = Color(0xFF65C9A8); // Secondary accent
  static const Color tertiary = Color(0xFF7ADFC9); // Tertiary elements

  // Neutral & Background Colors
  static const Color background = Color(0xFFF8FAF9); // App background
  static const Color surface = Color(0xFFFFFFFF); // Card backgrounds, dialogs
  static const Color divider = Color(0xFFE5E5E5); // Divider lines

  // Text Colors
  static const Color textPrimary = Color(0xFF121212); // Primary text
  static const Color textSecondary = Color(0xFF6E6E6E); // Secondary text
  static const Color textTertiary = Color(0xFF9E9E9E); // Tertiary text
  static const Color textDisabled = Color(0xFFBDBDBD); // Disabled text

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Success indicators
  static const Color warning = Color(0xFFFF9800); // Warning messages
  static const Color error = Color(0xFFB00020); // Error messages
  static const Color info = Color(0xFF2196F3); // Information messages

  // Token Display Colors
  static const Color tokenBackground =
      Color(0xFFF0F9F5); // Background for token display card
  static const Color tokenBorder =
      Color(0xFFDDF0E9); // Border for token display card
  static const Color tokenTextDark =
      Color(0xFF2A5F4A); // Darker text on token card
  static const Color tokenTextLight =
      Color(0xFF5AB992); // Lighter text/icons on token card
}

/// Text Styles for the app
class OseerTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontFamily: 'Geist',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: OseerColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: 'Geist',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: OseerColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: 'Geist',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: OseerColors.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: 'Geist',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: OseerColors.textPrimary,
  );

  // Body text
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: OseerColors.textPrimary,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: OseerColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: OseerColors.textSecondary,
  );

  // Button text
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Geist',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Input text
  static const TextStyle inputText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: OseerColors.textPrimary,
  );

  // Caption text
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: OseerColors.textTertiary,
  );
}

/// Spacing constants
class OseerSpacing {
  // Base spacing units
  static const double micro = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Specific component spacing
  static const double cardPadding = 20.0;
  static const double screenMargin = 16.0;
  static const double betweenCards = 16.0;
  static const double formFieldSpacing = 24.0;

  // Border radius
  static const double buttonRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
}

/// Shared Preferences Helper Class
class SharedPreferencesHelper {
  /// Save a user profile to SharedPreferences
  static Future<bool> saveUserProfile({
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
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(OseerConstants.keyUserName, name);
      await prefs.setString(OseerConstants.keyUserEmail, email);

      if (phone != null)
        await prefs.setString(OseerConstants.keyUserPhone, phone);
      if (age != null) await prefs.setInt(OseerConstants.keyUserAge, age);
      if (gender != null)
        await prefs.setString(OseerConstants.keyUserGender, gender);
      if (height != null)
        await prefs.setDouble(OseerConstants.keyUserHeight, height);
      if (weight != null)
        await prefs.setDouble(OseerConstants.keyUserWeight, weight);
      if (activityLevel != null)
        await prefs.setString(
            OseerConstants.keyUserActivityLevel, activityLevel);

      await prefs.setBool(OseerConstants.keyProfileComplete, true);

      return true;
    } catch (e) {
      return false;
    }
  }
}
