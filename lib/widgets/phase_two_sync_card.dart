// lib/widgets/phase_two_sync_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../utils/constants.dart';

class PhaseTwoSyncCard extends StatelessWidget {
  final int daysProcessed;
  final int totalDays;

  const PhaseTwoSyncCard({
    Key? key,
    required this.daysProcessed,
    this.totalDays = 90,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double progress = (daysProcessed / totalDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: OseerColors.primary.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: OseerColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: OseerColors.primary,
                  size: 24,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .rotate(duration: 3000.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phase 2: Digital Twin',
                      style: OseerTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: OseerColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Building your comprehensive wellness profile',
                      style: OseerTextStyles.bodySmall.copyWith(
                        color: OseerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OseerColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historical Data Sync',
                      style: OseerTextStyles.bodyRegular.copyWith(
                        fontWeight: FontWeight.w500,
                        color: OseerColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: OseerTextStyles.bodyRegular.copyWith(
                        fontWeight: FontWeight.w600,
                        color: OseerColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      OseerColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$daysProcessed of $totalDays days synced',
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: OseerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.shade200.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This runs in the background and may take up to 2 hours. You can safely close the app.',
                    style: OseerTextStyles.bodySmall.copyWith(
                      color: Colors.blue.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                context
                    .read<ConnectionBloc>()
                    .add(const LaunchWellnessHubEvent());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: OseerColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View Wellness Hub',
                    style: OseerTextStyles.buttonText.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .slideY(begin: 0.02, end: 0, duration: 400.ms);
  }
}
