// lib/widgets/wellness_permissions_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../managers/health_permission_manager.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';

class WellnessPermissionsSheet extends StatefulWidget {
  final bool isPreAuth;
  final ScrollController? scrollController;

  const WellnessPermissionsSheet({
    Key? key,
    this.isPreAuth = true,
    this.scrollController,
  }) : super(key: key);

  @override
  State<WellnessPermissionsSheet> createState() =>
      _WellnessPermissionsSheetState();
}

class _WellnessPermissionsSheetState extends State<WellnessPermissionsSheet> {
  bool _isRequesting = false;
  bool _isCheckingHealthConnect = false;
  bool? _isHealthConnectInstalled;

  @override
  void initState() {
    super.initState();
    // Only check Health Connect on Android
    if (Platform.isAndroid) {
      _checkHealthConnectStatus();
    } else if (Platform.isIOS) {
      // iOS always has HealthKit available
      setState(() {
        _isHealthConnectInstalled = true;
        _isCheckingHealthConnect = false;
      });
    }
  }

  Future<void> _checkHealthConnectStatus() async {
    if (!Platform.isAndroid) return;

    setState(() => _isCheckingHealthConnect = true);
    try {
      final isInstalled =
          await HealthPermissionManager.isHealthConnectInstalled();
      setState(() {
        _isHealthConnectInstalled = isInstalled;
        _isCheckingHealthConnect = false;
      });
    } catch (e) {
      setState(() {
        _isHealthConnectInstalled = false;
        _isCheckingHealthConnect = false;
      });
    }
  }

  Future<void> _openHealthConnectInPlayStore() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
    try {
      if (await canLaunchUrl(Uri.parse(playStoreUrl))) {
        await launchUrl(
          Uri.parse(playStoreUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      OseerLogger.error('Failed to open Play Store', e);
    }
  }

  /// Handles the "Grant Permissions" button tap
  Future<void> _requestAndClose() async {
    if (!mounted || _isRequesting) return;

    // Only check Health Connect on Android
    if (Platform.isAndroid && _isHealthConnectInstalled == false) {
      await _openHealthConnectInPlayStore();
      return;
    }

    setState(() => _isRequesting = true);

    try {
      OseerLogger.info(
          '🏥 GRANT PERMISSIONS TAPPED. Dispatching event to AuthBloc...');

      // SIMPLIFIED: Just dispatch the event and close
      context.read<AuthBloc>().add(const AuthHealthPermissionsRequested());

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      OseerLogger.error('Error dispatching permission event', e);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  /// Handles the "Skip" button tap
  void _handleSkip() {
    OseerLogger.info('🏥 SKIP PERMISSIONS TAPPED by user.');

    // Dispatch the skip event
    context.read<AuthBloc>().add(const AuthHealthPermissionsSkipped());

    if (mounted) Navigator.of(context).pop();
  }

  String get _healthPlatformName {
    if (Platform.isIOS) return 'Apple Health';
    if (Platform.isAndroid) return 'Health Connect';
    return 'Health Data';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, -16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: OseerColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ).animate().fadeIn(duration: 300.ms),

          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Header icon with gradient
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
                          color: OseerColors.primary.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      (Platform.isAndroid && _isHealthConnectInstalled == false)
                          ? Icons.download_rounded
                          : Icons.favorite_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .fade(duration: 300.ms),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    (Platform.isAndroid && _isHealthConnectInstalled == false)
                        ? 'Health Connect Required'
                        : 'Connect Your Health Data',
                    style: OseerTextStyles.h2.copyWith(
                      color: OseerColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    (Platform.isAndroid && _isHealthConnectInstalled == false)
                        ? 'Health Connect is required to sync your health data. Please install it from the Play Store.'
                        : 'To provide personalized wellness insights, Oseer needs access to your health data via $_healthPlatformName.',
                    style: OseerTextStyles.bodyRegular.copyWith(
                      color: OseerColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Show loading or content
                  if (_isCheckingHealthConnect)
                    Container(
                      padding: const EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          OseerColors.primary,
                        ),
                      ),
                    )
                  else if (Platform.isIOS ||
                      _isHealthConnectInstalled != false) ...[
                    // Permission items grid
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildPermissionCard(
                                icon: Icons.directions_walk_rounded,
                                title: 'Activity',
                                subtitle: 'Steps & workouts',
                                gradientColors: [
                                  const Color(0xFF4ECDC4),
                                  const Color(0xFF44A3A0),
                                ],
                                delay: 400,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPermissionCard(
                                icon: Icons.accessibility_new_rounded,
                                title: 'Body',
                                subtitle: 'Height & weight',
                                gradientColors: [
                                  const Color(0xFFFF6B6B),
                                  const Color(0xFFEE5A6F),
                                ],
                                delay: 500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPermissionCard(
                                icon: Icons.bedtime_rounded,
                                title: 'Sleep',
                                subtitle: 'Duration & quality',
                                gradientColors: [
                                  const Color(0xFF667EEA),
                                  const Color(0xFF764BA2),
                                ],
                                delay: 600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPermissionCard(
                                icon: Icons.favorite_rounded,
                                title: 'Vitals',
                                subtitle: 'Heart rate & more',
                                gradientColors: [
                                  const Color(0xFFFA709A),
                                  const Color(0xFFFEE140),
                                ],
                                delay: 700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    // Health Connect not installed (Android only)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: OseerColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 48,
                            color: OseerColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Health Connect is Google\'s official platform for managing health data on Android',
                            style: OseerTextStyles.bodyRegular.copyWith(
                              color: OseerColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1, 1)),
                  ],

                  const SizedBox(height: 40),

                  // Grant button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isRequesting || _isCheckingHealthConnect)
                          ? null
                          : _requestAndClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OseerColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        disabledBackgroundColor:
                            OseerColors.primary.withOpacity(0.3),
                      ),
                      child: _isRequesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              (Platform.isAndroid &&
                                      _isHealthConnectInstalled == false)
                                  ? 'Install Health Connect'
                                  : 'Grant Permissions',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 800.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  // Skip button
                  TextButton(
                    onPressed: _handleSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'I\'ll do this later',
                      style: OseerTextStyles.bodyRegular.copyWith(
                        color: OseerColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 900.ms),

                  const SizedBox(height: 24),

                  // Privacy note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OseerColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: OseerColors.border.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 18,
                          color: OseerColors.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            Platform.isIOS
                                ? 'Your health data stays in Apple Health unless you explicitly choose to share it. You can change permissions anytime in Settings > Privacy & Security > Health.'
                                : 'Your health data stays on your device unless you explicitly choose to share it. You can change permissions anytime in settings.',
                            style: OseerTextStyles.caption.copyWith(
                              color: OseerColors.textTertiary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 1000.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradientColors.first.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: OseerTextStyles.bodyBold.copyWith(
              color: OseerColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: OseerTextStyles.caption.copyWith(
              color: OseerColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay))
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}
