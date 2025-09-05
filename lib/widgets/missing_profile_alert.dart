// lib/widgets/missing_profile_alert.dart

import 'package:flutter/material.dart';

/// Simplified alert for missing profile data
/// Removed complex Digital Twin integration prompts
class MissingProfileAlert extends StatelessWidget {
  final VoidCallback? onCompleteProfile;
  final VoidCallback? onDismiss;
  final String? customMessage;

  const MissingProfileAlert({
    Key? key,
    this.onCompleteProfile,
    this.onDismiss,
    this.customMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.person_outline,
            color: Colors.orange,
          ),
          SizedBox(width: 8),
          Text('Complete Your Profile'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customMessage ??
                'Your profile is missing some important health information. '
                    'Complete your profile to get better health insights.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'We need basic info like height, weight, and activity level.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: const Text('Later'),
          ),
        if (onCompleteProfile != null)
          ElevatedButton(
            onPressed: onCompleteProfile,
            child: const Text('Complete Profile'),
          ),
      ],
    );
  }

  /// Show the alert dialog
  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onCompleteProfile,
    VoidCallback? onDismiss,
    String? customMessage,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MissingProfileAlert(
        onCompleteProfile: () {
          Navigator.of(context).pop(true);
          onCompleteProfile?.call();
        },
        onDismiss: () {
          Navigator.of(context).pop(false);
          onDismiss?.call();
        },
        customMessage: customMessage,
      ),
    );
  }
}
