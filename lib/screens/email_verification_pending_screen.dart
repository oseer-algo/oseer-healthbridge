// lib/screens/email_verification_pending_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import 'auth/login_screen.dart';
import 'onboarding_screen.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  final String email;

  const EmailVerificationPendingScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  bool _isCheckingStatus = false;
  bool _isResendingEmail = false;
  Timer? _autoCheckTimer;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  static const int _resendCooldownSeconds = 60;
  int _attemptCount = 0;
  AuthBloc? _authBloc;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _authBloc = context.read<AuthBloc>();
    _setupTimers();
    OseerLogger.info(
        'EmailVerificationPendingScreen initialized for ${widget.email}');
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setupTimers() {
    // Auto-check every 5 seconds (up to 12 times = 1 minute)
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_attemptCount < 12 && !_isCheckingStatus && !_isNavigating) {
        _checkVerificationStatus();
        _attemptCount++;
        OseerLogger.debug(
            'Auto-checking verification status (attempt $_attemptCount/12)');
      } else if (_attemptCount >= 12) {
        // Stop auto-checking after 1 minute
        timer.cancel();
        OseerLogger.info('Auto-check timer completed after 12 attempts');
      }
    });
  }

  void _startResendCooldown() {
    // Set initial countdown
    setState(() {
      _remainingSeconds = _resendCooldownSeconds;
    });

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus || _isNavigating) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      OseerLogger.info(
          'Checking email verification status for ${widget.email}');
      final authService = context.read<AuthService>();
      final isVerified = authService.isEmailVerified();

      if (isVerified) {
        OseerLogger.info('Email verification confirmed for ${widget.email}');

        // Cancel timers
        _autoCheckTimer?.cancel();
        _countdownTimer?.cancel();

        // Update auth state - very important for navigation
        final currentUser = authService.getCurrentUser();
        if (currentUser != null) {
          _isNavigating = true;
          _authBloc?.add(
            AuthUserUpdatedEvent(currentUser),
          );

          // Also force a stored auth check to ensure state is updated
          _authBloc?.add(
            const AuthCheckStoredAuthEvent(),
          );
        }

        // Show successful verification message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Email verified successfully! Proceeding to next step...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        OseerLogger.info('Email ${widget.email} not yet verified');
      }
    } catch (e, s) {
      OseerLogger.error('Error checking verification status', e, s);
    } finally {
      if (mounted && !_isNavigating) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResendingEmail || _remainingSeconds > 0) return;

    setState(() {
      _isResendingEmail = true;
    });

    try {
      OseerLogger.info(
          'Attempting to resend verification email to ${widget.email}');

      // Send the authentication bloc event to trigger a resend
      _authBloc?.add(AuthResendVerificationEvent(widget.email));

      // Reset attempt count since we're restarting the process
      _attemptCount = 0;

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email has been resent'),
            backgroundColor: Colors.blue,
          ),
        );

        // Start cooldown
        _startResendCooldown();

        // Restart auto-check timer
        _setupTimers();
      }
    } catch (e, s) {
      OseerLogger.error('Error resending verification email', e, s);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendingEmail = false;
        });
      }
    }
  }

  Future<void> _openEmailApp() async {
    try {
      OseerLogger.info('Attempting to open email app');

      // Get platform-specific mail URI
      final Uri emailUri = Uri.parse('mailto:');

      // Try to launch email app
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        OseerLogger.warning('Could not launch email app');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email app'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, s) {
      OseerLogger.error('Error opening email app', e, s);
    }
  }

  void _navigateToLogin() {
    OseerLogger.info('Returning to login screen');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _proceedToOnboarding() {
    OseerLogger.info('Proceeding to onboarding');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        OseerLogger.info(
            'Auth state changed in EmailVerificationPendingScreen: ${state.runtimeType}');

        if (state is AuthAuthenticated) {
          // If user becomes fully authenticated, navigate to home screen
          OseerLogger.info('User is authenticated, navigating to home');
          Navigator.of(context).pushReplacementNamed(OseerRoutes.home);
        } else if (state is AuthOnboarding) {
          // If user needs onboarding, navigate to onboarding
          OseerLogger.info(
              'User needs onboarding, navigating to onboarding screen');
          _isNavigating = true;
          _proceedToOnboarding();
        } else if (state is AuthUnauthenticated) {
          // If user is unauthenticated, navigate to login
          OseerLogger.info(
              'User is unauthenticated, navigating to login screen');
          _navigateToLogin();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify Your Email'),
          backgroundColor: OseerColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateToLogin,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email sent image
                  Center(
                    child: Icon(
                      Icons.mark_email_read,
                      size: 100,
                      color: OseerColors.primary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Check Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Email info
                  const Text(
                    'We\'ve sent you a verification email. Please check your inbox and click the link to continue.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Email sent to
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Email sent to:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.email,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: widget.email));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Email copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Check verification button
                  ElevatedButton.icon(
                    onPressed:
                        _isCheckingStatus ? null : _checkVerificationStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OseerColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isCheckingStatus
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isCheckingStatus
                          ? 'Checking...'
                          : 'I\'ve verified my email',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Open email app button
                  OutlinedButton.icon(
                    onPressed: _openEmailApp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OseerColors.primary,
                      side: BorderSide(color: OseerColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.email),
                    label: const Text(
                      'Open Email App',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Didn\'t receive the email?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Resend email button
                  TextButton(
                    onPressed: _remainingSeconds > 0 || _isResendingEmail
                        ? null
                        : _resendVerificationEmail,
                    style: TextButton.styleFrom(
                      foregroundColor: OseerColors.primary,
                    ),
                    child: Text(
                      _remainingSeconds > 0
                          ? 'Resend Email (${_remainingSeconds}s)'
                          : _isResendingEmail
                              ? 'Sending...'
                              : 'Resend Verification Email',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Troubleshooting tips
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates,
                                color: Colors.blue[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Tips:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Check your spam or junk folder\n'
                          '• Make sure your email address is correct\n'
                          '• If you\'re still having trouble, try resending the email',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
