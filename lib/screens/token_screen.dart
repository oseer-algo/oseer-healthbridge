// File path: lib/screens/token_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/connection/connection_bloc.dart' as conn;
import '../blocs/connection/connection_event.dart';
import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';
import '../widgets/token_card.dart';

class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  String? _token;
  String? _formattedToken;
  DateTime? _expiryDate;
  bool _isGenerating = false;
  bool _isCopied = false;
  Timer? _expiryTimer;
  String _timeRemaining = '';

  @override
  void initState() {
    super.initState();
    _initializeToken();

    // Setup timer to update remaining time display
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeToken() async {
    setState(() {
      _isGenerating = false;
    });

    final tokenManager = context.read<HealthBloc>().tokenManager;

    // Get existing token or generate new one
    _token = tokenManager.getCurrentToken();
    _formattedToken = tokenManager.getFormattedToken();
    _expiryDate = tokenManager.getTokenExpiryDate();

    _updateRemainingTime();

    setState(() {});
  }

  void _updateRemainingTime() {
    if (_expiryDate != null) {
      final now = DateTime.now();
      if (_expiryDate!.isAfter(now)) {
        final remaining = _expiryDate!.difference(now);

        // Format the duration
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;

        if (mounted) {
          setState(() {
            if (hours > 0) {
              _timeRemaining =
                  '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            } else {
              _timeRemaining = '$minutes:${seconds.toString().padLeft(2, '0')}';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _timeRemaining = 'Expired';
          });
        }
      }
    }
  }

  Future<void> _generateToken() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _isCopied = false;
    });

    try {
      // Generate the token
      final healthBloc = context.read<HealthBloc>();
      healthBloc.add(const GenerateConnectionTokenEvent());

      // Register to listen for result
      final completer = Completer<String>();
      late final StreamSubscription subscription;

      subscription = healthBloc.stream.listen((state) {
        if (state is TokenGenerated && !completer.isCompleted) {
          completer.complete(state.token);
          subscription.cancel();
        } else if (state is HealthError && !completer.isCompleted) {
          completer.completeError(state.message);
          subscription.cancel();
        }
      });

      // Wait for token generation
      try {
        final token =
            await completer.future.timeout(const Duration(seconds: 30));

        if (mounted) {
          setState(() {
            _token = token;
            _formattedToken = OseerConstants.formatTokenForDisplay(token);
            _expiryDate = healthBloc.tokenManager.getTokenExpiryDate();
          });
        }

        // Use haptic feedback to indicate success
        HapticFeedback.mediumImpact();
      } catch (e) {
        OseerLogger.error('Error in token generation', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate token: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Use haptic feedback to indicate error
        HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_formattedToken == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _formattedToken!));

      setState(() {
        _isCopied = true;
      });

      // Reset copied status after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });

      // Use haptic feedback to indicate copy success
      HapticFeedback.selectionClick();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection code copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF47B58E), // OseerColors.success
        ),
      );
    } catch (e) {
      OseerLogger.error('Error copying to clipboard', e);

      // Use haptic feedback to indicate error
      HapticFeedback.vibrate();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchWebApp() async {
    try {
      // Use the simpler base URL as suggested
      final url =
          Uri.parse('https://demo.oseerapp.com/onboarding/connect-device');
      OseerLogger.info('🌐 Launching URL: ${url.toString()}');

      // Check if the URL can be launched
      if (await canLaunchUrl(url)) {
        // Using external application mode for more compatibility
        final result =
            await launchUrl(url, mode: LaunchMode.externalApplication);

        if (!result) {
          throw Exception('Could not launch URL: $url');
        }

        OseerLogger.info('✅ URL launched successfully');
      } else {
        // Fallback to a more universal URL that should work on most devices
        final fallbackUrl = Uri.parse('https://demo.oseerapp.com');

        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
          OseerLogger.info('✅ Fallback URL launched successfully');

          // Show instructions to navigate to the actual site
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please navigate to demo.oseerapp.com in your browser'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          throw Exception('Could not launch any URL');
        }
      }
    } catch (e) {
      OseerLogger.error('❌ Error launching URL', e);

      // Use haptic feedback to indicate error
      HapticFeedback.vibrate();

      // Show a more helpful message instead of the technical error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open browser. Please manually navigate to demo.oseerapp.com'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _disconnectFromService() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Disconnect from Oseer'),
            content: const Text(
                'This will disconnect your device from the Oseer service. You will need to generate a new connection code to reconnect. Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DISCONNECT'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        // Use haptic feedback
        HapticFeedback.mediumImpact();

        // Clear token
        await context.read<HealthBloc>().tokenManager.clearToken();

        // Update connection status
        context.read<conn.ConnectionBloc>().add(DisconnectEvent());

        // Reset state
        setState(() {
          _token = null;
          _formattedToken = null;
          _expiryDate = null;
          _timeRemaining = '';
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully disconnected from Oseer'),
              backgroundColor: Color(0xFF4CAF50), // OseerColors.success
            ),
          );
        }
      }
    } catch (e) {
      OseerLogger.error('Error disconnecting', e);

      // Use haptic feedback to indicate error
      HapticFeedback.vibrate();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to disconnect: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use explicit type annotations to avoid ambiguity with Flutter's ConnectionState
    final conn.ConnectionState connState =
        context.watch<conn.ConnectionBloc>().state;
    final bool isConnected =
        connState.status == conn.ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Code'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _initializeToken,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildStatusCard(isConnected),

              const SizedBox(height: 24),

              // Token Card
              if (_token != null)
                TokenCard(
                  token: _formattedToken!,
                  isExpired: _expiryDate != null &&
                      DateTime.now().isAfter(_expiryDate!),
                  onCopy: _copyToClipboard,
                  isCopied: _isCopied,
                ).animate().fadeIn(duration: 300.ms).slide(
                      begin: const Offset(0, 0.2),
                      end: const Offset(0, 0),
                      duration: 300.ms,
                      curve: Curves.easeOutQuad,
                    ),

              const SizedBox(height: 24),

              // Generate Button
              _buildGenerateButton(),

              // Open Web App Button
              if (_token != null) ...[
                const SizedBox(height: 16),
                _buildWebAppButton(),
              ],

              // Disconnect Button
              if (_token != null) ...[
                const SizedBox(height: 16),
                _buildDisconnectButton(),
              ],

              const SizedBox(height: 24),

              // Instructions
              _buildInstructionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connection Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF4CAF50) : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeOut(duration: 1500.ms, curve: Curves.easeInOut)
                  .fadeIn(duration: 1500.ms, curve: Curves.easeInOut),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Connected to Oseer' : 'Not Connected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isConnected ? const Color(0xFF4CAF50) : Colors.red,
                ),
              ),
            ],
          ),
          if (_expiryDate != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Token expires:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: _expiryDate != null &&
                              DateTime.now().isAfter(_expiryDate!)
                          ? Colors.red
                          : const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _timeRemaining.isNotEmpty ? _timeRemaining : 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _expiryDate != null &&
                                DateTime.now().isAfter(_expiryDate!)
                            ? Colors.red
                            : const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Generated: ${_expiryDate != null ? DateFormat('MMM d, y HH:mm').format(_expiryDate!.subtract(const Duration(minutes: 30))) : 'Unknown'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _isGenerating ? null : _generateToken,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF47B58E), // OseerColors.primary
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 56),
        disabledBackgroundColor: const Color(0xFF47B58E).withOpacity(0.6),
      ),
      child: _isGenerating
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Generating...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _token == null ? Icons.add_circle_outline : Icons.refresh,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _token == null
                      ? 'Generate Connection Code'
                      : 'Regenerate Code',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    ).animate().fadeIn(duration: 300.ms).slide(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildWebAppButton() {
    return OutlinedButton(
      onPressed: _launchWebApp,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue[700],
        backgroundColor: Colors.blue[50],
        side: BorderSide(color: Colors.blue[300]!),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_browser, size: 20),
          SizedBox(width: 12),
          Text(
            'Open Oseer Web App',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slide(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildDisconnectButton() {
    return TextButton(
      onPressed: _disconnectFromService,
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 20),
          SizedBox(width: 12),
          Text(
            'Disconnect from Oseer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slide(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connection Instructions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            index: 1,
            text: 'Generate a new connection code if you don\'t have one.',
          ),
          _buildInstructionStep(
            index: 2,
            text: 'Copy the code by tapping on it or using the copy button.',
          ),
          _buildInstructionStep(
            index: 3,
            text: 'Open the Oseer web app and enter the code when prompted.',
          ),
          _buildInstructionStep(
            index: 4,
            text:
                'After successful connection, your health data will sync automatically.',
            isLast: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slide(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildInstructionStep({
    required int index,
    required String text,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF47B58E).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              index.toString(),
              style: const TextStyle(
                color: Color(0xFF47B58E),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
