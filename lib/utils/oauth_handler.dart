// lib/utils/oauth_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../services/secure_storage_service.dart';

/// Deep link types for clearer routing
enum DeepLinkType {
  // Maintain original enum values for compatibility
  auth, // Authentication related links (login-callback, verification)
  authError, // Authentication links with error parameters
  connection, // Connection between devices (connect token)
  wellness, // Wellness dashboard links
  unknown // Unrecognized links
}

/// Handles OAuth-related deep linking functionality
class OAuthHandler {
  // Stream subscription for deep links
  static StreamSubscription? _deepLinkSubscription;
  static bool _isInitialized = false;
  static final AppLinks _appLinks = AppLinks();

  // Callback for successful OAuth redirects
  static Function(Uri)? _onSuccessCallback;

  // Callback for error OAuth redirects
  static Function(Uri, String?, String?)? _onErrorCallback;

  // Track processed deep links to prevent double handling
  static final Set<String> _processedLinks = {};

  // Secure storage for PKCE parameters
  static SecureStorageService? _secureStorage;

  /// Initialize deep link handling
  static Future<void> initDeepLinks(
    NavigatorState navigator, {
    required Function(Uri) onSuccess,
    required Function(Uri, String?, String?) onError,
    required SecureStorageService secureStorage,
  }) async {
    if (_isInitialized) return;

    _onSuccessCallback = onSuccess;
    _onErrorCallback = onError;
    _secureStorage = secureStorage;

    try {
      // Handle initial URI if the app was opened by a deep link
      final initialUri = await getInitialLink();
      if (initialUri != null) {
        OseerLogger.info('App opened with deep link: $initialUri');
        _handleDeepLink(initialUri, navigator);
      }

      // Listen for incoming deep links while the app is running
      _deepLinkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        OseerLogger.info('Received deep link while app running: $uri');
        _handleDeepLink(uri, navigator);
      }, onError: (error) {
        OseerLogger.error('Deep link error', error);
      });

