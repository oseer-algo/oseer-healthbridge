// lib/widgets/notification_permission_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../utils/constants.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: screenHeight,
      width: screenWidth,
      alignment: Alignment.bottomCenter,
      child: Container(
        height: screenHeight * 0.95, // Increased to 95% like wellness sheet
        width: screenWidth,
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Stack(
          children: [
            // Subtle gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
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
            // Background decorative circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      OseerColors.primary.withOpacity(0.05),
                      OseerColors.primary.withOpacity(0.0),
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    duration: 4000.ms,
                    curve: Curves.easeInOut,
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                  )
                  .then()
                  .scale(
                    duration: 4000.ms,
                    curve: Curves.easeInOut,
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(0.9, 0.9),
                  ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      OseerColors.primaryLight.withOpacity(0.04),
                      OseerColors.primaryLight.withOpacity(0.0),
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    duration: 5000.ms,
                    delay: 1000.ms,
                    curve: Curves.easeInOut,
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                  )
                  .then()
                  .scale(
                    duration: 5000.ms,
                    curve: Curves.easeInOut,
                    begin: const Offset(1.05, 1.05),
                    end: const Offset(0.95, 0.95),
                  ),
            ),
            // Content
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

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
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: OseerColors.primary.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 44,
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 2000.ms,
                          delay: 1000.ms,
                          color: Colors.white.withOpacity(0.3),
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

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Stay Connected',
                    style: OseerTextStyles.h1.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 300.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuint),
                  const SizedBox(height: 8),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Get timely updates about your wellness journey',
                      style: OseerTextStyles.bodyRegular.copyWith(
                        color: OseerColors.textSecondary,
                        fontSize: 16,
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuint),

                  const SizedBox(height: 40),

                  // Benefits
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildBenefitItem(
                          icon: Icons.sync_rounded,
                          iconColor: OseerColors.info,
                          title: 'Real-time Updates',
                          description: 'Instant health sync alerts',
                          delay: 500,
                        ),
                        const SizedBox(height: 20),
                        _buildBenefitItem(
                          icon: Icons.insights_rounded,
                          iconColor: OseerColors.success,
                          title: 'Smart Insights',
                          description: 'Personalized wellness tips',
                          delay: 600,
                        ),
                        const SizedBox(height: 20),
                        _buildBenefitItem(
                          icon: Icons.celebration_rounded,
                          iconColor: OseerColors.warning,
                          title: 'Celebrate Wins',
                          description: 'Achievement notifications',
                          delay: 700,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Enable button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                OseerColors.primary,
                                OseerColors.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: OseerColors.primary.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.read<AuthBloc>().add(
                                    const AuthNotificationsPermissionRequested());
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Text(
                                  'Enable Notifications',
                                  style: OseerTextStyles.buttonText.copyWith(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 800.ms)
                            .slideY(
                                begin: 0.3, end: 0, curve: Curves.easeOutQuint)
                            .scale(
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1.0, 1.0),
                              duration: 400.ms,
                              delay: 800.ms,
                            ),

                        const SizedBox(height: 16),

                        // Skip button
                        TextButton(
                          onPressed: () {
                            context.read<AuthBloc>().add(
                                const AuthNotificationPermissionHandled(false));
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Maybe Later',
                            style: OseerTextStyles.bodyRegular.copyWith(
                              color: OseerColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Privacy note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: OseerColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: OseerColors.border.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: OseerColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: OseerColors.primary,
                            )
                                .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true),
                                  delay: 2000.ms,
                                )
                                .scale(
                                  duration: 1500.ms,
                                  begin: const Offset(1.0, 1.0),
                                  end: const Offset(1.1, 1.1),
                                ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can change this anytime in settings',
                              style: OseerTextStyles.bodySmall.copyWith(
                                color: OseerColors.textTertiary,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ).animate().slideY(
              begin: 1.0,
              end: 0.0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OseerColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OseerColors.border.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.12),
                  iconColor.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 26,
              color: iconColor,
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                  delay: Duration(milliseconds: delay + 500),
                )
                .scale(
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.05, 1.05),
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OseerTextStyles.bodyBold.copyWith(
                    color: OseerColors.textPrimary,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: OseerColors.textSecondary,
                    fontSize: 14,
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuint);
  }
}
