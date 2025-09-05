// lib/utils/error_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../services/toast_service.dart';
import '../utils/constants.dart';

/// Global error handler for consistent error management across the app
class ErrorHandler {
  // Private constructor to prevent instantiation
  ErrorHandler._();

  // Default error messages by error type
  static const Map<String, String> _defaultErrorMessages = {
    'network':
        'Network connection error. Please check your internet connection.',
    'timeout': 'Request timed out. Please try again.',
    'server': 'Server error. Please try again later.',
    'auth': 'Authentication error. Please log in again.',
    'permission': 'Permission denied. Please check app permissions.',
    'not_found': 'Resource not found.',
    'validation': 'Validation error. Please check your input.',
    'unknown': 'An unexpected error occurred. Please try again.',
  };

  /// Initialize global error handling
  static void init() {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      OseerLogger.error('Flutter error', details.exception, details.stack);

      // Show UI error only in release mode or if error is critical
      if (!OseerConstants.environment.contains('lab')) {
        _showUIError(
            'An unexpected error occurred', details.exception.toString());
      }
    };

    // Set up Zone error handling for async errors
    runZonedGuarded(() {}, (error, stack) {
      OseerLogger.error('Unhandled async error', error, stack);

      // Show UI error only in release mode or if error is critical
      if (!OseerConstants.environment.contains('lab')) {
        _showUIError('An unexpected error occurred', error.toString());
      }
    });

    OseerLogger.info('ErrorHandler initialized');
  }

  /// Handle API errors with appropriate UI feedback
  static void handleApiError(
    dynamic error, {
    VoidCallback? onRetry,
    String? customMessage,
    bool showToast = true,
  }) {
    String errorMessage = customMessage ?? _getErrorMessage(error);

    // Log the error
    OseerLogger.error('API Error: $errorMessage', error);

    // Show UI feedback if enabled
    if (showToast) {
      if (onRetry != null && _isNetworkRelatedError(error)) {
        ToastService.networkError(
          message: errorMessage,
          onRetry: onRetry,
        );
      } else {
        ToastService.error(errorMessage);
      }
    }
  }

  /// Handle authentication errors
  static void handleAuthError(
    dynamic error, {
    BuildContext? context,
    VoidCallback? onLogout,
    String? customMessage,
  }) {
    String errorMessage =
        customMessage ?? _getErrorMessage(error, type: 'auth');

    // Log the error
    OseerLogger.error('Auth Error: $errorMessage', error);

    // Show toast notification
    ToastService.error(errorMessage);

    // Perform logout if session is invalid and callback provided
    if (_isSessionInvalidError(error) && onLogout != null) {
      // Add small delay to ensure toast is visible
      Future.delayed(const Duration(milliseconds: 1500), () {
        onLogout();
      });
    }
  }

  /// Handle form validation errors
  static void handleValidationError(
    dynamic error, {
    required BuildContext context,
    String? customMessage,
    Map<String, String>? fieldErrors,
  }) {
    String errorMessage =
        customMessage ?? _getErrorMessage(error, type: 'validation');

    // Log the error
    OseerLogger.error('Validation Error: $errorMessage', error);

    // Show toast notification for general errors
    if (customMessage != null || fieldErrors == null || fieldErrors.isEmpty) {
      ToastService.warning(errorMessage);
    }

    // Field errors are typically handled by the form itself
  }

  /// Handle permission errors
  static void handlePermissionError(
    dynamic error, {
    String? customMessage,
    VoidCallback? onOpenSettings,
  }) {
    String errorMessage =
        customMessage ?? _getErrorMessage(error, type: 'permission');

    // Log the error
    OseerLogger.error('Permission Error: $errorMessage', error);

    ToastService.warning(
      errorMessage,
      duration: const Duration(seconds: 6),
    );
  }

  /// Show a dialog for critical errors
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    // Log the error
    OseerLogger.error('Error Dialog: $title - $message');

    showDialog(
      context: context,
      barrierDismissible: onDismiss != null,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OseerSpacing.cardRadius),
          ),
          actions: <Widget>[
            if (onDismiss != null)
              TextButton(
                child: const Text('Dismiss'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
              ),
            if (onRetry != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OseerColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
              ),
          ],
        );
      },
    );
  }

  /// Get appropriate error message based on error type
  static String _getErrorMessage(dynamic error, {String type = 'unknown'}) {
    // Handle common error types
    if (error is TimeoutException || error.toString().contains('timeout')) {
      return _defaultErrorMessages['timeout']!;
    }

    if (_isNetworkRelatedError(error)) {
      return _defaultErrorMessages['network']!;
    }

    if (_isServerError(error)) {
      return _defaultErrorMessages['server']!;
    }

    // If error contains a message, extract and clean it
    String errorMessage = error.toString();

    // Remove common prefixes
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring(11);
    }

    if (errorMessage.startsWith('Error: ')) {
      errorMessage = errorMessage.substring(7);
    }

    // If still no good message, use default for the type
    if (errorMessage.isEmpty || errorMessage == 'null') {
      return _defaultErrorMessages[type] ?? _defaultErrorMessages['unknown']!;
    }

    return errorMessage;
  }

  /// Check if error is network related
  static bool _isNetworkRelatedError(dynamic error) {
    String errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        errorString.contains('host');
  }

  /// Check if error is server related
  static bool _isServerError(dynamic error) {
    String errorString = error.toString().toLowerCase();
    return errorString.contains('500') ||
        errorString.contains('server') ||
        errorString.contains('internal');
  }

  /// Check if error indicates invalid session
  static bool _isSessionInvalidError(dynamic error) {
    String errorString = error.toString().toLowerCase();
    return errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('unauthenticated') ||
        errorString.contains('invalid token') ||
        errorString.contains('invalid session') ||
        errorString.contains('expired');
  }

  /// Show UI error with toast
  static void _showUIError(String title, String details) {
    ToastService.error('$title: ${_formatErrorForUI(details)}');
  }

  /// Format error message for UI display
  static String _formatErrorForUI(String errorMessage) {
    // Limit length
    if (errorMessage.length > 100) {
      errorMessage = errorMessage.substring(0, 97) + '...';
    }

    // Remove sensitive info
    errorMessage = errorMessage.replaceAll(
        RegExp(r'(api_key|token|password)=\S+'), '[REDACTED]');

    return errorMessage;
  }
}
