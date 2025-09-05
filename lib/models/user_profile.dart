// lib/models/user_profile.dart
import 'package:equatable/equatable.dart';

import '../services/logger_service.dart';

/// User profile data model with validation rules
class UserProfile extends Equatable {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final String? activityLevel;
  final String? deviceId;
  final String? platformType;
  final String? deviceModel;
  final String? osVersion;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.activityLevel,
    this.deviceId,
    this.platformType,
    this.deviceModel,
    this.osVersion,
  });

  /// Copy with method for creating updated instances
  UserProfile copyWith({
    String? userId,
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    String? deviceId,
    String? platformType,
    String? deviceModel,
    String? osVersion,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      deviceId: deviceId ?? this.deviceId,
      platformType: platformType ?? this.platformType,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
    );
  }

  /// Convert from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      height:
          json['height'] != null ? (json['height'] as num).toDouble() : null,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      activityLevel:
          json['activity_level'] as String? ?? json['activityLevel'] as String?,
      deviceId: json['device_id'] as String? ?? json['deviceId'] as String?,
      platformType:
          json['platform_type'] as String? ?? json['platformType'] as String?,
      deviceModel:
          json['device_model'] as String? ?? json['deviceModel'] as String?,
      osVersion: json['os_version'] as String? ?? json['osVersion'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (deviceId != null) 'device_id': deviceId,
      if (platformType != null) 'platform_type': platformType,
      if (deviceModel != null) 'device_model': deviceModel,
      if (osVersion != null) 'os_version': osVersion,
    };
  }

  /// Check if profile has all expected fields from server
  bool isServerDataComplete() {
    // More lenient check for server data - allows missing optional fields
    final serverRequiredFields = {
      'userId': userId.isNotEmpty,
      'name': name.isNotEmpty,
      'email': email.isNotEmpty && hasValidEmail(),
    };

    final serverExpectedFields = {
      'age': age != null && age! > 0 && age! <= 120,
      'gender': gender != null && gender!.isNotEmpty,
      'height': height != null && height! >= 50 && height! <= 250,
      'weight': weight != null && weight! >= 20 && weight! <= 500,
      'activityLevel': activityLevel != null && activityLevel!.isNotEmpty,
    };

    // Must have all required fields
    final hasRequiredFields =
        serverRequiredFields.values.every((isValid) => isValid);

    // Count how many expected fields we have
    final expectedFieldCount =
        serverExpectedFields.values.where((isValid) => isValid).length;

    // Consider complete if we have required fields and at least 3 out of 5 expected fields
    final isComplete = hasRequiredFields && expectedFieldCount >= 3;

    OseerLogger.debug(
        'Profile server data check - required: $hasRequiredFields, expected: $expectedFieldCount/5, complete: $isComplete');

    return isComplete;
  }

  /// Get list of fields that are expected but missing from server data
  List<String> getMissingFields() {
    final missing = <String>[];

    // Check required fields
    if (userId.isEmpty) missing.add('userId');
    if (name.isEmpty) missing.add('name');
    if (email.isEmpty || !hasValidEmail()) missing.add('email');

    // Check expected fields with validation
    if (age == null || age! <= 0 || age! > 120) missing.add('age');
    if (gender == null || gender!.isEmpty) missing.add('gender');
    if (height == null || height! < 50 || height! > 250) missing.add('height');
    if (weight == null || weight! < 20 || weight! > 500) missing.add('weight');
    if (activityLevel == null || activityLevel!.isEmpty)
      missing.add('activityLevel');

    return missing;
  }

  /// Check if profile is complete based on required fields for app functionality
  bool isComplete() {
    final conditions = {
      'userId': userId.isNotEmpty,
      'name': name.isNotEmpty,
      'email': email.isNotEmpty,
      'age': age != null,
      'gender': gender != null,
      'height': height != null,
      'weight': weight != null,
      'activityLevel': activityLevel != null,
    };

    // Log which conditions are failing for debugging
    conditions.forEach((field, isValid) {
      if (!isValid) {
        OseerLogger.debug('Profile incomplete: missing $field');
      }
    });

    return conditions.values.every((isValid) => isValid);
  }

  /// Check if profile has critical fields for wellness features
  bool hasRequiredHealthInfo() {
    return height != null && weight != null && age != null;
  }

  /// Validate email format
  bool hasValidEmail() {
    return email.contains('@') && email.contains('.');
  }

  /// Check if profile needs update
  bool needsUpdate() {
    return !isComplete() || !hasValidEmail();
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        email,
        phone,
        age,
        gender,
        height,
        weight,
        activityLevel,
        deviceId,
        platformType,
        deviceModel,
        osVersion,
      ];

  @override
  String toString() {
    return 'UserProfile(userId: $userId, name: $name, email: $email, age: $age, gender: $gender)';
  }
}
