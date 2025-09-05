// lib/services/notification_service.dart

import 'dart:io';
import 'package:flutter/material.dart'; // FIX: Added missing import for Color class
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/sync_progress.dart';
import '../services/logger_service.dart';

/// Professional notification service for Oseer HealthBridge
class NotificationService {
  // Singleton setup
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() {
    return _instance;
  }

  static const String _channelId = 'oseer_notifications';
  static const String _syncChannelId = 'oseer_sync_notifications';
  static const String _generalChannelId = 'oseer_general';

  // Notification IDs
  static const int _syncProgressNotificationId = 1001;
  static const int _syncCompleteNotificationId = 1002;
  static const int _syncErrorNotificationId = 1003;
  static const int _generalNotificationId = 1004;

  final FlutterLocalNotificationsPlugin _notifications;

  bool _isInitialized = false;
  bool _areNotificationsEnabled = false;

  // Track last notification state
  String? _lastNotificationPhase;
  bool? _lastNotificationIsError;
  int _lastProgressValue = -1;

  NotificationService._internal({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OseerLogger.info('Initializing notification service');

      // Android initialization with custom icon
      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels with professional settings
      await _createNotificationChannels();

      _isInitialized = true;
      OseerLogger.info('Notification service initialized successfully');
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to initialize notification service', e, stackTrace);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      OseerLogger.warning(
          'Cannot request permissions: NotificationService not initialized.');
      await initialize();
    }

