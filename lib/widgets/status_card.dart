// File path: lib/widgets/status_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/connection/connection_bloc.dart' as connection;
import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_state.dart' as health_state;
import '../models/helper_models.dart';
import '../utils/constants.dart';

class StatusCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showShadow;

  const StatusCard({
    Key? key,
    this.onTap,
    this.showShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OseerSpacing.cardRadius),
      child: BlocBuilder<HealthBloc, health_state.HealthState>(
        builder: (context, healthState) {
          return Card(
            elevation: showShadow ? 1 : 0,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OseerSpacing.cardRadius),
              side: BorderSide(
                color: OseerColors.divider,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(OseerSpacing.cardPadding),
              child: Column(
                children: [
                  _buildConnectionStatus(context),
                  const SizedBox(height: OseerSpacing.md),
                  const Divider(color: OseerColors.divider),
                  const SizedBox(height: OseerSpacing.md),
                  _buildWellnessPermissionStatus(context, healthState),
                  const SizedBox(height: OseerSpacing.md),
                ],
              ),
            ),
          ).animate().fadeIn(duration: OseerConstants.mediumAnimDuration);
        },
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context) {
    return BlocBuilder<connection.ConnectionBloc, connection.ConnectionState>(
      builder: (context, state) {
        return Row(
          children: [
            _buildStatusIcon(
              isConnected:
                  state.status == connection.ConnectionStatus.connected,
              type: 'connection',
              isLoading: state.status == connection.ConnectionStatus.connecting,
              showError:
                  state.status == connection.ConnectionStatus.disconnected ||
                      state.status == connection.ConnectionStatus.error,
            ),
            const SizedBox(width: OseerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.status == connection.ConnectionStatus.connected
                        ? 'Connected to Oseer'
                        : state.status == connection.ConnectionStatus.connecting
                            ? 'Connecting to Oseer...'
                            : 'Not Connected',
                    style: OseerTextStyles.bodyRegular.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.status == connection.ConnectionStatus.connected
                        ? 'Your device is linked and syncing'
                        : state.status == connection.ConnectionStatus.connecting
                            ? 'Establishing connection...'
                            : 'Tap to connect your device',
                    style: OseerTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: OseerColors.textTertiary,
              size: 20,
            ),
          ],
        );
      },
    );
  }

  Widget _buildWellnessPermissionStatus(
      BuildContext context, health_state.HealthState state) {
    // Default values
    bool isConnected = false;
    bool isLoading = false;
    bool showWarning = false;
    String title = 'Wellness Permissions';
    String subtitle = 'Allow access to wellness data';
    HealthPermissionStatus? status;

    // Get status from the state
    if (state is health_state.HealthPermissionsChecked) {
      status = state.authStatus.status;
      isLoading = state.requestStatus == RequestStatus.loading;

      if (status == HealthPermissionStatus.granted) {
        isConnected = true;
        title = 'All Wellness Permissions Granted';
        subtitle = 'Your wellness data is being monitored';
      } else if (status == HealthPermissionStatus.partiallyGranted) {
        isConnected = false;
        showWarning = true;
        title = 'Wellness Access Partially Granted';
        subtitle = 'Some wellness features may be limited';
      } else if (status == HealthPermissionStatus.denied) {
        isConnected = false;
        title = 'Wellness Permissions Required';
        subtitle = 'Tap to allow access to wellness data';
      } else if (status == HealthPermissionStatus.unavailable) {
        isConnected = false;
        title = 'Wellness Services Unavailable';
        subtitle = 'Limited features available on this device';
      } else if (status == HealthPermissionStatus.promptingUser) {
        isLoading = true;
        title = 'Requesting Permissions...';
        subtitle = 'Please respond to the system prompt';
      }
    } else if (state is health_state.HealthDataSynced) {
      status = state.authStatus.status;

      if (status == HealthPermissionStatus.granted) {
        isConnected = true;
        title = 'All Wellness Permissions Granted';
        subtitle = 'Your wellness data is being monitored';
      } else if (status == HealthPermissionStatus.partiallyGranted) {
        isConnected = false;
        showWarning = true;
        title = 'Wellness Access Partially Granted';
        subtitle = 'Some wellness features may be limited';
      } else if (status == HealthPermissionStatus.denied) {
        isConnected = false;
        title = 'Wellness Permissions Required';
        subtitle = 'Tap to allow access to wellness data';
      } else if (status == HealthPermissionStatus.unavailable) {
        isConnected = false;
        title = 'Wellness Services Unavailable';
        subtitle = 'Limited features available on this device';
      } else if (status == HealthPermissionStatus.promptingUser) {
        isLoading = true;
        title = 'Requesting Permissions...';
        subtitle = 'Please respond to the system prompt';
      }
    } else if (state is health_state.HealthLoading) {
      isLoading = true;
      title = 'Checking Wellness Permissions...';
      subtitle = 'Please wait while we check your permissions';
    }

    return Row(
      children: [
        _buildStatusIcon(
          isConnected: isConnected,
          type: 'wellness',
          isLoading: isLoading,
          showWarning: showWarning,
        ),
        const SizedBox(width: OseerSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: OseerTextStyles.bodyRegular.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: OseerTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          color: OseerColors.textTertiary,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildStatusIcon({
    required bool isConnected,
    required String type,
    bool isLoading = false,
    bool showWarning = false,
    bool showError = false,
  }) {
    if (isLoading) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(OseerSpacing.buttonRadius),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(OseerColors.primary),
            ),
          ),
        ),
      );
    }

    Color bgColor;
    IconData icon;
    Color iconColor;

    // Error state (red X)
    if (showError) {
      bgColor = Colors.red[50]!;
      iconColor = OseerColors.error;
      icon = Icons.close;
    }
    // Warning state (yellow triangle)
    else if (showWarning) {
      bgColor = Colors.amber[50]!;
      iconColor = OseerColors.warning;
      icon = Icons.warning_amber_rounded;
    }
    // Connected state (green checkmark or relevant icon)
    else if (isConnected) {
      bgColor = OseerColors.primary.withOpacity(0.1);
      iconColor = OseerColors.primary;

      if (type == 'connection') {
        icon = Icons.link;
      } else {
        // wellness
        icon = Icons.favorite;
      }
    }
    // Disconnected state (gray icon)
    else {
      bgColor = Colors.grey[100]!;
      iconColor = Colors.grey;

      if (type == 'connection') {
        icon = Icons.link_off;
      } else {
        // wellness
        icon = Icons.favorite_border;
      }
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OseerSpacing.buttonRadius),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 20,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fadeIn(duration: 300.ms)
        .then(delay: 2000.ms) // Only animate when status changes
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.05, 1.05),
          duration: 700.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.05, 1.05),
          end: const Offset(1.0, 1.0),
          duration: 700.ms,
        );
  }
}
