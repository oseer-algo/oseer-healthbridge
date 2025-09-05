// lib/utils/constants.dart
import 'dart:io' show Platform;
import 'dart:math'; // For Random and min
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart'; // Required for Color, FontWeight, etc.
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For environment variables

/// Constants used throughout the Oseer HealthBridge app.
class OseerConstants {
  // --- App Information ---
  static const String appName = "Oseer HealthBridge";
  static const String appVersion = "2.5"; // Updated version

  // --- API Configuration ---
  // FIX #1: This URL MUST point to your deployed Next.js application, NOT the Supabase functions URL.
  static final String apiBaseUrl = 'https://demo.oseerapp.com/api';

  // --- Supabase Edge Function Configuration ---
  static const String supabaseFunctionsUrl =
      'https://oxvhffqnenhtyypzpcam.supabase.co/functions/v1';
  static const String processHealthDataFunction = 'process-health-data';

  // --- Supabase Configuration ---
  // Get these values from environment variables with careful fallback handling
  static String get supabaseUrl {
    final envUrl = dotenv.env['SUPABASE_URL'];
    if (envUrl == null || envUrl.isEmpty) {
      // Log warning if URL is missing or empty
      if (kDebugMode) {
        print('[WARN] SUPABASE_URL not found in .env file, using fallback URL');
      }
      return 'https://oxvhffqnenhtyypzpcam.supabase.co';
    }
    return envUrl;
  }

