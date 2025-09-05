// lib/widgets/sync_loading_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/sync_progress.dart';
import '../utils/constants.dart';

class SyncLoadingDialog extends StatefulWidget {
  final String title;
  final String initialMessage;
  final Stream<SyncProgress>? progressStream;
  final VoidCallback? onCancel;

  const SyncLoadingDialog({
    Key? key,
    required this.title,
    required this.initialMessage,
    this.progressStream,
    this.onCancel,
  }) : super(key: key);

  @override
  State<SyncLoadingDialog> createState() => _SyncLoadingDialogState();
}

class _SyncLoadingDialogState extends State<SyncLoadingDialog> {
  SyncProgress? _currentProgress;
  String _currentMessage = '';
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.initialMessage;
    _listenToProgress();
  }

  void _listenToProgress() {
    widget.progressStream?.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
          _currentMessage = progress.statusMessage;
          _progressValue = progress.progressPercentage;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 600 ? screenWidth * 0.9 : 480.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 48,
              offset: const Offset(0, 24),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: OseerColors.primary.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        OseerColors.primary.withOpacity(0.03),
                        Colors.transparent,
                        OseerColors.primaryLight.withOpacity(0.02),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Animated background circles
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        OseerColors.primary.withOpacity(0.08),
                        OseerColors.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(duration: 8000.ms, begin: 0, end: 1),
              ),
              Positioned(
                bottom: -40,
                left: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        OseerColors.primaryLight.withOpacity(0.06),
                        OseerColors.primaryLight.withOpacity(0.0),
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .rotate(duration: 10000.ms, begin: 1, end: 0),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OseerColors.primary,
                            OseerColors.primaryLight,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: OseerColors.primary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            color: Colors.white,
                            size: 44,
                          )
                              .animate(
                                  onPlay: (controller) => controller.repeat())
                              .rotate(duration: 2000.ms, begin: 0, end: 1),
                        ],
                      ),
                    )
                        .animate()
                        .scale(
                          duration: 700.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.0, 1.0),
                        )
                        .fade(duration: 400.ms),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: OseerColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuint),
                    const SizedBox(height: 12),

                    // Current activity message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _currentMessage,
                        key: ValueKey(_currentMessage),
                        style: TextStyle(
                          fontSize: 16,
                          color: OseerColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: OseerColors.border.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          child: LinearProgressIndicator(
                            value: _progressValue,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              OseerColors.primary,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                    const SizedBox(height: 12),

                    // Progress percentage
                    Text(
                      '${(_progressValue * 100).toInt()}% Complete',
                      style: TextStyle(
                        fontSize: 14,
                        color: OseerColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

                    // Details section
                    if (_currentProgress != null) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: OseerColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: OseerColors.border.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              Icons.fitness_center,
                              'Records Processed',
                              '${_currentProgress!.processedDataPoints}',
                              OseerColors.success,
                            ),
                            if (_currentProgress!.successfulUploads > 0) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                Icons.cloud_upload,
                                'Uploaded',
                                '${_currentProgress!.successfulUploads}',
                                OseerColors.info,
                              ),
                            ],
                            if (_currentProgress!.currentPhase != null) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                Icons.timeline,
                                'Phase',
                                _currentProgress!.currentPhase == 'bodyPrep'
                                    ? 'Body Prep'
                                    : _currentProgress!.currentPhase ==
                                            'digitalTwin'
                                        ? 'Digital Twin'
                                        : _currentProgress!.currentPhase ?? '',
                                OseerColors.primary,
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
                    ],

                    // Cancel button
                    if (widget.onCancel != null) ...[
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Continue in Background',
                          style: TextStyle(
                            color: OseerColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 700.ms),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.0, 1.0),
              duration: 500.ms,
              curve: Curves.easeOutQuint,
            )
            .fade(
              duration: 300.ms,
              curve: Curves.easeOut,
            ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: OseerColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: OseerColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
