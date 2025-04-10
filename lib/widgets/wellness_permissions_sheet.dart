// File path: lib/widgets/wellness_permissions_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart';
import '../models/helper_models.dart';
import '../utils/constants.dart';

/// Bottom sheet that requests wellness permissions
class WellnessPermissionsSheet extends StatefulWidget {
  final VoidCallback onGranted;
  final VoidCallback onSkip;

  const WellnessPermissionsSheet({
    Key? key,
    required this.onGranted,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<WellnessPermissionsSheet> createState() =>
      _WellnessPermissionsSheetState();
}

class _WellnessPermissionsSheetState extends State<WellnessPermissionsSheet> {
  bool _isRequestingPermissions = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: BlocConsumer<HealthBloc, HealthState>(
          listener: (context, state) {
            if (state is HealthPermissionsChecked) {
              if (state.requestStatus == RequestStatus.success) {
                if (state.authStatus.status == HealthPermissionStatus.granted ||
                    state.authStatus.status ==
                        HealthPermissionStatus.partiallyGranted) {
                  // Permissions granted, proceed
                  widget.onGranted();
                } else if (state.authStatus.status ==
                    HealthPermissionStatus.unavailable) {
                  // Wellness Connect not available, show message and allow skip
                  _showWellnessConnectUnavailableDialog(context);
                }
              }
              setState(() {
                _isRequestingPermissions = false;
              });
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSheetHeader(),
                const SizedBox(height: 24),
                _buildPermissionsList(),
                const SizedBox(height: 32),
                _buildActionButtons(context, state),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isRequestingPermissions ? null : widget.onSkip,
                    child: const Text('Skip for now'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Gray drag handle at top
        Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Icon with text
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: OseerColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.favorite,
            color: OseerColors.primary,
            size: 32,
          ),
        ).animate().scale(
              duration: 300.ms,
              curve: Curves.easeOut,
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
            ),

        const SizedBox(height: 16),
        Text(
          'Wellness Data Access',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'To provide personalized insights, we need access to your wellness data. This data never leaves your device without your permission.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildPermissionsList() {
    return Column(
      children: [
        _buildPermissionItem(
          icon: Icons.monitor_heart,
          title: 'Heart Rate & HRV',
          description: 'Monitor heart health patterns and stress levels',
        ),
        _buildPermissionItem(
          icon: Icons.directions_walk,
          title: 'Steps & Activity',
          description: 'Track your daily movement and exercise',
        ),
        _buildPermissionItem(
          icon: Icons.bedtime,
          title: 'Sleep Data',
          description: 'Analyze sleep duration and quality',
        ),
        _buildPermissionItem(
          icon: Icons.straighten,
          title: 'Body Measurements',
          description: 'Record height, weight, and other metrics',
        ),
      ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slide(
            begin: const Offset(0, 0.1),
            end: const Offset(0, 0),
            duration: 300.ms,
          ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: OseerColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: OseerColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, HealthState state) {
    bool isWellnessConnectAvailable = true;
    String buttonText = 'Allow Wellness Data Access';

    if (state is HealthPermissionsChecked) {
      isWellnessConnectAvailable =
          state.authStatus.status != HealthPermissionStatus.unavailable;

      if (!isWellnessConnectAvailable) {
        buttonText = 'Continue Anyway';
      }
    }

    return ElevatedButton(
      onPressed: _isRequestingPermissions
          ? null
          : () async {
              try {
                setState(() {
                  _isRequestingPermissions = true;
                });

                // Provide haptic feedback
                HapticFeedback.mediumImpact();

                if (!isWellnessConnectAvailable) {
                  // If Wellness Connect isn't available, just skip to next step
                  await Future.delayed(const Duration(milliseconds: 300));
                  widget.onGranted();
                  return;
                }

                // Request permissions
                context
                    .read<HealthBloc>()
                    .add(const RequestHealthPermissionsEvent());
              } catch (e) {
                setState(() {
                  _isRequestingPermissions = false;
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: OseerColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isRequestingPermissions
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              buttonText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  void _showWellnessConnectUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wellness Connect Not Available'),
        content: const Text(
            'Wellness Connect is not available on this device. You can still use the app with limited features.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSkip();
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onGranted();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OseerColors.primary,
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }
}
