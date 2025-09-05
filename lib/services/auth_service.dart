// lib/services/auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:equatable/equatable.dart';

import '../models/helper_models.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../services/secure_storage_service.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../utils/oauth_handler.dart';

// User Authentication status
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  onboarding,
  emailVerificationPending,
  error
}

// Custom exception for email verification requirement
class EmailVerificationRequiredException implements Exception {
  final String email;

  EmailVerificationRequiredException(this.email);

  @override
  String toString() => 'Email verification required for: $email';
}

// Service-specific AuthState class (to avoid conflict with bloc/auth/auth_state.dart)
class AppAuthState extends Equatable {
  const AppAuthState();

  @override
  List<Object?> get props => [];
}

// Specific state classes
class AuthenticatedState extends AppAuthState {
  final User user;
  const AuthenticatedState(this.user);

  @override
  List<Object> get props => [user];
}

class UnauthenticatedState extends AppAuthState {
  const UnauthenticatedState();
}

class OnboardingState extends AppAuthState {
  final User user;
  const OnboardingState(this.user);

  @override
  List<Object> get props => [user];
}

class EmailVerificationPendingState extends AppAuthState {
  final String email;
  const EmailVerificationPendingState(this.email);

  @override
  List<Object> get props => [email];
}

class ErrorState extends AppAuthState {
  final String message;
  const ErrorState(this.message);

  @override
  List<Object> get props => [message];
}

// Authentication service
class AuthService {
  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;
  final ApiService _apiService;
  final BiometricService _biometricService;
  final _authStateController = StreamController<AppAuthState>.broadcast();

  // Stream and properties
  Stream<AppAuthState> get authStateChanges => _authStateController.stream;
  SupabaseClient get _supabase => Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  // Initialization flag
  bool _isInitialized = false;
  bool _isInitializing = false; // Added to prevent concurrent initialization

  AuthService({
    required SharedPreferences prefs,
    required SecureStorageService secureStorage,
    required ApiService apiService,
    required BiometricService biometricService,
  })  : _prefs = prefs,
        _secureStorage = secureStorage,
        _apiService = apiService,
        _biometricService = biometricService {
    OseerLogger.debug(
        'AuthService constructed - Initializing asynchronously...');
    // Don't block constructor, but make sure initialization starts immediately
    _initialize();
  }

  // Public method for initialization that can be called by the AuthBloc
  Future<void> initialize() async {
    await _initialize();
  }

  Future<void> _initialize() async {
    // Prevent concurrent initializations which could lead to race conditions
    if (_isInitialized || _isInitializing) {
      OseerLogger.debug(
          'AuthService already initialized or initializing, skipping redundant initialization');
      return;
    }

    _isInitializing = true;
    OseerLogger.info('🔐 Initializing AuthService');

    try {
      // Debug logging the instance ID for SharedPreferences
      OseerLogger.debug(
          '🔐 AuthService using SharedPreferences instance: ${_prefs.hashCode}');

      // Log Supabase client instance to help with debugging
      final clientHashCode = _supabase.hashCode;
      OseerLogger.debug(
          '🔐 AuthService using Supabase client: $clientHashCode');

      // Log current auth instance state
      final preSessionCheck = _supabase.auth.currentSession;
      OseerLogger.debug(
          '🔐 Pre-setup Supabase session check: ${preSessionCheck != null ? "EXISTS" : "NULL"}');

      if (preSessionCheck != null) {
        OseerLogger.debug(
            '🔐 Session token (first 10 chars): ${preSessionCheck.accessToken.substring(0, 10)}...');
        OseerLogger.debug(
            '🔐 Session expiry: ${DateTime.fromMillisecondsSinceEpoch(preSessionCheck.expiresAt! * 1000)}');
      }

      // Set up auth state change listener - do this first to catch initial states
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });

      // Check current session on initialization
      final session = _supabase.auth.currentSession;
      OseerLogger.debug(
          '🔐 Checking current Supabase session: ${session != null ? "EXISTS" : "NULL"}');

