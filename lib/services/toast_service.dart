// lib/services/toast_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';

/// Toast service for showing user-facing notifications in a consistent way
class ToastService {
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  // Global navigator key to show toasts without context
  static GlobalKey<NavigatorState>? navigatorKey;

  // Method to initialize the service with navigator key
  static void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    OseerLogger.info('ToastService initialized');
  }

  /// Show a success toast notification
  static void success(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool withHaptic = true,
    VoidCallback? onTap,
  }) {
    _showToast(
      message: message,
      type: ToastType.success,
      duration: duration,
      withHaptic: withHaptic,
      onTap: onTap,
    );

    OseerLogger.ui('toast_success', message);
  }

  /// Show an info toast notification
  static void info(
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool withHaptic = false,
    VoidCallback? onTap,
  }) {
    _showToast(
      message: message,
      type: ToastType.info,
      duration: duration,
      withHaptic: withHaptic,
      onTap: onTap,
    );

    OseerLogger.ui('toast_info', message);
  }

  /// Show a warning toast notification
  static void warning(
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool withHaptic = true,
    VoidCallback? onTap,
  }) {
    _showToast(
      message: message,
      type: ToastType.warning,
      duration: duration,
      withHaptic: withHaptic,
      onTap: onTap,
    );

    OseerLogger.ui('toast_warning', message);
  }

  /// Show an error toast notification
  static void error(
    String message, {
    Duration duration = const Duration(seconds: 5),
    bool withHaptic = true,
    VoidCallback? onTap,
  }) {
    _showToast(
      message: message,
      type: ToastType.error,
      duration: duration,
      withHaptic: withHaptic,
      onTap: onTap,
    );

    OseerLogger.ui('toast_error', message);
    OseerLogger.error('UI Error Toast: $message');
  }

  /// Show a network error toast with retry option
  static void networkError({
    String message = 'Network connection error',
    required VoidCallback onRetry,
  }) {
    _showToast(
      message: message,
      type: ToastType.error,
      duration: const Duration(seconds: 10),
      withHaptic: true,
      action: _ToastAction(
        label: 'Retry',
        onPressed: onRetry,
      ),
    );

    OseerLogger.ui('toast_network_error', message);
    OseerLogger.error('Network Error Toast: $message');
  }

  /// Internal method to show toast via SnackBar
  static void _showToast({
    required String message,
    required ToastType type,
    required Duration duration,
    bool withHaptic = false,
    VoidCallback? onTap,
    _ToastAction? action,
  }) {
    // Get icon and colors based on toast type
    final IconData icon = _getIconForType(type);
    final Color backgroundColor = _getBackgroundColorForType(type);
    final Color textColor = _getTextColorForType(type);

    // Check if navigatorKey is available
    if (navigatorKey?.currentState?.context == null) {
      OseerLogger.warning('Cannot show toast: No valid context available');
      return;
    }

    // Get scaffold messenger
    final scaffoldMessenger =
        ScaffoldMessenger.of(navigatorKey!.currentState!.context);

    // Trigger haptic feedback if enabled
    if (withHaptic) {
      switch (type) {
        case ToastType.success:
          HapticFeedback.lightImpact();
          break;
        case ToastType.info:
          // No haptic by default
          break;
        case ToastType.warning:
          HapticFeedback.mediumImpact();
          break;
        case ToastType.error:
          HapticFeedback.heavyImpact();
          break;
      }
    }

    // Hide any existing snackbars
    scaffoldMessenger.hideCurrentSnackBar();

    // Create and show snackbar
    final SnackBar snackBar = SnackBar(
      content: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OseerSpacing.cardRadius),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: OseerSpacing.screenMargin,
        vertical: OseerSpacing.screenMargin,
      ),
      action: action != null
          ? SnackBarAction(
              label: action.label,
              textColor: textColor,
              onPressed: action.onPressed,
            )
          : null,
    );

    scaffoldMessenger.showSnackBar(snackBar);
  }

  /// Get icon for toast type
  static IconData _getIconForType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_outline;
      case ToastType.info:
        return Icons.info_outline;
      case ToastType.warning:
        return Icons.warning_amber_outlined;
      case ToastType.error:
        return Icons.error_outline;
    }
  }

  /// Get background color for toast type
  static Color _getBackgroundColorForType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return OseerColors.success.withOpacity(0.9);
      case ToastType.info:
        return OseerColors.info.withOpacity(0.9);
      case ToastType.warning:
        return OseerColors.warning.withOpacity(0.9);
      case ToastType.error:
        return OseerColors.error.withOpacity(0.9);
    }
  }

  /// Get text color for toast type
  static Color _getTextColorForType(ToastType type) {
    // For all toast types, we use white text
    return Colors.white;
  }
}

/// Toast types
enum ToastType {
  success,
  info,
  warning,
  error,
}

/// Internal class for toast actions
class _ToastAction {
  final String label;
  final VoidCallback onPressed;

  _ToastAction({
    required this.label,
    required this.onPressed,
  });
}
