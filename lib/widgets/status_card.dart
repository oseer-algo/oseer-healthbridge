// File path: lib/widgets/status_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/connection/connection_bloc.dart' as connection;
import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_state.dart' as health_state;
import '../models/helper_models.dart'; // Ensure HealthPermissionStatus is defined here
import '../utils/constants.dart'; // Import constants

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
              side: const BorderSide(
                // Can be const
                color: OseerColors.divider,
                width: 1,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(OseerSpacing.cardPadding), // Use const
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionStatus(context),
                  const SizedBox(height: OseerSpacing.md),
                  const Divider(color: OseerColors.divider),
                  const SizedBox(height: OseerSpacing.md),
                  _buildWellnessPermissionStatus(context, healthState),
                  // Removed extra SizedBox at the end if not needed for layout
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
                            ? 'Connecting...'
                            : 'Not Connected',
                    style: OseerTextStyles.bodyRegular.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.status == connection.ConnectionStatus.connected
                        ? state.deviceName ?? 'Device linked'
                        : state.status == connection.ConnectionStatus.connecting
                            ? 'Establishing link...'
                            : 'Tap to connect',
                    style: OseerTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
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
    bool isConnected = false;
    bool isLoading = false;
    bool showWarning = false;
    bool showError = false;
    String title = 'Wellness Permissions';
    String subtitle = 'Allow access to sync data';
    HealthPermissionStatus? status;

    if (state is health_state.HealthPermissionsChecked) {
      status = state.authStatus.status;
      isLoading = state.requestStatus == RequestStatus.loading;
    } else if (state is health_state.HealthDataSynced) {
      status = state.authStatus.status;
    } else if (state is health_state.HealthLoading &&
        (state.message?.toLowerCase().contains('permission') ?? false)) {
      isLoading = true;
    } else if (state is health_state.HealthError &&
        (state.message?.toLowerCase().contains('permission') ?? false)) {
      // *** FIX: Use a valid enum status like denied or unavailable for errors ***
      status = HealthPermissionStatus
          .denied; // Or .unavailable or a custom .error if you define it
      showError = true; // Indicate error state visually
    }

    // Set UI text based on status
    if (status == HealthPermissionStatus.granted) {
      isConnected = true;
      title = 'Permissions Granted';
      subtitle = 'Wellness data access enabled';
    } else if (status == HealthPermissionStatus.partiallyGranted) {
      isConnected = false;
      showWarning = true;
      title = 'Partial Access Granted';
      subtitle = 'Some data may not sync';
    } else if (status == HealthPermissionStatus.denied) {
      isConnected = false;
      showError = true;
      title = 'Permissions Required';
      subtitle = 'Tap to grant access';
    } else if (status == HealthPermissionStatus.unavailable) {
      isConnected = false;
      showWarning = true;
      title = 'Service Unavailable';
      subtitle = 'Health Connect/Kit not supported';
    }
    // FIXED: Removed reference to non-existent promptingUser enum constant
    // Default state if status is null and not loading
    else if (status == null && !isLoading) {
      isConnected = false;
      title = 'Check Permissions';
      subtitle = 'Tap to verify wellness access';
    }

    return Row(
      children: [
        _buildStatusIcon(
          isConnected: isConnected,
          type: 'wellness',
          isLoading: isLoading,
          showWarning: showWarning,
          showError: showError,
        ),
        const SizedBox(width: OseerSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: OseerTextStyles.bodyRegular
                      .copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: OseerTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const Icon(Icons.chevron_right,
            color: OseerColors.textTertiary, size: 20),
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
    Widget content;
    Color bgColor;
    Color iconColor;
    // *** FIX: Declare icon variable with a default value ***
    IconData icon = Icons.help_outline; // Default icon

    if (isLoading) {
      bgColor = Colors.grey[100]!;
      content = Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(OseerColors.primary))));
    } else {
      if (showError) {
        bgColor = OseerColors.error.withOpacity(0.1);
        iconColor = OseerColors.error;
        icon = Icons.error_outline_rounded;
      } else if (showWarning) {
        bgColor = OseerColors.warning.withOpacity(0.1);
        iconColor = OseerColors.warning;
        icon = Icons.warning_amber_rounded;
      } else if (isConnected) {
        bgColor = OseerColors.primary.withOpacity(0.1);
        iconColor = OseerColors.primary;
        icon = (type == 'connection')
            ? Icons.link_rounded
            : Icons.favorite_rounded;
      } else {
        bgColor = Colors.grey[100]!;
        iconColor = Colors.grey;
        icon = (type == 'connection')
            ? Icons.link_off_rounded
            : Icons.favorite_border_rounded;
      }
      content = Icon(icon, color: iconColor, size: 20);
    }

    Widget container = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(OseerSpacing.buttonRadius)),
      child: content,
    );

    if (!isLoading) {
      container = container
          .animate()
          .fadeIn(duration: OseerConstants.shortAnimDuration);
    }
    return container;
  }
}
