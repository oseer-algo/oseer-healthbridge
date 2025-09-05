// lib/models/health_data.dart
import 'package:flutter/foundation.dart'; // For kDebugMode if needed

/// Contains health/wellness data structures and helper methods

/// Represents a collection of health data for a specific user
/// NOTE: This specific structure might not be used directly if sending ProcessedHealthDataPoint list.
@immutable // Make immutable
class HealthDataCollection {
  final String userId;
  final DateTime timestamp;
  final List<HealthDataPoint>
      dataPoints; // Uses your HealthDataPoint model below

  const HealthDataCollection({
    // Use const constructor
    required this.userId,
    required this.timestamp,
    required this.dataPoints,
  });

  /// Convert to JSON for API submission (if this specific structure is needed)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'timestamp': timestamp.toUtc().toIso8601String(), // Use UTC standard
      'data_points': dataPoints.map((point) => point.toJson()).toList(),
    };
  }
}

/// Represents a single health/wellness data point (as defined in your file).
/// NOTE: This is distinct from the `HealthDataPoint` from the `health` package
/// and the `ProcessedHealthDataPoint` used for API transmission.
@immutable // Make immutable
class HealthDataPoint {
  final String type; // Should ideally align with HealthDataType names
  final String unit; // Should ideally align with HealthDataUnit names
  final dynamic value; // Keep dynamic, but ensure serialization is safe
  final DateTime dateFrom;
  final DateTime dateTo;
  final String sourceId;
  final String sourceName;

  const HealthDataPoint({
    // Use const constructor
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
    // WARNING: value.toString() is generally unsafe for complex types (like Workout) or numbers.
    // Consider more specific serialization based on `type` or ensure `value` is always a simple type.
    // Using ProcessedHealthDataPoint.toJson is usually safer for API calls.
    return {
      'type': type,
      'unit': unit,
      'value': value
          .toString(), // Potential issue: Might not be correct JSON representation
      'date_from': dateFrom.toUtc().toIso8601String(), // Use UTC standard
      'date_to': dateTo.toUtc().toIso8601String(), // Use UTC standard
      'source_id': sourceId,
      'source_name': sourceName,
    };
  }
}

/// Represents a wellness report (keep as is, assuming it matches API)
@immutable // Make immutable
class WellnessReport {
  final String userId;
  final DateTime timestamp;
  final Map<String, dynamic> metrics;
  final List<String> insights;
  final List<String> recommendations;

  const WellnessReport({
    // Use const constructor
    required this.userId,
    required this.timestamp,
    required this.metrics,
    required this.insights,
    required this.recommendations,
  });

  /// Convert from API response
  factory WellnessReport.fromJson(Map<String, dynamic> json) {
    // Add error handling for parsing
    try {
      return WellnessReport(
        userId: json['user_id'] as String? ?? '', // Handle potential null
        timestamp: DateTime.parse(json['timestamp'] as String? ??
            ''), // Handle potential null/format error
        metrics: json['metrics'] as Map<String, dynamic>? ??
            {}, // Handle potential null
        insights: List<String>.from(json['insights'] as List? ??
            []), // Handle potential null/type error
        recommendations: List<String>.from(json['recommendations'] as List? ??
            []), // Handle potential null/type error
      );
    } catch (e) {
      print("Error parsing WellnessReport: $e, JSON: $json"); // Log error
      // Return a default/empty report or rethrow
      throw FormatException("Failed to parse WellnessReport JSON: $e");
    }
  }
}

/// Helper class for categorizing health data types (keep as is)
class HealthDataCategories {
  // Activity data
  static const List<String> activity = [/* ... */];
  // Vital signs
  static const List<String> vitalSigns = [/* ... */];
  // Sleep data
  static const List<String> sleep = [/* ... */];
  // Body measurements
  static const List<String> bodyMeasurements = [/* ... */];
}