  static String get supabaseAnonKey {
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey == null || envKey.isEmpty) {
      // Log warning if key is missing or empty
      if (kDebugMode) {
        print(
            '[WARN] SUPABASE_ANON_KEY not found in .env file, using fallback key');
      }
      // Using a placeholder key for logging/debugging purposes
      // You should obtain a proper key from your Supabase project settings
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94dmhmZnFuZW5odHl5cHpwY2FtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODkwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.placeholder';
    }
    return envKey;
  }

  // --- Google Auth ---
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  // API Endpoints - Updated to match Next.js API routes
  static const String endpointTokenStatus = '/token/status';
  static const String endpointEventLog = '/event/log';
  static const String endpointUserCreate = '/user/create';
  static const String endpointUserUpdate = '/user/update';
  static const String endpointUserMe = '/user/me';

  // Added health data API endpoints
  static const String endpointHealthData = '/health-data';
  static const String endpointHealthDataActivities = '/health-data-activities';
  static const String endpointHealthDataPreparedness =
      '/health-data-preparedness';
  static const String endpointInsightsGenerate = '/insights-generate';
  static const String endpointAlgorithmRun = '/algorithm-run';

  // Added device endpoint
  static const String endpointDeviceHeartbeat = '/device/heartbeat';

  // Authentication Endpoints
  static const String endpointAuthSignup = '/auth-signup';
  static const String endpointAuthLogin = '/auth-login';
  static const String endpointAuthGoogle = '/auth-google';
  static const String endpointAuthLinkEmail = '/auth-link-email';

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 15); // General default
  static const Duration apiTokenTimeout =
      Duration(seconds: 10); // Specific for token ops

  // *** ADDED: API Retry Constants ***
  static const int apiRetryAttempts =
      1; // Max number of retries (total attempts = retries + 1)
  static final Duration apiRetryDelay =
      const Duration(seconds: 1); // Delay between retries

  // --- Web App URLs ---
  static const String webAppBaseUrl = 'https://demo.oseerapp.com';
  static const String webConnectUrl =
      webAppBaseUrl; // Updated to use base URL directly
  static const String webAppUrl = webAppBaseUrl;

  // --- Token Generation & Formatting ---
  static const String tokenChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int tokenLength = 24;
  static const int tokenGroupSize = 4;
  // FIX #2: Correct token expiry to 15 minutes as per documentation
  static const int localTokenExpiryMinutes = 15;

  // --- Development & Feature Flags ---
  static const bool useLocalUuidFallback =
      true; // Allow local UUID generation for testing/offline
  static const bool useLocalTokenFallback =
      false; // Disable local token generation (RECOMMENDED)

  // --- Platform Detection ---
  // Wrap Platform checks for web compatibility if needed, though kIsWeb check helps
  static final bool isAndroid = !kIsWeb && Platform.isAndroid;
  static final bool isIOS = !kIsWeb && Platform.isIOS;

  // --- Deep Link Configuration ---
  static const String deepLinkScheme = 'oseerbridge';
  static const String deepLinkDomain = 'login-callback';
  static const String oAuthRedirectUri = 'oseerbridge://login-callback/';

  // --- Background Task Identifiers ---
  static const String backgroundTaskHistoricalSync = 'historicalSync';

  // --- SharedPreferences Keys ---
  // Core Session/User Keys
  static const String keyUserId = 'oseer_user_id';
  static const String keyDeviceId = 'oseer_device_id';
  static const String keyConnectionToken = 'oseer_connection_token';
  static const String keyTokenExpiry = 'oseer_token_expiry_time';
  static const String keyTokenGenerationTime =
      'oseer_token_generation_time'; // Added for token refresh handling
  static const String keyTokenOrigin =
      'oseer_token_origin'; // "server" or "local" (now likely always server)
  static const String keyIsConnected = 'oseer_is_connected_flag';

  // App State Keys
  static const String keyOnboardingComplete = 'oseer_onboarding_complete_flag';
  static const String keyOnboardingStarted =
      'oseer_onboarding_started_flag'; // Added for auth flow
  static const String keyProfileComplete = 'oseer_profile_complete_flag';
  static const String keyGrantedPermissions = 'oseer_granted_permissions';
  static const String keyBackgroundPermissionGranted =
      'oseer_background_permission_granted'; // New key for background permission
  static const String keyLastSync = 'oseer_last_sync_time';
  static const String keyPotentialUserId =
      'oseer_potential_user_id'; // Potentially used during auth linking
  static const String keyBackgroundSyncUserId =
      'oseer_background_sync_user_id'; // Added for background sync

  // Welcome Screen Key
  static const String keyHasSeenWelcome = 'oseer_has_seen_welcome';

  // Auth Specific Keys
  static const String keyAuthUser = 'oseer_auth_user';
  static const String keyAuthCredentials = 'oseer_auth_credentials';
  static const String keyAuthSessionToken = 'oseer_auth_session_token';
  static const String keyAuthSessionExpiry = 'oseer_auth_session_expiry';
  static const String keyAuthRefreshToken = 'oseer_auth_refresh_token';
  static const String keyAuthPkceVerifier =
      'oseer_auth_pkce_verifier'; // NEW: PKCE code verifier

  // FIXED: P5 - Add new Supabase access token key (separate from connection tokens)
  static const String keySupabaseAccessToken = 'oseer_supabase_access_token';

  // NEW: Add handoff token key for simplified TokenManager
  static const String keyHandoffToken = 'handoff_token';

  // NEW CONSTANT for tracking handoff state
  static const String keyAwaitingWebHandoff = 'awaiting_web_handoff';

  // Health Permission Keys (Added for early permission request pattern)
  static const String keyHealthPermissionsRequested =
      'oseer_health_permissions_requested';
  static const String keyHealthPermissionResult =
      'oseer_health_permission_result';
  static const String keyHealthPermissionRequestTime =
      'oseer_health_permission_request_time';
  static const String keyHealthPermissionResultTime =
      'oseer_health_permission_result_time';
  // FIXED: P1 - Add new key for static permission success tracking
  static const String keyLastStaticPermissionsGranted =
      'oseer_last_static_permissions_granted';

  // Profile Keys (Used by UserProfile and potentially SharedPreferences)
  static const String keyUserName = 'oseer_user_name';
  static const String keyUserEmail = 'oseer_user_email';
  static const String keyUserPhone = 'oseer_user_phone';
  static const String keyUserAge = 'oseer_user_age';
  static const String keyUserGender = 'oseer_user_gender';
  static const String keyUserHeight = 'oseer_user_height';
  static const String keyUserWeight = 'oseer_user_weight';
  static const String keyUserActivityLevel = 'oseer_user_activity_level';
  static const String keyDeviceName =
      'oseer_device_name'; // Added for consistency
  static const String keyDeviceType =
      'oseer_device_type'; // Added for consistency

  // FIXED: P4 - Add key for Phase 2 sync progress tracking
  static const String keyLastHistoricalSyncEndTime =
      'oseer_last_historical_sync_end_time';
  static const String keyHistoricalSyncComplete =
      'oseer_historical_sync_complete';
  static const String keyHistoricalSyncCompletedAt =
      'oseer_historical_sync_completed_at';

  // NEW: Keys for resumable sync state
  static const String keyBodyPrepSyncComplete = 'oseer_body_prep_sync_complete';
  static const String keyHistoricalSyncState = 'oseer_historical_sync_state';

  // --- UI & Animations ---
  static const Duration shortAnimDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimDuration = Duration(milliseconds: 400);
  static const Duration longAnimDuration = Duration(milliseconds: 600);

  // --- Network & Sync Settings ---
  // Note: apiRetryAttempts/Delay are defined above
  static const int maxConnectionRetries = 2;
  static const int connectionRetryBaseDelaySeconds = 1;
  static const int connectionRetryMaxDelaySeconds = 10;
  static const Duration syncFrequency = Duration(hours: 1);
  static const Duration minSyncInterval = Duration(minutes: 15);
  static const int maxWellnessDataHistoryDays = 7;

  // --- Environment ---
  static const String environment = kDebugMode ? 'lab' : 'production';

  /// Formats a token string with separators for display purposes.
  static String formatTokenForDisplay(String token) {
    final String cleanToken =
        token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (cleanToken.isEmpty) return '';
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < cleanToken.length; i++) {
      buffer.write(cleanToken[i]);
      if ((i + 1) % tokenGroupSize == 0 && i != cleanToken.length - 1) {
        buffer.write('-');
      }
    }
    return buffer.toString();
  }

  /// Cleans and standardizes a token string (uppercase, alphanumeric only).
  static String cleanToken(String token) {
    return token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
  }

  /// Generates a cryptographically secure random token of specified length.
  static String generateSecureToken() {
    final Random secureRandom = Random.secure();
    return List.generate(
      tokenLength,
      (_) => tokenChars[secureRandom.nextInt(tokenChars.length)],
    ).join();
  }
}

