// lib/screens/token_screen.dart (FINAL, ENHANCED VERSION)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

// Use a prefix to resolve the ambiguous import for ConnectionState
import '../blocs/connection/connection_bloc.dart' as connection;
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../widgets/action_button.dart';
import 'home_screen.dart';

class TokenScreen extends StatefulWidget {
  const TokenScreen({Key? key}) : super(key: key);

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  void _connectToWeb() {
    OseerLogger.info("UI: 'Connect to Wellness Hub' button pressed.");
    // Dispatch the event to the ConnectionBloc to handle the entire handoff flow.
    context
        .read<connection.ConnectionBloc>()
        .add(const connection.ConnectToWebPressed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<connection.ConnectionBloc, connection.ConnectionState>(
      listener: (context, state) {
        // This listener will automatically navigate away once the connection is
        // established and the sync process begins.
        if (state.status == connection.ConnectionStatus.syncIntro ||
            state.status == connection.ConnectionStatus.syncing) {
          OseerLogger.info(
              'TokenScreen: Connection established and sync started! Navigating to HomeScreen...');
          // Use pushAndRemoveUntil to prevent the user from navigating back to this screen.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }

        // Show an error message if the handoff fails and we are not in a connecting state.
        if (state.errorMessage != null && !state.isAwaitingWebValidation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: OseerColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: OseerColors.background,
        appBar: AppBar(
          title: const Text('Final Step', style: OseerTextStyles.h3),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _buildContent(),
                const Spacer(),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Lottie animation
        Lottie.asset(
          'assets/animations/secure_connection.json',
          width: 200,
          height: 200,
          repeat: true,
        ),
        const SizedBox(height: 32),
        // Main heading
        Text(
          'Connect to Your Wellness Hub',
          style: OseerTextStyles.h1.copyWith(color: OseerColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Subtitle with clearer instructions
        Text(
          'Your health data stays on your device. We\'ll open your browser to securely link this app with your personal Wellness Hub.',
          style: OseerTextStyles.bodyRegular
              .copyWith(color: OseerColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Additional context
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OseerColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: OseerColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: OseerColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'After connecting, you\'ll see your personalized wellness insights',
                  style: OseerTextStyles.bodySmall.copyWith(
                    color: OseerColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildFooter() {
    return BlocBuilder<connection.ConnectionBloc, connection.ConnectionState>(
      builder: (context, state) {
        final bool isConnecting = state.isAwaitingWebValidation;

        return Column(
          children: [
            // Main action button
            ActionButton(
              label: isConnecting
                  ? 'Waiting for Browser...'
                  : 'Connect to Wellness Hub',
              onPressed: isConnecting ? () {} : _connectToWeb,
              icon: isConnecting ? null : Icons.open_in_new_rounded,
              isLoading: isConnecting,
            ),
            const SizedBox(height: 24),
            // Status indicator
            if (isConnecting) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: OseerColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(OseerColors.warning),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Complete the connection in your browser',
                      style: OseerTextStyles.bodySmall.copyWith(
                        color: OseerColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
            ],
            // Security badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 16, color: OseerColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'Our encryption protects your data',
                  style: OseerTextStyles.bodySmall
                      .copyWith(color: OseerColors.textTertiary),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
          ],
        );
      },
    );
  }
}