    try {
      OseerLogger.info('Requesting notification permissions from the OS...');
      bool? granted;

      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iosImplementation != null) {
          granted = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          granted =
              await androidImplementation.requestNotificationsPermission();
        }
      }

      _areNotificationsEnabled = granted ?? false;
      OseerLogger.info(
          'Notification permissions request result: $_areNotificationsEnabled');
      return _areNotificationsEnabled;
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to request notification permissions', e, stackTrace);
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;

    try {
      if (Platform.isAndroid) {
        final result = await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        _areNotificationsEnabled = result ?? false;
      } else if (Platform.isIOS) {
        _areNotificationsEnabled = true;
      }

      return _areNotificationsEnabled;
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to check notification permissions', e, stackTrace);
      return false;
    }
  }

  /// Shows a professional sync progress notification
  Future<void> showSyncProgressNotification(SyncProgress progress) async {
    if (!await _canShowNotifications()) return;

    try {
      // Dismiss notification if complete or error
      if (progress.isComplete || progress.isError) {
        await _notifications.cancel(_syncProgressNotificationId);
        _lastNotificationPhase = null;
        _lastNotificationIsError = null;
        _lastProgressValue = -1;
        return;
      }

      final String title;
      final String message;
      final int progressValue;
      final int maxProgress;
      final bool isOngoing;
      bool shouldVibrate = false;

      // Only vibrate on significant changes
      if (_lastNotificationPhase == null ||
          _lastNotificationPhase != progress.currentPhase ||
          (_lastNotificationIsError != progress.isError && progress.isError)) {
        shouldVibrate = true;
      }

      _lastNotificationPhase = progress.currentPhase;
      _lastNotificationIsError = progress.isError;

      // Professional notification content
      if (progress.currentPhase == 'bodyPrep') {
        title = 'Analyzing Wellness Data';
        message =
            progress.currentActivity ?? 'Processing your recent health metrics';
        progressValue = ((progress.bodyPrepProgress ?? 0.0) * 100).toInt();
        maxProgress = 100;
        isOngoing = true;
      } else if (progress.currentPhase == 'digitalTwin') {
        title = 'Building Your Digital Twin';
        message =
            progress.currentActivity ?? 'Processing historical wellness data';
        progressValue = progress.digitalTwinDaysProcessed ?? 0;
        maxProgress = 90;
        isOngoing = true;
      } else {
        await _notifications.cancel(_syncProgressNotificationId);
        _lastNotificationPhase = null;
        _lastNotificationIsError = null;
        _lastProgressValue = -1;
        return;
      }

      // Only update if progress has changed significantly
      if (progressValue == _lastProgressValue && !shouldVibrate) {
        return;
      }
      _lastProgressValue = progressValue;

      final androidDetails = AndroidNotificationDetails(
        _syncChannelId,
        'Wellness Assessment',
        channelDescription: 'Real-time progress of your wellness assessment',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progressValue,
        ongoing: isOngoing,
        autoCancel: false,
        enableVibration: shouldVibrate,
        playSound: false,
        silent: !shouldVibrate,
        onlyAlertOnce: true,
        color: const Color(0xFF1E88E5),
        icon: '@drawable/ic_notification',
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: !isOngoing,
        presentBadge: !isOngoing,
        presentSound: !isOngoing && shouldVibrate,
      );

      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        _syncProgressNotificationId,
        title,
        message,
        details,
        payload: 'sync_progress',
      );
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to show sync progress notification', e, stackTrace);
    }
  }

  /// Show professional notification with custom styling
  Future<void> showNotification({
    required String title,
    required String message,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
    List<String>? actions,
  }) async {
    // **FIX: Add a guard clause with a permission check**
    if (!await _canShowNotifications()) {
      OseerLogger.warning("Cannot show notification, permissions not granted.");
      return;
    }

    try {
      final androidImportance = _getAndroidImportance(priority);
      final androidPriority = _getAndroidPriority(priority);

      final androidActions = actions
          ?.map((action) => AndroidNotificationAction(
                action.toLowerCase().replaceAll(' ', '_'),
                action,
                showsUserInterface: true,
              ))
          .toList();

      final androidDetails = AndroidNotificationDetails(
        _generalChannelId,
        'Oseer Notifications',
        channelDescription: 'Important updates about your wellness journey',
        importance: androidImportance,
        priority: androidPriority,
        autoCancel: true,
        enableVibration: priority == NotificationPriority.high,
        playSound: priority == NotificationPriority.high,
        actions: androidActions,
        color: const Color(0xFF1E88E5),
        icon: '@drawable/ic_notification',
        styleInformation: BigTextStyleInformation(
          message,
          contentTitle: title,
          summaryText: 'Oseer HealthBridge',
        ),
      );

      final iosInterruption = priority == NotificationPriority.high
          ? InterruptionLevel.active
          : InterruptionLevel.passive;

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: priority == NotificationPriority.high,
        presentSound: priority == NotificationPriority.high,
        interruptionLevel: iosInterruption,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        title,
        message,
        details,
        payload: payload,
      );

      OseerLogger.info('Notification shown: $title');
    } catch (e, stackTrace) {
      OseerLogger.error('Failed to show notification', e, stackTrace);
    }
  }

  /// Show sync complete notification with professional styling
  Future<void> showSyncCompleteNotification({
    required String title,
    required String message,
    int? recordsProcessed,
    Duration? duration,
  }) async {
    if (!await _canShowNotifications()) return;

    try {
      String enhancedMessage = message;
      if (recordsProcessed != null) {
        enhancedMessage += '\n$recordsProcessed health records analyzed';
      }
      if (duration != null) {
        final minutes = duration.inMinutes;
        enhancedMessage +=
            minutes > 0 ? ' in ${minutes}m' : ' in ${duration.inSeconds}s';
      }

      final androidDetails = AndroidNotificationDetails(
        _syncChannelId,
        'Wellness Assessment',
        channelDescription: 'Completion notifications for wellness assessments',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        color: const Color(0xFF4CAF50),
        icon: '@drawable/ic_notification',
        styleInformation: BigTextStyleInformation(
          enhancedMessage,
          contentTitle: title,
          summaryText: 'Assessment Complete',
        ),
        actions: [
          const AndroidNotificationAction(
            'view_results',
            'View Results',
            showsUserInterface: true,
            icon: DrawableResourceAndroidBitmap('@drawable/ic_view'),
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _syncCompleteNotificationId,
        title,
        enhancedMessage,
        details,
        payload: 'sync_complete',
      );

      _lastNotificationPhase = null;
      _lastNotificationIsError = null;
      _lastProgressValue = -1;

      OseerLogger.info('Sync complete notification shown');
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to show sync complete notification', e, stackTrace);
    }
  }

  /// Show sync error notification with professional styling
  Future<void> showSyncErrorNotification({
    required String title,
    required String message,
    String? errorCode,
    bool canRetry = true,
  }) async {
    if (!await _canShowNotifications()) return;

    try {
      final actions = <AndroidNotificationAction>[
        if (canRetry)
          const AndroidNotificationAction(
            'retry_sync',
            'Retry',
            showsUserInterface: true,
            icon: DrawableResourceAndroidBitmap('@drawable/ic_retry'),
          ),
        const AndroidNotificationAction(
          'view_details',
          'Details',
          showsUserInterface: true,
          icon: DrawableResourceAndroidBitmap('@drawable/ic_info'),
        ),
      ];

      final androidDetails = AndroidNotificationDetails(
        _syncChannelId,
        'Wellness Assessment',
        channelDescription: 'Error notifications for wellness assessments',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        actions: actions,
        color: const Color(0xFFE53935),
        icon: '@drawable/ic_notification',
        styleInformation: BigTextStyleInformation(
          message,
          contentTitle: title,
          summaryText: 'Action Required',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _syncErrorNotificationId,
        title,
        message,
        details,
        payload: 'sync_error_${errorCode ?? 'unknown'}',
      );

      OseerLogger.info('Sync error notification shown');
    } catch (e, stackTrace) {
      OseerLogger.error(
          'Failed to show sync error notification', e, stackTrace);
    }
  }

  /// Dismiss sync notifications
  Future<void> dismissSyncNotifications() async {
    try {
      await _notifications.cancel(_syncProgressNotificationId);
      await _notifications.cancel(_syncCompleteNotificationId);
      await _notifications.cancel(_syncErrorNotificationId);

      _lastNotificationPhase = null;
      _lastNotificationIsError = null;
      _lastProgressValue = -1;

      OseerLogger.info('Sync notifications dismissed');
    } catch (e, stackTrace) {
      OseerLogger.error('Failed to dismiss sync notifications', e, stackTrace);
    }
  }

  /// Dismiss all notifications
  Future<void> dismissAllNotifications() async {
    try {
      await _notifications.cancelAll();

      _lastNotificationPhase = null;
      _lastNotificationIsError = null;
      _lastProgressValue = -1;

      OseerLogger.info('All notifications dismissed');
    } catch (e, stackTrace) {
      OseerLogger.error('Failed to dismiss all notifications', e, stackTrace);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    OseerLogger.info('Notification tapped: payload=$payload, action=$actionId');

    if (payload != null) {
      if (payload.startsWith('sync_')) {
        _handleSyncNotificationTap(payload, actionId);
      }
    }
  }

  void _handleSyncNotificationTap(String payload, String? actionId) {
    OseerLogger.info(
        'Handling sync notification tap: $payload, action: $actionId');

    switch (actionId) {
      case 'view_results':
        // Navigate to results screen
        break;
      case 'retry_sync':
        // Retry failed sync
        break;
      case 'view_details':
        // Navigate to details screen
        break;
    }
  }

  // Private helper methods

  Future<bool> _canShowNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await areNotificationsEnabled();
  }

  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Professional sync notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _syncChannelId,
        'Wellness Assessment',
        description: 'Real-time updates for your wellness assessments',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );

    // General notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        'Oseer Notifications',
        description: 'Important updates about your wellness journey',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );

    OseerLogger.info('Notification channels created');
  }

  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
    }
  }

  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
    }
  }
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
}
