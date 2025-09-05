// lib/services/logger_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

/// Service wrapper for logging functionality
class LoggerService {
  final Logger _logger;

  /// Constructor with optional level parameter
  LoggerService({Level level = Level.info})
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 2,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            printTime: true,
          ),
          level: level,
        );

  /// Initialize the logger
  Future<void> initialize() async {
    await OseerLogger.init(Level.info);
  }

  /// Log a debug message
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    OseerLogger.debug(message, error, stackTrace);
  }

  /// Log an info message
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    OseerLogger.info(message, error, stackTrace);
  }

  /// Log a warning message
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    OseerLogger.warning(message, error, stackTrace);
  }

  /// Log an error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    OseerLogger.error(message, error, stackTrace);
  }

  /// Log a fatal error message
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    OseerLogger.fatal(message, error, stackTrace);
  }

  /// Get recent logs as a string
  String getRecentLogs() {
    return OseerLogger.getRecentLogs();
  }

  /// Export logs to a file path for sharing
  Future<String> exportLogs() async {
    return await OseerLogger.exportLogs();
  }
}

/// Global logger service with improved formatting and diagnostics
class OseerLogger {
  // Make the Logger instance static and accessible via getter
  static Logger? _logger;
  // Add a getter to make _logger accessible in main.dart for error checking
  static Logger? get logger => _logger;

  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');
  static final DateFormat _fileFormat = DateFormat('yyyy-MM-dd');
  static DateTime? _lastLogTimestamp; // Use DateTime for accurate diff

  // List to store recent logs for debugging purposes
  static final List<String> _recentLogs = [];
  static const int _maxRecentLogs = 200;

  // File logging
  static File? _logFile;
  static const int _maxLogFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5; // Keep last 5 log files

