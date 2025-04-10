// File path: lib/models/user_profile.dart

/// Model class for user profile information
class UserProfile {
  /// User's full name
  final String name;

  /// User's email address
  final String email;

  /// Optional phone number
  final String? phone;

  /// Optional age
  final int? age;

  /// Optional gender (male, female, other, prefer not to say)
  final String? gender;

  /// Optional height in cm
  final double? height;

  /// Optional weight in kg
  final double? weight;

  /// Optional activity level
  final String? activityLevel;

  /// Constructor
  UserProfile({
    required this.name,
    required this.email,
    this.phone,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.activityLevel,
  });

  /// Create a profile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      age: json['age'] != null ? int.tryParse(json['age'].toString()) : null,
      gender: json['gender'] as String?,
      height: json['height'] != null
          ? double.tryParse(json['height'].toString())
          : null,
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString())
          : null,
      activityLevel: json['activity_level'] as String?,
    );
  }

  /// Convert profile to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (activityLevel != null) 'activity_level': activityLevel,
    };
  }

  /// Create a copy of this profile with modified fields
  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }

  /// Create a profile with minimal information
  static UserProfile minimal(String name, String email) {
    return UserProfile(
      name: name,
      email: email,
    );
  }

  /// Check if the profile has enough information for token generation
  bool hasRequiredInfo() {
    return name.isNotEmpty && email.isNotEmpty;
  }

  /// Load profile from SharedPreferences
  static UserProfile? fromPrefs(Map<String, dynamic> data) {
    if (!data.containsKey('name') || !data.containsKey('email')) {
      return null;
    }

    return UserProfile(
      name: data['name'] as String,
      email: data['email'] as String,
      phone: data['phone'] as String?,
      age: data['age'] != null ? int.tryParse(data['age'].toString()) : null,
      gender: data['gender'] as String?,
      height: data['height'] != null
          ? double.tryParse(data['height'].toString())
          : null,
      weight: data['weight'] != null
          ? double.tryParse(data['weight'].toString())
          : null,
      activityLevel: data['activity_level'] as String?,
    );
  }

  /// Check if the profile is complete with recommended fields
  bool isComplete() {
    return name.isNotEmpty && email.isNotEmpty && age != null && gender != null;
  }
}
