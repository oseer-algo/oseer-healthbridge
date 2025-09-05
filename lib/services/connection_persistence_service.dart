// lib/services/connection_persistence_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/connection_persistence.dart';
import '../models/helper_models.dart' hide ConnectionPersistenceState;
import 'secure_storage_service.dart';
import 'logger_service.dart';

/// SIMPLIFIED: Service for basic connection persistence without Digital Twin orchestration
class ConnectionPersistenceService {
  static const String _connectionKey = 'persistent_connection';
  static const String _connectionStateKey = 'connection_state';
  static const String _migrationVersionKey = 'connection_migration_version';
  static const int _currentMigrationVersion = 1;

  final SecureStorageService _secureStorage;
  final LoggerService _logger;

  ConnectionPersistence? _currentConnection;
  ConnectionPersistenceState? _currentState;

  Timer? _healthCheckTimer;
  Timer? _renewalTimer;

  /// Stream of connection health updates
  final _connectionHealthController =
      StreamController<ConnectionHealth>.broadcast();
  Stream<ConnectionHealth> get connectionHealthStream =>
      _connectionHealthController.stream;

  /// Stream of connection status updates
  final _connectionStatusController =
      StreamController<ConnectionPersistenceStatus>.broadcast();
  Stream<ConnectionPersistenceStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  ConnectionPersistenceService({
    required SecureStorageService secureStorage,
    required LoggerService logger,
  })  : _secureStorage = secureStorage,
        _logger = logger;

  /// Initialize the service and check for existing connections
  Future<void> initialize() async {
    try {
      _logger.info('Initializing connection persistence service');

      // Check migration version and migrate if needed
      await _checkAndMigrate();

      // Load existing connection if any
      await _loadExistingConnection();

      // Load existing state if any
      await _loadConnectionState();

      // Start health monitoring if connection exists
      if (_currentConnection != null) {
        _startHealthMonitoring();
        _scheduleRenewalCheck();
      }

      _logger.info('Connection persistence service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to initialize connection persistence service', e, stackTrace);
    }
  }

  /// Save a new connection for persistence
  Future<ConnectionPersistenceResult> saveConnection({
    required String token,
    required DateTime expiryDate,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.info('Saving new persistent connection');

      // Get current device binding info
      final deviceBinding = await _getCurrentDeviceBinding();

      // Create new connection persistence object
      final connection = ConnectionPersistence.create(
        token: token,
        expiryDate: expiryDate,
        deviceBinding: deviceBinding,
        metadata: metadata,
      );

      // Save to secure storage
      await _secureStorage.write(
        _connectionKey,
        jsonEncode(connection.toJson()),
      );

      // Update current connection
      _currentConnection = connection;

      // Start monitoring
      _startHealthMonitoring();
      _scheduleRenewalCheck();

      // Create basic state if it doesn't exist - use ONLY actual parameters
      if (_currentState == null) {
        _currentState = ConnectionPersistenceState(
          isConnected: true,
          lastSyncTime: DateTime.now(),
        );
        await saveConnectionState(_currentState!);
      }

      // Emit status update
      _connectionStatusController.add(connection.status);
      _connectionHealthController.add(connection.health);

      _logger.info('Connection saved successfully');
      return ConnectionPersistenceResult.success(connection);
    } catch (e, stackTrace) {
      _logger.error('Failed to save connection', e, stackTrace);
      return ConnectionPersistenceResult.failure(
        'Failed to save connection: ${e.toString()}',
      );
    }
  }

  /// Load existing connection from storage
  Future<ConnectionPersistenceResult> loadConnection() async {
    try {
      _logger.info('Loading existing connection');

      final connectionData = await _secureStorage.read(_connectionKey);
      if (connectionData == null) {
        _logger.info('No existing connection found');
        return ConnectionPersistenceResult.failure(
          'No existing connection found',
          status: ConnectionPersistenceStatus.none,
        );
      }

      final connectionJson = jsonDecode(connectionData);
      final connection = ConnectionPersistence.fromJson(connectionJson);

      // Validate the connection
      final validationResult = _validateStoredConnection(connection);
      if (!validationResult.isValid) {
        _logger.warning(
            'Stored connection is invalid: ${validationResult.reason}');
        await clearConnection();
        return ConnectionPersistenceResult.failure(
          validationResult.reason,
          status: validationResult.status,
        );
      }

      _currentConnection = connection;

      // Start monitoring
      _startHealthMonitoring();
      _scheduleRenewalCheck();

      // Emit status update
      _connectionStatusController.add(connection.status);
      _connectionHealthController.add(connection.health);

      _logger.info('Connection loaded successfully');
      return ConnectionPersistenceResult.success(connection);
    } catch (e, stackTrace) {
      _logger.error('Failed to load connection', e, stackTrace);
      return ConnectionPersistenceResult.failure(
        'Failed to load connection: ${e.toString()}',
      );
    }
  }

