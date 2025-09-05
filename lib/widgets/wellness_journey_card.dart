// lib/widgets/wellness_journey_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart';
import '../utils/constants.dart';
import '../models/sync_progress.dart';
import '../services/logger_service.dart';
import '../services/toast_service.dart';

enum WellnessPhase {
  intro,
  bodyPrep,
  digitalTwin,
  complete,
}

class WellnessJourneyCard extends StatefulWidget {
  final WellnessPhase currentPhase;
  final double bodyPrepProgress;
  final int digitalTwinDaysProcessed;
  final DateTime? bodyPrepReadyTime;
  final DateTime? estimatedTwinCompletion;
  final bool isBodyPrepReady;
  final VoidCallback? onViewResults;

  const WellnessJourneyCard({
    Key? key,
    required this.currentPhase,
    this.bodyPrepProgress = 0.0,
    this.digitalTwinDaysProcessed = 0,
    this.bodyPrepReadyTime,
    this.estimatedTwinCompletion,
    this.isBodyPrepReady = false,
    this.onViewResults,
  }) : super(key: key);

  @override
  State<WellnessJourneyCard> createState() => _WellnessJourneyCardState();
}

class _WellnessJourneyCardState extends State<WellnessJourneyCard> {
  bool _isInfoExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildContent(context),
            if (widget.isBodyPrepReady) _buildActionSection(context),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .slideY(begin: 0.02, end: 0, duration: 400.ms);
  }

  Widget _buildHeader(BuildContext context) {
    String title = 'Wellness Profile Setup';
    String subtitle = widget.currentPhase == WellnessPhase.intro
        ? 'STARTING'
        : widget.currentPhase == WellnessPhase.bodyPrep
            ? 'IN-PROGRESS | PHASE 1'
            : widget.currentPhase == WellnessPhase.digitalTwin
                ? 'IN-PROGRESS | PHASE 2'
                : 'COMPLETE';

    return Container(
      padding: const EdgeInsets.all(24), // HaHo standard padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OseerColors.primary.withOpacity(0.9),
            OseerColors.primaryLight.withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: OseerTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 22, // Apple standard title
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: OseerTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13, // Apple standard caption
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildProgressIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    double progress = 0.0;
    if (widget.currentPhase == WellnessPhase.intro) {
      progress = 0.0;
    } else if (widget.currentPhase == WellnessPhase.bodyPrep) {
      progress = widget.bodyPrepProgress * 0.5;
    } else if (widget.currentPhase == WellnessPhase.digitalTwin) {
      progress = 0.5 + (widget.digitalTwinDaysProcessed / 90.0 * 0.5);
    } else if (widget.currentPhase == WellnessPhase.complete) {
      progress = 1.0;
    }

    return Container(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: OseerTextStyles.bodyRegular.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17, // Apple standard body
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.currentPhase == WellnessPhase.intro) {
      return _buildIntroContent(context);
    }
    return _buildProgressContent(context);
  }

  Widget _buildIntroContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), // HaHo standard padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creating Your Personalized Profile',
            style: OseerTextStyles.h3.copyWith(
              fontSize: 20, // Apple standard headline
              fontWeight: FontWeight.w600,
              color: OseerColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Two-phase analysis: Quick 2-minute Body Preparedness score, '
            'then 90-day background sync for your Digital Twin.',
            style: OseerTextStyles.bodyRegular.copyWith(
              color: OseerColors.textSecondary,
              height: 1.5,
              fontSize: 15, // Apple standard body
            ),
          ),
          const SizedBox(height: 32),
          _buildPhasePreview(
            number: '1',
            title: 'Phase 1: Body Preparedness',
            subtitle: '2-minute quick analysis',
            isActive: true,
            isComplete: false,
          ),
          const SizedBox(height: 16),
          _buildPhasePreview(
            number: '2',
            title: 'Phase 2: Digital Twin',
            subtitle: '90-day comprehensive analysis',
            isActive: false,
            isComplete: false,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildProgressContent(BuildContext context) {
    final phaseText = widget.currentPhase == WellnessPhase.bodyPrep
        ? '2 Tasks • Phase 1'
        : widget.currentPhase == WellnessPhase.digitalTwin
            ? '2 Tasks • Phase 2'
            : 'Complete';

    // FIX: Get sync progress from ConnectionBloc for dynamic text
    final syncProgress = context.watch<ConnectionBloc>().state.syncProgressData;

    return Container(
      padding: const EdgeInsets.all(24), // HaHo standard padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phaseText,
            style: OseerTextStyles.bodyRegular.copyWith(
              color: OseerColors.textSecondary,
              fontSize: 15, // Apple standard body
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.currentPhase == WellnessPhase.bodyPrep) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _isInfoExpanded = !_isInfoExpanded;
                });
              },
              child: _buildTaskItem(
                icon: Icons.sync_rounded,
                title: 'Syncing Health Data',
                subtitle: _getProgressSubtitle(syncProgress),
                isActive: true,
                isComplete: false,
                progress: widget.bodyPrepProgress,
                progressText:
                    _getProgressText(syncProgress, widget.bodyPrepProgress),
                isAnimated: true,
                isExpandable: true,
                isExpanded: _isInfoExpanded,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isInfoExpanded ? null : 0,
              child: _isInfoExpanded
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: OseerColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Oseer performs a two-step sync to create your wellness profile. '
                          'First, a quick 2-minute sync for your Body Preparedness score. '
                          'Then, a 90-day background sync to build your Digital Twin and Wellness Report.',
                          style: OseerTextStyles.bodyRegular.copyWith(
                            color: OseerColors.primary,
                            fontSize: 14, // Apple standard footnote
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _buildTaskItem(
              icon: Icons.analytics_rounded,
              title: 'Calculate Body Preparedness',
              subtitle: 'Your readiness score',
              isActive: false,
              isComplete: false,
              isLocked: widget.bodyPrepProgress < 1.0,
            ),
          ] else if (widget.currentPhase == WellnessPhase.digitalTwin) ...[
            _buildTaskItem(
              icon: Icons.check_circle_rounded,
              title: 'Body Preparedness Complete',
              subtitle: 'Score ready to view',
              isActive: false,
              isComplete: true,
            ),
            const SizedBox(height: 16),
            _buildTaskItem(
              icon: Icons.psychology_rounded,
              title: 'Building Digital Twin',
              subtitle:
                  'Processing ${widget.digitalTwinDaysProcessed} of 90 days',
              isActive: true,
              isComplete: false,
              progress: widget.digitalTwinDaysProcessed / 90.0,
              progressText: 'Analyzing historical data...',
              isAnimated: true,
            ),
          ] else if (widget.currentPhase == WellnessPhase.complete) ...[
            _buildTaskItem(
              icon: Icons.check_circle_rounded,
              title: 'Body Preparedness',
              subtitle: 'Analysis complete',
              isActive: false,
              isComplete: true,
            ),
            const SizedBox(height: 16),
            _buildTaskItem(
              icon: Icons.check_circle_rounded,
              title: 'Digital Twin',
              subtitle: '90-day analysis complete',
              isActive: false,
              isComplete: true,
            ),
          ],
        ],
      ),
    );
  }

  String _getProgressSubtitle(SyncProgress? syncProgress) {
    if (syncProgress == null) return 'Analyzing recent wellness metrics';

    switch (syncProgress.stage) {
      case SyncStage.fetching:
        return 'Fetching from your device...';
      case SyncStage.processing:
        return 'Preparing wellness data...';
      case SyncStage.uploading:
        return 'Uploading to Oseer cloud...';
      case SyncStage.analyzing:
        return 'Analyzing your metrics on our servers...';
      default:
        return 'Analyzing recent wellness metrics';
    }
  }

  String _getProgressText(SyncProgress? syncProgress, double bodyPrepProgress) {
    if (syncProgress == null) {
      return '${(bodyPrepProgress * 100).round()}% complete';
    }

    // Provides more granular text based on the current stage
    switch (syncProgress.stage) {
      case SyncStage.fetching:
        return 'Reading data...';
      case SyncStage.processing:
        return 'Processing ${syncProgress.totalDataPoints} records...';
      case SyncStage.uploading:
        final percent = (syncProgress.progressPercentage * 100).toInt();
        return 'Uploading: $percent%';
      case SyncStage.analyzing:
        return 'Finalizing analysis...';
      default:
        return '${(bodyPrepProgress * 100).round()}% complete';
    }
  }

  Widget _buildPhasePreview({
    required String number,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isComplete,
  }) {
    return Container(
      padding: const EdgeInsets.all(20), // HaHo standard inner padding
      decoration: BoxDecoration(
        color: isActive
            ? OseerColors.primary.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? OseerColors.primary.withOpacity(0.2)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? OseerColors.primary : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: OseerTextStyles.bodyRegular.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17, // Apple standard body
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OseerTextStyles.bodyRegular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: OseerColors.textPrimary,
                    fontSize: 17, // Apple standard body
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: OseerColors.textSecondary,
                    fontSize: 15, // Apple standard callout
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isComplete,
    double? progress,
    String? progressText,
    SyncProgress? syncProgress, // ADD THIS NEW PARAMETER
    bool isLocked = false,
    bool isAnimated = false,
    bool isExpandable = false,
    bool isExpanded = false,
  }) {
    // Determine progress and text from the SyncProgress object if available
    final currentProgress = syncProgress?.bodyPrepProgress ?? progress ?? 0.0;
    final currentProgressText = syncProgress != null
        ? _getProgressText(syncProgress, currentProgress)
        : progressText;
    final currentSubtitle =
        syncProgress != null ? _getProgressSubtitle(syncProgress) : subtitle;

    return Container(
      padding: const EdgeInsets.all(20), // HaHo standard inner padding
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.grey.shade50
            : isComplete
                ? Colors.green.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked
              ? Colors.grey.shade200
              : isComplete
                  ? Colors.green.shade200
                  : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.grey.shade200
                  : isComplete
                      ? Colors.green.shade100
                      : OseerColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: isAnimated && isActive && !isComplete
                ? Icon(
                    icon,
                    color: OseerColors.primary,
                    size: 24,
                  )
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(duration: 2000.ms)
                : Icon(
                    isLocked ? Icons.lock_outline : icon,
                    color: isLocked
                        ? Colors.grey.shade400
                        : isComplete
                            ? Colors.green.shade600
                            : OseerColors.primary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OseerTextStyles.bodyRegular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLocked
                        ? Colors.grey.shade400
                        : OseerColors.textPrimary,
                    fontSize: 17, // Apple standard body
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentSubtitle, // USE DYNAMIC SUBTITLE
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: isLocked
                        ? Colors.grey.shade400
                        : OseerColors.textSecondary,
                    fontSize: 15, // Apple standard callout
                  ),
                ),
                if (currentProgress > 0 && !isComplete) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: currentProgress),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              OseerColors.primary,
                            ),
                            minHeight: 4,
                          );
                        },
                      ),
                      if (currentProgressText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          currentProgressText,
                          style: OseerTextStyles.bodySmall.copyWith(
                            color: OseerColors.textSecondary,
                            fontSize: 13, // Apple standard caption
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isExpandable)
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey.shade400,
              size: 24,
            )
          else
            Icon(
              Icons.chevron_right,
              color: isLocked ? Colors.grey.shade300 : Colors.grey.shade400,
              size: 24,
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), // HaHo standard padding
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56, // HaHo standard button height
        child: ElevatedButton(
          onPressed: widget.onViewResults,
          style: ElevatedButton.styleFrom(
            backgroundColor: OseerColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'VIEW YOUR SCORE',
            style: OseerTextStyles.buttonText.copyWith(
              fontSize: 17, // Apple standard body
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
