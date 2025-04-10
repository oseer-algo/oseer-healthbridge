// File path: lib/managers/health_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/health_data.dart';
import '../models/helper_models.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

/// Manager for wellness data collection - only collects data, no processing
class HealthManager {
  final ApiService _apiService;
  final SharedPreferences _prefs;
  final Health _health = Health();
  final Uuid _uuid = const Uuid();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Health data timespan - collect last 90 days of data
  final Duration _dataTimespan = const Duration(days: 90);

  // Base types of health data to collect (will be filtered by availability)
  final List<HealthDataType> _baseTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    // Optional types that may not be available on all devices
    // These will be filtered by device compatibility
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
  ];

  // Explicitly excluded types that are known to cause issues
  final List<HealthDataType> _excludedTypes = [
    // These types cause issues on many devices and should be avoided
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  /// Creates a new HealthManager
  HealthManager(this._apiService, this._prefs);

  /// Checks if Health Connect permissions are granted
  Future<HealthAuthStatus> checkWellnessPermissions() async {
    try {
      OseerLogger.info('Checking Health Connect permissions...');

      // Check if Health Connect is available
      final isAvailable = await isWellnessConnectAvailable();
      if (!isAvailable) {
        OseerLogger.info('Health Connect is not available on this device');
        return const HealthAuthStatus(
          status: HealthPermissionStatus.unavailable,
          grantedPermissions: [],
          message: 'Health Connect is not available on this device',
        );
      }

      // Determine which types are actually available on this device
      final availableTypes = await _getDeviceSupportedDataTypes();
      if (availableTypes.isEmpty) {
        OseerLogger.warning(
            'No supported health data types found on this device');
        return const HealthAuthStatus(
          status: HealthPermissionStatus.unavailable,
          grantedPermissions: [],
          message: 'No supported health data types found on this device',
        );
      }

      // Check permissions for available types
      List<String> grantedTypes = [];
      bool allGranted = false;
      bool anyGranted = false;

      try {
        final permissionsResult = await _health.hasPermissions(availableTypes);
        OseerLogger.info('Permissions check result: $permissionsResult');

        if (permissionsResult == true) {
          allGranted = true;
          grantedTypes = availableTypes.map((e) => e.toString()).toList();
          anyGranted = true;
        }
      } catch (e) {
        OseerLogger.warning('Error with comprehensive permissions check', e);
        // Continue with individual checks
      }

      // If the comprehensive check didn't confirm all permissions, check individually
      if (!allGranted) {
        for (final type in availableTypes) {
          try {
            final hasPermission = await _health.hasPermissions([type]);
            if (hasPermission == true) {
              grantedTypes.add(type.toString());
              anyGranted = true;
            }
          } catch (e) {
            OseerLogger.warning(
                'Error checking permission for ${type.toString()}', e);
          }
        }
      }

      // Determine the overall status
      if (allGranted) {
        return HealthAuthStatus(
          status: HealthPermissionStatus.granted,
          grantedPermissions: grantedTypes,
        );
      } else if (anyGranted) {
        return HealthAuthStatus(
          status: HealthPermissionStatus.partiallyGranted,
          grantedPermissions: grantedTypes,
        );
      } else {
        return const HealthAuthStatus(
          status: HealthPermissionStatus.denied,
          grantedPermissions: [],
        );
      }
    } catch (e) {
      OseerLogger.error('Error checking health permissions', e);
      return HealthAuthStatus(
        status: HealthPermissionStatus.denied,
        grantedPermissions: [],
        message: 'Error checking permissions: ${e.toString()}',
      );
    }
  }

  /// Get available data types for this device
  Future<List<HealthDataType>> _getDeviceSupportedDataTypes() async {
    final supportedTypes = <HealthDataType>[];

    // Filter out known problematic types
    final typesToCheck =
        _baseTypes.where((type) => !_excludedTypes.contains(type)).toList();

    // Check each type individually for support
    for (final type in typesToCheck) {
      try {
        // Try to check permission for this type to see if it's supported
        await _health.hasPermissions([type]);
        supportedTypes.add(type);
      } catch (e) {
        // Skip types that cause errors (not supported on this device/platform)
        OseerLogger.info(
            'Health data type ${type.toString()} not available on this device');
      }
    }

    OseerLogger.info(
        'Available health data types: ${supportedTypes.map((e) => e.toString()).join(", ")}');
    return supportedTypes;
  }

  /// Request Health Connect permissions
  Future<HealthAuthStatus> requestWellnessPermissions() async {
    try {
      OseerLogger.info('Requesting Health Connect permissions...');

      // Check if Health Connect is available
      final isAvailable = await isWellnessConnectAvailable();
      if (!isAvailable) {
        OseerLogger.info('Health Connect is not available on this device');
        return const HealthAuthStatus(
          status: HealthPermissionStatus.unavailable,
          grantedPermissions: [],
          message: 'Health Connect is not available on this device',
        );
      }

      // Get available data types for this device
      final availableTypes = await _getDeviceSupportedDataTypes();
      if (availableTypes.isEmpty) {
        OseerLogger.warning(
            'No supported health data types found on this device');
        return const HealthAuthStatus(
          status: HealthPermissionStatus.unavailable,
          grantedPermissions: [],
          message: 'No supported health data types found on this device',
        );
      }

      // Request permissions for available types
      OseerLogger.info(
          'Requesting permissions for ${availableTypes.length} data types');
      bool requestResult = false;
      try {
        requestResult = await _health.requestAuthorization(availableTypes);
      } catch (e) {
        OseerLogger.warning('Error requesting health permissions', e);

        // Try with essential types if the full request fails
        try {
          final essentialTypes = availableTypes
              .where((type) =>
                  type == HealthDataType.STEPS ||
                  type == HealthDataType.HEART_RATE ||
                  type == HealthDataType.SLEEP_ASLEEP)
              .toList();

          if (essentialTypes.isNotEmpty) {
            OseerLogger.info(
                'Trying with essential permissions only: ${essentialTypes.length} types');
            requestResult = await _health.requestAuthorization(essentialTypes);
          }
        } catch (subsetError) {
          OseerLogger.error(
              'Failed to request even essential permissions', subsetError);
        }
      }

      // Check which permissions were actually granted
      final grantedTypes = <String>[];
      for (final type in availableTypes) {
        try {
          final hasPermission = await _health.hasPermissions([type]);
          if (hasPermission == true) {
            grantedTypes.add(type.toString());
          }
        } catch (e) {
          OseerLogger.warning(
              'Error checking granted permission for ${type.toString()}', e);
        }
      }

      // Determine the status based on granted permissions
      if (grantedTypes.length == availableTypes.length) {
        OseerLogger.info('All health permissions granted');
        return HealthAuthStatus(
          status: HealthPermissionStatus.granted,
          grantedPermissions: grantedTypes,
        );
      } else if (grantedTypes.isNotEmpty) {
        OseerLogger.info(
            'Partially granted health permissions: ${grantedTypes.join(", ")}');
        return HealthAuthStatus(
          status: HealthPermissionStatus.partiallyGranted,
          grantedPermissions: grantedTypes,
        );
      } else {
        OseerLogger.info('No health permissions granted after request');
        return const HealthAuthStatus(
          status: HealthPermissionStatus.denied,
          grantedPermissions: [],
        );
      }
    } catch (e) {
      OseerLogger.error('Error requesting health permissions', e);
      return HealthAuthStatus(
        status: HealthPermissionStatus.denied,
        grantedPermissions: [],
        message: 'Error requesting permissions: ${e.toString()}',
      );
    }
  }

  /// Collect and sync health data with the API
  Future<bool> syncWellnessData() async {
    try {
      OseerLogger.info('Starting health data collection');

      // Check permissions first
      final authStatus = await checkWellnessPermissions();
      if (authStatus.status == HealthPermissionStatus.denied) {
        OseerLogger.warning('Cannot collect health data: No permissions');
        return false;
      }

      // If Health Connect is unavailable, return with clear message
      if (authStatus.status == HealthPermissionStatus.unavailable) {
        OseerLogger.warning(
            'Cannot collect health data: Health Connect unavailable');
        return false;
      }

      // Get available data types
      final availableTypes = await _getDeviceSupportedDataTypes();
      if (availableTypes.isEmpty) {
        OseerLogger.warning('No available health data types to collect');
        return false;
      }

      // Get time range (last 90 days to now)
      final now = DateTime.now();
      final startTime = now.subtract(_dataTimespan);

      OseerLogger.info(
          'Collecting health data from ${startTime.toIso8601String()} to ${now.toIso8601String()}');

      // Define which types to use based on granted permissions
      final typesToFetch = <HealthDataType>[];
      for (final type in availableTypes) {
        try {
          final hasPermission = await _health.hasPermissions([type]);
          if (hasPermission == true) {
            typesToFetch.add(type);
          }
        } catch (e) {
          // Skip types that cause errors
        }
      }

      if (typesToFetch.isEmpty) {
        OseerLogger.warning('No available health data types with permissions');
        return false;
      }

      OseerLogger.info(
          'Collecting data for types: ${typesToFetch.map((e) => e.toString()).join(", ")}');

      // Get device information
      final deviceInfo = await getDeviceInfo();

      // Fetch available health data
      final healthData = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: typesToFetch,
      );

      if (healthData.isEmpty) {
        OseerLogger.warning('No health data found for the requested period');
        return false;
      }

      OseerLogger.info('Retrieved ${healthData.length} health data points');

      // Get user ID
      final userId = _prefs.getString(OseerConstants.keyUserId);
      if (userId == null || userId.isEmpty) {
        OseerLogger.error('User ID not found in preferences');
        return false;
      }

      // Create health data object with raw data - no processing
      final healthDataObject = {
        'user_id': userId,
        'timestamp': now.toISOString(),
        'device_info': deviceInfo.toJson(),
        'raw_data': healthData
            .map((e) => {
                  'type': e.type.toString(),
                  'unit': e.unit.toString(),
                  'value': e.value.toString(),
                  'date_from': e.dateFrom.toISOString(),
                  'date_to': e.dateTo.toISOString(),
                  'source_id': e.sourceId,
                  'source_name': e.sourceName,
                })
            .toList(),
      };

      // Send to API without any processing
      final result = await _apiService.processWellnessData(healthDataObject);

      // Save last sync time
      await _prefs.setString(OseerConstants.keyLastSync, now.toISOString());

      OseerLogger.info('Health data collection successful');
      return result['success'] == true;
    } catch (e) {
      OseerLogger.error('Error collecting health data', e);
      return false;
    }
  }

  /// Check if Health Connect is available on the device
  Future<bool> isWellnessConnectAvailable() async {
    try {
      OseerLogger.info('Checking if Health Connect is available...');

      // Multiple detection approaches for better reliability
      bool isAvailable = false;

      // Method 1: Check if Health is installed using device information
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        // Health Connect requires Android API 30+
        if (sdkInt < 30) {
          OseerLogger.info(
              'Device running Android API $sdkInt (too old for Health Connect)');
          return false;
        }

        // Try to check if package is installed by testing a simple Health API call
        try {
          final hasStepsType =
              await _health.hasPermissions([HealthDataType.STEPS]);
          isAvailable = hasStepsType != null;
          OseerLogger.info('Health Connect is installed');
          return true;
        } catch (e) {
          if (e.toString().contains('not installed') ||
              e.toString().contains('unavailable')) {
            OseerLogger.info('Health Connect is not installed');
            return false;
          }
          // Other errors might mean it's installed but has other issues
        }
      } catch (e) {
        OseerLogger.warning('Error checking device info', e);
      }

      // Method 2: Try to verify one simple health data type
      if (!isAvailable) {
        try {
          final hasPermissions =
              await _health.hasPermissions([HealthDataType.STEPS]);
          if (hasPermissions != null) {
            OseerLogger.info(
                'Health Connect permission check: $hasPermissions');
            isAvailable = true;
          }
        } catch (e) {
          // If error is specifically about Health Connect not installed, return false
          if (e.toString().contains('not installed') ||
              e.toString().contains('unavailable')) {
            OseerLogger.info(
                'Health Connect is not installed based on permission check');
            return false;
          }
          // Otherwise, could be permissions or other issue
          OseerLogger.warning(
              'Error checking Health Connect via permissions', e);
        }
      }

      return isAvailable;
    } catch (e) {
      OseerLogger.error('Error checking Health Connect availability', e);
      return false;
    }
  }

  /// Get device information
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;

      return DeviceInfo(
        model: androidInfo.model,
        systemVersion: 'Android ${androidInfo.version.release}',
        name: androidInfo.device,
        identifier: androidInfo.id,
      );
    } catch (e) {
      OseerLogger.warning('Error getting device info', e);

      // Use fallback values
      return DeviceInfo(
        model: 'Android Device',
        systemVersion: 'Android',
        name: 'Android Device',
        identifier: _prefs.getString('device_id') ?? 'unknown',
      );
    }
  }

  /// Get device ID - creates one if it doesn't exist
  Future<String> getDeviceId() async {
    try {
      // Check if we already have a device ID
      final existingId = _prefs.getString('device_id');
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }

      // Generate a new device ID
      final deviceId = _uuid.v4();
      await _prefs.setString('device_id', deviceId);

      return deviceId;
    } catch (e) {
      // Fallback to a randomly generated ID
      final deviceId = _uuid.v4();
      OseerLogger.warning(
          'Error getting device ID, using fallback: $deviceId', e);
      return deviceId;
    }
  }

  /// Extract user profile data from Health Connect
  Future<UserProfile?> extractUserProfileData() async {
    try {
      OseerLogger.info(
          'Attempting to extract user profile data from Health Connect');

      // Check if Health Connect is available and we have permissions
      final isAvailable = await isWellnessConnectAvailable();
      if (!isAvailable) {
        OseerLogger.warning(
            'Health Connect is not available for profile data extraction');
        return _createDefaultUserProfile();
      }

      // Get available data types
      final availableTypes = await _getDeviceSupportedDataTypes();
      if (availableTypes.isEmpty) {
        OseerLogger.warning(
            'No available health data types found for profile extraction');
        return _createDefaultUserProfile();
      }

      // Check permissions
      final neededTypes = [
        HealthDataType.HEIGHT,
        HealthDataType.WEIGHT,
        HealthDataType.STEPS
      ].where((type) => availableTypes.contains(type)).toList();

      if (neededTypes.isEmpty) {
        OseerLogger.warning(
            'No needed health types are available on this device');
        return _createDefaultUserProfile();
      }

      bool hasAnyNeededType = false;

      for (final type in neededTypes) {
        try {
          final hasPermission = await _health.hasPermissions([type]);
          if (hasPermission == true) {
            hasAnyNeededType = true;
            break;
          }
        } catch (e) {
          // Ignore errors for individual checks
        }
      }

      if (!hasAnyNeededType) {
        OseerLogger.warning(
            'Insufficient permissions for profile data extraction');
        return _createDefaultUserProfile();
      }

      // Get any existing profile data as a starting point
      final existingProfile = _getUserProfileFromPrefs();

      // Prepare a data object to hold extracted values
      double? height;
      double? weight;
      String? gender;
      int? age;

      final now = DateTime.now();
      final startTime =
          now.subtract(const Duration(days: 30)); // Look at recent data

      try {
        // Try to get height data if available and permitted
        if (availableTypes.contains(HealthDataType.HEIGHT)) {
          try {
            final heightData = await _health.getHealthDataFromTypes(
              startTime: startTime,
              endTime: now,
              types: [HealthDataType.HEIGHT],
            );

            if (heightData.isNotEmpty) {
              for (final dataPoint in heightData) {
                final heightValue = double.tryParse(dataPoint.value.toString());
                if (heightValue != null) {
                  height = heightValue; // Store the most recent value
                  break;
                }
              }
            }
          } catch (e) {
            OseerLogger.warning('Error extracting height data', e);
          }
        }

        // Try to get weight data if available and permitted
        if (availableTypes.contains(HealthDataType.WEIGHT)) {
          try {
            final weightData = await _health.getHealthDataFromTypes(
              startTime: startTime,
              endTime: now,
              types: [HealthDataType.WEIGHT],
            );

            if (weightData.isNotEmpty) {
              for (final dataPoint in weightData) {
                final weightValue = double.tryParse(dataPoint.value.toString());
                if (weightValue != null) {
                  weight = weightValue; // Store the most recent value
                  break;
                }
              }
            }
          } catch (e) {
            OseerLogger.warning('Error extracting weight data', e);
          }
        }
      } catch (e) {
        OseerLogger.warning('Error extracting specific health data', e);
        // Continue with whatever data we managed to get
      }

      // Determine activity level based on step data (if available)
      String? activityLevel;
      if (availableTypes.contains(HealthDataType.STEPS)) {
        try {
          final stepData = await _health.getHealthDataFromTypes(
            startTime: startTime,
            endTime: now,
            types: [HealthDataType.STEPS],
          );

          if (stepData.isNotEmpty) {
            // Calculate approximate daily average
            int totalSteps = 0;
            for (final dataPoint in stepData) {
              final steps = int.tryParse(dataPoint.value.toString());
              if (steps != null) {
                totalSteps += steps;
              }
            }

            // Get the number of days in the data
            final daysInData = stepData.isNotEmpty
                ? max(1, now.difference(stepData.first.dateFrom).inDays)
                : 7;

            final avgDailySteps = totalSteps / daysInData;

            // Determine activity level based on average steps
            if (avgDailySteps < 5000) {
              activityLevel = 'Sedentary';
            } else if (avgDailySteps < 7500) {
              activityLevel = 'Light';
            } else if (avgDailySteps < 10000) {
              activityLevel = 'Moderate';
            } else if (avgDailySteps < 12500) {
              activityLevel = 'Active';
            } else {
              activityLevel = 'Very Active';
            }
          }
        } catch (e) {
          OseerLogger.info(
              'Step data not available for activity level estimation');
        }
      }

      // Create profile with the data we've extracted
      final extractedProfile = UserProfile(
        // Use existing profile data for name and email
        name: existingProfile?.name ?? '',
        email: existingProfile?.email ?? '',
        phone: existingProfile?.phone,

        // Use newly extracted data for health metrics
        height: height,
        weight: weight,
        gender: gender,
        age: age,
        activityLevel: activityLevel,
      );

      // Check if we actually extracted any useful data
      final hasExtractedData =
          height != null || weight != null || activityLevel != null;

      // Only return the profile if we found some data or if we already have a base profile
      if (hasExtractedData ||
          (existingProfile != null && existingProfile.name.isNotEmpty)) {
        OseerLogger.info(
            'Successfully extracted user profile data from Health Connect');
        OseerLogger.info(
            'Extracted profile: height=$height, weight=$weight, gender=$gender, age=$age, activityLevel=$activityLevel');

        return extractedProfile;
      } else {
        OseerLogger.warning('Extracted profile contained no useful data');
        return _createDefaultUserProfile();
      }
    } catch (e) {
      OseerLogger.error(
          'Error extracting user profile data from Health Connect', e);
      return _createDefaultUserProfile();
    }
  }

  // Create a default user profile when extraction fails
  UserProfile _createDefaultUserProfile() {
    return UserProfile(
      name: _prefs.getString(OseerConstants.keyUserName) ?? '',
      email: _prefs.getString(OseerConstants.keyUserEmail) ?? '',
    );
  }

  // Get user profile from preferences
  UserProfile? _getUserProfileFromPrefs() {
    final userName = _prefs.getString(OseerConstants.keyUserName);
    final userEmail = _prefs.getString(OseerConstants.keyUserEmail);
    final userPhone = _prefs.getString(OseerConstants.keyUserPhone);

    // Return null if required fields are missing
    if (userName == null || userEmail == null) {
      return null;
    }

    return UserProfile(
      name: userName,
      email: userEmail,
      phone: userPhone,
      age: _prefs.getInt(OseerConstants.keyUserAge),
      gender: _prefs.getString(OseerConstants.keyUserGender),
      height: _prefs.getDouble(OseerConstants.keyUserHeight),
      weight: _prefs.getDouble(OseerConstants.keyUserWeight),
      activityLevel: _prefs.getString(OseerConstants.keyUserActivityLevel),
    );
  }
}

// Extension method to convert DateTime to ISO8601 string
extension DateTimeExtension on DateTime {
  String toISOString() {
    return toIso8601String();
  }
}

// Math.max implementation for Dart
int max(int a, int b) {
  return a > b ? a : b;
}
