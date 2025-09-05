// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    OseerLogger.info('🚀 WelcomeScreen initialized');
  }

  Future<void> _handleContinue() async {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      final prefs = context.read<SharedPreferences>();
      await prefs.setBool(OseerConstants.keyHasSeenWelcome, true);

      if (mounted) {
        // Trigger the AuthBloc to re-evaluate and navigate to login
        context.read<AuthBloc>().add(const AuthInitializeEvent());
      }
    } catch (e) {
      OseerLogger.error('Failed to handle continue action', e);
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseerColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              OseerColors.background,
              OseerColors.primary.withOpacity(0.03),
              OseerColors.primaryLight.withOpacity(0.02),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative circles
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 250,
                  height: 250,
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
                bottom: -80,
                left: -80,
                child: Container(
                  width: 200,
                  height: 200,
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OseerColors.primary,
                            OseerColors.primaryLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: OseerColors.primary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.healing_rounded,
                        color: Colors.white,
                        size: 52,
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

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'Welcome to HealthBridge',
                      style: OseerTextStyles.h1.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuint),

                    const SizedBox(height: 12),

                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'The secure key to your Oseer Wellness Hub',
                        style: OseerTextStyles.bodyRegular.copyWith(
                          color: OseerColors.textSecondary,
                          fontSize: 18,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 400.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuint),

                    const SizedBox(height: 48),

                    // Info Cards
                    Column(
                      children: [
                        _buildInfoCard(
                          icon: Icons.sync_alt_rounded,
                          iconColor: OseerColors.info,
                          title: 'A Secure Bridge',
                          subtitle:
                              'Connect your device\'s health data directly and securely to the Oseer Hub.',
                          delay: 500,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.insights_rounded,
                          iconColor: OseerColors.success,
                          title: 'Unlock Insights',
                          subtitle:
                              'Enable personalized reports, from your daily Body Prep score to your full Digital Twin.',
                          delay: 600,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.lock_person_rounded,
                          iconColor: OseerColors.warning,
                          title: 'You\'re in Control',
                          subtitle:
                              'Your data is encrypted and is only used to power your personal wellness journey.',
                          delay: 700,
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Continue Button
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
                          onTap: _isNavigating ? null : _handleContinue,
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: _isNavigating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: OseerTextStyles.buttonText.copyWith(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 800.ms)
                        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutQuint)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.0, 1.0),
                          duration: 400.ms,
                          delay: 800.ms,
                        ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OseerColors.border.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.15),
                  iconColor.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 28,
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
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: OseerColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
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
        .slideX(begin: -0.02, end: 0, curve: Curves.easeOutQuint)
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          delay: Duration(milliseconds: delay),
        );
  }
}