  /// Load connection state from storage
  Future<ConnectionPersistenceState?> loadConnectionState() async {
    try {
      _logger.info('Loading connection state');

      final stateData = await _secureStorage.read(_connectionStateKey);
      if (stateData == null) {
        _logger.info('No existing connection state found');
        return null;
      }

      final stateJson = jsonDecode(stateData);
      _currentState = ConnectionPersistenceState.fromJson(stateJson);

      _logger.info('Connection state loaded successfully');
      return _currentState;
    } catch (e, stackTrace) {
      _logger.error('Failed to load connection state', e, stackTrace);
      return null;
    }
  }

  /// Save connection state to storage
  Future<bool> saveConnectionState(ConnectionPersistenceState state) async {
    try {
      _logger.info('Saving connection state');

      await _secureStorage.write(
        _connectionStateKey,
        jsonEncode(state.toJson()),
      );

      _currentState = state;

      _logger.info('Connection state saved successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to save connection state', e, stackTrace);
      return false;
    }
  }

  /// SIMPLIFIED: Update sync status - only track basic connection and sync time
  Future<bool> updateSyncStatus(
      bool isConnected, bool isInSync, DateTime timestamp) async {
    try {
      final currentState = _currentState ??
          ConnectionPersistenceState(
            isConnected: isConnected,
            lastSyncTime: timestamp,
          );

      final updatedState = currentState.copyWith(
        isConnected: isConnected,
        lastSyncTime: timestamp,
      );

      return await saveConnectionState(updatedState);
    } catch (e, stackTrace) {
      _logger.error('Failed to update sync status', e, stackTrace);
      return false;
    }
  }

  /// REMOVED: Digital Twin settings - no longer needed
  /// This method is kept for backward compatibility but does nothing
  Future<bool> updateDigitalTwinSettings(bool enabled) async {
    _logger.info('Digital Twin settings update ignored - feature removed');
    return true;
  }

  /// Update wellness status
  Future<bool> updateWellnessStatus({
    bool? bodyPrepComplete,
    DateTime? bodyPrepCompletedAt,
    bool? digitalTwinComplete,
    DateTime? digitalTwinCompletedAt,
  }) async {
    try {
      if (_currentState == null) {
        _currentState = ConnectionPersistenceState(
          isConnected: true,
          lastSyncTime: DateTime.now(),
        );
      }

      // Update state with wellness information
      final updatedState = _currentState!.copyWith(
        lastSyncTime: DateTime.now(),
      );

      // Store wellness metadata separately if needed
      final wellnessMetadata = <String, dynamic>{};
      if (bodyPrepComplete != null) {
        wellnessMetadata['bodyPrepComplete'] = bodyPrepComplete;
      }
      if (bodyPrepCompletedAt != null) {
        wellnessMetadata['bodyPrepCompletedAt'] =
            bodyPrepCompletedAt.toIso8601String();
      }
      if (digitalTwinComplete != null) {
        wellnessMetadata['digitalTwinComplete'] = digitalTwinComplete;
      }
      if (digitalTwinCompletedAt != null) {
        wellnessMetadata['digitalTwinCompletedAt'] =
            digitalTwinCompletedAt.toIso8601String();
      }

      if (wellnessMetadata.isNotEmpty) {
        await _secureStorage.write(
          'wellness_status',
          jsonEncode(wellnessMetadata),
        );
      }

      return await saveConnectionState(updatedState);
    } catch (e, stackTrace) {
      _logger.error('Failed to update wellness status', e, stackTrace);
      return false;
    }
  }

  /// Clear stored connection
  Future<void> clearConnection() async {
    try {
      _logger.info('Clearing stored connection');

      await _secureStorage.delete(_connectionKey);
      _currentConnection = null;

      // Stop monitoring
      _stopHealthMonitoring();
      _stopRenewalMonitoring();

      // Emit status update
      _connectionStatusController.add(ConnectionPersistenceStatus.none);

      _logger.info('Connection cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear connection', e, stackTrace);
    }
  }

  /// Clear stored connection state
  Future<void> clearConnectionState() async {
    try {
      _logger.info('Clearing stored connection state');

      await _secureStorage.delete(_connectionStateKey);
      _currentState = null;

      _logger.info('Connection state cleared successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear connection state', e, stackTrace);
    }
  }

  /// Check if a valid connection exists
  bool hasValidConnection() {
    return _currentConnection != null && _currentConnection!.isValid;
  }

  /// Get current connection if it exists and is valid
  ConnectionPersistence? getValidConnection() {
    return hasValidConnection() ? _currentConnection : null;
  }

