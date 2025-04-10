// File path: lib/models/helper_models.dart

/// Status of wellness permissions
enum HealthPermissionStatus {
  /// All requested permissions are granted
  granted,

  /// Some of the requested permissions are granted
  partiallyGranted,

  /// No permissions are granted
  denied,

  /// Wellness services are not available on the device
  unavailable,

  /// System is prompting user for permissions
  promptingUser,
}

/// Wellness authorization status
class HealthAuthStatus {
  final HealthPermissionStatus status;
  final List<String> grantedPermissions;
  final String? message;

  const HealthAuthStatus({
    required this.status,
    required this.grantedPermissions,
    this.message,
  });

  @override
  String toString() {
    return 'HealthAuthStatus{status: $status, grantedPermissions: $grantedPermissions, message: $message}';
  }
}

/// Device information
class DeviceInfo {
  final String model;
  final String systemVersion;
  final String name;
  final String identifier;

  DeviceInfo({
    required this.model,
    required this.systemVersion,
    required this.name,
    required this.identifier,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'system_version': systemVersion,
      'name': name,
      'identifier': identifier,
    };
  }

  @override
  String toString() {
    return 'DeviceInfo{model: $model, systemVersion: $systemVersion, name: $name, identifier: $identifier}';
  }
}

/// Activity information
class Activity {
  final String type;
  final double duration;
  final double intensity;
  final DateTime timestamp;
  final double? calories;
  final double? heartRateAvg;
  final double? heartRateMax;

  Activity({
    required this.type,
    required this.duration,
    required this.intensity,
    required this.timestamp,
    this.calories,
    this.heartRateAvg,
    this.heartRateMax,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'duration': duration,
      'intensity': intensity,
      'timestamp': timestamp.toIso8601String(),
      if (calories != null) 'calories': calories,
      if (heartRateAvg != null) 'heart_rate_avg': heartRateAvg,
      if (heartRateMax != null) 'heart_rate_max': heartRateMax,
    };
  }

  @override
  String toString() {
    return 'Activity{type: $type, duration: $duration, intensity: $intensity, timestamp: $timestamp, calories: $calories, heartRateAvg: $heartRateAvg, heartRateMax: $heartRateMax}';
  }
}

/// Sync status for wellness data operations
enum SyncStatus { initial, syncing, success, failure }

/// Wellness request status for tracking async operations
enum RequestStatus { initial, loading, success, failure }
