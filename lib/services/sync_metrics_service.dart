// lib/services/sync_metrics_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'secure_storage_service.dart';
import 'logger_service.dart';

/// Simplified service for tracking basic sync metrics
/// Focused on health data extraction and upload statistics only
class SyncMetricsService {
  static const String _metricsHistoryKey = 'sync_metrics_history';
  static const int _maxHistoryEntries = 50;

  final SecureStorageService _secureStorage;
  final LoggerService _logger;
  final Connectivity _connectivity = Connectivity();

  /// Stream controller for metrics updates
  final _metricsController = StreamController<SyncMetric>.broadcast();
  Stream<SyncMetric> get metricsStream => _metricsController.stream;

  SyncMetricsService({
    required SecureStorageService secureStorage,
    required LoggerService logger,
  })  : _secureStorage = secureStorage,
        _logger = logger;

  /// Initialize the metrics service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing sync metrics service');
      // Cleanup old metrics on startup
      await _cleanupOldMetrics();
      _logger.info('Sync metrics service initialized');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize sync metrics service', e, stackTrace);
    }
  }

  /// Record a connection event
  Future<void> recordConnectionEvent(
    String eventType,
    DateTime timestamp,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      final metric = SyncMetric(
        timestamp: timestamp,
        dataType: 'connection_event',
        dataSize: eventData.toString().length,
        isSuccess:
            !eventType.contains('error') && !eventType.contains('failed'),
        errorType: eventType.contains('error') || eventType.contains('failed')
            ? eventType
            : null,
        errorMessage: eventData['error_message']?.toString(),
        networkType: connectivityResult.name,
      );

      // Add to history
      await _addToHistory(metric);

      // Emit update
      _metricsController.add(metric);

      _logger.info('Recorded connection event: $eventType');
    } catch (e, stackTrace) {
      _logger.error('Failed to record connection event', e, stackTrace);
    }
  }

  /// Record a data upload event
  Future<void> recordDataUpload(int dataSize, String dataType) async {
    try {
      // Create metric
      final now = DateTime.now();
      final connectivityResult = await _connectivity.checkConnectivity();

      final metric = SyncMetric(
        timestamp: now,
        dataType: dataType,
        dataSize: dataSize,
        isSuccess: true,
        networkType: connectivityResult.name,
      );

      // Add to history
      await _addToHistory(metric);

      // Emit update
      _metricsController.add(metric);

      _logger.info('Recorded data upload: $dataSize bytes of $dataType');
    } catch (e, stackTrace) {
      _logger.error('Failed to record data upload', e, stackTrace);
    }
  }

  /// Record a sync error
  Future<void> recordSyncError(String errorType, String message) async {
    try {
      // Create metric
      final now = DateTime.now();
      final connectivityResult = await _connectivity.checkConnectivity();

      final metric = SyncMetric(
        timestamp: now,
        dataType: 'error',
        dataSize: 0,
        isSuccess: false,
        errorType: errorType,
        errorMessage: message,
        networkType: connectivityResult.name,
      );

      // Add to history
      await _addToHistory(metric);

      // Emit update
      _metricsController.add(metric);

      _logger.error('Recorded sync error: $errorType - $message');
    } catch (e, stackTrace) {
      _logger.error('Failed to record sync error', e, stackTrace);
    }
  }

  /// Get sync history
  Future<List<SyncMetric>> getSyncHistory({
    int? limit,
    DateTime? since,
    bool? onlyErrors = false,
  }) async {
    try {
      final historyData = await _secureStorage.read(_metricsHistoryKey);
      if (historyData == null) return [];

      final historyList = jsonDecode(historyData) as List<dynamic>;
      var history =
          historyList.map((json) => SyncMetric.fromJson(json)).toList();

      // Apply filters
      if (since != null) {
        history = history.where((m) => m.timestamp.isAfter(since)).toList();
      }

      if (onlyErrors == true) {
        history = history.where((m) => !m.isSuccess).toList();
      }

      // Sort by timestamp (newest first)
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply limit
      if (limit != null && history.length > limit) {
        history = history.take(limit).toList();
      }

      return history;
    } catch (e, stackTrace) {
      _logger.error('Failed to get sync history', e, stackTrace);
      return [];
    }
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats({DateTime? since}) async {
    try {
      final history = await getSyncHistory(since: since);

      if (history.isEmpty) {
        return SyncStats.empty();
      }

      // Calculate stats
      final totalUploads = history.length;
      final successfulUploads = history.where((m) => m.isSuccess).length;
      final failedUploads = totalUploads - successfulUploads;
      final totalDataUploaded =
          history.fold<int>(0, (sum, metric) => sum + metric.dataSize);

      // Get unique error types
      final errorTypes = <String, int>{};
      for (final metric in history.where((m) => !m.isSuccess)) {
        if (metric.errorType != null) {
          errorTypes[metric.errorType!] =
              (errorTypes[metric.errorType!] ?? 0) + 1;
        }
      }

      return SyncStats(
        totalUploads: totalUploads,
        successfulUploads: successfulUploads,
        failedUploads: failedUploads,
        totalDataUploaded: totalDataUploaded,
        errorTypes: errorTypes,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get sync stats', e, stackTrace);
      return SyncStats.empty();
    }
  }

  /// Clear all metrics
  Future<void> clearAllMetrics() async {
    try {
      await _secureStorage.delete(_metricsHistoryKey);
      _logger.info('All sync metrics cleared');
    } catch (e, stackTrace) {
      _logger.error('Failed to clear metrics', e, stackTrace);
    }
  }

  /// Dispose of the service
  void dispose() {
    _metricsController.close();
  }

  // Private methods

  Future<void> _addToHistory(SyncMetric metric) async {
    try {
      final historyData = await _secureStorage.read(_metricsHistoryKey);
      List<Map<String, dynamic>> history = [];

      if (historyData != null) {
        final historyList = jsonDecode(historyData) as List<dynamic>;
        history = historyList.cast<Map<String, dynamic>>();
      }

      history.add(metric.toJson());

      // Keep only the most recent entries
      if (history.length > _maxHistoryEntries) {
        history = history.sublist(history.length - _maxHistoryEntries);
      }

      await _secureStorage.write(
        _metricsHistoryKey,
        jsonEncode(history),
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to add metric to history', e, stackTrace);
    }
  }

  Future<void> _cleanupOldMetrics() async {
    try {
      final history = await getSyncHistory();

      // Keep only the most recent entries
      if (history.length > _maxHistoryEntries) {
        final recentHistory = history.take(_maxHistoryEntries).toList();
        final historyJson = recentHistory.map((m) => m.toJson()).toList();

        await _secureStorage.write(
          _metricsHistoryKey,
          jsonEncode(historyJson),
        );

        _logger.info(
            'Cleaned up ${history.length - _maxHistoryEntries} old metric entries');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to cleanup old metrics', e, stackTrace);
    }
  }
}

/// Simple metric for tracking sync events
class SyncMetric {
  final DateTime timestamp;
  final String dataType;
  final int dataSize;
  final bool isSuccess;
  final String? errorType;
  final String? errorMessage;
  final String? networkType;

  SyncMetric({
    required this.timestamp,
    required this.dataType,
    required this.dataSize,
    required this.isSuccess,
    this.errorType,
    this.errorMessage,
    this.networkType,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'dataType': dataType,
      'dataSize': dataSize,
      'isSuccess': isSuccess,
      'errorType': errorType,
      'errorMessage': errorMessage,
      'networkType': networkType,
    };
  }

  factory SyncMetric.fromJson(Map<String, dynamic> json) {
    return SyncMetric(
      timestamp: DateTime.parse(json['timestamp']),
      dataType: json['dataType'],
      dataSize: json['dataSize'],
      isSuccess: json['isSuccess'],
      errorType: json['errorType'],
      errorMessage: json['errorMessage'],
      networkType: json['networkType'],
    );
  }
}

/// Summary stats for sync metrics
class SyncStats {
  final int totalUploads;
  final int successfulUploads;
  final int failedUploads;
  final int totalDataUploaded;
  final Map<String, int> errorTypes;

  SyncStats({
    required this.totalUploads,
    required this.successfulUploads,
    required this.failedUploads,
    required this.totalDataUploaded,
    required this.errorTypes,
  });

  double get successRate =>
      totalUploads > 0 ? successfulUploads / totalUploads : 1.0;

  factory SyncStats.empty() {
    return SyncStats(
      totalUploads: 0,
      successfulUploads: 0,
      failedUploads: 0,
      totalDataUploaded: 0,
      errorTypes: {},
    );
  }
}
