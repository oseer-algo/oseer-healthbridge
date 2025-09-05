// lib/models/sync_progress.dart

import 'package:equatable/equatable.dart';

/// Detailed stages for sync progress
enum SyncStage { fetching, processing, uploading, analyzing }

/// Represents the progress of wellness data sync with phase tracking
class SyncProgress extends Equatable {
  /// Total data points to process
  final int totalDataPoints;

  /// Data points processed so far
  final int processedDataPoints;

  /// Successfully uploaded data points
  final int successfulUploads;

  /// When the sync started
  final DateTime? syncStartTime;

  /// Current activity description
  final String currentActivity;

  /// Whether the sync is complete
  final bool isComplete;

  /// Whether there's an error
  final bool isError;

  /// Error message if any
  final String? errorMessage;

  /// Last update time
  final DateTime? lastUpdateTime;

  /// Metadata for additional context
  final Map<String, dynamic> metadata;

  /// Current wellness phase
  final String? currentPhase; // 'bodyPrep', 'digitalTwin', 'complete'

  /// Body Prep progress (0.0 to 1.0)
  final double? bodyPrepProgress;

  /// Digital Twin progress (0.0 to 1.0)
  final double? digitalTwinProgress;

  /// Digital Twin days processed (0 to 90)
  final int? digitalTwinDaysProcessed;

  /// When Body Prep will be ready
  final DateTime? bodyPrepReadyTime;

  /// Metrics found during sync
  final Map<String, bool>? metricsFound;

  /// Current stage of sync process
  final SyncStage? stage;

  const SyncProgress({
    this.totalDataPoints = 0,
    this.processedDataPoints = 0,
    this.successfulUploads = 0,
    this.syncStartTime,
    this.currentActivity = '',
    this.isComplete = false,
    this.isError = false,
    this.errorMessage,
    this.lastUpdateTime,
    this.metadata = const {},
    this.currentPhase,
    this.bodyPrepProgress,
    this.digitalTwinProgress,
    this.digitalTwinDaysProcessed,
    this.bodyPrepReadyTime,
    this.metricsFound,
    this.stage,
  });

  /// Create an initial sync progress
  factory SyncProgress.initial() {
    return SyncProgress(
      currentActivity: 'Ready to begin your wellness assessment',
      syncStartTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
      currentPhase: 'bodyPrep',
      bodyPrepProgress: 0.0,
      digitalTwinProgress: 0.0,
      digitalTwinDaysProcessed: 0,
      metricsFound: const {},
    );
  }

  /// Create Body Prep phase progress
  factory SyncProgress.bodyPrep({
    required double progress,
    required int processed,
    required int total,
    DateTime? readyTime,
    Map<String, bool>? metricsFound,
    SyncStage? stage,
  }) {
    return SyncProgress(
      currentPhase: 'bodyPrep',
      bodyPrepProgress: progress,
      totalDataPoints: total,
      processedDataPoints: processed,
      currentActivity: 'Analyzing your recent wellness data...',
      syncStartTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
      bodyPrepReadyTime: readyTime,
      metricsFound: metricsFound ?? const {},
      stage: stage,
    );
  }

  /// Create Digital Twin phase progress
  factory SyncProgress.digitalTwin({
    required int daysProcessed,
    required double progress,
    required int processed,
    required int total,
    DateTime? estimatedCompletion,
  }) {
    return SyncProgress(
      currentPhase: 'digitalTwin',
      digitalTwinProgress: progress,
      digitalTwinDaysProcessed: daysProcessed,
      totalDataPoints: total,
      processedDataPoints: processed,
      currentActivity: 'Building your Digital Twin...',
      syncStartTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
      metadata: {
        'estimatedCompletion': estimatedCompletion?.toIso8601String(),
      },
    );
  }

  /// Create error sync progress
  factory SyncProgress.error(String errorMessage) {
    return SyncProgress(
      isError: true,
      isComplete: true,
      currentActivity: 'Wellness assessment encountered an error',
      errorMessage: errorMessage,
      lastUpdateTime: DateTime.now(),
    );
  }

  /// Get the percentage as an integer (0-100)
  int get percentageInt {
    if (totalDataPoints <= 0) return 0;
    return ((processedDataPoints / totalDataPoints) * 100)
        .round()
        .clamp(0, 100);
  }

  /// Get the percentage as a double (0.0-1.0)
  double get progressPercentage {
    if (totalDataPoints <= 0) return 0.0;
    return (processedDataPoints / totalDataPoints).clamp(0.0, 1.0);
  }

  /// Get sync duration if sync has started
  Duration? get syncDuration {
    if (syncStartTime != null) {
      final endTime =
          isComplete ? (lastUpdateTime ?? DateTime.now()) : DateTime.now();
      return endTime.difference(syncStartTime!);
    }
    return null;
  }

  /// Get a user-friendly status message
  String get statusMessage {
    if (isError) {
      return errorMessage ?? 'Wellness assessment failed';
    }

    if (isComplete) {
      return 'Wellness assessment completed successfully';
    }

    if (currentPhase == 'bodyPrep') {
      return 'Preparing your Body Preparedness score...';
    } else if (currentPhase == 'digitalTwin') {
      return 'Creating your Digital Twin companion...';
    }

    return currentActivity;
  }