      if (session != null) {
        OseerLogger.info(
            '🔐 Found existing Supabase session on initialization');

        final user = _supabase.auth.currentUser;
        if (user != null) {
          // Save user data to prefs
          await _saveUserData(user);

          // Save session data
          await _saveSessionData(session);

          // Check onboarding status
          final onboardingComplete =
              _prefs.getBool(OseerConstants.keyOnboardingComplete) ?? false;

          if (onboardingComplete) {
            OseerLogger.info(
                '🔐 User is authenticated and onboarding complete');
            _authStateController.add(AuthenticatedState(user));
          } else {
            OseerLogger.info('🔐 User is authenticated but needs onboarding');
            _authStateController.add(OnboardingState(user));
          }
        } else {
          OseerLogger.warning(
              '🔐 Found session but no current user, attempting restore');
          // We have a session but no current user - attempt restore from stored session
          final hasSessionData = await _restoreSessionFromPrefs();

          if (!hasSessionData) {
            OseerLogger.warning(
                '🔐 Failed to restore session, user is unauthenticated');
            _authStateController.add(const UnauthenticatedState());
          }
        }
      } else {
        // First try secure storage for session, fallback to SharedPreferences
        OseerLogger.info(
            '🔐 No current Supabase session, attempting to restore from storage');

        // Check for stored session/auth data in secure storage first
        try {
          final secureSessionData =
              await _secureStorage.read(OseerConstants.keyAuthSessionToken);
          if (secureSessionData != null && secureSessionData.isNotEmpty) {
            OseerLogger.info(
                '🔐 Found session data in secure storage, attempting to restore');
            await _supabase.auth.setSession(secureSessionData);

            // Verify restore was successful
            final restoredUser = _supabase.auth.currentUser;
            if (restoredUser != null) {
              OseerLogger.info(
                  '🔐 Successfully restored session from secure storage');

              // Process restored session
              final restoredSession = _supabase.auth.currentSession;
              if (restoredSession != null) {
                await _processRestoredSession(restoredUser, restoredSession);
                _isInitializing = false;
                _isInitialized = true;
                return;
              }
            } else {
              OseerLogger.warning(
                  '🔐 Failed to restore session from secure storage');
            }
          } else {
            OseerLogger.info('🔐 No session data found in secure storage');
          }
        } catch (e) {
          OseerLogger.warning(
              '🔐 Error reading session from secure storage: $e');
        }

        // Fallback to SharedPreferences
        final hasSessionData = await _restoreSessionFromPrefs();

        if (!hasSessionData) {
          OseerLogger.info(
              "💡 No stored session found, user is unauthenticated");
          _authStateController.add(const UnauthenticatedState());
        }
      }
    } catch (e, s) {
      OseerLogger.error('Error initializing AuthService', e, s);
      _authStateController.add(
          ErrorState('Failed to initialize authentication: ${e.toString()}'));
    }

    _isInitializing = false;
    _isInitialized = true;
    OseerLogger.info('🔐 AuthService initialization completed');
  }

  // Helper method to process a restored session
  Future<void> _processRestoredSession(User user, Session session) async {
    // Save user data
    await _saveUserData(user);

    // Save session data
    await _saveSessionData(session);

    // Check onboarding status
    final onboardingComplete =
        _prefs.getBool(OseerConstants.keyOnboardingComplete) ?? false;

    if (onboardingComplete) {
      _authStateController.add(AuthenticatedState(user));
    } else {
      _authStateController.add(OnboardingState(user));
    }
  }

  Future<bool> _restoreSessionFromPrefs() async {
    try {
      // Check if we have a session token
      final sessionDataJson =
          _prefs.getString(OseerConstants.keyAuthSessionToken);
      OseerLogger.debug(
          '🔐 _restoreSessionFromPrefs: sessionDataJson = ${sessionDataJson != null ? "Found (${sessionDataJson.length} chars)" : "NULL"}');

      if (sessionDataJson == null || sessionDataJson.isEmpty) {
        OseerLogger.info('🔐 No session data found in prefs');
        return false;
      }

      OseerLogger.info(
          '🔐 Found stored session data in prefs, attempting to restore');

      try {
        // Try to restore Supabase session
        OseerLogger.debug('🔐 Setting Supabase session with stored data');
        await _supabase.auth.setSession(sessionDataJson);

        // Check if restoration was successful
        final currentUser = _supabase.auth.currentUser;
        final currentSession = _supabase.auth.currentSession;

        OseerLogger.debug(
            '🔐 After setSession: user=${currentUser != null}, session=${currentSession != null}');

        if (currentUser != null && currentSession != null) {
          OseerLogger.info(
              '🔐 Successfully restored session for user: ${currentUser.id}');

          // Save the session data to secure storage for future restorations
          try {
            await _secureStorage.write(
                OseerConstants.keyAuthSessionToken, sessionDataJson);
            OseerLogger.debug('🔐 Session data backed up to secure storage');
          } catch (e) {
            OseerLogger.warning(
                '🔐 Failed to backup session to secure storage: $e');
          }

          // Process the restored session
          await _processRestoredSession(currentUser, currentSession);
          return true;
        } else {
          OseerLogger.warning('🔐 Failed to restore user from session data');
        }
      } catch (e, stack) {
        OseerLogger.error(
            '🔐 Error restoring session from stored data', e, stack);

        // If setSession failed, the session data might be invalid
        // Try to extract tokens and reconstruct manually as a fallback
        try {
          Map<String, dynamic> sessionData = json.decode(sessionDataJson);
          if (sessionData.containsKey('access_token') &&
              sessionData.containsKey('refresh_token')) {
            OseerLogger.info(
                '🔐 Trying alternative session restoration approach');

            final accessToken = sessionData['access_token'];
            final refreshToken = sessionData['refresh_token'];

            // Use refresh token to get a new session
            await _supabase.auth.setSession(refreshToken);

            // Check if this worked
            final recoveredUser = _supabase.auth.currentUser;
            final recoveredSession = _supabase.auth.currentSession;

            if (recoveredUser != null && recoveredSession != null) {
              OseerLogger.info(
                  '🔐 Successfully recovered session using refresh token');
              await _processRestoredSession(recoveredUser, recoveredSession);
              return true;
            }
          }
        } catch (fallbackError) {
          OseerLogger.error(
              '🔐 Fallback session restoration also failed', fallbackError);
        }
      }
    } catch (e, s) {
      OseerLogger.error('🔐 Error in _restoreSessionFromPrefs', e, s);
    }

    return false;
  }

  void _handleAuthStateChange(AuthChangeEvent event, Session? session) async {
    OseerLogger.info('🔐 Supabase auth state changed: ${event.name}');

    switch (event) {
      case AuthChangeEvent.signedIn:
        if (session != null && session.user != null) {
          final user = session.user!;
          // CORRECT: We ONLY save the user data and the Supabase session.
          // We DO NOT interact with TokenManager here at all.
          await _saveUserData(user);
          await _saveSessionData(session);

          final onboardingComplete =
              _prefs.getBool(OseerConstants.keyOnboardingComplete) ?? false;

          if (onboardingComplete) {
            OseerLogger.info('🔐 User signed in and onboarding is complete.');
            _authStateController.add(AuthenticatedState(user));
          } else {
            OseerLogger.info('🔐 User signed in but needs onboarding.');
            _authStateController.add(OnboardingState(user));
          }
        }
        break;

      case AuthChangeEvent.signedOut:
        OseerLogger.info('🔐 User signed out');
        // CORRECT: We ONLY clear auth-related data. TokenManager is not involved.
        await _prefs.remove(OseerConstants.keyAuthSessionToken);
        await _prefs.remove(OseerConstants.keyAuthSessionExpiry);
        await _prefs.remove(OseerConstants.keyAuthRefreshToken);
        await _prefs.remove(OseerConstants.keyIsConnected);

        // Also clear from secure storage
        try {
          await _secureStorage.delete(OseerConstants.keyAuthSessionToken);
        } catch (e) {
          OseerLogger.warning('🔐 Failed to clear secure storage: $e');
        }

        _authStateController.add(const UnauthenticatedState());
        break;

      case AuthChangeEvent.userUpdated:
        if (session != null && session.user != null) {
          OseerLogger.info('🔐 User data updated');
          await _saveUserData(session.user!);
        }
        break;

      case AuthChangeEvent.tokenRefreshed:
        if (session != null) {
          OseerLogger.info('🔐 Token refreshed');
          // CORRECT: Just save the new session. No need to touch TokenManager.
          await _saveSessionData(session);
        }
        break;

      default:
        OseerLogger.debug('🔐 Unhandled auth event: ${event.name}');
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserData(User user) async {
    try {
      // Save user ID
      await _prefs.setString(OseerConstants.keyUserId, user.id);

      // Save email if available
      if (user.email != null) {
        await _prefs.setString(OseerConstants.keyUserEmail, user.email!);
      }

      // Save name if available in metadata
      if (user.userMetadata != null) {
        final metadata = user.userMetadata!;

        if (metadata.containsKey('name') || metadata.containsKey('full_name')) {
          final name = metadata['name'] ?? metadata['full_name'];
          if (name != null && name is String) {
            await _prefs.setString(OseerConstants.keyUserName, name);
          }
        }
      }

      OseerLogger.debug('🔐 User data saved to SharedPreferences');
    } catch (e, s) {
      OseerLogger.error('🔐 Error saving user data', e, s);
    }
  }

  // Save session data to SharedPreferences and SecureStorage
  Future<void> _saveSessionData(Session session) async {
    try {
      // Save full session JSON
      final sessionJson = json.encode(session.toJson());

      // Save to SharedPreferences
      await _prefs.setString(OseerConstants.keyAuthSessionToken, sessionJson);

      // Also save to SecureStorage for more reliable retrieval
      try {
        await _secureStorage.write(
            OseerConstants.keyAuthSessionToken, sessionJson);
      } catch (e) {
        OseerLogger.warning('🔐 Failed to save session to secure storage: $e');
      }

      // Save expiry if available
      if (session.expiresAt != null) {
        await _prefs.setInt(
            OseerConstants.keyAuthSessionExpiry, session.expiresAt!);
      }

      // Save refresh token if available
      if (session.refreshToken != null) {
        await _prefs.setString(
            OseerConstants.keyAuthRefreshToken, session.refreshToken!);
      }

      OseerLogger.debug('🔐 Session data saved to storage');

      // Verify session was persisted immediately
      final savedData = _prefs.getString(OseerConstants.keyAuthSessionToken);
      if (savedData == null || savedData.isEmpty) {
        OseerLogger.warning(
            '🔐 Session data not immediately persisted to SharedPreferences!');
      }
    } catch (e, s) {
      OseerLogger.error('🔐 Error saving session data', e, s);
    }
  }

  // Sign in with email and password
  Future<User> signInWithEmail(String email, String password) async {
    try {
      OseerLogger.info('🔐 Attempting to sign in with email: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign-in failed: No user returned');
      }

      final user = response.user!;

      // Check if email is verified
      if (user.emailConfirmedAt == null) {
        OseerLogger.warning('🔐 User email not confirmed: $email');
        throw EmailVerificationRequiredException(email);
      }

      OseerLogger.info('🔐 Email sign-in successful: $email');
      return user;
    } on AuthException catch (e) {
      OseerLogger.error('🔐 Auth exception during sign-in', e);

      if (e.message.contains('Email not confirmed')) {
        throw EmailVerificationRequiredException(email);
      } else if (e.message.contains('Invalid login credentials')) {
        throw AuthException('Invalid email or password. Please try again.');
      }

      throw AuthException('Sign-in failed: ${e.message}');
    } catch (e, s) {
      OseerLogger.error('🔐 Error during sign-in', e, s);

      if (e is EmailVerificationRequiredException) {
        rethrow;
      }

      throw AuthException('Sign-in failed: ${e.toString()}');
    }
  }

  // Sign up with email and password
  Future<User> signUpWithEmail(
      String email, String password, String name) async {
    try {
      OseerLogger.info('🔐 Attempting to sign up with email: $email');

      // Set up user metadata with name
      final Map<String, dynamic> userMetadata = {
        'name': name,
        'full_name': name,
      };

      // Sign up with Supabase
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
        emailRedirectTo: OseerConstants.oAuthRedirectUri,
      );

      if (response.user == null) {
        throw Exception('Sign-up failed: No user returned');
      }

      final user = response.user!;

      // Save user data regardless of email verification status
      await _saveUserData(user);

      // Check if email confirmation is required
      if (user.emailConfirmedAt == null) {
        OseerLogger.info('🔐 Email verification required for: $email');
        throw EmailVerificationRequiredException(email);
      }

      OseerLogger.info('🔐 Email sign-up successful: $email');
      return user;
    } on AuthException catch (e) {
      OseerLogger.error('🔐 Auth exception during sign-up', e);

      if (e.message.contains('already registered')) {
        throw AuthException(
            'This email is already registered. Please log in instead.');
      }

      throw AuthException('Sign-up failed: ${e.message}');
    } catch (e, s) {
      OseerLogger.error('🔐 Error during sign-up', e, s);

      if (e is EmailVerificationRequiredException) {
        rethrow;
      }

      throw AuthException('Sign-up failed: ${e.toString()}');
    }
  }

  // Sign out - clear all auth data
  Future<void> signOut() async {
    try {
      OseerLogger.info('🔐 Signing out user');

      // CORRECT: No call to TokenManager. The handoff token is temporary and
      // doesn't need to be cleared on sign out.
      await _prefs.remove(OseerConstants.keyAuthSessionToken);
      await _prefs.remove(OseerConstants.keyAuthSessionExpiry);
      await _prefs.remove(OseerConstants.keyAuthRefreshToken);
      await _prefs.remove(OseerConstants.keyIsConnected);

      // Also clear secure storage
      try {
        await _secureStorage.delete(OseerConstants.keyAuthSessionToken);
      } catch (e) {
        OseerLogger.warning('🔐 Failed to clear secure storage: $e');
      }

      // Sign out from Supabase
      await _supabase.auth.signOut();

      OseerLogger.info('🔐 User signed out successfully');
    } catch (e, s) {
      OseerLogger.error('🔐 Error during sign-out', e, s);

      // Force local clean-up even if Supabase fails
      await _prefs.remove(OseerConstants.keyAuthSessionToken);
      await _prefs.remove(OseerConstants.keyAuthSessionExpiry);
      await _prefs.remove(OseerConstants.keyAuthRefreshToken);
      await _prefs.remove(OseerConstants.keyIsConnected);

      try {
        await _secureStorage.delete(OseerConstants.keyAuthSessionToken);
      } catch (_) {}

      throw AuthException('Sign-out error: ${e.toString()}');
    }
  }

  // Set onboarding as complete
  Future<void> completeOnboarding() async {
    await _prefs.setBool(OseerConstants.keyOnboardingComplete, true);

    // Check if user is authenticated
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      _authStateController.add(AuthenticatedState(currentUser));
    }
  }

  // Update current user metadata
  Future<void> updateCurrentUser(Map<String, dynamic> userMetadata) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(data: userMetadata));
      OseerLogger.info('🔐 User metadata updated successfully');
    } catch (e, s) {
      OseerLogger.error('🔐 Error updating user metadata', e, s);
      throw AuthException('Failed to update user data: ${e.toString()}');
    }
  }

  // Set onboarding status
  Future<void> setOnboardingStatus(bool isComplete) async {
    await _prefs.setBool(OseerConstants.keyOnboardingComplete, isComplete);
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      if (isComplete) {
        _authStateController.add(AuthenticatedState(currentUser));
      } else {
        _authStateController.add(OnboardingState(currentUser));
      }
    }
  }

  // Check if there is an active authenticated session
  Future<bool> isAuthenticated() async {
    try {
      final currentSession = _supabase.auth.currentSession;
      return currentSession != null;
    } catch (e) {
      OseerLogger.error('🔐 Error checking authentication status', e);
      return false;
    }
  }

  // Check if the user needs to complete onboarding
  Future<bool> needsOnboarding() async {
    final onboardingComplete =
        _prefs.getBool(OseerConstants.keyOnboardingComplete) ?? false;
    return !onboardingComplete && _supabase.auth.currentUser != null;
  }

  // Check if user's email is verified
  bool isEmailVerified() {
    final currentUser = _supabase.auth.currentUser;
    return currentUser?.emailConfirmedAt != null;
  }

  // Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Get user name from metadata
  String? getUserName(User user) {
    if (user.userMetadata != null) {
      return user.userMetadata!['name'] as String? ??
          user.userMetadata!['full_name'] as String?;
    }
    return null;
  }

  // Clean up resources
  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }
}
