// File path: lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/connection/connection_bloc.dart' as app_connection;
import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart' as health_state;
import '../models/helper_models.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../widgets/action_button.dart';
import '../widgets/connection_options_sheet.dart';
import '../widgets/status_card.dart';
import '../widgets/wellness_permissions_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _checkHealthPermissions();
  }

  void _checkConnectionStatus() {
    // Get connection status
    context
        .read<app_connection.ConnectionBloc>()
        .add(app_connection.CheckConnectionStatusEvent());
  }

  void _checkHealthPermissions() {
    // Get health permissions status
    context.read<HealthBloc>().add(const CheckHealthPermissionsEvent());
  }

  Future<void> _refreshData() async {
    // Refresh connection status
    context
        .read<app_connection.ConnectionBloc>()
        .add(app_connection.RefreshConnectionEvent());

    // Sync health data
    setState(() {
      _isSyncing = true;
    });

    try {
      context.read<HealthBloc>().add(const SyncHealthDataEvent());
      // Add a small delay to show that we're refreshing
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseerColors.background,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'Oseer WellnessBridge',
              style: TextStyle(
                fontFamily: 'Geist',
                fontWeight: FontWeight.w600,
                color: OseerColors.primary,
              ),
            );
          },
        ),
        backgroundColor: OseerColors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigate to settings
              _showComingSoonDialog(context, 'Settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        key: refreshKey,
        color: OseerColors.primary,
        backgroundColor: Colors.white,
        onRefresh: _refreshData,
        child: BlocConsumer<HealthBloc, health_state.HealthState>(
          listener: (context, state) {
            // When health data is synced, update UI
            if (state is health_state.HealthDataSynced) {
              if (state.syncStatus == SyncStatus.success) {
                _showSuccessSnackbar("Wellness data synced successfully!");
              } else if (state.syncStatus == SyncStatus.failure) {
                _showErrorSnackbar("Failed to sync wellness data");
              }
            }
          },
          builder: (context, healthState) {
            return BlocBuilder<app_connection.ConnectionBloc,
                app_connection.ConnectionState>(
              builder: (context, connectionState) {
                return _buildBody(context, connectionState, healthState);
              },
            );
          },
        ),
      ),
      floatingActionButton: BlocBuilder<app_connection.ConnectionBloc,
          app_connection.ConnectionState>(
        builder: (context, state) {
          if (state.status == app_connection.ConnectionStatus.connected) {
            return FloatingActionButton(
              onPressed: _isSyncing
                  ? null
                  : () {
                      // Trigger health data sync
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _isSyncing = true;
                      });
                      context
                          .read<HealthBloc>()
                          .add(const SyncHealthDataEvent());

                      // We'll set this back to false when the sync completes
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            _isSyncing = false;
                          });
                        }
                      });
                    },
              backgroundColor: OseerColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.sync),
            ).animate().fadeIn(duration: 300.ms);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    app_connection.ConnectionState connectionState,
    health_state.HealthState healthState,
  ) {
    // If there's an error state, show error
    if (connectionState.status == app_connection.ConnectionStatus.error) {
      return _buildErrorState(
          context, connectionState.errorMessage ?? "Connection error");
    }

    // If we're still loading, show loading state
    if (healthState is health_state.HealthLoading) {
      return _buildLoadingState(healthState.message);
    }

    // If disconnected, show connection options
    if (connectionState.status ==
        app_connection.ConnectionStatus.disconnected) {
      return _buildDisconnectedState(context);
    }

    // If connected, show connected state
    return _buildConnectedState(context, connectionState, healthState);
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(OseerColors.primary),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: OseerColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: OseerColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: OseerColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ActionButton(
              label: 'Retry Connection',
              icon: Icons.refresh,
              onPressed: () {
                context
                    .read<app_connection.ConnectionBloc>()
                    .add(app_connection.RefreshConnectionEvent());
              },
              type: ActionButtonType.primary,
            ),
            const SizedBox(height: 16),
            ActionButton(
              label: 'Connection Options',
              icon: Icons.settings_ethernet,
              onPressed: () {
                _showConnectionOptionsSheet(context);
              },
              type: ActionButtonType.secondary,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildDisconnectedState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 16),

        // Header
        Text(
          'Connect to Oseer',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: OseerColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Link your device to your Oseer account to sync your wellness data',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: OseerColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Connection card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                OseerColors.primary.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: OseerColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      OseerColors.primary.withOpacity(0.1),
                      OseerColors.primary.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.link,
                  size: 40,
                  color: OseerColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Connect Your Device',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: OseerColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'To get started, you need to connect your device to Oseer. This allows us to securely sync your wellness data.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: OseerColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Connect button
              ActionButton(
                label: 'Connect',
                icon: Icons.link,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showConnectionOptionsSheet(context);
                },
                type: ActionButtonType.primary,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slide(
              begin: const Offset(0, 0.1),
              end: const Offset(0, 0),
              duration: 500.ms,
            ),

        const SizedBox(height: 40),

        // Features section
        Text(
          'Features & Benefits',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: OseerColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Wellness data
        _buildFeatureItem(
          icon: Icons.favorite,
          title: 'Wellness Data Analysis',
          description:
              'Sync your vital signs, activity levels, and sleep patterns',
        ),

        // Digital twin
        _buildFeatureItem(
          icon: Icons.person,
          title: 'Digital Twin',
          description:
              'Get a personalized wellness model to visualize your wellbeing',
        ),

        // Personalized insights
        _buildFeatureItem(
          icon: Icons.lightbulb,
          title: 'Personalized Insights',
          description: 'Receive tailored recommendations based on your data',
        ),

        const SizedBox(height: 100), // Space for button
      ],
    );
  }

  Widget _buildConnectedState(
    BuildContext context,
    app_connection.ConnectionState connectionState,
    health_state.HealthState healthState,
  ) {
    // Get the last sync time
    String lastSyncText = 'Never';
    if (connectionState.lastSyncTime != null) {
      final now = DateTime.now();
      final diff = now.difference(connectionState.lastSyncTime!);

      if (diff.inMinutes < 1) {
        lastSyncText = 'Just now';
      } else if (diff.inHours < 1) {
        lastSyncText =
            '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (diff.inDays < 1) {
        lastSyncText =
            '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
      } else {
        lastSyncText =
            DateFormat('MMM d, h:mm a').format(connectionState.lastSyncTime!);
      }
    }

    // Wellness permissions check
    bool hasHealthPermissions = false;
    if (healthState is health_state.HealthPermissionsChecked) {
      hasHealthPermissions =
          healthState.authStatus.status == HealthPermissionStatus.granted ||
              healthState.authStatus.status ==
                  HealthPermissionStatus.partiallyGranted;
    } else if (healthState is health_state.HealthDataSynced) {
      hasHealthPermissions =
          healthState.authStatus.status == HealthPermissionStatus.granted ||
              healthState.authStatus.status ==
                  HealthPermissionStatus.partiallyGranted;
    }

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Header
        Text(
          'Hello there!',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: OseerColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your device is connected to Oseer',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: OseerColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // Connection status card
        _buildConnectionStatusCard(
          connectionState: connectionState,
          lastSyncText: lastSyncText,
        ),

        const SizedBox(height: 20),

        // Wellness permissions status card
        _buildWellnessPermissionsCard(
          hasHealthPermissions: hasHealthPermissions,
        ),

        const SizedBox(height: 20),

        // Web connection info
        _buildWebAccessCard(),

        const SizedBox(height: 100), // Extra space at bottom
      ],
    );
  }

  Widget _buildConnectionStatusCard({
    required app_connection.ConnectionState connectionState,
    required String lastSyncText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white,
            OseerColors.primary.withOpacity(0.03),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: OseerColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      OseerColors.primary.withOpacity(0.08),
                      OseerColors.primary.withOpacity(0.16),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.phonelink,
                  color: OseerColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Connected',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: OseerColors.textPrimary,
                      ),
                    ),
                    Text(
                      connectionState.deviceName ?? 'Android Device',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: OseerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  _showDisconnectConfirmation(context);
                },
                tooltip: 'Disconnect Device',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: OseerColors.divider,
          ),
          const SizedBox(height: 16),

          // Last sync
          Row(
            children: [
              Icon(
                Icons.sync,
                size: 16,
                color: OseerColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Last sync: $lastSyncText',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: OseerColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_isSyncing)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OseerColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Syncing...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: OseerColors.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildWellnessPermissionsCard({
    required bool hasHealthPermissions,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: hasHealthPermissions
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: hasHealthPermissions
                        ? [
                            Colors.green.shade50,
                            Colors.green.shade100,
                          ]
                        : [
                            Colors.orange.shade50,
                            Colors.orange.shade100,
                          ],
                  ),
                ),
                child: Icon(
                  hasHealthPermissions
                      ? Icons.check_circle
                      : Icons.warning_rounded,
                  color: hasHealthPermissions
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasHealthPermissions
                          ? 'Wellness Permissions Granted'
                          : 'Wellness Permissions Required',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: OseerColors.textPrimary,
                      ),
                    ),
                    Text(
                      hasHealthPermissions
                          ? 'Your wellness data is being monitored'
                          : 'Enable permissions to sync wellness data',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: OseerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasHealthPermissions) ...[
            const SizedBox(height: 20),
            ActionButton(
              label: 'Grant Permissions',
              icon: Icons.health_and_safety,
              onPressed: () {
                _showWellnessPermissionsSheet(context);
              },
              type: ActionButtonType.secondary,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  Widget _buildWebAccessCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            OseerColors.info.withOpacity(0.03),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Access Your Wellness Data',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: OseerColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'View your Wellness insights, reports, and recommendations on the Oseer web App.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: OseerColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Visit:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 16,
                  color: OseerColors.info,
                ),
                const SizedBox(width: 12),
                Text(
                  OseerConstants.webAppUrl,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: OseerColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: OseerConstants.webAppUrl),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: OseerColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OseerColors.primary.withOpacity(0.08),
                  OseerColors.primary.withOpacity(0.16),
                ],
              ),
            ),
            child: Icon(
              icon,
              color: OseerColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: OseerColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: OseerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slide(
          begin: const Offset(0, 0.1),
          end: const Offset(0, 0),
          duration: 500.ms,
        );
  }

  void _showConnectionOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConnectionOptionsSheet(
        onGetConnectionCode: () {
          // Generate a connection token for this device
          context.read<HealthBloc>().add(const GenerateConnectionTokenEvent());

          // Navigate to token screen
          Navigator.pushNamed(context, '/token');
        },
        onReconnect: () {
          // Navigate to token screen for reconnection
          Navigator.pushNamed(context, '/token');
        },
      ),
    );
  }

  void _showWellnessPermissionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WellnessPermissionsSheet(
        onGranted: () {
          // Permissions granted, close sheet
          Navigator.pop(context);

          // Trigger health data sync
          context.read<HealthBloc>().add(const SyncHealthDataEvent());
        },
        onSkip: () {
          // User skipped, close sheet
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDisconnectConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Disconnect Device',
          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to disconnect this device from Oseer? You will need to reconnect to sync wellness data again.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: OseerColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Disconnect device
              context
                  .read<app_connection.ConnectionBloc>()
                  .add(app_connection.DisconnectEvent());
              Navigator.pop(context);

              // Show snackbar
              _showSuccessSnackbar('Device disconnected successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OseerColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Disconnect',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Coming Soon',
          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
        ),
        content: Text(
          'The $featureName feature is coming soon.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OseerColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: OseerColors.success,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: OseerColors.error,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
      ),
    );
  }
}
