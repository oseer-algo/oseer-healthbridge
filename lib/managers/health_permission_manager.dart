// lib/managers/health_permission_manager.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../services/logger_service.dart';

enum HealthPermissionResult {
  granted,
  partiallyGranted,
  denied,
  error,
  notAvailable,
}

/// A platform-agnostic layer for handling health data permissions.
class HealthPermissionManager {
  static final Health _health = Health();

  /// Maps our internal data types to platform-specific HealthDataType.
  static List<HealthDataType> get allRequestedTypes {
    if (Platform.isIOS) {
      return _getIOSDataTypes();
    } else {
      return _getAndroidDataTypes();
    }
  }

  static List<HealthDataType> _getIOSDataTypes() {
    // CORRECTED: Removed types that cause warnings and failures on iOS.
    // Specifically:
    // - DISTANCE_DELTA (use DISTANCE_WALKING_RUNNING instead for more reliability)
    // - TOTAL_CALORIES_BURNED (ACTIVE_ENERGY_BURNED + BASAL_ENERGY_BURNED is the correct way)
    // - SLEEP_SESSION (The individual sleep types like SLEEP_ASLEEP are what contain data)
    // - BODY_WATER_MASS (less common and potentially causing issues)
    // - NUTRITION (This is a category, not a specific type to request)

    return const [
      // Vitals
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,

      // Activity
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.DISTANCE_WALKING_RUNNING, // More specific and reliable
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.WORKOUT,

      // Sleep
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_AWAKE,

      // Body Measurements
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.LEAN_BODY_MASS,

      // Other
      HealthDataType.WATER,
      HealthDataType.MENSTRUATION_FLOW,
    ];
  }

  static List<HealthDataType> _getAndroidDataTypes() {
    return const [
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.WORKOUT,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.LEAN_BODY_MASS,
      HealthDataType.BODY_WATER_MASS,
      HealthDataType.WATER,
      HealthDataType.NUTRITION,
      HealthDataType.MENSTRUATION_FLOW,
    ];
  }

  static List<HealthDataType> get _criticalTypes {
    if (Platform.isIOS) {
      return const [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.STEPS,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
    } else {
      return const [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.STEPS,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
    }
  }

  static Future<bool> isHealthConnectInstalled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      return false;
    }
  }

  /// FIX: This method ONLY CHECKS permissions, it does NOT request them.
  /// This is called first to see if we need to show the wellness sheet.
  static Future<HealthPermissionResult> checkPermissions() async {
    if (kIsWeb) return HealthPermissionResult.granted;

    // iOS doesn't need Health Connect check
    if (Platform.isIOS) {
      try {
        final hasCritical =
            await _health.hasPermissions(_criticalTypes) ?? false;

        if (hasCritical) {
          return HealthPermissionResult.granted;
        }
        return HealthPermissionResult.denied;
      } catch (e, s) {
        OseerLogger.error('[HPM] Error during iOS permission check', e, s);
        return HealthPermissionResult.error;
      }
    }

    // Android logic
    if (!await isHealthConnectInstalled()) {
      return HealthPermissionResult.notAvailable;
    }

    try {
      final hasCritical = await _health.hasPermissions(_criticalTypes) ?? false;
      final hasBackground = await _health.isHealthDataInBackgroundAuthorized();

      if (hasCritical && hasBackground) {
        return HealthPermissionResult.granted;
      }
      return HealthPermissionResult.denied;
    } catch (e, s) {
      OseerLogger.error('[HPM] Error during Android permission check', e, s);
      return HealthPermissionResult.error;
    }
  }

  /// FIX: This method ONLY REQUESTS permissions, triggering the OS dialog.
  /// This is called *after* the user taps "Grant" on our custom sheet.
  static Future<HealthPermissionResult> requestPermissions() async {
    final logPrefix = '[HPM]';
    if (kIsWeb) return HealthPermissionResult.granted;

    try {
      OseerLogger.info(
          '$logPrefix Requesting permissions for ${Platform.operatingSystem}...');

      // The requestAuthorization method returns a boolean indicating if the request was successful.
      // We trust this result directly to avoid race conditions with checking immediately after.
      final bool granted =
          await _health.requestAuthorization(allRequestedTypes);

      if (granted) {
        OseerLogger.info(
            '$logPrefix ✅ Permissions were successfully requested and likely granted by the user.');
        // For Android, also request background authorization. This is a no-op on iOS.
        if (Platform.isAndroid) {
          await _health.requestHealthDataInBackgroundAuthorization();
          await _health.requestHealthDataHistoryAuthorization();
        }
        return HealthPermissionResult.granted;
      } else {
        OseerLogger.warning(
            '$logPrefix ⚠️ The permission request returned false. The user may have cancelled or denied.');
        // As a fallback, check if at least the critical permissions were granted.
        final hasCritical =
            await _health.hasPermissions(_criticalTypes) ?? false;
        return hasCritical
            ? HealthPermissionResult.partiallyGranted
            : HealthPermissionResult.denied;
      }
    } catch (e, s) {
      OseerLogger.error(
          '$logPrefix Error during permission request process', e, s);
      return HealthPermissionResult.error;
    }
  }
}
