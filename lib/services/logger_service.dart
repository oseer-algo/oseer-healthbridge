// File path: lib/services/logger_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

/// Global logger service with improved formatting and diagnostics
class OseerLogger {
  static Logger? _logger;
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');
  static String _lastLogTime = '';

  // List to store recent logs for debugging purposes
  static final List<String> _recentLogs = [];
  static const int _maxRecentLogs = 200; // Increased from 100

  /// Initialize the logger
  static void init(Logger logger) {
    _logger = logger;
    _lastLogTime = _timeFormat.format(DateTime.now());

    // Log app startup with version info
    info(
        '🚀 App started - ${OseerConstants.appName} v${OseerConstants.appVersion}');
    info('📱 Environment: ${kDebugMode ? 'DEBUG' : 'RELEASE'}');
    info('⚙️ System initialized with default configuration');
  }

  /// Log a debug message
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log('🔍', message, LogLevel.debug, error, stackTrace);
    _logger?.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log('💡', message, LogLevel.info, error, stackTrace);
    _logger?.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  static void warning(dynamic message,
      [dynamic error, StackTrace? stackTrace]) {
    _log('⚠️', message, LogLevel.warning, error, stackTrace);
    _logger?.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log('❌', message, LogLevel.error, error, stackTrace);
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error message
  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _log('💀', message, LogLevel.fatal, error, stackTrace);
    _logger?.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log token operations
  static void token(String operation, String tokenInfo, [bool success = true]) {
    final emoji = success ? '🔑' : '⚠️';
    final level = success ? LogLevel.info : LogLevel.warning;
    _log(emoji, 'TOKEN: $operation - $tokenInfo', level);
    if (success) {
      _logger?.i('TOKEN: $operation - $tokenInfo');
    } else {
      _logger?.w('TOKEN: $operation - $tokenInfo');
    }
  }

  /// Log health data operations
  static void health(String operation, String details, [bool success = true]) {
    final emoji = success ? '❤️' : '⚠️';
    final level = success ? LogLevel.info : LogLevel.warning;
    _log(emoji, 'HEALTH: $operation - $details', level);
    if (success) {
      _logger?.i('HEALTH: $operation - $details');
    } else {
      _logger?.w('HEALTH: $operation - $details');
    }
  }

  /// Log connection status changes
  static void connection(String status, String details) {
    String emoji;
    LogLevel level;

    switch (status.toLowerCase()) {
      case 'connected':
        emoji = '🔌';
        level = LogLevel.info;
        break;
      case 'disconnected':
        emoji = '🔌';
        level = LogLevel.info;
        break;
      case 'error':
        emoji = '⚡';
        level = LogLevel.error;
        break;
      default:
        emoji = '🔄';
        level = LogLevel.info;
    }

    _log(emoji, 'CONNECTION: $status - $details', level);
    if (level == LogLevel.error) {
      _logger?.e('CONNECTION: $status - $details');
    } else {
      _logger?.i('CONNECTION: $status - $details');
    }
  }

  /// Log network request
  static void network(String method, String url,
      [dynamic data, int? statusCode]) {
    final String statusText =
        statusCode != null ? " (Status: $statusCode)" : "";
    final String dataText = data != null ? "\nData: ${_formatData(data)}" : "";
    _log('🌐', "$method $url$statusText$dataText", LogLevel.info);
    _logger?.i("$method $url$statusText$dataText");
  }

  /// Log API response
  static void apiResponse(String url, int statusCode, dynamic data) {
    final String formattedData = _formatData(data);
    final String emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    _log(
        emoji,
        "API Response: $url (Status: $statusCode)\nData: $formattedData",
        LogLevel.info);
    _logger
        ?.i("API Response: $url (Status: $statusCode)\nData: $formattedData");
  }

  /// Log performance metrics
  static void performance(String operation, int durationMs) {
    String emoji;
    LogLevel level;

    if (durationMs < 100) {
      emoji = '⚡'; // Fast
      level = LogLevel.info;
    } else if (durationMs < 500) {
      emoji = '🚶'; // Moderate
      level = LogLevel.info;
    } else if (durationMs < 1000) {
      emoji = '🐢'; // Slow
      level = LogLevel.warning;
    } else {
      emoji = '🐌'; // Very slow
      level = LogLevel.warning;
    }

    _log(emoji, 'PERFORMANCE: $operation took $durationMs ms', level);
    if (level == LogLevel.warning) {
      _logger?.w('PERFORMANCE: $operation took $durationMs ms');
    } else {
      _logger?.i('PERFORMANCE: $operation took $durationMs ms');
    }
  }

  /// Get recent logs as a string (for debugging)
  static String getRecentLogs() {
    return _recentLogs.join('\n');
  }

  /// Export logs to a file (this is a stub - implement as needed)
  static Future<String> exportLogs() async {
    // This would be implemented to write logs to a file or send them to a service
    final allLogs = _recentLogs.join('\n');
    return allLogs;
  }

  /// Clear the log buffer
  static void clearLogs() {
    _recentLogs.clear();
    _lastLogTime = _timeFormat.format(DateTime.now());
    _log('🧹', 'Logs cleared', LogLevel.info);
  }

  /// Internal method to format and store logs
  static void _log(String emoji, dynamic message, LogLevel level,
      [dynamic error, StackTrace? stackTrace]) {
    if (_logger == null) return;

    try {
      final now = DateTime.now();
      final timeString = _timeFormat.format(now);
      final timeDiff = now
          .difference(DateTime.parse("2025-04-06 ${_lastLogTime}"))
          .inMilliseconds;
      _lastLogTime = timeString;

      // Format stacktrace if available
      String stackTraceText = '';
      if (stackTrace != null) {
        final frames = stackTrace.toString().split('\n');
        if (frames.length > 2) {
          // Only show first two frames for brevity
          stackTraceText =
              '\n    at ${frames[0].trim()}\n    at ${frames[1].trim()}';
        } else {
          stackTraceText = '\n    at ${stackTrace.toString().trim()}';
        }
      }

      // Format error if available
      String errorText = '';
      if (error != null) {
        errorText = ' - Error: ${error.toString()}';
      }

      // Add colored level indicator
      String levelIndicator;
      switch (level) {
        case LogLevel.debug:
          levelIndicator = '[DEBUG]';
          break;
        case LogLevel.info:
          levelIndicator = '[INFO]';
          break;
        case LogLevel.warning:
          levelIndicator = '[WARN]';
          break;
        case LogLevel.error:
          levelIndicator = '[ERROR]';
          break;
        case LogLevel.fatal:
          levelIndicator = '[FATAL]';
          break;
      }

      // Create formatted log entry
      final String logEntry =
          '$emoji $timeString (+${timeDiff}ms) $levelIndicator ${message.toString()}$errorText$stackTraceText';

      // Store for recent logs
      _recentLogs.add(logEntry);
      if (_recentLogs.length > _maxRecentLogs) {
        _recentLogs.removeAt(0);
      }
    } catch (e) {
      // Failsafe for any logging errors
      print('Error in logger: $e');
    }
  }

  /// Format data for logging
  static String _formatData(dynamic data) {
    if (data == null) return 'null';

    try {
      if (data is Map || data is List) {
        return json.encode(data);
      } else if (data is String &&
          (data.startsWith('{') || data.startsWith('['))) {
        // Try to parse as JSON if it looks like JSON
        try {
          final parsed = json.decode(data);
          return json.encode(parsed); // Re-encode for consistent formatting
        } catch (e) {
          return data;
        }
      } else {
        return data.toString();
      }
    } catch (e) {
      return data.toString();
    }
  }
}

/// Log levels for different types of messages
enum LogLevel { debug, info, warning, error, fatal }
