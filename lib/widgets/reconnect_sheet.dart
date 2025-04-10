import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../blocs/connection/connection_bloc.dart';
import '../utils/constants.dart';
import '../services/logger_service.dart';

class ReconnectSheet extends StatefulWidget {
  const ReconnectSheet({super.key});

  @override
  State<ReconnectSheet> createState() => _ReconnectSheetState();
}

class _ReconnectSheetState extends State<ReconnectSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current connection state
    final connectionState = context.watch<ConnectionBloc>().state;

    // Close the sheet if connection is successful
    if (connectionState.status == ConnectionStatus.connected && _isConnecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.lightImpact(); // Success haptic
        Navigator.of(context).pop();
      });
    } else if (connectionState.errorMessage != null && _isConnecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact(); // Error haptic
      });
      setState(() {
        _errorMessage = connectionState.errorMessage;
        _isConnecting = false;
      });
    }

    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                _buildHeader(),

                const SizedBox(height: 32),

                // Code TextField
                _buildCodeInput(),
                const SizedBox(height: 24),

                // Connect Button
                _buildConnectButton()
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 400.ms)
                    .scale(
                        duration: 300.ms,
                        begin: const Offset(0.98, 0.98),
                        end: const Offset(1.0, 1.0),
                        curve: Curves.easeOut),
                const SizedBox(height: 32),

                // Help text
                _buildHelpText()
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 500.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Close button at top right
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ),

        // Center content - logo and title
        Column(
          children: [
            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/oseer_logo.png',
                  width: 50,
                  height: 50,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.link_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate().scale(
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Reconnect to Oseer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            // Instructions
            Text(
              'Enter the reconnection code from the Oseer web app to reconnect your device.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field with error handling
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _errorMessage != null
                  ? Colors.red.withOpacity(0.5)
                  : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: _errorMessage != null
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: TextField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: 'Enter reconnection code',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 17),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              suffixIcon: _codeController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _codeController.clear();
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 17),
            autofocus: true,
            enabled: !_isConnecting,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _connectWithCode(),
            onChanged: (value) {
              // Clear error when typing
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }

              // Force refresh to show/hide clear button
              setState(() {});
            },
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 14,
                  color: Colors.red,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 200.ms),
      ],
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isConnecting ? null : _connectWithCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: OseerColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: OseerColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Where to find your reconnection code',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You can find your reconnection code in the Oseer web app under Account → Devices → Reconnect',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _connectWithCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _errorMessage = 'Please enter a reconnection code';
      });
      return;
    }

    // Check code format
    if (!code.contains('/')) {
      HapticFeedback.mediumImpact();
      setState(() {
        _errorMessage = 'Invalid code format. Should be userId/token';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    // Log the connection attempt
    OseerLogger.info(
        'Attempting to reconnect with code: ${code.split('/')[0]}/***');

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Initiate connection process
    context.read<ConnectionBloc>().add(ConnectWithCodeEvent(code));
  }
}