  /// Initialize the logger with a specified log level
  static Future<void> init(Level level) async {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true, // Logger's internal time, ours adds diff
      ),
      level: level,
    );

    _lastLogTimestamp = DateTime.now(); // Initialize timestamp

    // Initialize file logging in non-web platforms
    if (!kIsWeb) {
      try {
        await _initializeFileLogging();
      } catch (e) {
        print('[OseerLogger] Failed to initialize file logging: $e');
      }
    }

    // Log app startup with version info using the logger itself
    info(
        '🚀 App started - ${OseerConstants.appName} v${OseerConstants.appVersion}');
    info('📱 Environment: ${kDebugMode ? 'DEBUG' : 'RELEASE'}');
    info('⚙️ System initialized with default configuration');
  }

  /// Initialize file logging
  static Future<void> _initializeFileLogging() async {
    try {
      final directory = await getTemporaryDirectory();
      final logDirectory = Directory('${directory.path}/logs');

      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      final today = _fileFormat.format(DateTime.now());
      final logFilePath = '${logDirectory.path}/oseer_log_$today.log';

      _logFile = File(logFilePath);

      // Rotate logs *before* creating/writing to the new file for the day
      await _rotateLogsIfNeeded(logDirectory);

      // Create file if it doesn't exist (or after rotation)
      if (!await _logFile!.exists()) {
        await _logFile!.create();
        // Add header only to newly created files
        await _logToFileInternal(
            '===== LOG STARTED AT ${DateTime.now().toIso8601String()} =====\n');
      } else {
        // If file exists, check size again in case it grew huge between app restarts
        final fileStats = await _logFile!.stat();
        if (fileStats.size > _maxLogFileSizeBytes) {
          await _rotateLogNow(logDirectory, _logFile!); // Force rotation
          _logFile = File(logFilePath); // Re-assign _logFile
          await _logFile!.create();
          await _logToFileInternal(
              '===== LOG STARTED (After Rotation) AT ${DateTime.now().toIso8601String()} =====\n');
        } else {
          // Append separator to existing file for clarity
          await _logToFileInternal(
              '\n===== RESUMING LOG AT ${DateTime.now().toIso8601String()} =====');
        }
      }

      debug('File logging initialized at: $logFilePath'); // Use logger
    } catch (e) {
      print('[OseerLogger] Error initializing file logging: $e');
    }
  }

  /// Force rotation of a specific log file
  static Future<void> _rotateLogNow(
      Directory logDirectory, File fileToRotate) async {
    try {
      if (!await fileToRotate.exists()) return;

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final oldPath = fileToRotate.path;
      // Ensure the rotated name doesn't clash with the daily name format
      final newPath =
          '${logDirectory.path}/rotated_${_fileFormat.format(DateTime.now())}_$timestamp.log';
      print('[OseerLogger] Rotating log file ${fileToRotate.path} to $newPath');
      await fileToRotate.rename(newPath);
      // Clean up excess rotated files after rotation
      await _cleanupOldLogs(logDirectory);
    } catch (e) {
      print('[OseerLogger] Error rotating log file immediately: $e');
    }
  }

  /// Rotate log files if current one is too large or day changed
  static Future<void> _rotateLogsIfNeeded(Directory logDirectory) async {
    if (_logFile == null) return;

    try {
      final currentDay = _fileFormat.format(DateTime.now());
      final expectedLogPath = '${logDirectory.path}/oseer_log_$currentDay.log';

      // If the expected path is different (new day), rotate the old one
      if (_logFile!.path != expectedLogPath) {
        print(
            '[OseerLogger] New day detected, rotating old log file: ${_logFile!.path}');
        await _rotateLogNow(logDirectory, _logFile!);
        _logFile =
            File(expectedLogPath); // Update _logFile to the new day's file
        // The calling function (_initializeFileLogging) will handle creation/header
        return; // Rotation handled by date change
      }

      // Check current file size if it's still the same day's file
      if (await _logFile!.exists()) {
        final fileStats = await _logFile!.stat();
        if (fileStats.size > _maxLogFileSizeBytes) {
          print(
              '[OseerLogger] Log file size exceeded limit (${fileStats.size} > $_maxLogFileSizeBytes), rotating.');
          await _rotateLogNow(logDirectory, _logFile!);
          _logFile = File(expectedLogPath); // Re-assign _logFile path
          // The calling function (_initializeFileLogging) will handle creation/header
        }
      }
    } catch (e) {
      print('[OseerLogger] Error checking log rotation: $e');
    }
  }

  /// Delete oldest log files if exceeding the limit
  static Future<void> _cleanupOldLogs(Directory logDirectory) async {
    try {
      // Find all log files (daily and rotated)
      final logFiles = await logDirectory
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.contains('oseer_log_') && // Catches daily logs
              entity.path.endsWith('.log'))
          .toList();

      final rotatedFiles = await logDirectory
          .list()
          .where((entity) =>
              entity is File &&
              entity.path.contains('rotated_') && // Catches rotated logs
              entity.path.endsWith('.log'))
          .toList();

      final allLogs = [...logFiles, ...rotatedFiles];

      if (allLogs.length > _maxLogFiles) {
        print(
            '[OseerLogger] Found ${allLogs.length} log files, exceeding max $_maxLogFiles. Cleaning up...');
        // Sort by modification time, oldest first
        allLogs.sort((a, b) {
          try {
            final aTime = (a as File).lastModifiedSync();
            final bTime = (b as File).lastModifiedSync();
            return aTime.compareTo(bTime);
          } catch (_) {
            return 0;
          } // Handle potential file access errors during sort
        });

        // Delete oldest files until limit is met
        int filesToDelete = allLogs.length - _maxLogFiles;
        for (var i = 0; i < filesToDelete; i++) {
          try {
            print('[OseerLogger] Deleting old log file: ${allLogs[i].path}');
            await (allLogs[i] as File).delete();
          } catch (deleteError) {
            print(
                '[OseerLogger] Error deleting old log file ${allLogs[i].path}: $deleteError');
          }
        }
      }
    } catch (e) {
      print('[OseerLogger] Error during log cleanup: $e');
    }
  }

  /// Internal log to file method
  static Future<void> _logToFileInternal(String formattedMessage) async {
    if (_logFile != null) {
      try {
        // Ensure the file object is up-to-date (especially after potential rotation)
        final currentDay = _fileFormat.format(DateTime.now());
        final expectedLogPath =
            '${_logFile!.parent.path}/oseer_log_$currentDay.log';
        if (_logFile!.path != expectedLogPath) {
          _logFile = File(expectedLogPath);
          if (!await _logFile!.exists()) {
            await _logFile!.create();
            // Add header if we had to create it here
            await _logFile!.writeAsString(
                '===== LOG CREATED (Late Init) AT ${DateTime.now().toIso8601String()} =====\n',
                mode: FileMode.append);
          }
        }

        await _logFile!
            .writeAsString('$formattedMessage\n', mode: FileMode.append);
      } catch (e) {
        print('[OseerLogger] Error writing to log file: $e');
        _logFile = null; // Disable file logging on write error to prevent spam
        print('[OseerLogger] File logging disabled due to error.');
      }
    }
  }

  /// Log a debug message
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logInternal(LogLevel.debug, message, error, stackTrace);
    _logger?.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logInternal(LogLevel.info, message, error, stackTrace);
    _logger?.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logInternal(LogLevel.warning, message, error, stackTrace);
    _logger?.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logInternal(LogLevel.error, message, error, stackTrace);
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error message
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logInternal(LogLevel.fatal, message, error, stackTrace);
    _logger?.f(message, error: error, stackTrace: stackTrace);
  }

  // --- Specialized Loggers ---

  /// Log token operations
  static void token(String operation, String tokenInfo, [bool success = true]) {
    final emoji = success ? '🔑' : '⚠️';
    final level = success ? LogLevel.info : LogLevel.warning;
    final message = 'TOKEN: $operation - $tokenInfo';
    _logInternal(level, message);
    if (success)
      _logger?.i(message);
    else
      _logger?.w(message);
  }

  /// Log health data operations
  static void health(String operation, String details, [bool success = true]) {
    final emoji = success ? '❤️' : '⚠️';
    final level = success ? LogLevel.info : LogLevel.warning;
    final message = 'HEALTH: $operation - $details';
    _logInternal(level, message);
    if (success)
      _logger?.i(message);
    else
      _logger?.w(message);
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
    final message = 'CONNECTION: $status - $details';
    _logInternal(level, message);
    if (level == LogLevel.error)
      _logger?.e(message);
    else
      _logger?.i(message);
  }

  /// Log network request
  static void network(String method, String url,
      [dynamic data, int? statusCode]) {
    final statusText = statusCode != null ? " (Status: $statusCode)" : "";
    final dataText = data != null ? "\nData: ${_formatData(data)}" : "";
    final message = "$method $url$statusText$dataText";
    _logInternal(LogLevel.info, message);
    _logger?.i(message); // Use info level for network requests
  }

  /// Log API response
  static void apiResponse(String url, int statusCode, dynamic data) {
    final formattedData = _formatData(data);
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    final message =
        "API Response: $url (Status: $statusCode)\nData: $formattedData";
    // Log API responses as Debug to reduce noise, or Info if preferred
    _logInternal(LogLevel.debug, message);
    _logger?.d(message);
  }

  /// Log performance metrics
  static void performance(String operation, int durationMs) {
    String emoji;
    LogLevel level;
    if (durationMs < 100) {
      emoji = '⚡';
      level = LogLevel.debug;
    } // Fast - Debug level
    else if (durationMs < 500) {
      emoji = '🚶';
      level = LogLevel.info;
    } // Moderate - Info
    else if (durationMs < 1500) {
      emoji = '🐢';
      level = LogLevel.warning;
    } // Slow - Warning
    else {
      emoji = '🐌';
      level = LogLevel.warning;
    } // Very slow - Warning

    final message = 'PERFORMANCE: $operation took $durationMs ms';
    _logInternal(level, message);
    if (level == LogLevel.warning)
      _logger?.w(message);
    else if (level == LogLevel.info)
      _logger?.i(message);
    else
      _logger?.d(message);
  }

  /// Log UI events
  static void ui(String eventType, String details) {
    final message = 'UI: $eventType - $details';
    _logInternal(LogLevel.debug, message); // UI events often verbose, use Debug
    _logger?.d(message);
  }

  /// Log user actions
  static void userAction(String action, [Map<String, dynamic>? data]) {
    final dataString = data != null ? " - Data: ${_formatData(data)}" : "";
    final message = 'USER: $action$dataString';
    _logInternal(LogLevel.info, message);
    _logger?.i(message);
  }

  /// Log authentication events
  static void auth(String action, [bool success = true]) {
    final emoji = success ? '🔒' : '🔓';
    final level = success ? LogLevel.info : LogLevel.warning;
    final message = 'AUTH: $action';
    _logInternal(level, message);
    if (success)
      _logger?.i(message);
    else
      _logger?.w(message);
  }

  // --- Utility Methods ---

  /// Get recent logs as a string (for debugging display or sharing)
  static String getRecentLogs() {
    return _recentLogs.join('\n');
  }

  /// Export logs to a file path for sharing. Returns path or error message.
  static Future<String> exportLogs() async {
    if (kIsWeb) {
      return 'Log export not supported on web.';
    }

    // Ensure file logging is active and file path is known
    if (_logFile == null) {
      await _initializeFileLogging(); // Attempt to init if not already
      if (_logFile == null) {
        return 'File logging is not initialized or failed.';
      }
    }

    try {
      if (await _logFile!.exists()) {
        // Optionally, copy the current log file to a shareable location if needed
        // For simplicity, just return the current path
        final path = _logFile!.path;
        info("Log file path for export: $path");
        return path;
      } else {
        return 'Current log file does not exist.';
      }
    } catch (e) {
      error('Failed to export logs', e);
      return 'Failed to export logs: $e';
    }
  }

  /// Clear the in-memory log buffer
  static void clearLogs() {
    _recentLogs.clear();
    _lastLogTimestamp = DateTime.now();
    _logInternal(
        LogLevel.info, 'In-memory logs cleared'); // Log clearing action
  }

  /// Internal method to format and store logs (both in memory and to file)
  static void _logInternal(LogLevel level, String message,
      [dynamic error, StackTrace? stackTrace]) {
    if (_logger == null) {
      print("LOGGER NOT INITIALIZED: $message"); // Fallback print
      return;
    }

    try {
      final now = DateTime.now();
      final timeString = _timeFormat.format(now);
      final timeDiff = _lastLogTimestamp != null
          ? now.difference(_lastLogTimestamp!).inMilliseconds
          : 0;
      _lastLogTimestamp = now; // Update last timestamp

      // Format stacktrace if available
      String stackTraceText = '';
      if (stackTrace != null) {
        // Basic formatting, could be enhanced
        stackTraceText = '\nStackTrace:\n$stackTrace';
      }

      // Format error if available
      String errorText = '';
      if (error != null) {
        errorText = ' | Error: ${error.toString()}';
      }

      // Map LogLevel enum to string for display/file
      String levelIndicator = level.toString().split('.').last.toUpperCase();
      String emoji = _getEmojiForLevel(level);

      // Create formatted log entry for memory/file
      final String logEntry =
          '$emoji $timeString (+${timeDiff}ms) [$levelIndicator] ${message.toString()}$errorText$stackTraceText';

      // Store for recent logs in memory
      if (_recentLogs.length >= _maxRecentLogs) {
        _recentLogs.removeAt(0); // Remove oldest log
      }
      _recentLogs.add(logEntry);

      // Write to file asynchronously (don't wait)
      if (!kIsWeb) {
        _logToFileInternal(logEntry);
      }
    } catch (e) {
      // Failsafe for any logging errors
      print('[OseerLogger] Internal logging error: $e');
      print('[OseerLogger] Original Message: $message');
    }
  }

  /// Get appropriate emoji for log level
  static String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return '💡';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.fatal:
        return '💀';
      default:
        return '➡️';
    }
  }

  /// Format data for logging (handles Maps, Lists, Strings, other types)
  static String _formatData(dynamic data) {
    if (data == null) return 'null';
    try {
      if (data is Map || data is List) {
        // Pretty print JSON for readability
        return const JsonEncoder.withIndent('  ').convert(data);
      } else {
        // Default to toString for other types
        return data.toString();
      }
    } catch (e) {
      // Fallback if JSON encoding fails or toString throws error
      return '[Error formatting data: $e] -> ${data.runtimeType}';
    }
  }

  /// Get current log file path for sharing purposes.
  static Future<String?> getLogFilePath() async {
    if (kIsWeb) return null;
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile!.path;
    }
    return null;
  }

  /// Get statistics about logged events in the current memory buffer.
  static Map<String, int> getLogStatistics() {
    final Map<String, int> stats = {
      'total': _recentLogs.length,
      'debug': 0,
      'info': 0,
      'warning': 0,
      'error': 0,
      'fatal': 0,
    };
    for (final log in _recentLogs) {
      if (log.contains('[DEBUG]'))
        stats['debug'] = (stats['debug'] ?? 0) + 1;
      else if (log.contains('[INFO]'))
        stats['info'] = (stats['info'] ?? 0) + 1;
      else if (log.contains('[WARN]'))
        stats['warning'] = (stats['warning'] ?? 0) + 1;
      else if (log.contains('[ERROR]'))
        stats['error'] = (stats['error'] ?? 0) + 1;
      else if (log.contains('[FATAL]'))
        stats['fatal'] = (stats['fatal'] ?? 0) + 1;
    }
    return stats;
  }
}

/// Log levels for different types of messages
enum LogLevel { debug, info, warning, error, fatal }
