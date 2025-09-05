// lib/widgets/connection_status_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../models/realtime_status.dart';

class ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final Duration? expiryTime;
  final DateTime? generatedTime;
  final DateTime? lastSyncTime;
  final String? deviceName;
  final String? errorMessage;
  final bool isAwaitingValidation;
  final RealtimeStatus realtimeStatus;
  final int reconnectAttempt;
  final VoidCallback? onDisconnectTap;

  const ConnectionStatusCard({
    Key? key,
    this.isConnected = false,
    this.expiryTime,
    this.generatedTime,
    this.lastSyncTime,
    this.deviceName,
    this.errorMessage,
    this.isAwaitingValidation = false,
    required this.realtimeStatus,
    required this.reconnectAttempt,
    this.onDisconnectTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final hasError = realtimeStatus == RealtimeStatus.error ||
        realtimeStatus == RealtimeStatus.networkError;

    final cardColor = isConnected
        ? OseerColors.tokenBackground
        : hasError
            ? OseerColors.error.withOpacity(0.1)
            : Colors.grey.shade100;

    final borderColor = isConnected
        ? OseerColors.tokenBorder
        : hasError
            ? OseerColors.error.withOpacity(0.3)
            : Colors.grey.shade300;

    String detailText = statusInfo.detailText;
    if (hasError && errorMessage != null && errorMessage!.isNotEmpty) {
      detailText = errorMessage!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusInfo.icon, color: statusInfo.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: statusInfo.color,
                        ),
                      ),
                      if (detailText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detailText,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasError
                                ? OseerColors.error
                                : OseerColors.textSecondary,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                if (isConnected && onDisconnectTap != null)
                  TextButton(
                    onPressed: onDisconnectTap,
                    style: TextButton.styleFrom(
                        foregroundColor: OseerColors.textSecondary),
                    child: const Text('Disconnect'),
                  )
              ],
            ),
            if (isConnected && deviceName != null)
              ..._buildDetailRow(Icons.phone_android, 'Device: $deviceName'),
            if (generatedTime != null && !isConnected)
              ..._buildDetailRow(Icons.access_time,
                  'Generated: ${OseerFormatters.formatDateTime(generatedTime!)}'),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
  }

  ({IconData icon, Color color, String title, String detailText})
      _getStatusInfo() {
    if (isConnected) {
      final syncText = lastSyncTime != null
          ? 'Last synced ${OseerFormatters.timeAgo(lastSyncTime!)}'
          : 'Ready to sync health data';
      return (
        icon: Icons.check_circle,
        color: OseerColors.success,
        title: 'Connected',
        detailText: syncText
      );
    }

    if (isAwaitingValidation) {
      return (
        icon: Icons.hourglass_top,
        color: OseerColors.info,
        title: 'Awaiting Validation',
        detailText: 'Enter the code on the web to connect.'
      );
    }

    switch (realtimeStatus) {
      case RealtimeStatus.connecting:
        return (
          icon: Icons.sync,
          color: OseerColors.info,
          title: 'Connecting...',
          detailText: 'Establishing a secure link...'
        );
      case RealtimeStatus.retrying:
        return (
          icon: Icons.sync_problem,
          color: OseerColors.warning,
          title: 'Reconnecting...',
          detailText: 'Connection unstable. Attempt $reconnectAttempt/5.'
        );
      case RealtimeStatus.networkError:
        return (
          icon: Icons.wifi_off,
          color: OseerColors.error,
          title: 'Network Error',
          detailText: 'Please check your internet connection.'
        );
      case RealtimeStatus.error:
        return (
          icon: Icons.error_outline,
          color: OseerColors.error,
          title: 'Connection Failed',
          detailText: 'Could not connect to the service.'
        );
      case RealtimeStatus.disconnected:
      case RealtimeStatus
            .subscribed: // A token can be subscribed but not yet 'Connected'
        if (expiryTime != null) {
          final formattedExpiry = OseerFormatters.formatDuration(expiryTime);
          return (
            icon: Icons.token,
            color: OseerColors.info,
            title: 'Token Generated',
            detailText: 'Expires in $formattedExpiry'
          );
        }
        return (
          icon: Icons.link_off,
          color: OseerColors.textSecondary,
          title: 'Not Connected',
          detailText: 'Generate a code to start.'
        );
    }
  }

  List<Widget> _buildDetailRow(IconData icon, String text) {
    return [
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(icon, size: 18, color: OseerColors.textSecondary),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: OseerColors.textSecondary)),
        ],
      ),
    ];
  }
}
