// lib/models/sync_metrics.dart

import 'package:equatable/equatable.dart';

/// Simplified sync metrics for basic data transfer tracking
class SyncMetrics extends Equatable {
  /// Unique identifier for this sync session
  final String syncId;

  /// User ID associated with this sync
  final String userId;

  /// Device ID that performed the sync
  final String deviceId;

  /// When the sync started
  final DateTime startTime;

  /// When the sync ended (null if still in progress)
  final DateTime? endTime;

  /// Total number of records to be processed
  final int totalRecords;

  /// Number of records successfully processed
  final int processedRecords;

  /// Number of records that failed to process
  final int failedRecords;

  /// Data types that were synced
  final List<String> dataTypesSynced;

  /// Data types that failed to sync
  final List<String> dataTypesFailed;

  /// Current operation being performed
  final String? currentOperation;

  /// Progress percentage (0.0 to 1.0)
  final double progress;

  /// Number of retry attempts made
  final int retryCount;

  /// Error messages encountered
  final List<String> errorMessages;

  /// Basic performance metrics
  final SyncPerformanceMetrics performance;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  const SyncMetrics({
    required this.syncId,
    required this.userId,
    required this.deviceId,
    required this.startTime,
    this.endTime,
    this.totalRecords = 0,
    this.processedRecords = 0,
    this.failedRecords = 0,
    this.dataTypesSynced = const [],
    this.dataTypesFailed = const [],
    this.currentOperation,
    this.progress = 0.0,
    this.retryCount = 0,
    this.errorMessages = const [],
    this.performance = const SyncPerformanceMetrics(),
    this.metadata = const {},
  });

  /// Whether the sync is currently active
  bool get isActive => endTime == null;

  /// Whether the sync completed successfully
  bool get isSuccessful =>
      endTime != null && errorMessages.isEmpty && failedRecords == 0;

  /// Whether the sync failed
  bool get isFailed =>
      endTime != null && (errorMessages.isNotEmpty || failedRecords > 0);

  /// Duration of the sync (or current duration if still active)
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Success rate (processed / total)
  double get successRate {
    if (totalRecords == 0) return 1.0;
    return processedRecords / totalRecords;
  }

  /// Failure rate (failed / total)
  double get failureRate {
    if (totalRecords == 0) return 0.0;
    return failedRecords / totalRecords;
  }

  /// Records per second
  double get recordsPerSecond {
    final durationSeconds = duration.inSeconds;
    if (durationSeconds == 0) return 0.0;
    return processedRecords / durationSeconds;
  }

  /// Start a new sync
  factory SyncMetrics.start({
    required String syncId,
    required String userId,
    required String deviceId,
    int? totalRecords,
    String? currentOperation,
    Map<String, dynamic>? metadata,
  }) {
    return SyncMetrics(
      syncId: syncId,
      userId: userId,
      deviceId: deviceId,
      startTime: DateTime.now(),
      totalRecords: totalRecords ?? 0,
      currentOperation: currentOperation,
      metadata: metadata ?? {},
    );
  }

  /// Update progress
  SyncMetrics updateProgress({
    int? processedRecords,
    int? totalRecords,
    String? currentOperation,
    double? progress,
    List<String>? dataTypesSynced,
  }) {
    return copyWith(
      processedRecords: processedRecords ?? this.processedRecords,
      totalRecords: totalRecords ?? this.totalRecords,
      currentOperation: currentOperation ?? this.currentOperation,
      progress: progress ?? this.progress,
      dataTypesSynced: dataTypesSynced ?? this.dataTypesSynced,
    );
  }

  /// Record an error
  SyncMetrics recordError(String errorMessage) {
    final newErrors = List<String>.from(errorMessages)..add(errorMessage);
    return copyWith(
      errorMessages: newErrors,
      retryCount: retryCount + 1,
    );
  }

  /// Record failed records
  SyncMetrics recordFailedRecords(int count, {String? dataType}) {
    var newFailedDataTypes = List<String>.from(dataTypesFailed);
    if (dataType != null && !newFailedDataTypes.contains(dataType)) {
      newFailedDataTypes.add(dataType);
    }

    return copyWith(
      failedRecords: failedRecords + count,
      dataTypesFailed: newFailedDataTypes,
    );
  }

  /// Complete the sync
  SyncMetrics complete({
    bool? success,
    String? finalOperation,
    SyncPerformanceMetrics? finalPerformance,
  }) {
    return copyWith(
      endTime: DateTime.now(),
      progress: 1.0,
      currentOperation: finalOperation ?? 'Completed',
      performance: finalPerformance ?? performance,
    );
  }

