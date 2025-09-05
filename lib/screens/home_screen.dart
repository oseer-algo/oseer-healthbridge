// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as conn;
import '../blocs/connection/connection_event.dart';
import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../managers/health_manager.dart';
import '../utils/constants.dart';
import '../widgets/wellness_journey_card.dart' as wellness;
import '../widgets/connection_status_card.dart';
import '../widgets/phase_two_sync_card.dart';
import '../models/sync_progress.dart';
import '../models/realtime_status.dart';
import '../models/helper_models.dart' as helper;
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/connectivity_service.dart';
import '../services/toast_service.dart';
import 'token_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // Animation controllers for visual feedback
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _progressAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    context.read<HealthBloc>().add(const SyncHealthDataEvent(isManual: true));
    await Future.delayed(const Duration(seconds: 2));
  }

  void _showInsufficientDataDialog(BuildContext context, String? message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recent Data Unavailable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message ??
                      'We couldn\'t find enough health data from the last 48 hours to generate your Body Preparedness score. This can happen if you haven\'t worn your device recently or if sleep was not tracked.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can still proceed with the 90-day historical sync to build your Digital Twin.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'TRY AGAIN LATER',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Optionally disconnect or reset
                context.read<ConnectionBloc>().add(const DisconnectEvent());
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OseerColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'PROCEED TO 90-DAY SYNC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                OseerLogger.info("User chose to proceed with historical sync.");
                // FIX: Get the current user ID from AuthBloc's state and pass it to the event.
                final authState = context.read<AuthBloc>().state;
                String? userId;
                if (authState is AuthAuthenticated) {
                  userId = authState.user.id;
                } else if (authState is AuthOnboardingSyncInProgress) {
                  // A bit more robust way to get user id if in another state
                  userId = context.read<ConnectionBloc>().state.userId;
                }

                if (userId != null) {
                  context
                      .read<ConnectionBloc>()
                      .add(TriggerHistoricalSyncEvent(userId: userId));
                } else {
                  ToastService.error(
                      "Could not start sync: User session is invalid.");
                  OseerLogger.error(
                      "Failed to trigger historical sync: User ID was null in auth state.");
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseerColors.background,
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        color: OseerColors.primary,
        backgroundColor: OseerColors.surface,
        onRefresh: _handleRefresh,
        child: BlocListener<ConnectionBloc, conn.ConnectionState>(
          listener: (context, connectionState) {
            // Add listener for the historicalSyncReady state
            if (connectionState.status ==
                conn.ConnectionStatus.historicalSyncReady) {
              _showInsufficientDataDialog(
                  context, connectionState.errorMessage);
            }
          },
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, authState) {
              if (authState is AuthError) {
                ToastService.error(authState.message);
              }

              // Handle priority sync complete state
              if (authState is AuthPrioritySyncComplete) {
                // Use Future.delayed to transition after user sees success
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted) {
                    context.read<AuthBloc>().add(const HistoricalSyncStarted());
                  }
                });
              }
            },
            builder: (context, authState) {
              return BlocBuilder<ConnectionBloc, conn.ConnectionState>(
                builder: (context, connectionState) {
                  // 1. Loading States
                  if (authState is AuthLoading ||
                      connectionState.status ==
                          conn.ConnectionStatus.connecting ||
                      authState is AuthHandoffInProgress) {
                    return _buildHandoffLoadingView();
                  }

                  // 2. Handle handoff timeout
                  if (connectionState.status == conn.ConnectionStatus.error &&
                      connectionState.errorMessage?.contains('timed out') ==
                          true) {
                    return _buildHandoffErrorView(
                        context, connectionState.errorMessage);
                  }

                  // 3. The entire sync journey with animated progress
                  if (authState is AuthOnboardingSyncInProgress ||
                      connectionState.status ==
                          conn.ConnectionStatus.syncIntro ||
                      connectionState.status == conn.ConnectionStatus.syncing ||
                      connectionState.status ==
                          conn.ConnectionStatus.processing) {
                    _progressAnimationController.forward();
                    return _buildWellnessJourneyView(context, connectionState);
                  }

                  // 4. Historical Sync Ready (handled by listener, show main view)
                  if (connectionState.status ==
                      conn.ConnectionStatus.historicalSyncReady) {
                    return _buildMainView(context, connectionState);
                  }

                  // 5. Insufficient Data View
                  if (connectionState.status ==
                      conn.ConnectionStatus.syncInsufficientData) {
                    return _buildInsufficientDataView(
                        context, connectionState.errorMessage);
                  }

                  // 6. Post-Phase 1 Success View
                  if (authState is AuthPrioritySyncComplete ||
                      connectionState.status ==
                          conn.ConnectionStatus.prioritySyncComplete) {
                    return _buildSyncCompleteView(context);
                  }

                  // 7. Phase 2 Historical Sync View
                  if (authState is AuthHistoricalSyncInProgress ||
                      connectionState.status ==
                          conn.ConnectionStatus.historicalSyncInProgress) {
                    return _buildHistoricalSyncView(context, connectionState);
                  }

                  // 8. Failure State
                  if (connectionState.status ==
                      conn.ConnectionStatus.syncFailed) {
                    return _buildSyncErrorView(
                        context, connectionState.errorMessage);
                  }

                  // 9. Main dashboard for authenticated & idle users
                  if (authState is AuthAuthenticated) {
                    return _buildMainView(context, connectionState);
                  }

                  // 10. Fallback
                  return _buildErrorState(context,
                      "An unexpected error occurred. Please restart the app.");
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWellnessJourneyView(
      BuildContext context, conn.ConnectionState connectionState) {
    final healthManager = context.read<HealthManager>();
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    return StreamBuilder<SyncProgress>(
      stream: healthManager.onboardingSyncProgressStream,
      initialData: SyncProgress.initial(),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? connectionState.syncProgressData;
        final hasError = progress?.isError ?? false;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildAppBar(
              greeting: 'Hi $userName!',
              subtitle: _getSubtitleForProgress(connectionState, progress),
              showSettings: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (hasError && progress != null) ...[
                    _buildSyncErrorCard(
                      message: progress.errorMessage ?? 'Sync was interrupted',
                      onRetry: () => _retrySyncWithConnectivityCheck(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return wellness.WellnessJourneyCard(
                          currentPhase:
                              _getCurrentPhase(connectionState, progress),
                          bodyPrepProgress:
                              (progress?.bodyPrepProgress ?? 0.0) *
                                  _progressAnimation.value,
                          digitalTwinDaysProcessed:
                              ((progress?.digitalTwinDaysProcessed ?? 0) *
                                      _progressAnimation.value)
                                  .round(),
                          bodyPrepReadyTime: _estimateBodyPrepTime(progress),
                          estimatedTwinCompletion:
                              _estimateTwinCompletionTime(progress),
                          isBodyPrepReady:
                              (progress?.bodyPrepProgress ?? 0.0) >= 1.0,
                          onViewResults:
                              (progress?.bodyPrepProgress ?? 0.0) >= 1.0
                                  ? () => _launchWellnessHub(context)
                                  : null,
                        );
                      }),

                  // Show data being processed
                  if (connectionState.status == conn.ConnectionStatus.syncing &&
                      connectionState.syncProgressData != null) ...[
                    const SizedBox(height: 24),
                    _buildDataProcessingCard(connectionState.syncProgressData!),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataProcessingCard(SyncProgress progress) {
    // Extract metrics from metadata
    final metrics = progress.metricsFound ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OseerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OseerColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: OseerColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Analyzing Your Data',
                style: OseerTextStyles.h3,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated checklist of metrics
          _buildMetricRow('Heart Rate Variability', metrics['hrv'] ?? false),
          _buildMetricRow('Resting Heart Rate', metrics['rhr'] ?? false),
          _buildMetricRow('Sleep Data', metrics['sleep'] ?? false),
          _buildMetricRow('Activity & Workouts', metrics['activity'] ?? false),
          _buildMetricRow('Daily Steps', metrics['steps'] ?? false),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildMetricRow(String label, bool hasData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasData ? Colors.green : Colors.grey.shade300,
            ),
            child: hasData
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                    .animate()
                    .scale(duration: 300.ms, curve: Curves.easeOutBack)
                : const SizedBox(),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: OseerTextStyles.bodyRegular.copyWith(
              color:
                  hasData ? OseerColors.textPrimary : OseerColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (hasData)
            Text(
              'Found',
              style: OseerTextStyles.bodySmall.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'Checking...',
              style: OseerTextStyles.bodySmall.copyWith(
                color: OseerColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataView(BuildContext context, String? message) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Hi $userName,',
          subtitle: 'We need a bit more data',
          showSettings: true,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.watch_later_outlined,
                      size: 50,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'More Data Needed',
                  style: OseerTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message ??
                      'We couldn\'t find enough recent wellness data (sleep, HRV, etc.) from the last 48 hours to calculate your Body Preparedness score.',
                  style: OseerTextStyles.bodyRegular
                      .copyWith(color: OseerColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                  child: Column(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tips to Get Started',
                        style: OseerTextStyles.h3.copyWith(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Wear your device for at least 48 hours\n'
                        '• Enable sleep tracking\n'
                        '• Record at least one workout\n'
                        '• Keep your device synced',
                        style: OseerTextStyles.bodySmall.copyWith(
                          color: Colors.blue.shade700,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'You can try again once you have more data, or proceed directly to Phase 2.',
                  style: OseerTextStyles.bodyRegular.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          context.read<ConnectionBloc>().add(
                              const RetrySyncEvent(
                                  syncType: helper.SyncType.priority));
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: OseerColors.primary),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context
                              .read<AuthBloc>()
                              .add(const HistoricalSyncStarted());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OseerColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Skip to Phase 2',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ]
                  .animate(interval: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalSyncView(
      BuildContext context, conn.ConnectionState connectionState) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    final syncProgress = connectionState.syncProgressData;
    final daysProcessed = syncProgress?.digitalTwinDaysProcessed ?? 0;

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Welcome back, $userName!',
          subtitle: 'Building your Digital Twin in the background',
          showSettings: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              PhaseTwoSyncCard(
                daysProcessed: daysProcessed,
                totalDays: 90,
              ),
              const SizedBox(height: 24),
              _buildWellnessHubCard(),
            ]),
          ),
        ),
      ],
    );
  }

  String _getSubtitleForProgress(
      conn.ConnectionState connectionState, SyncProgress? progress) {
    if (progress?.isError ?? false) {
      return "Sync Interrupted";
    } else if (connectionState.status == conn.ConnectionStatus.syncIntro) {
      return "Preparing Your Wellness Journey";
    } else if (connectionState.status == conn.ConnectionStatus.processing) {
      return "Analyzing your wellness data";
    } else if (progress?.currentPhase == 'bodyPrep') {
      return "Analyzing recent wellness data";
    } else if (progress?.currentPhase == 'digitalTwin') {
      return "Building your Digital Twin";
    } else {
      return "Preparing your wellness profile";
    }
  }

  Widget _buildSyncErrorView(BuildContext context, String? message) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Hi $userName',
          subtitle: 'We couldn\'t sync your data',
          showSettings: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSyncErrorCard(
                message: message ??
                    'Please check your internet connection and try again.',
                onRetry: () => _retrySyncWithConnectivityCheck(context),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCompleteView(BuildContext context) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Congratulations, $userName!',
          subtitle: 'Your Body Preparedness score is ready',
          showSettings: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSuccessCard(context),
              const SizedBox(height: 16),
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
                        'Phase 2 will begin shortly to build your Digital Twin',
                        style: OseerTextStyles.bodySmall.copyWith(
                          color: Colors.blue.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMainView(
      BuildContext context, conn.ConnectionState connectionState) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';
    final needsReconnection = !connectionState.isConnected &&
        connectionState.status != conn.ConnectionStatus.connecting;

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Welcome Back, $userName!',
          subtitle: needsReconnection
              ? 'Your HealthBridge needs to reconnect'
              : 'Your HealthBridge is active',
          showSettings: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (needsReconnection) ...[
                _buildReconnectButton(),
                const SizedBox(height: 24),
              ],
              ConnectionStatusCard(
                isConnected: connectionState.isConnected,
                lastSyncTime: connectionState.lastSyncTime,
                realtimeStatus: connectionState.realtimeStatus,
                reconnectAttempt: connectionState.reconnectAttempt,
                deviceName: connectionState.deviceName,
                errorMessage: connectionState.errorMessage,
                isAwaitingValidation: connectionState.isAwaitingWebValidation,
                onDisconnectTap: connectionState.isConnected
                    ? () => context
                        .read<ConnectionBloc>()
                        .add(const DisconnectEvent())
                    : null,
              ),
              const SizedBox(height: 24),
              _buildWellnessHubCard(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar({
    required String greeting,
    required String subtitle,
    required bool showSettings,
  }) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                OseerColors.primary,
                OseerColors.primaryLight,
                const Color(0xFF4ECDC4).withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      duration: 4000.ms,
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                    )
                    .then()
                    .scale(
                      duration: 4000.ms,
                      begin: const Offset(1.1, 1.1),
                      end: const Offset(0.9, 0.9),
                    ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      duration: 5000.ms,
                      delay: 1000.ms,
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.05, 1.05),
                    )
                    .then()
                    .scale(
                      duration: 5000.ms,
                      begin: const Offset(1.05, 1.05),
                      end: const Offset(0.95, 0.95),
                    ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/oseer_logo.png',
                            height: 40,
                            fit: BoxFit.contain,
                          ).animate().scale(
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1.0, 1.0),
                              ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 24),
                      Text(
                        greeting,
                        style: OseerTextStyles.h1.copyWith(
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: OseerTextStyles.bodyRegular.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (showSettings)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
      ],
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.teal.shade50.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.green.shade200.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade400,
                    Colors.teal.shade500,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 48,
              ),
            )
                .animate()
                .scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .shimmer(
                  duration: 1500.ms,
                  color: Colors.white.withOpacity(0.3),
                ),
            const SizedBox(height: 24),
            Text(
              'Phase 1 Complete!',
              style: OseerTextStyles.h2.copyWith(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Body Preparedness score is ready. View your personalized insights on the Wellness Hub.',
              style: OseerTextStyles.bodyRegular.copyWith(
                color: Colors.green.shade700,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
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
                    color: OseerColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchWellnessHub(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'View Your Score',
                          style: OseerTextStyles.buttonText.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSyncErrorCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade50,
            Colors.amber.shade50.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.shade200.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade400,
                        Colors.amber.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                )
                    .animate()
                    .scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .shimmer(
                      duration: 1500.ms,
                      color: Colors.white.withOpacity(0.3),
                    ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync Interrupted',
                        style: OseerTextStyles.h3.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: OseerTextStyles.bodySmall.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    OseerColors.primary,
                    OseerColors.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: OseerColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: OseerTextStyles.buttonText.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(
                  begin: 0.1,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildReconnectButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OseerColors.primary,
            OseerColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: OseerColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TokenScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Reconnect to Continue',
                  style: OseerTextStyles.buttonText.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildWellnessHubCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF667EEA),
            const Color(0xFF764BA2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchWellnessHub(context),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insights,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Your Wellness Hub',
                      style: OseerTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Visit the Wellness Hub to view your Body Preparedness score and Digital Twin insights.',
                  style: OseerTextStyles.bodyRegular.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Open Wellness Hub',
                        style: OseerTextStyles.buttonText.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildHandoffLoadingView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OseerColors.primary, OseerColors.primaryLight],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.sync_lock_rounded,
                  color: Colors.white, size: 44),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 1500.ms, curve: Curves.easeInOut)
                .then()
                .shimmer(
                    duration: 1500.ms, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 24),
            Text(
              'Finalizing Connection...',
              style: OseerTextStyles.h3.copyWith(color: Colors.white),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoffErrorView(BuildContext context, String? message) {
    final prefs = context.read<SharedPreferences>();
    final userName =
        prefs.getString(OseerConstants.keyUserName)?.split(' ').first ??
            'there';

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildAppBar(
          greeting: 'Hi $userName',
          subtitle: 'Connection timed out',
          showSettings: true,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade400,
                        Colors.amber.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade300.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.access_time_outlined,
                    size: 44,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .fade(duration: 300.ms),
                const SizedBox(height: 24),
                Text(
                  'Connection Timeout',
                  style: OseerTextStyles.h2,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  message ??
                      'The connection took too long to complete. Please try again.',
                  style: OseerTextStyles.bodyRegular.copyWith(
                    color: OseerColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                const SizedBox(height: 32),
                Container(
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
                        color: OseerColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        context
                            .read<ConnectionBloc>()
                            .add(const ConnectToWebPressed());
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Try Again',
                              style: OseerTextStyles.buttonText.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    OseerColors.error.withOpacity(0.8),
                    OseerColors.error,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: OseerColors.error.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline,
                size: 44,
                color: Colors.white,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .fade(duration: 300.ms),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: OseerTextStyles.h2,
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              message,
              style: OseerTextStyles.bodyRegular.copyWith(
                color: OseerColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            const SizedBox(height: 24),
            Container(
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
                    color: OseerColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleRefresh,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Text(
                      'Retry',
                      style: OseerTextStyles.buttonText.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }

  void _launchWellnessHub(BuildContext context) {
    context.read<ConnectionBloc>().add(const LaunchWellnessHubEvent());
  }

  Future<void> _retrySyncWithConnectivityCheck(BuildContext context) async {
    final connectivityService = context.read<ConnectivityService>();
    final isConnected = await connectivityService.checkConnectivity();

    if (!isConnected) {
      ToastService.error(
          'No internet connection. Please check your network settings.');
      return;
    }

    context
        .read<ConnectionBloc>()
        .add(const PerformSyncEvent(syncType: helper.SyncType.priority));
  }

  wellness.WellnessPhase _getCurrentPhase(
      conn.ConnectionState connectionState, SyncProgress? progress) {
    if (connectionState.status == conn.ConnectionStatus.syncIntro) {
      return wellness.WellnessPhase.intro;
    }
    if (progress == null) {
      return wellness.WellnessPhase.bodyPrep;
    }
    if (progress.isComplete) {
      return wellness.WellnessPhase.complete;
    } else if (progress.currentPhase == 'digitalTwin') {
      return wellness.WellnessPhase.digitalTwin;
    }
    return wellness.WellnessPhase.bodyPrep;
  }

  DateTime? _estimateBodyPrepTime(SyncProgress? progress) {
    if (progress == null || progress.isComplete) return null;

    final currentProgress = progress.bodyPrepProgress ?? 0.0;
    if (currentProgress >= 1.0) return null;

    final remainingProgress = 1.0 - currentProgress;
    final estimatedMinutes = (remainingProgress * 2.0).ceil();

    return DateTime.now().add(Duration(minutes: estimatedMinutes));
  }

  DateTime? _estimateTwinCompletionTime(SyncProgress? progress) {
    if (progress == null || progress.currentPhase != 'digitalTwin') return null;

    final daysProcessed = progress.digitalTwinDaysProcessed ?? 0;
    final remainingDays = 90 - daysProcessed;

    final estimatedHours = (remainingDays / 30).ceil();

    return DateTime.now().add(Duration(hours: estimatedHours));
  }
}
