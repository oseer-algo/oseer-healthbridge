// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, Logger;

import '../models/helper_models.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

enum ApiExceptionType {
  networkError,
  timeout,
  unauthorized,
  serverError,
  validationError,
  notFound,
  parsingError,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final ApiExceptionType type;
  final String? details;

  ApiException({
    required this.statusCode,
    required this.message,
    required this.type,
    this.details,
  });

  @override
  String toString() =>
      'ApiException($statusCode, $type): $message ${details ?? ''}';
}

class ApiService {
  final SharedPreferences _prefs;
  final http.Client _client = http.Client();
  final String baseUrl;
  final String _supabaseFunctionsUrl =
      'https://oxvhffqnenhtyypzpcam.supabase.co/functions/v1';

  static const Duration dnsResolveTimeout = Duration(seconds: 5);
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);

  final Map<String, DateTime> _lastSuccessfulConnections = {};
  static const Duration _dnsSuccessCacheDuration = Duration(minutes: 1);

  // Circuit breaker for orchestration
  int _orchestrationFailures = 0;
  DateTime? _orchestrationLastFailure;
  static const int _orchestrationMaxFailures = 3;
  static const Duration _orchestrationCooldown = Duration(minutes: 5);

  // Circuit breaker for health data batch
  int _healthDataFailures = 0;
  DateTime? _healthDataLastFailure;
  static const int _healthDataMaxFailures = 5;
  static const Duration _healthDataCooldown = Duration(minutes: 10);

  ApiService(this._prefs, {String? customBaseUrl})
      : baseUrl = customBaseUrl ?? OseerConstants.apiBaseUrl {
    resumeFailedBatches();
  }

  Future<void> resumeFailedBatches() async {
    OseerLogger.info('Checking for failed batches to resume...');

    final tables = ['raw_health_data_staging', 'raw_activities_staging'];
    for (final table in tables) {
      final failedBatchKey = 'failed_batch_$table';
      final failedData = _prefs.getString(failedBatchKey);

      if (failedData != null) {
        try {
          OseerLogger.info(
              'Found failed batch for $table, attempting to resend...');
          final batchData = jsonDecode(failedData) as List<dynamic>;
          final typedBatch = batchData
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final success = await sendHealthDataBatch(typedBatch, table);
          if (success) {
            await _prefs.remove(failedBatchKey);
            OseerLogger.info('Successfully resumed failed batch for $table');
          }
        } catch (e) {
          OseerLogger.error('Error resuming failed batch for $table', e);
        }
      }
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int retryCount = _maxRetries,
    String operationName = 'API request',
    bool useExponentialBackoff = true,
  }) async {
    int attempts = 0;
    late dynamic lastError;

    while (attempts < retryCount) {
      try {
        return await operation();
      } on ApiException catch (e) {
        // Don't retry on auth errors or client errors
        if (e.statusCode == 401 ||
            e.statusCode == 403 ||
            e.statusCode == 404 ||
            e.statusCode >= 400 && e.statusCode < 500) {
          OseerLogger.error('Non-retriable error in $operationName', e);
          rethrow;
        }

        lastError = e;
        attempts++;

        if (attempts < retryCount) {
          final delay = useExponentialBackoff
              ? _baseRetryDelay * (1 << (attempts - 1))
              : _baseRetryDelay;
          OseerLogger.warning(
              'Retry $attempts/$retryCount for $operationName in ${delay.inSeconds}s',
              e);
          await Future.delayed(delay);
        }
      } catch (e, s) {
        lastError = e;
        attempts++;

        if (attempts < retryCount) {
          final delay = useExponentialBackoff
              ? _baseRetryDelay * (1 << (attempts - 1))
              : _baseRetryDelay;
          OseerLogger.warning(
              'Unexpected error on attempt $attempts for $operationName. Retrying in ${delay.inSeconds}s',
              e,
              s);
          await Future.delayed(delay);
        }
      }
    }

    OseerLogger.error(
        'Request failed after $retryCount attempts for $operationName',
        lastError);
    throw lastError;
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final supabase = Supabase.instance.client;
    final currentSession = supabase.auth.currentSession;

    if (currentSession == null) {
      OseerLogger.error('No active session', null, StackTrace.current);
      throw ApiException(
        statusCode: 401,
        message: 'No active session. Please log in again.',
        type: ApiExceptionType.unauthorized,
      );
    }

    OseerLogger.debug('Auth Headers constructed with a valid session token.');
    return {
      'Authorization': 'Bearer ${currentSession.accessToken}',
      'apikey': OseerConstants.supabaseAnonKey,
    };
  }

  Future<http.Response> _makeHttpRequest(String method, String url,
      {Map<String, String>? headers, dynamic body, Duration? timeout}) async {
    try {
      final uri = Uri.parse(url);
      final baseHeaders = await _getAuthHeaders();
      final requestHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...baseHeaders,
        ...?headers
      };
      final requestBody = body != null ? json.encode(body) : null;
      final requestTimeout = timeout ?? _defaultTimeout;

      OseerLogger.network(method, uri.toString(),
          requestBody?.substring(0, min(500, requestBody.length ?? 0)));

      switch (method) {
        case 'POST':
          return await _client
              .post(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout, onTimeout: () {
            throw TimeoutException(
                'Request timed out after ${requestTimeout.inSeconds}s');
          });
        case 'GET':
          return await _client
              .get(uri, headers: requestHeaders)
              .timeout(requestTimeout, onTimeout: () {
            throw TimeoutException(
                'Request timed out after ${requestTimeout.inSeconds}s');
          });
        case 'PUT':
          return await _client
              .put(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout, onTimeout: () {
            throw TimeoutException(
                'Request timed out after ${requestTimeout.inSeconds}s');
          });
        case 'DELETE':
          return await _client
              .delete(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout, onTimeout: () {
            throw TimeoutException(
                'Request timed out after ${requestTimeout.inSeconds}s');
          });
        case 'PATCH':
          return await _client
              .patch(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout, onTimeout: () {
            throw TimeoutException(
                'Request timed out after ${requestTimeout.inSeconds}s');
          });
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on SocketException catch (e, s) {
      OseerLogger.error('Network error on $method $url', e, s);
      throw ApiException(
          statusCode: 0,
          message: "Network connection error. Please check your connection.",
          type: ApiExceptionType.networkError,
          details: e.message);
    } on TimeoutException catch (e, s) {
      OseerLogger.error('Timeout on $method $url', e, s);
      throw ApiException(
          statusCode: 408,
          message: 'Request timed out. Please try again.',
          type: ApiExceptionType.timeout);
    } on HttpException catch (e, s) {
      OseerLogger.error('HTTP error on $method $url', e, s);
      throw ApiException(
          statusCode: 0,
          message: 'HTTP error occurred',
          type: ApiExceptionType.networkError,
          details: e.message);
    } on FormatException catch (e, s) {
      OseerLogger.error('Format error on $method $url', e, s);
      throw ApiException(
          statusCode: 0,
          message: 'Invalid response format',
          type: ApiExceptionType.parsingError,
          details: e.message);
    }
  }

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? headers,
      Map<String, dynamic>? queryParams,
      Duration? timeout}) async {
    final Map<String, String> stringQueryParams = queryParams?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        {};
    final Uri uri = Uri.parse(baseUrl + endpoint).replace(
        queryParameters: stringQueryParams.isEmpty ? null : stringQueryParams);
    final response = await _makeHttpRequest('GET', uri.toString(),
        headers: headers, timeout: timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, dynamic data,
      {Map<String, String>? headers, Duration? timeout}) async {
    final response = await _makeHttpRequest('POST', baseUrl + endpoint,
        body: data, headers: headers, timeout: timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, dynamic data,
      {Map<String, String>? headers, Duration? timeout}) async {
    final response = await _makeHttpRequest('PUT', baseUrl + endpoint,
        body: data, headers: headers, timeout: timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint,
      {Map<String, String>? headers, Duration? timeout}) async {
    final response = await _makeHttpRequest('DELETE', baseUrl + endpoint,
        headers: headers, timeout: timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String endpoint, dynamic data,
      {Map<String, String>? headers, Duration? timeout}) async {
    final response = await _makeHttpRequest('PATCH', baseUrl + endpoint,
        body: data, headers: headers, timeout: timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getWithRetry(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    int retryCount = _maxRetries,
  }) async {
    return _withRetry(
      () => get(endpoint,
          headers: headers, queryParams: queryParams, timeout: timeout),
      retryCount: retryCount,
      operationName: 'GET $endpoint',
    );
  }

  Future<Map<String, dynamic>> postWithRetry(
    String endpoint,
    dynamic data, {
    Map<String, String>? headers,
    Duration? timeout,
    int retryCount = _maxRetries,
  }) async {
    return _withRetry(
      () => post(endpoint, data, headers: headers, timeout: timeout),
      retryCount: retryCount,
      operationName: 'POST $endpoint',
    );
  }

  Future<Map<String, dynamic>> putWithRetry(
    String endpoint,
    dynamic data, {
    Map<String, String>? headers,
    Duration? timeout,
    int retryCount = _maxRetries,
  }) async {
    return _withRetry(
      () => put(endpoint, data, headers: headers, timeout: timeout),
      retryCount: retryCount,
      operationName: 'PUT $endpoint',
    );
  }

  Future<Map<String, dynamic>> invokeFunction(String functionName, dynamic data,
      {Map<String, String>? headers, Duration? timeout}) async {
    try {
      // Try Supabase SDK first
      try {
        final supabase = Supabase.instance.client;
        final currentSession = supabase.auth.currentSession;

        if (currentSession != null) {
          OseerLogger.debug('Invoking Edge Function via SDK: $functionName');

          final functionTimeout = timeout ?? const Duration(seconds: 60);

          final response = await supabase.functions
              .invoke(
            functionName,
            body: data,
            headers: headers,
          )
              .timeout(functionTimeout, onTimeout: () {
            throw TimeoutException(
                'Edge function timed out after ${functionTimeout.inSeconds}s');
          });

          OseerLogger.debug(
              'Edge Function response status: ${response.status}');

          if (response.data != null) {
            if (response.data is Map) {
              return Map<String, dynamic>.from(response.data as Map);
            } else {
              return {
                'data': response.data,
                'success': response.status >= 200 && response.status < 300
              };
            }
          }
          return {'success': response.status >= 200 && response.status < 300};
        }
      } catch (supabaseError) {
        if (supabaseError is TimeoutException) {
          throw ApiException(
            statusCode: 408,
            message: 'Edge function request timed out',
            type: ApiExceptionType.timeout,
          );
        }
        OseerLogger.warning(
            'SDK invocation failed, falling back to HTTP: $supabaseError');
      }

      // Fallback to HTTP request
      final response = await _makeHttpRequest(
          'POST', '$_supabaseFunctionsUrl/$functionName',
          body: data,
          headers: headers,
          timeout: timeout ?? const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      OseerLogger.error('Error invoking Edge function $functionName', e);
      throw _mapException(e);
    }
  }

  Future<bool> sendHealthDataBatch(
    List<Map<String, dynamic>> batchData,
    String targetTable,
  ) async {
    if (batchData.isEmpty) {
      OseerLogger.warning('Empty batch provided to sendHealthDataBatch');
      return true;
    }

    // Check circuit breaker for health data
    if (_healthDataFailures >= _healthDataMaxFailures) {
      final timeSinceLastFailure =
          DateTime.now().difference(_healthDataLastFailure ?? DateTime.now());
      if (timeSinceLastFailure < _healthDataCooldown) {
        OseerLogger.warning(
            'Health data circuit breaker active. Cooldown remaining: ${_healthDataCooldown - timeSinceLastFailure}');
        return false;
      }
      // Reset circuit breaker after cooldown
      _healthDataFailures = 0;
    }

    OseerLogger.health(
      'send',
      'Sending ${batchData.length} records to $targetTable',
      true,
    );

    // Generate minute-granular idempotency key
    final userId = _prefs.getString(OseerConstants.keyUserId) ?? 'unknown';
    final now = DateTime.now();
    final minuteTimestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final idempotencyKey = '${userId}_${targetTable}_$minuteTimestamp';

    final payload = {
      'targetTable': targetTable,
      'records': batchData,
      'idempotencyKey': idempotencyKey,
    };

    try {
      await _withRetry(
        () => invokeFunction('process-health-data', payload,
            timeout: const Duration(seconds: 45)),
        retryCount: 3,
        operationName: 'sendHealthDataBatch',
      );
      OseerLogger.info(
          '✅ Successfully sent batch of ${batchData.length} records with idempotency key: $idempotencyKey');
      _healthDataFailures = 0; // Reset on success
      return true;
    } on ApiException catch (e) {
      _healthDataFailures++;
      _healthDataLastFailure = DateTime.now();

      // Save failed batch for later retry on network errors
      if (e.type == ApiExceptionType.networkError ||
          e.type == ApiExceptionType.timeout) {
        final failedBatchKey = 'failed_batch_$targetTable';
        await _prefs.setString(failedBatchKey, jsonEncode(batchData));
        OseerLogger.warning(
            'Saved failed batch for $targetTable to retry later');
      }
      return false;
    } catch (e, s) {
      _healthDataFailures++;
      _healthDataLastFailure = DateTime.now();
      OseerLogger.error('Unexpected error in sendHealthDataBatch', e, s);
      return false;
    }
  }

  Future<bool> triggerSyncOrchestration(String syncType) async {
    // Check circuit breaker
    if (_orchestrationFailures >= _orchestrationMaxFailures) {
      final timeSinceLastFailure = DateTime.now()
          .difference(_orchestrationLastFailure ?? DateTime.now());
      if (timeSinceLastFailure < _orchestrationCooldown) {
        OseerLogger.warning(
            'Orchestration circuit breaker active. Cooldown remaining: ${_orchestrationCooldown - timeSinceLastFailure}');
        return false;
      }
      // Reset circuit breaker after cooldown
      _orchestrationFailures = 0;
    }

    OseerLogger.info('Triggering sync orchestration for type: $syncType');
    try {
      // Retrieve the deviceId from shared preferences
      final deviceId = _prefs.getString(OseerConstants.keyDeviceId);
      final headers = <String, String>{};
      if (deviceId != null) {
        // Add the deviceId to the request headers
        headers['x-device-id'] = deviceId;
      }

      final response = await _withRetry(
        () => invokeFunction('orchestrate-sync', {'syncType': syncType},
            headers: headers, timeout: const Duration(seconds: 45)),
        retryCount: 3,
        operationName: 'triggerSyncOrchestration',
      );

      if (response['success'] == true) {
        OseerLogger.info(
            '✅ Successfully triggered orchestration for $syncType');
        _orchestrationFailures = 0; // Reset on success
        return true;
      }

      OseerLogger.error('Orchestration failed: ${response['error']}');
      _orchestrationFailures++;
      _orchestrationLastFailure = DateTime.now();
      return false;
    } catch (e, s) {
      OseerLogger.error('Exception triggering sync orchestration', e, s);
      _orchestrationFailures++;
      _orchestrationLastFailure = DateTime.now();
      return false;
    }
  }

  Future<void> notifyChunkComplete({
    required int chunkIndex,
    required int totalChunks,
    required String userId,
    required String deviceId,
    Map<String, dynamic>? syncState,
  }) async {
    OseerLogger.info('Notifying backend of chunk $chunkIndex completion');

    try {
      final response = await invokeFunction(
          'notify-chunk-complete',
          {
            'chunkIndex': chunkIndex,
            'totalChunks': totalChunks,
            'userId': userId,
            'deviceId': deviceId,
            'syncState': syncState,
          },
          timeout: const Duration(seconds: 20));

      if (response['success'] == true) {
        OseerLogger.info('✅ Backend acknowledged chunk $chunkIndex');
        if (response['isComplete'] == true) {
          OseerLogger.info(
              '🎉 All chunks complete - Digital Twin processing started');
        }
      } else {
        OseerLogger.warning(
            'Backend failed to process chunk notification: ${response['error']}');
      }
    } catch (e) {
      OseerLogger.error('Failed to notify chunk completion', e);
      // Non-critical error - continue with next chunk
    }
  }

  Future<void> sendHeartbeat() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final deviceId = _prefs.getString(OseerConstants.keyDeviceId);

    if (userId == null || deviceId == null || deviceId.isEmpty) {
      OseerLogger.debug('Heartbeat: Missing userId or deviceId');
      return;
    }

    try {
      OseerLogger.debug('Sending heartbeat for device $deviceId');

      final payload = {
        'userId': userId,
        'deviceId': deviceId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'appVersion': OseerConstants.appVersion,
        'platform': Platform.isIOS ? 'ios' : 'android',
      };

      await putWithRetry(
        OseerConstants.endpointDeviceHeartbeat,
        payload,
        timeout: const Duration(seconds: 10),
        retryCount: 1,
      );

      OseerLogger.debug('Heartbeat sent successfully');
    } catch (e) {
      OseerLogger.warning('Failed to send heartbeat: $e');
    }
  }

  Future<bool> registerDevice(Map<String, dynamic> deviceDetails) async {
    const endpoint = '/device/connect';
    OseerLogger.info('📱 Registering device with backend...');
    try {
      final response = await postWithRetry(endpoint, deviceDetails,
          retryCount: 2, timeout: const Duration(seconds: 20));
      if (response['success'] == true) {
        OseerLogger.info('✅ Device successfully registered');
        return true;
      } else {
        OseerLogger.error('Failed to register device: ${response['error']}');
        return false;
      }
    } catch (e, s) {
      OseerLogger.error('❌ Exception during device registration', e, s);
      return false;
    }
  }

  Future<Map<String, dynamic>> generateWebAuthToken({
    required String userId,
    required String purpose,
    Duration validity = const Duration(minutes: 5),
  }) async {
    OseerLogger.info('Generating web auth token for purpose: $purpose');

    try {
      final deviceId = _prefs.getString(OseerConstants.keyDeviceId);
      final now = DateTime.now();
      final expiresAt = now.add(validity);

      final payload = {
        'userId': userId,
        'user_id': userId,
        'deviceId': deviceId,
        'device_id': deviceId,
        'purpose': purpose,
        'issuedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'source': 'mobile_app',
        'appVersion': OseerConstants.appVersion,
      };

      final response = await postWithRetry(
        '/auth/generate-web-token',
        payload,
        timeout: const Duration(seconds: 10),
      );

      if (response['success'] == true && response['token'] != null) {
        OseerLogger.info('Web auth token generated successfully');
        return {
          'success': true,
          'token': response['token'],
          'expiresAt': expiresAt.toIso8601String(),
          'dashboardUrl': response['dashboardUrl'],
        };
      } else {
        throw ApiException(
          statusCode: 500,
          message: response['error'] ?? 'Failed to generate auth token',
          type: ApiExceptionType.serverError,
        );
      }
    } catch (e) {
      OseerLogger.error('Failed to generate web auth token', e);
      rethrow;
    }
  }

  Future<String?> generateHandoffToken({
    required String deviceId,
    required String purpose,
  }) async {
    const endpoint = '/auth/generate-mobile-handoff';
    OseerLogger.info('Requesting handoff token for purpose: $purpose');

    try {
      if (deviceId.isEmpty) {
        OseerLogger.error('Cannot generate handoff token: empty deviceId');
        return null;
      }

      final payload = <String, dynamic>{
        'deviceId': deviceId,
        'purpose': purpose,
      };

      if (purpose == 'login') {
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession == null || currentSession.refreshToken == null) {
          OseerLogger.error('Cannot generate login token: No active session');
          throw ApiException(
            statusCode: 401,
            message: "User is not logged in",
            type: ApiExceptionType.unauthorized,
          );
        }

        payload['session'] = {
          'access_token': currentSession.accessToken,
          'refresh_token': currentSession.refreshToken,
        };
        OseerLogger.info("Attaching full session object for 'login' handoff.");
      }

      final response = await postWithRetry(endpoint, payload,
          timeout: const Duration(seconds: 15));

      if (response['success'] == true && response['handoff_token'] is String) {
        OseerLogger.info('Successfully received handoff token');
        return response['handoff_token'] as String;
      } else {
        final serverError = response['error'] ?? 'No token returned';
        OseerLogger.error('Failed to get handoff token: $serverError');
        throw ApiException(
          statusCode: response['statusCode'] ?? 500,
          message: serverError,
          type: ApiExceptionType.serverError,
        );
      }
    } catch (e, s) {
      OseerLogger.error('Exception generating handoff token', e, s);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getConnectionTokenAfterHandoff() async {
    const endpoint = '/device/get-connection-token';
    OseerLogger.info('Fetching connection token after handoff from: $endpoint');

    try {
      final response = await getWithRetry(
        endpoint,
        timeout: const Duration(seconds: 10),
      );

      if (response['success'] == true && response['connection_token'] != null) {
        OseerLogger.info('Successfully retrieved connection token from server');
        return {
          'success': true,
          'connection_token': response['connection_token'],
        };
      } else {
        final error = response['error'] ?? 'No connection token found';
        OseerLogger.error('Failed to get connection token: $error');
        return {
          'success': false,
          'error': error,
        };
      }
    } catch (e, s) {
      OseerLogger.error('Exception while fetching connection token', e, s);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> validateWellnessSession(
      String sessionToken) async {
    OseerLogger.info('Validating wellness session token');

    try {
      final response = await postWithRetry(
        '/auth/validate-session',
        {'sessionToken': sessionToken},
        timeout: const Duration(seconds: 10),
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'userId': response['userId'],
          'purpose': response['purpose'],
          'valid': response['valid'] ?? true,
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Invalid session',
        };
      }
    } catch (e) {
      OseerLogger.error('Failed to validate wellness session', e);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getUserStatus() async {
    OseerLogger.info('Querying server for user session status...');
    return getWithRetry('/user/status', timeout: const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    return postWithRetry(OseerConstants.endpointUserCreate, userData,
        timeout: const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> updateUser(
      String userId, Map<String, dynamic> userData) async {
    try {
      OseerLogger.debug('Updating user $userId');

      final Map<String, dynamic> payload = {...userData};
      final logSafePayload = Map<String, dynamic>.from(payload);
      if (logSafePayload.containsKey('password')) {
        logSafePayload['password'] = '*****';
      }
      OseerLogger.debug('Update payload: ${json.encode(logSafePayload)}');

      final response = await postWithRetry(
          OseerConstants.endpointUserUpdate, payload,
          timeout: const Duration(seconds: 15));
      OseerLogger.debug('User update response: ${json.encode(response)}');
      return response;
    } catch (e, stack) {
      OseerLogger.error('Error updating user $userId:', e, stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return getWithRetry(OseerConstants.endpointUserMe,
        timeout: const Duration(seconds: 10));
  }

  Future<void> logEventToDatabase(String eventType, String? userIdOverride,
      Map<String, dynamic> metadata) async {
    final userId = userIdOverride ?? _prefs.getString(OseerConstants.keyUserId);

    if (eventType.isEmpty) {
      OseerLogger.warning('Cannot log event: Empty eventType');
      return;
    }

    final Map<String, dynamic> sanitizedMetadata = {};
    metadata.forEach((key, value) {
      sanitizedMetadata[key.toString()] = value;
    });

    final Map<String, dynamic> body = {
      'event_type': eventType,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'environment': OseerConstants.environment,
      'details': sanitizedMetadata,
    };

    if (userId != null && userId.isNotEmpty) {
      body['user_id'] = userId;
    }

    try {
      final response = await postWithRetry(
          OseerConstants.endpointEventLog, body,
          timeout: const Duration(seconds: 8), retryCount: 1);

      if (response['success'] == true) {
        OseerLogger.debug('Event logged: $eventType');
      } else {
        OseerLogger.warning('Event logging failed: ${response['error']}');
      }
    } catch (e) {
      OseerLogger.error("Failed to log event '$eventType'", e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final hasBody = response.body.isNotEmpty;

    Map<String, dynamic> responseBody = {};
    if (hasBody) {
      try {
        responseBody = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        OseerLogger.error('Error parsing response body', e);
        throw ApiException(
          statusCode: statusCode,
          message: 'Invalid response format from server',
          type: ApiExceptionType.parsingError,
        );
      }
    }

    OseerLogger.apiResponse(
      response.request?.url.toString() ?? 'unknown URL',
      statusCode,
      responseBody,
    );

    if (statusCode >= 200 && statusCode < 300) {
      if (!responseBody.containsKey('success')) {
        responseBody['success'] = true;
      }
      return responseBody;
    } else {
      final errorMessage = responseBody['error'] as String? ??
          responseBody['message'] as String? ??
          _getHttpStatusMessage(statusCode);

      // Handle both String and Map details to prevent the crash
      String? errorDetails;
      if (responseBody['details'] is String) {
        errorDetails = responseBody['details'] as String?;
      } else if (responseBody['details'] is Map) {
        // If it's a map (like a validation error), serialize it to a string
        errorDetails = json.encode(responseBody['details']);
      }

      final exceptionType = _determineExceptionType(statusCode);
      throw ApiException(
        statusCode: statusCode,
        message: errorMessage,
        details: errorDetails,
        type: exceptionType,
      );
    }
  }

  String _getHttpStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Authentication required';
      case 403:
        return 'Access forbidden';
      case 404:
        return 'Resource not found';
      case 408:
        return 'Request timed out';
      case 409:
        return 'Conflict with current state';
      case 422:
        return 'Validation error';
      case 429:
        return 'Too many requests';
      case 500:
        return 'Server error';
      case 502:
        return 'Bad gateway';
      case 503:
        return 'Service unavailable';
      case 504:
        return 'Gateway timeout';
      default:
        return 'Server error ($statusCode)';
    }
  }

  ApiExceptionType _determineExceptionType(int statusCode) {
    if (statusCode == 408) return ApiExceptionType.timeout;
    if (statusCode == 401 || statusCode == 403)
      return ApiExceptionType.unauthorized;
    if (statusCode == 404) return ApiExceptionType.notFound;
    if (statusCode == 422) return ApiExceptionType.validationError;
    if (statusCode >= 500) return ApiExceptionType.serverError;
    return ApiExceptionType.unknown;
  }

  ApiException _mapException(dynamic exception) {
    if (exception is ApiException) {
      return exception;
    }

    if (exception is SocketException) {
      return ApiException(
        statusCode: 0,
        message: 'Network connection error. Please check your connection.',
        type: ApiExceptionType.networkError,
        details: exception.message,
      );
    }

    if (exception is TimeoutException) {
      return ApiException(
        statusCode: 408,
        message: 'Request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    }

    if (exception is HttpException) {
      return ApiException(
        statusCode: 0,
        message: 'HTTP error occurred',
        type: ApiExceptionType.networkError,
        details: exception.message,
      );
    }

    if (exception is FormatException) {
      return ApiException(
        statusCode: 0,
        message: 'Invalid data format received from server.',
        type: ApiExceptionType.parsingError,
        details: exception.message,
      );
    }

    return ApiException(
      statusCode: 500,
      message: 'An unexpected error occurred',
      type: ApiExceptionType.unknown,
      details: exception.toString(),
    );
  }

  void dispose() {
    _client.close();
  }
}