  /// Update performance metrics
  SyncMetrics updatePerformance(SyncPerformanceMetrics newPerformance) {
    return copyWith(performance: newPerformance);
  }

  /// Add metadata
  SyncMetrics addMetadata(String key, dynamic value) {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata[key] = value;
    return copyWith(metadata: newMetadata);
  }

  @override
  List<Object?> get props => [
        syncId,
        userId,
        deviceId,
        startTime,
        endTime,
        totalRecords,
        processedRecords,
        failedRecords,
        dataTypesSynced,
        dataTypesFailed,
        currentOperation,
        progress,
        retryCount,
        errorMessages,
        performance,
        metadata,
      ];

  /// Copy with new values
  SyncMetrics copyWith({
    String? syncId,
    String? userId,
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int? totalRecords,
    int? processedRecords,
    int? failedRecords,
    List<String>? dataTypesSynced,
    List<String>? dataTypesFailed,
    String? currentOperation,
    double? progress,
    int? retryCount,
    List<String>? errorMessages,
    SyncPerformanceMetrics? performance,
    Map<String, dynamic>? metadata,
  }) {
    return SyncMetrics(
      syncId: syncId ?? this.syncId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalRecords: totalRecords ?? this.totalRecords,
      processedRecords: processedRecords ?? this.processedRecords,
      failedRecords: failedRecords ?? this.failedRecords,
      dataTypesSynced: dataTypesSynced ?? this.dataTypesSynced,
      dataTypesFailed: dataTypesFailed ?? this.dataTypesFailed,
      currentOperation: currentOperation ?? this.currentOperation,
      progress: progress ?? this.progress,
      retryCount: retryCount ?? this.retryCount,
      errorMessages: errorMessages ?? this.errorMessages,
      performance: performance ?? this.performance,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'syncId': syncId,
      'userId': userId,
      'deviceId': deviceId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalRecords': totalRecords,
      'processedRecords': processedRecords,
      'failedRecords': failedRecords,
      'dataTypesSynced': dataTypesSynced,
      'dataTypesFailed': dataTypesFailed,
      'currentOperation': currentOperation,
      'progress': progress,
      'retryCount': retryCount,
      'errorMessages': errorMessages,
      'performance': performance.toJson(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory SyncMetrics.fromJson(Map<String, dynamic> json) {
    return SyncMetrics(
      syncId: json['syncId'],
      userId: json['userId'],
      deviceId: json['deviceId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      totalRecords: json['totalRecords'] ?? 0,
      processedRecords: json['processedRecords'] ?? 0,
      failedRecords: json['failedRecords'] ?? 0,
      dataTypesSynced: List<String>.from(json['dataTypesSynced'] ?? []),
      dataTypesFailed: List<String>.from(json['dataTypesFailed'] ?? []),
      currentOperation: json['currentOperation'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      retryCount: json['retryCount'] ?? 0,
      errorMessages: List<String>.from(json['errorMessages'] ?? []),
      performance: json['performance'] != null
          ? SyncPerformanceMetrics.fromJson(json['performance'])
          : const SyncPerformanceMetrics(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Basic performance metrics for sync operations
class SyncPerformanceMetrics extends Equatable {
  /// Total bytes transferred
  final int bytesTransferred;

  /// Average transfer speed in bytes per second
  final double transferSpeedBps;

  /// Number of API calls made
  final int apiCalls;

  /// Number of successful API calls
  final int successfulApiCalls;

  /// Number of failed API calls
  final int failedApiCalls;

  /// Average API response time in milliseconds
  final double averageResponseTimeMs;

  /// Network type used (wifi, cellular, etc.)
  final String? networkType;

  const SyncPerformanceMetrics({
    this.bytesTransferred = 0,
    this.transferSpeedBps = 0.0,
    this.apiCalls = 0,
    this.successfulApiCalls = 0,
    this.failedApiCalls = 0,
    this.averageResponseTimeMs = 0.0,
    this.networkType,
  });

  /// API success rate
  double get apiSuccessRate {
    if (apiCalls == 0) return 1.0;
    return successfulApiCalls / apiCalls;
  }

  /// Transfer speed in MB/s
  double get transferSpeedMbps {
    return transferSpeedBps / (1024 * 1024);
  }

  /// Copy with new values
  SyncPerformanceMetrics copyWith({
    int? bytesTransferred,
    double? transferSpeedBps,
    int? apiCalls,
    int? successfulApiCalls,
    int? failedApiCalls,
    double? averageResponseTimeMs,
    String? networkType,
  }) {
    return SyncPerformanceMetrics(
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      transferSpeedBps: transferSpeedBps ?? this.transferSpeedBps,
      apiCalls: apiCalls ?? this.apiCalls,
      successfulApiCalls: successfulApiCalls ?? this.successfulApiCalls,
      failedApiCalls: failedApiCalls ?? this.failedApiCalls,
      averageResponseTimeMs:
          averageResponseTimeMs ?? this.averageResponseTimeMs,
      networkType: networkType ?? this.networkType,
    );
  }

  @override
  List<Object?> get props => [
        bytesTransferred,
        transferSpeedBps,
        apiCalls,
        successfulApiCalls,
        failedApiCalls,
        averageResponseTimeMs,
        networkType,
      ];

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'bytesTransferred': bytesTransferred,
      'transferSpeedBps': transferSpeedBps,
      'apiCalls': apiCalls,
      'successfulApiCalls': successfulApiCalls,
      'failedApiCalls': failedApiCalls,
      'averageResponseTimeMs': averageResponseTimeMs,
      'networkType': networkType,
    };
  }

  /// Create from JSON
  factory SyncPerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return SyncPerformanceMetrics(
      bytesTransferred: json['bytesTransferred'] ?? 0,
      transferSpeedBps: (json['transferSpeedBps'] ?? 0.0).toDouble(),
      apiCalls: json['apiCalls'] ?? 0,
      successfulApiCalls: json['successfulApiCalls'] ?? 0,
      failedApiCalls: json['failedApiCalls'] ?? 0,
      averageResponseTimeMs: (json['averageResponseTimeMs'] ?? 0.0).toDouble(),
      networkType: json['networkType'],
    );
  }
}

/// Simple aggregated metrics for historical analysis
class SyncHistoryMetrics extends Equatable {
  /// Time period these metrics cover
  final DateTime startDate;
  final DateTime endDate;

  /// Total number of syncs performed
  final int totalSyncs;

  /// Number of successful syncs
  final int successfulSyncs;

  /// Number of failed syncs
  final int failedSyncs;

  /// Average sync duration
  final Duration averageDuration;

  /// Total records synced
  final int totalRecordsSynced;

  /// Average records per sync
  final double averageRecordsPerSync;

  /// Most common failure reasons
  final Map<String, int> failureReasons;

  const SyncHistoryMetrics({
    required this.startDate,
    required this.endDate,
    this.totalSyncs = 0,
    this.successfulSyncs = 0,
    this.failedSyncs = 0,
    this.averageDuration = Duration.zero,
    this.totalRecordsSynced = 0,
    this.averageRecordsPerSync = 0.0,
    this.failureReasons = const {},
  });

  /// Success rate (successful / total)
  double get successRate {
    if (totalSyncs == 0) return 1.0;
    return successfulSyncs / totalSyncs;
  }

  /// Failure rate (failed / total)
  double get failureRate {
    if (totalSyncs == 0) return 0.0;
    return failedSyncs / totalSyncs;
  }

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        totalSyncs,
        successfulSyncs,
        failedSyncs,
        averageDuration,
        totalRecordsSynced,
        averageRecordsPerSync,
        failureReasons,
      ];

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalSyncs': totalSyncs,
      'successfulSyncs': successfulSyncs,
      'failedSyncs': failedSyncs,
      'averageDuration': averageDuration.inMilliseconds,
      'totalRecordsSynced': totalRecordsSynced,
      'averageRecordsPerSync': averageRecordsPerSync,
      'failureReasons': failureReasons,
    };
  }

  /// Create from JSON
  factory SyncHistoryMetrics.fromJson(Map<String, dynamic> json) {
    return SyncHistoryMetrics(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      totalSyncs: json['totalSyncs'] ?? 0,
      successfulSyncs: json['successfulSyncs'] ?? 0,
      failedSyncs: json['failedSyncs'] ?? 0,
      averageDuration: Duration(milliseconds: json['averageDuration'] ?? 0),
      totalRecordsSynced: json['totalRecordsSynced'] ?? 0,
      averageRecordsPerSync: (json['averageRecordsPerSync'] ?? 0.0).toDouble(),
      failureReasons: Map<String, int>.from(json['failureReasons'] ?? {}),
    );
  }
}
