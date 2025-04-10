// File path: lib/models/health_data.dart

/// Contains health/wellness data structures and helper methods

/// Represents a collection of health data for a specific user
class HealthDataCollection {
  final String userId;
  final DateTime timestamp;
  final List<HealthDataPoint> dataPoints;

  HealthDataCollection({
    required this.userId,
    required this.timestamp,
    required this.dataPoints,
  });

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'data_points': dataPoints.map((point) => point.toJson()).toList(),
    };
  }
}

/// Represents a single health/wellness data point
class HealthDataPoint {
  final String type;
  final String unit;
  final dynamic value;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String sourceId;
  final String sourceName;

  HealthDataPoint({
    required this.type,
    required this.unit,
    required this.value,
    required this.dateFrom,
    required this.dateTo,
    required this.sourceId,
    required this.sourceName,
  });

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'unit': unit,
      'value': value.toString(),
      'date_from': dateFrom.toIso8601String(),
      'date_to': dateTo.toIso8601String(),
      'source_id': sourceId,
      'source_name': sourceName,
    };
  }
}

/// Represents a wellness report with processed metrics and insights
class WellnessReport {
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> metrics;
  final List<String> insights;
  final List<String> recommendations;

  WellnessReport({
    required this.userId,
    required this.timestamp,
    required this.metrics,
    required this.insights,
    required this.recommendations,
  });

  /// Convert from API response
  factory WellnessReport.fromJson(Map<String, dynamic> json) {
    return WellnessReport(
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      metrics: json['metrics'],
      insights: List<String>.from(json['insights']),
      recommendations: List<String>.from(json['recommendations']),
    );
  }
}

/// Helper class for categorizing health data types
class HealthDataCategories {
  // Activity data
  static const List<String> activity = [
    'STEPS',
    'ACTIVE_ENERGY_BURNED',
    'DISTANCE_WALKING_RUNNING',
    'WORKOUT',
  ];

  // Vital signs
  static const List<String> vitalSigns = [
    'HEART_RATE',
    'HEART_RATE_VARIABILITY_SDNN',
    'BLOOD_PRESSURE_SYSTOLIC',
    'BLOOD_PRESSURE_DIASTOLIC',
    'BODY_TEMPERATURE',
    'BLOOD_OXYGEN',
    'RESPIRATORY_RATE',
  ];

  // Sleep data
  static const List<String> sleep = [
    'SLEEP_ASLEEP',
    'SLEEP_AWAKE',
    'SLEEP_IN_BED',
  ];

  // Body measurements
  static const List<String> bodyMeasurements = [
    'WEIGHT',
    'HEIGHT',
    'BODY_MASS_INDEX',
    'BODY_FAT_PERCENTAGE',
  ];
}