  /// Get current connection state
  ConnectionPersistenceState? getConnectionState() {
    return _currentState;
  }

  /// Update connection validation timestamp
  Future<ConnectionPersistenceResult> updateValidation({
    ConnectionHealth? health,
  }) async {
    if (_currentConnection == null) {
      return ConnectionPersistenceResult.failure('No connection to update');
    }

    try {
      _logger.info('Updating connection validation');

      final updatedConnection = _currentConnection!.updateValidation(
        health: health,
      );

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Emit health update
      _connectionHealthController.add(updatedConnection.health);
      _connectionStatusController.add(updatedConnection.status);

      _logger.info('Connection validation updated');
      return ConnectionPersistenceResult.success(updatedConnection);
    } catch (e, stackTrace) {
      _logger.error('Failed to update validation', e, stackTrace);
      return ConnectionPersistenceResult.failure(
        'Failed to update validation: ${e.toString()}',
      );
    }
  }

  /// Record a successful ping
  Future<void> recordSuccessfulPing() async {
    if (_currentConnection == null) return;

    try {
      final updatedConnection = _currentConnection!.recordSuccessfulPing();

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Emit health update
      _connectionHealthController.add(updatedConnection.health);
      _connectionStatusController.add(updatedConnection.status);
    } catch (e, stackTrace) {
      _logger.error('Failed to record successful ping', e, stackTrace);
    }
  }

  /// Record a connection error
  Future<void> recordError() async {
    if (_currentConnection == null) return;

    try {
      final updatedConnection = _currentConnection!.recordError();

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Emit health update
      _connectionHealthController.add(updatedConnection.health);
      _connectionStatusController.add(updatedConnection.status);

      // If connection is now unhealthy, consider recovery
      if (updatedConnection.health == ConnectionHealth.unhealthy) {
        _considerRecovery();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to record error', e, stackTrace);
    }
  }

  /// Start a reconnection attempt
  Future<void> startReconnectionAttempt() async {
    if (_currentConnection == null) return;

    try {
      final updatedConnection = _currentConnection!.recordReconnectionAttempt();

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Emit status update
      _connectionStatusController.add(updatedConnection.status);
    } catch (e, stackTrace) {
      _logger.error('Failed to record reconnection attempt', e, stackTrace);
    }
  }

  /// Reset reconnection attempts after successful reconnection
  Future<void> resetReconnectionAttempts() async {
    if (_currentConnection == null) return;

    try {
      final updatedConnection = _currentConnection!.resetReconnectionAttempts();

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Emit updates
      _connectionHealthController.add(updatedConnection.health);
      _connectionStatusController.add(updatedConnection.status);
    } catch (e, stackTrace) {
      _logger.error('Failed to reset reconnection attempts', e, stackTrace);
    }
  }

  /// Extend token expiry
  Future<ConnectionPersistenceResult> extendExpiry(Duration extension) async {
    if (_currentConnection == null) {
      return ConnectionPersistenceResult.failure('No connection to extend');
    }

    try {
      _logger.info(
          'Extending connection expiry by ${extension.inMinutes} minutes');

      final updatedConnection = _currentConnection!.extendExpiry(extension);

      await _secureStorage.write(
        _connectionKey,
        jsonEncode(updatedConnection.toJson()),
      );

      _currentConnection = updatedConnection;

      // Reschedule renewal check
      _scheduleRenewalCheck();

      _logger.info('Connection expiry extended');
      return ConnectionPersistenceResult.success(updatedConnection);
    } catch (e, stackTrace) {
      _logger.error('Failed to extend expiry', e, stackTrace);
      return ConnectionPersistenceResult.failure(
        'Failed to extend expiry: ${e.toString()}',
      );
    }
  }

  /// Dispose of the service
  void dispose() {
    _stopHealthMonitoring();
    _stopRenewalMonitoring();
    _connectionHealthController.close();
    _connectionStatusController.close();
  }

  // Private methods

  /// Load connection state from secure storage during initialization
  Future<void> _loadConnectionState() async {
    try {
      final stateData = await _secureStorage.read(_connectionStateKey);
      if (stateData != null) {
        final stateJson = jsonDecode(stateData);
        _currentState = ConnectionPersistenceState.fromJson(stateJson);
        _logger.info('Loaded existing connection state');
      }
    } catch (e) {
      _logger.warning('Failed to load connection state: $e');
    }
  }

  Future<void> _checkAndMigrate() async {
    try {
      final versionString = await _secureStorage.read(_migrationVersionKey);
      final currentVersion =
          versionString != null ? int.tryParse(versionString) ?? 0 : 0;

      if (currentVersion < _currentMigrationVersion) {
        _logger.info(
            'Running connection persistence migration from v$currentVersion to v$_currentMigrationVersion');

        await _secureStorage.write(
          _migrationVersionKey,
          _currentMigrationVersion.toString(),
        );

        _logger.info('Migration completed');
      }
    } catch (e, stackTrace) {
      _logger.error('Migration failed', e, stackTrace);
    }
  }

  Future<void> _loadExistingConnection() async {
    final result = await loadConnection();
    if (!result.success) {
      _logger.info('No valid existing connection found');
    }
  }

  Future<DeviceBindingInfo> _getCurrentDeviceBinding() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return DeviceBindingInfo(
        deviceId: androidInfo.id,
        deviceName: androidInfo.model,
        deviceType: 'android',
        deviceModel: '${androidInfo.brand} ${androidInfo.model}',
        osVersion: androidInfo.version.release,
        appVersion: packageInfo.version,
        platformInfo: {
          'manufacturer': androidInfo.manufacturer,
          'board': androidInfo.board,
          'bootloader': androidInfo.bootloader,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'hardware': androidInfo.hardware,
          'host': androidInfo.host,
          'product': androidInfo.product,
          'apiLevel': androidInfo.version.sdkInt,
        },
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return DeviceBindingInfo(
        deviceId: iosInfo.identifierForVendor ?? iosInfo.name,
        deviceName: iosInfo.name,
        deviceType: 'ios',
        deviceModel: '${iosInfo.model} ${iosInfo.localizedModel}',
        osVersion: iosInfo.systemVersion,
        appVersion: packageInfo.version,
        platformInfo: {
          'model': iosInfo.model,
          'localizedModel': iosInfo.localizedModel,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'utsname': iosInfo.utsname.toString(),
        },
      );
    } else {
      return DeviceBindingInfo(
        deviceId: 'unknown',
        deviceName: 'Unknown Device',
        deviceType: Platform.operatingSystem,
        deviceModel: 'Unknown Model',
        osVersion: Platform.operatingSystemVersion,
        appVersion: packageInfo.version,
      );
    }
  }