/// Defines named routes used for navigation.
class OseerRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String onboardingIntro = '/onboarding/intro';
  static const String onboardingProfile = '/onboarding/profile';
  static const String onboardingPermissions = '/onboarding/permissions';
  static const String tokenScreen = '/token';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String debug = '/debug';
}

// Colors for the Oseer app
class OseerColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF47B58E);
  static const Color primaryLight = Color(0xFF65C9A8);
  static const Color primaryDark = Color(0xFF007E57);

  // Secondary Color
  static const Color secondary = Color(0xFF5B8DEF);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF2196F3);

  // Neutral & Background Colors
  static const Color background = Color(0xFFFAFFFE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimary = Color(0xFF272727);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);

  // Token Display Specific Colors
  static const Color tokenBackground = Color(0xFFF0F9F5);
  static const Color tokenBorder = Color(0xFFDDF0E9);
  static const Color tokenTextDark = Color(0xFF2A5F4A);
  static const Color tokenTextLight = Color(0xFF5AB992);
}

/// Text Styles for the app
class OseerTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
      fontFamily: 'Geist',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: OseerColors.textPrimary);
  static const TextStyle h2 = TextStyle(
      fontFamily: 'Geist',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: OseerColors.textPrimary);
  static const TextStyle h3 = TextStyle(
      fontFamily: 'Geist',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: OseerColors.textPrimary);

  // Body Text
  static const TextStyle bodyRegular = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: OseerColors.textPrimary);
  static const TextStyle bodyBold = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: OseerColors.textPrimary);
  static const TextStyle bodySmall = TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: OseerColors.textSecondary);
  static const TextStyle caption = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: OseerColors.textSecondary);

  // Button Text
  static const TextStyle buttonText = TextStyle(
      fontFamily: 'Geist',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white);

  // Input Text
  static const TextStyle inputText = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: OseerColors.textPrimary);
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
  static const double cardPadding = 24.0;
  static const double screenMargin = 16.0;
  static const double betweenCards = 16.0;
  static const double formFieldSpacing = 24.0;

  // Border radius
  static const double buttonRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
}

// *** ADDED: UserProfileKeys ***
/// Defines keys used for accessing user profile data,
/// often used with maps or SharedPreferences. Matches OseerConstants profile keys.
class UserProfileKeys {
  static const String userId = OseerConstants.keyUserId;
  static const String name = OseerConstants.keyUserName;
  static const String email = OseerConstants.keyUserEmail;
  static const String phone = OseerConstants.keyUserPhone;
  static const String age = OseerConstants.keyUserAge;
  static const String gender = OseerConstants.keyUserGender;
  static const String height = OseerConstants.keyUserHeight;
  static const String weight = OseerConstants.keyUserWeight;
  static const String activityLevel = OseerConstants.keyUserActivityLevel;
  static const String deviceId = OseerConstants.keyDeviceId;
  static const String deviceType = OseerConstants.keyDeviceType;
  // Add other profile-related keys here if needed
}
