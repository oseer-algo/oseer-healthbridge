// lib/models/connection_persistence.dart

import 'package:equatable/equatable.dart';

/// Simple connection persistence state for basic connection tracking
class ConnectionPersistenceState extends Equatable {
  final String? connectionId;
  final String? token;
  final String? deviceId;
  final String? userId;
  final DateTime? lastSyncTime;
  final bool isConnected;
  final Map<String, dynamic> metadata;

  const ConnectionPersistenceState({
    this.connectionId,
    this.token,
    this.deviceId,
    this.userId,
    this.lastSyncTime,
    this.isConnected = false,
    this.metadata = const {},
  });

  factory ConnectionPersistenceState.initial() {
    return const ConnectionPersistenceState();
  }

  ConnectionPersistenceState copyWith({
    String? connectionId,
    String? token,
    String? deviceId,
    String? userId,
    DateTime? lastSyncTime,
    bool? isConnected,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionPersistenceState(
      connectionId: connectionId ?? this.connectionId,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isConnected: isConnected ?? this.isConnected,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        connectionId,
        token,
        deviceId,
        userId,
        lastSyncTime,
        isConnected,
        metadata,
      ];

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'token': token,
      'deviceId': deviceId,
      'userId': userId,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'isConnected': isConnected,
      'metadata': metadata,
    };
  }

