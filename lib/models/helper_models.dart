// lib/models/helper_models.dart

import 'package:equatable/equatable.dart';

/// Basic sync status for simple operations
enum SyncStatus {
  idle,
  starting,
  inProgress,
  success,
  failure,
  cancelled,
}

/// Request status for async operations
enum RequestStatus {
  idle,
  loading,
  success,
  error,
}

/// Health permission status
enum HealthPermissionStatus {
  initial,
  notRequested,
  granted,
  partiallyGranted,
  denied,
  unavailable,
  error,
}

/// Connection status for the app
enum ConnectionStatus {
  initial,
  needsToken,
  tokenGenerated,
  connecting,
  connected,
  disconnecting,
  disconnected,
  error,
}

/// API exception types for error handling
enum ApiExceptionType {
  networkError,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  serverError,
  validationError,
  parsingError,
  methodNotAllowed,
  payloadTooLarge,
  rateLimit,
  unknown,
}

/// Enum for different types of health data sync operations
enum SyncType {
  priority, // Quick sync for initial body prep assessment (minimal data types)
  historical // Full sync for comprehensive historical data
}

/// Status update for user connections
class ConnectionStatusUpdate extends Equatable {
  final bool isConnected;
  final bool previouslyConnected;
  final DateTime timestamp;
  final String? reason;

  const ConnectionStatusUpdate({
    required this.isConnected,
    this.previouslyConnected = false,
    required this.timestamp,
    this.reason,
  });

  @override
  List<Object?> get props =>
      [isConnected, previouslyConnected, timestamp, reason];
}

/// Health authentication status with basic permissions
class HealthAuthStatus extends Equatable {
  final HealthPermissionStatus status;
  final List<String> grantedPermissions;
  final List<String> deniedPermissions;
  final String? message;
  final DateTime? lastChecked;

  const HealthAuthStatus({
    required this.status,
    this.grantedPermissions = const [],
    this.deniedPermissions = const [],
    this.message,
    this.lastChecked,
  });

  /// Whether all critical permissions are granted
  bool get hasCriticalPermissions {
    const criticalPerms = ['weight', 'height', 'steps', 'sleep_asleep'];
    return criticalPerms.every((perm) => grantedPermissions.contains(perm));
  }

  /// Whether ready for sync
  bool get isReadyForSync {
    return status == HealthPermissionStatus.granted ||
        (status == HealthPermissionStatus.partiallyGranted &&
            hasCriticalPermissions);
  }

  @override
  List<Object?> get props => [
        status,
        grantedPermissions,
        deniedPermissions,
        message,
        lastChecked,
      ];

  HealthAuthStatus copyWith({
    HealthPermissionStatus? status,
    List<String>? grantedPermissions,
    List<String>? deniedPermissions,
    String? message,
    DateTime? lastChecked,
  }) {
    return HealthAuthStatus(
      status: status ?? this.status,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
      deniedPermissions: deniedPermissions ?? this.deniedPermissions,
      message: message ?? this.message,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'grantedPermissions': grantedPermissions,
      'deniedPermissions': deniedPermissions,
      'message': message,
      'lastChecked': lastChecked?.toIso8601String(),
    };
  }

  factory HealthAuthStatus.fromJson(Map<String, dynamic> json) {
    return HealthAuthStatus(
      status: HealthPermissionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => HealthPermissionStatus.notRequested,
      ),
      grantedPermissions: List<String>.from(json['grantedPermissions'] ?? []),
      deniedPermissions: List<String>.from(json['deniedPermissions'] ?? []),
      message: json['message'],
      lastChecked: json['lastChecked'] != null
          ? DateTime.parse(json['lastChecked'])
          : null,
    );
  }
}

/// Simple API Exception for error handling
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? details;
  final String? errorCode;
  final ApiExceptionType type;
  final String? rawResponse;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
    this.errorCode,
    required this.type,
    this.rawResponse,
  });

  /// User-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case ApiExceptionType.networkError:
        return 'Please check your internet connection and try again.';
      case ApiExceptionType.timeout:
        return 'Request timed out. Please try again.';
      case ApiExceptionType.unauthorized:
        return 'Authentication required. Please log in again.';
      case ApiExceptionType.forbidden:
        return 'Access denied. Please check your permissions.';
      case ApiExceptionType.notFound:
        return 'Requested resource not found.';
      case ApiExceptionType.serverError:
        return 'Server error. Please try again later.';
      case ApiExceptionType.validationError:
        return details ?? message;
      case ApiExceptionType.parsingError:
        return 'Invalid response format from server.';
      case ApiExceptionType.methodNotAllowed:
        return 'Operation not allowed.';
      case ApiExceptionType.payloadTooLarge:
        return 'Request data is too large.';
      case ApiExceptionType.rateLimit:
        return 'Too many requests. Please try again later.';
      default:
        return message;
    }
  }

  /// Whether this error is retryable
  bool get isRetryable {
    return type == ApiExceptionType.networkError ||
        type == ApiExceptionType.timeout ||
        type == ApiExceptionType.serverError;
  }

  @override
  String toString() {
    return 'ApiException($statusCode): $message${details != null ? ' - $details' : ''}';
  }
}

/// Simple result wrapper for operations
class Result<T> extends Equatable {
  final bool isSuccess;
  final T? data;
  final String? error;
  final ApiException? exception;

  const Result._({
    required this.isSuccess,
    this.data,
    this.error,
    this.exception,
  });

  factory Result.success(T data) {
    return Result._(isSuccess: true, data: data);
  }

  factory Result.failure(String error, {ApiException? exception}) {
    return Result._(isSuccess: false, error: error, exception: exception);
  }

  /// Whether the result is a failure
  bool get isFailure => !isSuccess;

  /// Get data or throw if failed
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw exception ?? Exception(error ?? 'Operation failed');
  }

  /// Get data or return default
  T getDataOr(T defaultValue) {
    return isSuccess && data != null ? data! : defaultValue;
  }

  @override
  List<Object?> get props => [isSuccess, data, error, exception];
}

/// Token validation result
class TokenValidationResult extends Equatable {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;
  final DateTime? validatedAt;
  final bool isExpired;
  final bool wasConsumed;

  const TokenValidationResult({
    required this.success,
    this.error,
    this.data,
    this.validatedAt,
    this.isExpired = false,
    this.wasConsumed = false,
  });

  factory TokenValidationResult.success({
    Map<String, dynamic>? data,
    bool wasConsumed = false,
  }) {
    return TokenValidationResult(
      success: true,
      data: data,
      validatedAt: DateTime.now(),
      wasConsumed: wasConsumed,
    );
  }

  factory TokenValidationResult.failure(
    String error, {
    bool isExpired = false,
    Map<String, dynamic>? data,
  }) {
    return TokenValidationResult(
      success: false,
      error: error,
      isExpired: isExpired,
      data: data,
    );
  }

  @override
  List<Object?> get props => [
        success,
        error,
        data,
        validatedAt,
        isExpired,
        wasConsumed,
      ];
}