      _isInitialized = true;
      OseerLogger.info('Deep link handler initialized');
    } catch (e) {
      OseerLogger.error('Error initializing deep links', e);
    }
  }

  /// Get the initial deep link that opened the app, if any
  static Future<Uri?> getInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      return initialUri;
    } catch (e) {
      OseerLogger.error('Error getting initial link', e);
      return null;
    }
  }

  /// Classify a deep link by its type
  static DeepLinkType classifyDeepLink(Uri uri) {
    OseerLogger.debug('Classifying deep link: $uri');

    // FIXED: Check if it's an auth link with error parameters
    // Specifically check for error parameters and OTP expired messages
    if ((uri.path.contains('login-callback') || uri.path.contains('verify')) &&
        (uri.queryParameters.containsKey('error') ||
            uri.queryParameters.containsKey('error_code') ||
            (uri.queryParameters.containsKey('message') &&
                uri.queryParameters['message']
                        ?.toLowerCase()
                        .contains('expired') ==
                    true) ||
            uri.fragment.contains('error=') ||
            uri.toString().contains('otp_expired'))) {
      OseerLogger.debug(
          'Classified as auth error link: ${uri.queryParameters['error'] ?? uri.queryParameters['message'] ?? "OTP expired"}');
      return DeepLinkType.authError;
    }

    // Authentication links
    if (uri.path.contains('login-callback') ||
        uri.path.contains('verify') ||
        uri.queryParameters.containsKey('token') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token')) {
      OseerLogger.debug('Classified as auth link');
      return DeepLinkType.auth;
    }

    // Connection links
    if ((uri.scheme == OseerConstants.deepLinkScheme &&
            uri.host == 'connect') ||
        ((uri.host == 'demo.oseerapp.com' || uri.host.contains('localhost')) &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'connect')) {
      OseerLogger.debug('Classified as connection link');
      return DeepLinkType.connection;
    }

    // Wellness links
    if (uri.path.contains('/wellness') ||
        uri.path.contains('/dashboard') ||
        uri.queryParameters.containsKey('session')) {
      OseerLogger.debug('Classified as wellness link');
      return DeepLinkType.wellness;
    }

    OseerLogger.debug('Classified as unknown link');
    return DeepLinkType.unknown;
  }

  /// Check if a link has been processed already
  static bool isLinkProcessed(Uri uri) {
    return _processedLinks.contains(uri.toString());
  }

  /// Mark a link as processed
  static void markLinkAsProcessed(Uri uri) {
    _processedLinks.add(uri.toString());

    // Limit the size of the processed links set
    if (_processedLinks.length > 100) {
      _processedLinks.remove(_processedLinks.first);
    }
  }

  /// Extract wellness session from deep link
  static Map<String, dynamic>? extractWellnessSession(Uri uri) {
    try {
      final session = uri.queryParameters['session'];
      final purpose = uri.queryParameters['purpose'];
      final timestamp = uri.queryParameters['ts'];

      if (session != null && session.isNotEmpty) {
        OseerLogger.info('Extracted wellness session for purpose: $purpose');

        return {
          'session': session,
          'purpose': purpose ?? 'dashboard_view',
          'timestamp': timestamp,
          'returnPath': uri.path,
        };
      }
    } catch (e) {
      OseerLogger.error('Error extracting wellness session', e);
    }
    return null;
  }

  /// Build wellness dashboard URL with auth token
  static Uri buildWellnessDashboardUrl({
    required String authToken,
    required String userId,
    String purpose = 'body_prep_view',
    String? returnDeepLink,
  }) {
    final Map<String, String> queryParams = {
      'token': authToken,
      'user': userId,
      'purpose': purpose,
      'source': 'mobile_app',
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (returnDeepLink != null) {
      queryParams['return'] = returnDeepLink;
    }

    final dashboardUrl =
        Uri.parse('${OseerConstants.webAppUrl}/dashboard').replace(
      queryParameters: queryParams,
    );

    OseerLogger.info('Built wellness dashboard URL for purpose: $purpose');
    return dashboardUrl;
  }

  /// Build return deep link for app
  static String buildReturnDeepLink({
    required String path,
    Map<String, String>? queryParams,
  }) {
    final uri = Uri(
      scheme: OseerConstants.deepLinkScheme,
      host: OseerConstants.deepLinkDomain,
      path: path,
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  /// Handle an incoming deep link
  static void _handleDeepLink(Uri uri, NavigatorState navigator) async {
    try {
      // Skip if already processed this exact URI
      if (isLinkProcessed(uri)) {
        OseerLogger.debug('Deep link already processed, skipping: $uri');
        return;
      }

      OseerLogger.debug('Processing deep link: $uri');
      final linkType = classifyDeepLink(uri);
      OseerLogger.debug('Deep link classified as: $linkType');

      if (linkType == DeepLinkType.auth) {
        await _processAuthDeepLink(uri, navigator);
        // Mark as processed after handling
        markLinkAsProcessed(uri);
        return;
      } else if (linkType == DeepLinkType.authError) {
        // FIXED: Handle auth error deep links
        final errorCode = uri.queryParameters['error_code'];
        final errorDescription = uri.queryParameters['error_description'];
        OseerLogger.error(
            'Auth deep link contains error: $errorCode - $errorDescription');

        // Call error callback if provided
        if (_onErrorCallback != null) {
          _onErrorCallback!(uri, errorCode, errorDescription);
        } else {
          // Show error dialog if no callback
          _showErrorDialog(
              navigator,
              'Verification Failed',
              errorDescription?.replaceAll('+', ' ') ??
                  'The verification link has expired or is invalid.');
        }

        // Mark as processed after handling
        markLinkAsProcessed(uri);
        return;
      } else if (linkType == DeepLinkType.connection) {
        OseerLogger.info('Detected connection deep link');

        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          OseerLogger.info(
              'Found token in deep link: ${token.substring(0, min(4, token.length))}...');

          // Call success callback if provided
          if (_onSuccessCallback != null) {
            _onSuccessCallback!(uri);
          }

          // Mark as processed after handling
          markLinkAsProcessed(uri);
        }
      } else if (linkType == DeepLinkType.wellness) {
        OseerLogger.info('Detected wellness deep link');

        // Call success callback for wellness links
        if (_onSuccessCallback != null) {
          _onSuccessCallback!(uri);
        }

        markLinkAsProcessed(uri);
      } else {
        OseerLogger.warning('Unknown deep link type: $uri');
      }
    } catch (e) {
      OseerLogger.error('Error handling deep link', e);
    }
  }

  /// Process authentication-related deep links
  static Future<void> _processAuthDeepLink(
      Uri uri, NavigatorState navigator) async {
    try {
      OseerLogger.info('Processing authentication deep link');

      // Extract the token/code parameter
      final queryParams = uri.queryParameters;
      final token = queryParams['token'] ??
          queryParams['code'] ??
          queryParams['access_token'];

      if (token == null || token.isEmpty) {
        OseerLogger.error('Auth deep link missing required token parameter');
        return;
      }

      OseerLogger.info("Processing auth deep link with token...");

      // Ensure we have the secure storage initialized
      if (_secureStorage == null) {
        OseerLogger.warning(
            'Secure storage not initialized, creating new instance');
        _secureStorage = SecureStorageService();
      }

      // Log verification attempt details
      final storedPkceKey = OseerConstants.keyAuthPkceVerifier;
      final hasStoredVerifier =
          await _secureStorage!.containsKey(storedPkceKey);
      OseerLogger.info(
          'PKCE Verification - Has stored verifier: $hasStoredVerifier');

      if (hasStoredVerifier) {
        final verifier = await _secureStorage!.read(storedPkceKey);
        OseerLogger.debug('Using stored PKCE verifier for authentication');

        try {
          // Process auth with Supabase
          final response =
              await Supabase.instance.client.auth.getSessionFromUrl(uri);

          // FIXED: Access the user from the session property
          final userId = response.session?.user.id;
          OseerLogger.info(
              'Successfully processed auth deep link. User: $userId');

          // Clear the used verifier immediately
          await _secureStorage!.delete(storedPkceKey);
          OseerLogger.debug(
              'Cleared used PKCE verifier after successful authentication');

          // Log in automatically after email verification
          if (response.session != null) {
            OseerLogger.info('Setting active session after email verification');
            final refreshToken = response.session?.refreshToken;
            if (refreshToken != null) {
              await Supabase.instance.client.auth.setSession(refreshToken);
            } else {
              OseerLogger.error('Refresh token is null, cannot set session.');
            }

            // Show success message
            if (navigator.context.mounted) {
              ScaffoldMessenger.of(navigator.context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Email verified successfully! Logging you in...'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }

          // Notify callback - this will trigger AuthBloc to check state
          if (_onSuccessCallback != null) {
            _onSuccessCallback!(uri);
          }
        } catch (e) {
          OseerLogger.error('Error processing auth deep link with Supabase', e);

          // Clear any stale verifier
          await _secureStorage!.delete(OseerConstants.keyAuthPkceVerifier);
          OseerLogger.debug(
              'Cleared stale PKCE verifier after authentication error');

          // Handle specific errors
          if (e.toString().contains('expired')) {
            _showErrorDialog(navigator, 'Verification Link Expired',
                'The verification link has expired. Please request a new verification email or contact support.');
          } else if (e.toString().contains('bad_code_verifier')) {
            _showErrorDialog(navigator, 'Authentication Error',
                'There was a problem with the verification process. Please try logging in again.');
          } else {
            _showErrorDialog(navigator, 'Authentication Error',
                'There was a problem verifying your email. Please try again or contact support.');
          }
        }
      } else {
        // FIXED: Special case: No PKCE verifier but has code - try to exchange directly
        if (queryParams.containsKey('code')) {
          try {
            // For email verification links, no verifier is needed
            final code = queryParams['code'];
            if (code != null) {
              // Ensure code is non-null before passing to exchangeCodeForSession
              final response = await Supabase.instance.client.auth
                  .exchangeCodeForSession(code);

              // Access user from session
              final userId = response.session.user.id;
              OseerLogger.info(
                  'Successfully exchanged code for session. User: $userId');

              // Show success message
              if (navigator.context.mounted) {
                ScaffoldMessenger.of(navigator.context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Email verified successfully! Logging you in...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              // Notify callback - this will trigger AuthBloc to check state
              if (_onSuccessCallback != null) {
                _onSuccessCallback!(uri);
              }

              return;
            } else {
              throw Exception('Code parameter is null');
            }
          } catch (e) {
            OseerLogger.error('Error exchanging code for session', e);
            // Continue to default error handling
          }
        }

        OseerLogger.error('No PKCE verifier found for authentication');
        _showErrorDialog(navigator, 'Authentication Error',
            'Could not verify your email. Please retry the login process.');
      }
    } catch (e) {
      OseerLogger.error('Error in _processAuthDeepLink', e);
    }
  }

  /// Open OAuth URL in external browser
  static Future<bool> openOAuthUrl(String url) async {
    OseerLogger.info('Opening OAuth URL: $url');
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        OseerLogger.error('Could not launch OAuth URL: $url');
        return false;
      }
    } catch (e) {
      OseerLogger.error('Error opening OAuth URL', e);
      return false;
    }
  }

  /// Store PKCE code verifier securely
  static Future<bool> storePkceVerifier(String verifier) async {
    try {
      if (_secureStorage == null) {
        OseerLogger.warning(
            'Secure storage not initialized, creating new instance');
        _secureStorage = SecureStorageService();
      }

      // Store the verifier securely
      await _secureStorage!.write(OseerConstants.keyAuthPkceVerifier, verifier);
      OseerLogger.debug('Stored PKCE verifier securely');
      return true;
    } catch (e) {
      OseerLogger.error('Failed to store PKCE verifier', e);
      return false;
    }
  }

  /// Clear all stored PKCE verifiers
  static Future<void> clearPkceVerifiers() async {
    try {
      if (_secureStorage == null) {
        _secureStorage = SecureStorageService();
      }
      await _secureStorage!.delete(OseerConstants.keyAuthPkceVerifier);
      OseerLogger.debug('Cleared PKCE verifiers');
    } catch (e) {
      OseerLogger.error('Error clearing PKCE verifiers', e);
    }
  }

  /// Show error dialog
  static void _showErrorDialog(
      NavigatorState navigator, String title, String message) {
    if (!navigator.context.mounted) return;

    showDialog(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Clean up resources
  static void dispose() {
    _deepLinkSubscription?.cancel();
    _isInitialized = false;
    _onSuccessCallback = null;
    _onErrorCallback = null;
    _processedLinks.clear();
    OseerLogger.debug('OAuth handler disposed');
  }

  /// Check if a URL is a valid redirect URL for our app
  static bool isValidRedirectUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.scheme == OseerConstants.deepLinkScheme &&
          uri.host == OseerConstants.deepLinkDomain;
    } catch (e) {
      OseerLogger.error('Error validating redirect URL', e);
      return false;
    }
  }
}

// Helper function to get minimum safely
int min(int a, int b) {
  return a < b ? a : b;
}