  factory ConnectionPersistenceState.fromJson(Map<String, dynamic> json) {
    return ConnectionPersistenceState(
      connectionId: json['connectionId'],
      token: json['token'],
      deviceId: json['deviceId'],
      userId: json['userId'],
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'])
          : null,
      isConnected: json['isConnected'] ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Status of connection persistence
enum ConnectionPersistenceStatus {
  /// Connection is active and healthy
  active,

  /// Connection exists but hasn't been validated recently
  stale,

  /// Connection token has expired
  expired,

  /// Connection is being recovered
  recovering,

  /// Connection failed and needs to be re-established
  failed,

  /// No connection exists
  none,
}

/// Health status of a persistent connection
enum ConnectionHealth {
  /// Connection is healthy (recent successful validation)
  healthy,

  /// Connection has some issues but is still functional
  degraded,

  /// Connection is unhealthy and may fail soon
  unhealthy,

  /// Connection health is unknown (not yet checked)
  unknown,
}

/// Model for storing connection data across app sessions
class ConnectionPersistence extends Equatable {
  /// The connection token
  final String token;

  /// When the token was first generated
  final DateTime generationTimestamp;

  /// When the token was last validated successfully
  final DateTime lastValidationTimestamp;

  /// When the token expires
  final DateTime expiryDate;

  /// Device information bound to this connection
  final DeviceBindingInfo deviceBinding;

  /// Current connection health status
  final ConnectionHealth health;

  /// Number of reconnection attempts made
  final int reconnectionAttempts;

  /// Consecutive error count
  final int consecutiveErrors;

  /// Last successful ping timestamp
  final DateTime? lastSuccessfulPing;

  /// Encryption version for future migration support
  final String encryptionVersion;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  const ConnectionPersistence({
    required this.token,
    required this.generationTimestamp,
    required this.lastValidationTimestamp,
    required this.expiryDate,
    required this.deviceBinding,
    this.health = ConnectionHealth.unknown,
    this.reconnectionAttempts = 0,
    this.consecutiveErrors = 0,
    this.lastSuccessfulPing,
    this.encryptionVersion = '1.0',
    this.metadata = const {},
  });

  /// Current status of the connection
  ConnectionPersistenceStatus get status {
    final now = DateTime.now();

    // Check if expired
    if (now.isAfter(expiryDate)) {
      return ConnectionPersistenceStatus.expired;
    }

    // Check if currently recovering
    if (reconnectionAttempts > 0) {
      return ConnectionPersistenceStatus.recovering;
    }

    // Check if failed (too many consecutive errors)
    if (consecutiveErrors >= 5) {
      return ConnectionPersistenceStatus.failed;
    }

    // Check if stale (not validated recently)
    final timeSinceValidation = now.difference(lastValidationTimestamp);
    if (timeSinceValidation > const Duration(hours: 24)) {
      return ConnectionPersistenceStatus.stale;
    }

    return ConnectionPersistenceStatus.active;
  }

  /// Whether the connection is currently valid
  bool get isValid {
    return status == ConnectionPersistenceStatus.active ||
        status == ConnectionPersistenceStatus.stale;
  }

  /// Whether the connection needs renewal
  bool get needsRenewal {
    final now = DateTime.now();
    final timeUntilExpiry = expiryDate.difference(now);

    // Renew if expires in less than 5 minutes
    return timeUntilExpiry < const Duration(minutes: 5);
  }

  /// Whether the connection can be recovered
  bool get canRecover {
    return status == ConnectionPersistenceStatus.stale ||
        status == ConnectionPersistenceStatus.recovering ||
        (status == ConnectionPersistenceStatus.failed &&
            reconnectionAttempts < 3);
  }

  /// Time until token expiry
  Duration get timeUntilExpiry {
    final now = DateTime.now();
    return expiryDate.difference(now);
  }

  /// Time since last validation
  Duration get timeSinceLastValidation {
    final now = DateTime.now();
    return now.difference(lastValidationTimestamp);
  }

  /// Connection age
  Duration get connectionAge {
    final now = DateTime.now();
    return now.difference(generationTimestamp);
  }

  /// Update validation timestamp
  ConnectionPersistence updateValidation({
    DateTime? validationTime,
    ConnectionHealth? health,
  }) {
    return copyWith(
      lastValidationTimestamp: validationTime ?? DateTime.now(),
      health: health ?? this.health,
      consecutiveErrors: 0, // Reset error count on successful validation
    );
  }

  /// Record a successful ping
  ConnectionPersistence recordSuccessfulPing() {
    return copyWith(
      lastSuccessfulPing: DateTime.now(),
      health: ConnectionHealth.healthy,
      consecutiveErrors: 0,
    );
  }

  /// Record a connection error
  ConnectionPersistence recordError() {
    final newErrorCount = consecutiveErrors + 1;
    ConnectionHealth newHealth;

    if (newErrorCount >= 5) {
      newHealth = ConnectionHealth.unhealthy;
    } else if (newErrorCount >= 3) {
      newHealth = ConnectionHealth.degraded;
    } else {
      newHealth = health;
    }

    return copyWith(
      consecutiveErrors: newErrorCount,
      health: newHealth,
    );
  }

  /// Record a reconnection attempt
  ConnectionPersistence recordReconnectionAttempt() {
    return copyWith(
      reconnectionAttempts: reconnectionAttempts + 1,
    );
  }

  /// Reset reconnection attempts (on successful reconnection)
  ConnectionPersistence resetReconnectionAttempts() {
    return copyWith(
      reconnectionAttempts: 0,
      consecutiveErrors: 0,
      health: ConnectionHealth.healthy,
      lastValidationTimestamp: DateTime.now(),
    );
  }

  /// Extend token expiry
  ConnectionPersistence extendExpiry(Duration extension) {
    return copyWith(
      expiryDate: expiryDate.add(extension),
    );
  }

  /// Update device binding information
  ConnectionPersistence updateDeviceBinding(DeviceBindingInfo newBinding) {
    return copyWith(
      deviceBinding: newBinding,
    );
  }

  /// Add metadata
  ConnectionPersistence addMetadata(String key, dynamic value) {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata[key] = value;
    return copyWith(metadata: newMetadata);
  }

  /// Remove metadata
  ConnectionPersistence removeMetadata(String key) {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata.remove(key);
    return copyWith(metadata: newMetadata);
  }

  @override
  List<Object?> get props => [
        token,
        generationTimestamp,
        lastValidationTimestamp,
        expiryDate,
        deviceBinding,
        health,
        reconnectionAttempts,
        consecutiveErrors,
        lastSuccessfulPing,
        encryptionVersion,
        metadata,
      ];

  /// Copy with new values
  ConnectionPersistence copyWith({
    String? token,
    DateTime? generationTimestamp,
    DateTime? lastValidationTimestamp,
    DateTime? expiryDate,
    DeviceBindingInfo? deviceBinding,
    ConnectionHealth? health,
    int? reconnectionAttempts,
    int? consecutiveErrors,
    DateTime? lastSuccessfulPing,
    String? encryptionVersion,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionPersistence(
      token: token ?? this.token,
      generationTimestamp: generationTimestamp ?? this.generationTimestamp,
      lastValidationTimestamp:
          lastValidationTimestamp ?? this.lastValidationTimestamp,
      expiryDate: expiryDate ?? this.expiryDate,
      deviceBinding: deviceBinding ?? this.deviceBinding,
      health: health ?? this.health,
      reconnectionAttempts: reconnectionAttempts ?? this.reconnectionAttempts,
      consecutiveErrors: consecutiveErrors ?? this.consecutiveErrors,
      lastSuccessfulPing: lastSuccessfulPing ?? this.lastSuccessfulPing,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'generationTimestamp': generationTimestamp.toIso8601String(),
      'lastValidationTimestamp': lastValidationTimestamp.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'deviceBinding': deviceBinding.toJson(),
      'health': health.name,
      'reconnectionAttempts': reconnectionAttempts,
      'consecutiveErrors': consecutiveErrors,
      'lastSuccessfulPing': lastSuccessfulPing?.toIso8601String(),
      'encryptionVersion': encryptionVersion,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ConnectionPersistence.fromJson(Map<String, dynamic> json) {
    return ConnectionPersistence(
      token: json['token'],
      generationTimestamp: DateTime.parse(json['generationTimestamp']),
      lastValidationTimestamp: DateTime.parse(json['lastValidationTimestamp']),
      expiryDate: DateTime.parse(json['expiryDate']),
      deviceBinding: DeviceBindingInfo.fromJson(json['deviceBinding']),
      health: ConnectionHealth.values.firstWhere(
        (e) => e.name == json['health'],
        orElse: () => ConnectionHealth.unknown,
      ),
      reconnectionAttempts: json['reconnectionAttempts'] ?? 0,
      consecutiveErrors: json['consecutiveErrors'] ?? 0,
      lastSuccessfulPing: json['lastSuccessfulPing'] != null
          ? DateTime.parse(json['lastSuccessfulPing'])
          : null,
      encryptionVersion: json['encryptionVersion'] ?? '1.0',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Create a new connection persistence
  factory ConnectionPersistence.create({
    required String token,
    required DateTime expiryDate,
    required DeviceBindingInfo deviceBinding,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return ConnectionPersistence(
      token: token,
      generationTimestamp: now,
      lastValidationTimestamp: now,
      expiryDate: expiryDate,
      deviceBinding: deviceBinding,
      health: ConnectionHealth.healthy,
      metadata: metadata ?? {},
    );
  }
}

/// Device information bound to a connection
class DeviceBindingInfo extends Equatable {
  /// Unique device identifier
  final String deviceId;

  /// Device name (e.g., "John's iPhone")
  final String deviceName;

  /// Device type (e.g., "ios", "android")
  final String deviceType;

  /// Device model (e.g., "iPhone 14 Pro")
  final String deviceModel;

  /// Operating system version
  final String osVersion;

  /// App version when connection was created
  final String appVersion;

  /// Platform-specific device info
  final Map<String, dynamic> platformInfo;

  const DeviceBindingInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    this.platformInfo = const {},
  });

  /// Whether this binding matches the current device
  bool matchesCurrentDevice(DeviceBindingInfo current) {
    return deviceId == current.deviceId &&
        deviceType == current.deviceType &&
        deviceModel == current.deviceModel;
  }

  /// Whether this is the same device but different OS/app version
  bool isSameDeviceUpdated(DeviceBindingInfo current) {
    return deviceId == current.deviceId &&
        deviceType == current.deviceType &&
        deviceModel == current.deviceModel &&
        (osVersion != current.osVersion || appVersion != current.appVersion);
  }

  @override
  List<Object?> get props => [
        deviceId,
        deviceName,
        deviceType,
        deviceModel,
        osVersion,
        appVersion,
        platformInfo,
      ];

  /// Copy with new values
  DeviceBindingInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? deviceType,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    Map<String, dynamic>? platformInfo,
  }) {
    return DeviceBindingInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      platformInfo: platformInfo ?? this.platformInfo,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'platformInfo': platformInfo,
    };
  }

  /// Create from JSON
  factory DeviceBindingInfo.fromJson(Map<String, dynamic> json) {
    return DeviceBindingInfo(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      deviceType: json['deviceType'],
      deviceModel: json['deviceModel'],
      osVersion: json['osVersion'],
      appVersion: json['appVersion'],
      platformInfo: Map<String, dynamic>.from(json['platformInfo'] ?? {}),
    );
  }
}

/// Result of connection persistence operations
class ConnectionPersistenceResult extends Equatable {
  final bool success;
  final ConnectionPersistence? connection;
  final String? errorMessage;
  final ConnectionPersistenceStatus? status;

  const ConnectionPersistenceResult._({
    required this.success,
    this.connection,
    this.errorMessage,
    this.status,
  });

  factory ConnectionPersistenceResult.success(
      ConnectionPersistence connection) {
    return ConnectionPersistenceResult._(
      success: true,
      connection: connection,
      status: connection.status,
    );
  }

  factory ConnectionPersistenceResult.failure(
    String errorMessage, {
    ConnectionPersistenceStatus? status,
  }) {
    return ConnectionPersistenceResult._(
      success: false,
      errorMessage: errorMessage,
      status: status,
    );
  }

  @override
  List<Object?> get props => [success, connection, errorMessage, status];
}