  /// Calculate processing rate (records per second)
  double get processingRate {
    if (syncStartTime != null && processedDataPoints > 0) {
      final duration = DateTime.now().difference(syncStartTime!);
      final seconds = duration.inSeconds;
      return seconds > 0 ? processedDataPoints / seconds : 0.0;
    }
    return 0.0;
  }

  /// Estimate completion time based on current rate
  DateTime? get estimatedCompletionTime {
    if (totalDataPoints > 0 && processedDataPoints > 0 && processingRate > 0) {
      final remainingRecords = totalDataPoints - processedDataPoints;
      final remainingSeconds = remainingRecords / processingRate;
      return DateTime.now().add(Duration(seconds: remainingSeconds.round()));
    }

    // Return from metadata if available
    if (metadata['estimatedCompletion'] != null) {
      return DateTime.tryParse(metadata['estimatedCompletion'] as String);
    }

    return null;
  }

  @override
  List<Object?> get props => [
        totalDataPoints,
        processedDataPoints,
        successfulUploads,
        syncStartTime,
        currentActivity,
        isComplete,
        isError,
        errorMessage,
        lastUpdateTime,
        metadata,
        currentPhase,
        bodyPrepProgress,
        digitalTwinProgress,
        digitalTwinDaysProcessed,
        bodyPrepReadyTime,
        metricsFound,
        stage,
      ];

  /// Create a copy with updated values
  SyncProgress copyWith({
    int? totalDataPoints,
    int? processedDataPoints,
    int? successfulUploads,
    DateTime? syncStartTime,
    String? currentActivity,
    bool? isComplete,
    bool? isError,
    String? errorMessage,
    DateTime? lastUpdateTime,
    Map<String, dynamic>? metadata,
    String? currentPhase,
    double? bodyPrepProgress,
    double? digitalTwinProgress,
    int? digitalTwinDaysProcessed,
    DateTime? bodyPrepReadyTime,
    Map<String, bool>? metricsFound,
    SyncStage? stage,
  }) {
    return SyncProgress(
      totalDataPoints: totalDataPoints ?? this.totalDataPoints,
      processedDataPoints: processedDataPoints ?? this.processedDataPoints,
      successfulUploads: successfulUploads ?? this.successfulUploads,
      syncStartTime: syncStartTime ?? this.syncStartTime,
      currentActivity: currentActivity ?? this.currentActivity,
      isComplete: isComplete ?? this.isComplete,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      metadata: metadata ?? this.metadata,
      currentPhase: currentPhase ?? this.currentPhase,
      bodyPrepProgress: bodyPrepProgress ?? this.bodyPrepProgress,
      digitalTwinProgress: digitalTwinProgress ?? this.digitalTwinProgress,
      digitalTwinDaysProcessed:
          digitalTwinDaysProcessed ?? this.digitalTwinDaysProcessed,
      bodyPrepReadyTime: bodyPrepReadyTime ?? this.bodyPrepReadyTime,
      metricsFound: metricsFound ?? this.metricsFound,
      stage: stage ?? this.stage,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalDataPoints': totalDataPoints,
      'processedDataPoints': processedDataPoints,
      'successfulUploads': successfulUploads,
      'syncStartTime': syncStartTime?.toIso8601String(),
      'currentActivity': currentActivity,
      'isComplete': isComplete,
      'isError': isError,
      'errorMessage': errorMessage,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'metadata': metadata,
      'currentPhase': currentPhase,
      'bodyPrepProgress': bodyPrepProgress,
      'digitalTwinProgress': digitalTwinProgress,
      'digitalTwinDaysProcessed': digitalTwinDaysProcessed,
      'bodyPrepReadyTime': bodyPrepReadyTime?.toIso8601String(),
      'metricsFound': metricsFound,
      'stage': stage?.name,
    };
  }

  /// Create from JSON
  factory SyncProgress.fromJson(Map<String, dynamic> json) {
    return SyncProgress(
      totalDataPoints: json['totalDataPoints'] ?? 0,
      processedDataPoints: json['processedDataPoints'] ?? 0,
      successfulUploads: json['successfulUploads'] ?? 0,
      syncStartTime: json['syncStartTime'] != null
          ? DateTime.parse(json['syncStartTime'])
          : null,
      currentActivity: json['currentActivity'] ?? '',
      isComplete: json['isComplete'] ?? false,
      isError: json['isError'] ?? false,
      errorMessage: json['errorMessage'],
      lastUpdateTime: json['lastUpdateTime'] != null
          ? DateTime.parse(json['lastUpdateTime'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      currentPhase: json['currentPhase'],
      bodyPrepProgress: json['bodyPrepProgress']?.toDouble(),
      digitalTwinProgress: json['digitalTwinProgress']?.toDouble(),
      digitalTwinDaysProcessed: json['digitalTwinDaysProcessed'],
      bodyPrepReadyTime: json['bodyPrepReadyTime'] != null
          ? DateTime.parse(json['bodyPrepReadyTime'])
          : null,
      metricsFound: json['metricsFound'] != null
          ? Map<String, bool>.from(json['metricsFound'])
          : null,
      stage: json['stage'] != null
          ? SyncStage.values.firstWhere((e) => e.name == json['stage'])
          : null,
    );
  }
}
