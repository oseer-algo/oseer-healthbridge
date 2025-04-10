// File path: lib/utils/health_connect_debugger.dart

import 'package:device_info_plus/device_info_plus.dart';
import 'package:health/health.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/logger_service.dart';

class HealthConnectDebugger {
  final Health _health = Health();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> runDiagnostics() async {
    try {
      OseerLogger.info('=====================================================');
      OseerLogger.info('STARTING COMPREHENSIVE WELLNESS CONNECT DIAGNOSTICS');
      OseerLogger.info('=====================================================');

      // Collect app information
      final packageInfo = await _collectAppInfo();

      // Collect device information
      final deviceInfo = await _collectDeviceInfo();

      // Check Wellness Connect availability
      final wellnessConnectAvailable = await _checkWellnessConnectAvailable();

      // Check if Wellness Connect app is installed
      final wellnessConnectInstalled = await _checkWellnessConnectInstalled();

      // Check permissions granted
      final wellnessConnectPermissionsGranted =
          await _checkWellnessConnectPermissions();

      // Get permissions details if granted
      final permissionsDetails = await _getPermissionsDetails();

      // Get Wellness Connect version info if available
      final wellnessConnectVersionInfo = await _getWellnessConnectVersionInfo();

      OseerLogger.info('=====================================================');
      OseerLogger.info('WELLNESS CONNECT DIAGNOSTICS COMPLETED');
      OseerLogger.info('=====================================================');

      // Return collected information
      return {
        'appName': packageInfo['appName'],
        'packageName': packageInfo['packageName'],
        'version': packageInfo['version'],
        'buildNumber': packageInfo['buildNumber'],
        'androidVersion': deviceInfo,
        'wellnessConnectAvailable': wellnessConnectAvailable,
        'wellnessConnectAppInstalled': wellnessConnectInstalled,
        'wellnessConnectPermissionsGranted': wellnessConnectPermissionsGranted,
        'permissionDetails': permissionsDetails,
        'wellnessConnectVersionInfo': wellnessConnectVersionInfo,
      };
    } catch (e) {
      OseerLogger.error('Error running Wellness Connect diagnostics', e);
      return {
        'error': e.toString(),
        'diagnosticsCompleted': false,
      };
    }
  }

  Future<Map<String, String>> _collectAppInfo() async {
    OseerLogger.info('App Package Info:');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      OseerLogger.info('  - App Name: ${packageInfo.appName}');
      OseerLogger.info('  - Package Name: ${packageInfo.packageName}');
      OseerLogger.info('  - Version: ${packageInfo.version}');
      OseerLogger.info('  - Build Number: ${packageInfo.buildNumber}');

      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      OseerLogger.error('Error collecting app info', e);
      return {
        'appName': 'Unknown',
        'packageName': 'Unknown',
        'version': 'Unknown',
        'buildNumber': 'Unknown',
      };
    }
  }

  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    OseerLogger.info('Android Device Info:');
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      final release = androidInfo.version.release;

      OseerLogger.info('  - SDK Int: $sdkInt');
      OseerLogger.info('  - Release: $release');
      OseerLogger.info('  - Manufacturer: ${androidInfo.manufacturer}');
      OseerLogger.info('  - Model: ${androidInfo.model}');

      return {
        'sdkInt': sdkInt,
        'release': release,
        'manufacturer': androidInfo.manufacturer,
        'model': androidInfo.model,
      };
    } catch (e) {
      OseerLogger.error('Error collecting device info', e);
      return {
        'sdkInt': 0,
        'release': 'Unknown',
        'manufacturer': 'Unknown',
        'model': 'Unknown',
      };
    }
  }

  Future<bool> _checkWellnessConnectAvailable() async {
    try {
      final result = await _health.hasPermissions([HealthDataType.STEPS]);
      OseerLogger.info('Wellness Connect hasPermissions check: $result');
      return result != null;
    } catch (e) {
      OseerLogger.warning('Wellness Connect not available: $e');
      return false;
    }
  }

  Future<bool> _checkWellnessConnectInstalled() async {
    try {
      // This is a simplified check - in a real app, use PackageManager
      final available = await _checkWellnessConnectAvailable();
      final result = available;
      OseerLogger.info('Wellness Connect app installed: $result');
      return result;
    } catch (e) {
      OseerLogger.error('Error checking if Wellness Connect is installed', e);
      return false;
    }
  }

  Future<bool> _checkWellnessConnectPermissions() async {
    try {
      final hasPermissions = await _health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.WEIGHT,
        HealthDataType.WORKOUT,
      ]);
      OseerLogger.info('Wellness Connect permissions granted: $hasPermissions');
      return hasPermissions == true;
    } catch (e) {
      OseerLogger.error('Error checking Wellness Connect permissions', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _getPermissionsDetails() async {
    final permissionTypes = [
      'STEPS',
      'HEART_RATE',
      'SLEEP_ASLEEP',
      'WEIGHT',
      'WORKOUT',
    ];

    final permissionDetails = <Map<String, dynamic>>[];

    for (final type in permissionTypes) {
      try {
        final healthDataType = _getHealthDataTypeByName(type);
        if (healthDataType != null) {
          final hasPermission = await _health.hasPermissions([healthDataType]);
          OseerLogger.info('Permission for $type: $hasPermission');
          permissionDetails.add({
            'type': type,
            'granted': hasPermission == true,
          });
        }
      } catch (e) {
        OseerLogger.warning('Error checking permission for $type: $e');
        permissionDetails.add({
          'type': type,
          'granted': false,
          'error': e.toString(),
        });
      }
    }

    return permissionDetails;
  }

  HealthDataType? _getHealthDataTypeByName(String name) {
    switch (name) {
      case 'STEPS':
        return HealthDataType.STEPS;
      case 'HEART_RATE':
        return HealthDataType.HEART_RATE;
      case 'SLEEP_ASLEEP':
        return HealthDataType.SLEEP_ASLEEP;
      case 'WEIGHT':
        return HealthDataType.WEIGHT;
      case 'WORKOUT':
        return HealthDataType.WORKOUT;
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _getWellnessConnectVersionInfo() async {
    try {
      // Since there's no direct API to get version info, we construct it from device info
      final androidInfo = await _deviceInfo.androidInfo;
      final installed = await _checkWellnessConnectInstalled();

      OseerLogger.info('Wellness Connect version info: ${{
        'androidSdkInt': androidInfo.version.sdkInt,
        'releaseVersion': androidInfo.version.release,
        'installed': installed
      }}');

      return {
        'androidSdkInt': androidInfo.version.sdkInt,
        'releaseVersion': androidInfo.version.release,
        'installed': installed,
      };
    } catch (e) {
      OseerLogger.error('Error getting Wellness Connect version info', e);
      return {
        'error': e.toString(),
      };
    }
  }
}