  _ConnectionValidationResult _validateStoredConnection(
      ConnectionPersistence connection) {
    final now = DateTime.now();

    if (now.isAfter(connection.expiryDate)) {
      return _ConnectionValidationResult(
        isValid: false,
        reason: 'Connection token has expired',
        status: ConnectionPersistenceStatus.expired,
      );
    }

    if (connection.consecutiveErrors >= 10) {
      return _ConnectionValidationResult(
        isValid: false,
        reason: 'Too many consecutive connection errors',
        status: ConnectionPersistenceStatus.failed,
      );
    }

    return _ConnectionValidationResult(
      isValid: true,
      reason: 'Connection is valid',
      status: connection.status,
    );
  }

  void _startHealthMonitoring() {
    _stopHealthMonitoring();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performHealthCheck();
    });
  }

  void _stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  void _scheduleRenewalCheck() {
    _stopRenewalMonitoring();

    if (_currentConnection == null) return;

    final timeUntilRenewal =
        _currentConnection!.timeUntilExpiry - const Duration(minutes: 5);
    if (timeUntilRenewal.isNegative) {
      _considerRenewal();
      return;
    }

    _renewalTimer = Timer(timeUntilRenewal, () {
      _considerRenewal();
    });
  }

  void _stopRenewalMonitoring() {
    _renewalTimer?.cancel();
    _renewalTimer = null;
  }

  Future<void> _performHealthCheck() async {
    if (_currentConnection == null) return;

    try {
      final timeSinceValidation = _currentConnection!.timeSinceLastValidation;

      ConnectionHealth newHealth;
      if (timeSinceValidation > const Duration(days: 1)) {
        newHealth = ConnectionHealth.degraded;
      } else if (timeSinceValidation > const Duration(hours: 6)) {
        newHealth = ConnectionHealth.degraded;
      } else {
        newHealth = ConnectionHealth.healthy;
      }

      if (newHealth != _currentConnection!.health) {
        await updateValidation(health: newHealth);
      }
    } catch (e, stackTrace) {
      _logger.error('Health check failed', e, stackTrace);
      await recordError();
    }
  }

  void _considerRecovery() {
    if (_currentConnection == null || !_currentConnection!.canRecover) return;
    _logger.info('Considering connection recovery');
    startReconnectionAttempt();
  }

  void _considerRenewal() {
    if (_currentConnection == null || !_currentConnection!.needsRenewal) return;
    _logger.info('Connection needs renewal');
  }
}

class _ConnectionValidationResult {
  final bool isValid;
  final String reason;
  final ConnectionPersistenceStatus status;

  _ConnectionValidationResult({
    required this.isValid,
    required this.reason,
    required this.status,
  });
}
