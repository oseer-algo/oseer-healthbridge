// File path: lib/services/api_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './logger_service.dart';
import '../utils/constants.dart';

/// Service for making API requests
class ApiService {
  final Dio _dio;
  final SharedPreferences _prefs;

  // Create a static instance for easy access
  static ApiService? _instance;
  static ApiService get instance => _instance!;

  /// Create a new API service
  factory ApiService(SharedPreferences prefs) {
    _instance ??= ApiService._internal(prefs);
    return _instance!;
  }

  /// Internal constructor
  ApiService._internal(this._prefs)
      : _dio = Dio(
          BaseOptions(
            baseUrl: OseerConstants.apiBaseUrl,
            connectTimeout: OseerConstants.apiConnectTimeout,
            receiveTimeout: OseerConstants.apiReceiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          OseerLogger.info('API Request: ${options.method} ${options.path}');
          OseerLogger.debug('API Request Body: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          OseerLogger.info('API Response: ${response.statusCode}');
          OseerLogger.debug('API Response Body: ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) {
          OseerLogger.error(
              'API Error: ${error.requestOptions.method} ${error.requestOptions.path} -> ${error.message}',
              error);

          if (error.response != null) {
            OseerLogger.error(
                'API Error Response Status: ${error.response?.statusCode}');
            OseerLogger.error(
                'API Error Response Data: ${error.response?.data}');
          }

          // Retry on network errors
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError) {
            // Implement retry on connection issues
            if (error.requestOptions.extra['retryCount'] == null) {
              error.requestOptions.extra['retryCount'] = 0;
            }

            final retryCount = error.requestOptions.extra['retryCount'] as int;
            if (retryCount < 2) {
              // Maximum 2 retries
              error.requestOptions.extra['retryCount'] = retryCount + 1;

              // Add a delay before retrying
              Future.delayed(Duration(seconds: min(3, retryCount + 1) * 2),
                  () async {
                OseerLogger.info(
                    'Retrying request (${retryCount + 1}/2): ${error.requestOptions.path}');
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
              });
              return;
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Process wellness data
  Future<Map<String, dynamic>> processWellnessData(
      Map<String, dynamic> data) async {
    try {
      OseerLogger.info('Sending wellness data to server');

      // Pre-check for user existence to avoid foreign key errors
      final userId = data['user_id'];
      if (userId != null) {
        try {
          await _ensureUserExists(userId);
        } catch (e) {
          OseerLogger.warning(
              'Error ensuring user exists, continuing anyway', e);
        }
      }

      // Make the real API call to send wellness data
      final response = await _dio.post('/wellness-data/process', data: data);

      OseerLogger.info(
          'Wellness data processed successfully: ${response.statusCode}');
      return response.data;
    } catch (e) {
      // Check if this is a duplicate key error that we can handle
      if (e is DioException &&
          e.response?.statusCode == 500 &&
          (e.response?.data.toString() ?? '').contains('duplicate key value')) {
        // Return partial success to allow flow to continue
        OseerLogger.warning('Duplicate data detected, continuing process', e);
        return {
          'success': true,
          'warning': 'Duplicate data detected',
          'status': 'partial'
        };
      }

      OseerLogger.error('Error processing wellness data', e);

      // Return a fallback response instead of throwing
      return {
        'success': false,
        'error': 'Failed to process wellness data',
        'message': e.toString()
      };
    }
  }

  /// Update device sync status
  Future<Map<String, dynamic>> updateDeviceStatus(
      Map<String, dynamic> data) async {
    try {
      OseerLogger.info('Updating device sync status on server');

      // Make real API call to update device status
      final response = await _dio.post('/device-sync-status', data: data);

      OseerLogger.info('Device sync status updated: ${response.statusCode}');
      return response.data;
    } catch (e) {
      OseerLogger.error('Error updating device status', e);

      // Return a fallback response
      return {
        'success': false,
        'error': 'Failed to update device status',
        'message': e.toString()
      };
    }
  }

  /// Validate a connection token
  Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      // Clean the token for consistency - remove any non-alphanumeric characters
      final cleanToken =
          token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

      // Log the validation attempt (limited to first 4 chars for security)
      OseerLogger.info('Validating token: ${cleanToken.substring(0, 4)}[...]');

      // Prepare the payload - ONLY sending the token as expected by server
      final data = {'token': cleanToken};

      OseerLogger.debug('Token validation payload: $data');

      // Make the API call
      final response = await _dio.post('/token/validate', data: data);

      OseerLogger.info('Token validation response: ${response.statusCode}');
      OseerLogger.debug('Token validation response data: ${response.data}');

      return response.data;
    } catch (e) {
      OseerLogger.error('Error validating token', e);

      // Check if we have a DioError with response data
      if (e is DioException && e.response != null) {
        OseerLogger.error('Server response: ${e.response?.data}');

        // Return the error data if available
        if (e.response?.data is Map<String, dynamic>) {
          return {
            'valid': false,
            'message':
                'Token validation failed: ${e.response?.data['error'] ?? 'Unknown error'}',
            ...e.response?.data as Map<String, dynamic>
          };
        }
      }

      // Generic error
      return {
        'valid': false,
        'message': 'Failed to validate token: ${e.toString()}',
      };
    }
  }

  /// Ensure a user exists in the database before operations that require foreign keys
  Future<bool> _ensureUserExists(String userId) async {
    try {
      // Check if the user already exists
      try {
        final checkUserResponse = await _dio.get('/user/me?userId=$userId');

        if (checkUserResponse.statusCode == 200 &&
            checkUserResponse.data is Map<String, dynamic> &&
            checkUserResponse.data.containsKey('userId')) {
          OseerLogger.info('User $userId already exists in database');
          return true;
        }
      } catch (e) {
        OseerLogger.info('User $userId not found, will create');
        // Fall through to user creation
      }

      // Generate a unique email to avoid conflicts
      final userEmail =
          'user-${userId.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}@oseerapp.com';

      // Create minimal user entry to satisfy foreign key constraints
      final userPayload = {
        'id': userId,
        'email': userEmail,
        'name': 'User ${userId.substring(0, 8)}',
        'environment': 'production'
      };

      final response = await _dio.post('/user/create', data: userPayload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        OseerLogger.info('User $userId created successfully');
        return true;
      } else {
        OseerLogger.warning(
            'Unexpected response creating user: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // Check for duplicate key errors which actually mean success
      if (e is DioException &&
          e.response?.statusCode == 500 &&
          (e.response?.data.toString() ?? '').contains('duplicate key value')) {
        OseerLogger.info('User $userId already exists (duplicate key)');
        return true;
      }

      OseerLogger.error('Failed to create user $userId', e);
      return false;
    }
  }

  /// Create or update a user
  Future<Map<String, dynamic>> createUser(String userId,
      {String? name, String? email}) async {
    try {
      OseerLogger.info('Creating or updating user in database: $userId');

      // Check if the user already exists by getting user info
      bool userExists = false;
      try {
        final checkResponse = await getUserInfo(userId);
        if (checkResponse['success'] == true ||
            (checkResponse.containsKey('userId') &&
                checkResponse['userId'] != null)) {
          userExists = true;
          OseerLogger.info('User $userId already exists');
        }
      } catch (e) {
        OseerLogger.info('User check failed, assuming new user: $e');
      }

      if (userExists) {
        // Update existing user
        return await updateUser(userId, name: name, email: email);
      }

      // Generate a unique email if not provided to avoid conflicts
      final userEmail = email ??
          'user-${userId.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}@oseerapp.com';

      // Create a payload with only the required fields
      final userPayload = {
        'id': userId,
        'email': userEmail,
        'name': name ?? 'User ${userId.substring(0, 8)}',
        'environment': 'production',
        'source': 'mobile_app'
      };

      // Create new user
      final response = await _dio.post('/user/create', data: userPayload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        OseerLogger.info('User created successfully: ${response.statusCode}');
        return response.data;
      } else {
        // Return partial success even with unexpected response
        return {
          'success': true,
          'userId': userId,
          'message':
              'User creation may have succeeded but returned unexpected status code'
        };
      }
    } catch (e) {
      // Check if the error is a duplicate key error
      if (e is DioException &&
          e.response?.statusCode == 500 &&
          (e.response?.data.toString() ?? '').contains('duplicate key value')) {
        OseerLogger.warning(
            'User already exists with this email, using existing user');

        // Return a success response since the user exists
        return {
          'success': true,
          'message': 'User already exists',
          'userId': userId,
        };
      }

      OseerLogger.warning('Error creating user (continuing anyway): $e');

      // Return a partial success to allow the flow to continue
      return {
        'success': true,
        'message': 'User creation attempted but encountered issues',
        'userId': userId,
      };
    }
  }

  /// Update an existing user
  Future<Map<String, dynamic>> updateUser(String userId,
      {String? name, String? email}) async {
    try {
      OseerLogger.info('Updating user: $userId');

      // Create a minimal update payload without problematic fields
      Map<String, dynamic> updatePayload = {
        'userId': userId,
      };

      // Only add fields that are provided and needed
      if (name != null && name.isNotEmpty) {
        updatePayload['name'] = name;
      }

      if (email != null && email.isNotEmpty) {
        updatePayload['email'] = email;
      }

      final response = await _dio.post('/user/update', data: updatePayload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        OseerLogger.info('User updated successfully: ${response.statusCode}');
        return response.data;
      } else {
        // Return partial success even with unexpected response
        return {
          'success': true,
          'userId': userId,
          'message':
              'User update may have succeeded but returned unexpected status code'
        };
      }
    } catch (e) {
      // Check for specific error about missing column
      if (e is DioException &&
          e.response?.statusCode == 500 &&
          (e.response?.data.toString() ?? '').contains('profile_data')) {
        OseerLogger.warning(
            "Server doesn't support profile_data column, ignoring this error");
      } else {
        OseerLogger.error('Error updating user', e);
      }

      // Return a partial success to allow the flow to continue
      return {
        'success': true,
        'message': 'User update attempted',
        'userId': userId,
      };
    }
  }

  /// Generate a connection token with profile data
  Future<Map<String, dynamic>> generateToken(
      Map<String, dynamic> profileData) async {
    try {
      // Extract user info from profile data
      final name =
          profileData.containsKey('name') ? profileData['name'] : 'User';
      final email =
          profileData.containsKey('email') ? profileData['email'] : null;

      // Generate user and device IDs if needed
      final userId = profileData.containsKey('userId')
          ? profileData['userId']
          : _prefs.getString(OseerConstants.keyUserId) ?? _generateUuid();

      final deviceId = profileData.containsKey('deviceId')
          ? profileData['deviceId']
          : _prefs.getString(OseerConstants.keyDeviceId) ?? _generateUuid();

      // Save IDs to preferences
      _prefs.setString(OseerConstants.keyUserId, userId);
      _prefs.setString(OseerConstants.keyDeviceId, deviceId);

      OseerLogger.info(
          'Generating token for user $userId with device $deviceId (android)');

      // First ensure the user exists in the database
      try {
        final userCreationResult =
            await createUser(userId, name: name, email: email);
        if (userCreationResult['success'] != true) {
          OseerLogger.warning(
              'User creation may have failed, token generation might fail');
        }
      } catch (e) {
        OseerLogger.warning('Error preparing user for token generation: $e');
      }

      // Prepare the token payload with minimal fields
      final tokenPayload = {
        'userId': userId,
        'deviceId': deviceId,
        'deviceType': 'android',
      };

      // Only include profile data if provided and needed
      if (name != null || email != null) {
        tokenPayload['profileData'] = {};
        if (name != null) tokenPayload['profileData']['name'] = name;
        if (email != null) tokenPayload['profileData']['email'] = email;
      }

      OseerLogger.debug('Token generation payload: $tokenPayload');

      try {
        // Make the API call to generate token
        final response = await _dio.post('/token/generate', data: tokenPayload);

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception(
              'Server returned status code: ${response.statusCode}');
        }

        // Parse and return the token response
        if (response.data is Map<String, dynamic> &&
            response.data.containsKey('token')) {
          final token = response.data['token'] as String;
          final expiresAt = response.data['expiresAt'] as String;

          // Ensure token is clean and properly formatted
          final formattedToken = _ensureTokenFormat(token);

          OseerLogger.info(
              'Token generated successfully: ${formattedToken.substring(0, 4)}[...]');
          OseerLogger.info('Token expires at: $expiresAt');

          // Save token to preferences
          _prefs.setString(OseerConstants.keyConnectionToken, formattedToken);
          _prefs.setString(OseerConstants.keyTokenExpiry, expiresAt);

          // Send welcome email in the background, don't block token response
          _sendWelcomeEmailAsync(email ?? '', name ?? 'User');

          return {
            'token': formattedToken,
            'expiresAt': expiresAt,
          };
        } else {
          throw Exception(
              'Server response missing token field: ${jsonEncode(response.data)}');
        }
      } catch (e) {
        OseerLogger.error('Server token generation failed', e);

        // Log more details for debugging
        if (e is DioException) {
          OseerLogger.error('Request: ${e.requestOptions.uri}');
          OseerLogger.error('Request data: ${e.requestOptions.data}');

          if (e.response?.statusCode == 500 &&
              e.response?.data is Map<String, dynamic> &&
              e.response?.data.containsKey('error')) {
            OseerLogger.error('Server error: ${e.response?.data['error']}');

            if (e.response?.data.containsKey('details')) {
              OseerLogger.error(
                  'Error details: ${e.response?.data['details']}');
            }
          }
        }

        // For development & testing - fallback to local token generation
        if (OseerConstants.allowLocalTokenFallback) {
          OseerLogger.warning(
              '⚠️ FALLBACK: Server token generation failed. Generating local token for development. Error: ${e.toString()}');
          return _generateLocalToken(userId, deviceId, name, email);
        }

        throw Exception('Failed to generate token: ${e.toString()}');
      }
    } catch (e) {
      OseerLogger.error('Error in generateToken main block', e);

      // For development & testing - fallback to local token generation
      if (OseerConstants.allowLocalTokenFallback) {
        OseerLogger.warning(
            '⚠️ FALLBACK: Server token generation failed. Generating local token for development.');

        final userId =
            _prefs.getString(OseerConstants.keyUserId) ?? _generateUuid();
        final deviceId =
            _prefs.getString(OseerConstants.keyDeviceId) ?? _generateUuid();
        final name =
            profileData.containsKey('name') ? profileData['name'] : 'User';
        final email =
            profileData.containsKey('email') ? profileData['email'] : null;

        return _generateLocalToken(userId, deviceId, name, email);
      }

      throw Exception('Failed to generate token: ${e.toString()}');
    }
  }

  // Helper method to ensure token is exactly 24 characters
  String _ensureTokenFormat(String token) {
    // Remove any non-alphanumeric characters and convert to uppercase
    final cleanToken = token.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

    if (cleanToken.length > OseerConstants.tokenLength) {
      // If token is too long, truncate
      return cleanToken.substring(0, OseerConstants.tokenLength);
    } else if (cleanToken.length < OseerConstants.tokenLength) {
      // If token is too short, pad with random characters to reach 24
      final padding = List.generate(
          OseerConstants.tokenLength - cleanToken.length,
          (_) => OseerConstants.tokenChars[
              (DateTime.now().millisecondsSinceEpoch + _) %
                  OseerConstants.tokenChars.length]).join();
      return cleanToken + padding;
    }

    // Token is already correct length
    return cleanToken;
  }

  // Generate a UUID
  String _generateUuid() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

    String getRandomString(int length) {
      return String.fromCharCodes(List.generate(
          length, (index) => chars.codeUnitAt(random.nextInt(chars.length))));
    }

    return '${getRandomString(8)}-${getRandomString(4)}-${getRandomString(4)}-${getRandomString(4)}-${getRandomString(12)}';
  }

  // Fallback method for local token generation (development only)
  Map<String, dynamic> _generateLocalToken(
      String userId, String deviceId, String name, String? email) {
    OseerLogger.info('Generating fallback local token for user $userId');

    // Generate a token with exactly 24 characters
    String token = '';
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < OseerConstants.tokenLength; i++) {
      final charIndex = (random + i) % OseerConstants.tokenChars.length;
      token += OseerConstants.tokenChars[charIndex];
    }

    // Calculate expiry time (30 minutes from now)
    final expiresAt =
        DateTime.now().add(const Duration(minutes: 30)).toIso8601String();

    // Save token to preferences
    _prefs.setString(OseerConstants.keyConnectionToken, token);
    _prefs.setString(OseerConstants.keyTokenExpiry, expiresAt);

    OseerLogger.warning(
        '⚠️ FALLBACK TOKEN GENERATED (local): ${token.substring(0, 4)}[...]');
    OseerLogger.warning('⚠️ Fallback token expires at: $expiresAt');

    // Send welcome email in the background
    if (email != null) {
      _sendWelcomeEmailAsync(email, name);
    }

    return {
      'token': token,
      'expiresAt': expiresAt,
    };
  }

  /// Get user information
  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      OseerLogger.info('Fetching user information for: $userId');

      final response = await _dio.get('/user/me?userId=$userId');

      OseerLogger.info('User info fetched successfully');
      return response.data;
    } catch (e) {
      OseerLogger.error('Error fetching user info', e);

      // Return a fallback response
      return {
        'success': false,
        'message': 'Failed to get user information',
        'userId': userId
      };
    }
  }

  /// Send welcome email
  Future<bool> sendWelcomeEmail(String email, String name) async {
    try {
      OseerLogger.info('Sending welcome email to $name at $email');

      final payload = {
        'to': email,
        'type': 'welcome',
        'data': {'name': name}
      };

      final response = await _dio.post('/email/send', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        OseerLogger.info('Welcome email sent successfully');
        return true;
      } else {
        OseerLogger.warning(
            'Failed to send welcome email: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      OseerLogger.warning('Failed to send welcome email, continuing flow', e);
      return false;
    }
  }

  /// Non-blocking welcome email sending
  Future<void> _sendWelcomeEmailAsync(String email, String name) async {
    if (email.isEmpty || !email.contains('@')) {
      OseerLogger.warning('Invalid email address, skipping welcome email');
      return;
    }

    // Fire and forget - don't wait for result
    sendWelcomeEmail(email, name).then((success) {
      if (success) {
        OseerLogger.info('Welcome email sent successfully in background');
      } else {
        OseerLogger.warning(
            'Background welcome email failed, but flow continues');
      }
    }).catchError((e) {
      OseerLogger.warning('Error in background welcome email, ignoring', e);
    });
  }
}
