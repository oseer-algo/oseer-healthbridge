// lib/services/background_isolate_handler.dart

import 'package:device_info_plus/device_info_plus.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import '../managers/health_manager.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

/// Handles initialization of services in background isolates
class BackgroundIsolateHandler {
  static HealthManager? _healthManager;
  static ApiService? _apiService;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      OseerLogger.info('BackgroundIsolateHandler already initialized');
      return;
    }

    try {
      OseerLogger.info('Initializing BackgroundIsolateHandler...');

      // Initialize logger
      await OseerLogger.init(Level.debug);

      // Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Initialize Supabase
      await Supabase.initialize(
        url: OseerConstants.supabaseUrl,
        anonKey: OseerConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      // Initialize API Service
      _apiService = ApiService(prefs);

      // Initialize Health Manager
      _healthManager = HealthManager(
        health: Health(),
        apiService: _apiService!,
        prefs: prefs,
        deviceInfo: DeviceInfoPlugin(),
        notificationService: NotificationService(),
      );

      _isInitialized = true;
      OseerLogger.info('✅ BackgroundIsolateHandler initialized successfully');
    } catch (e, s) {
      OseerLogger.error('Failed to initialize BackgroundIsolateHandler', e, s);
      throw Exception('BackgroundIsolateHandler initialization failed: $e');
    }
  }

  static HealthManager getHealthManager() {
    if (!_isInitialized || _healthManager == null) {
      throw Exception(
          'BackgroundIsolateHandler not initialized. Call initialize() first.');
    }
    return _healthManager!;
  }

  static ApiService getApiService() {
    if (!_isInitialized || _apiService == null) {
      throw Exception(
          'BackgroundIsolateHandler not initialized. Call initialize() first.');
    }
    return _apiService!;
  }

  static void dispose() {
    _healthManager = null;
    _apiService?.dispose();
    _apiService = null;
    _isInitialized = false;
    OseerLogger.info('BackgroundIsolateHandler disposed');
  }
}
