// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../services/toast_service.dart';
import '../../utils/constants.dart';
import '../home_screen.dart';
import '../onboarding_screen.dart';
import '../email_verification_pending_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _verificationEmailSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });

      ToastService.error(message);
    }
  }

  void _setVerificationEmailSent() {
    if (mounted) {
      setState(() {
        _verificationEmailSent = true;
        _isLoading = false;
      });

      ToastService.success(
        'Verification email sent! Please check your inbox.',
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _clearError() {
    if (mounted && _errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    _clearError();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    context.read<AuthBloc>().add(
          AuthSignUpEvent(
            name: name,
            email: email,
            password: password,
          ),
        );
  }

  void _navigateToLogin() {
    context.read<AuthBloc>().add(const AuthNavigateToLoginEvent());
  }

  void _navigateToEmailVerification() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => EmailVerificationPendingScreen(
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width to handle overflow issues
    double screenWidth = MediaQuery.of(context).size.width;
    double formWidth = screenWidth > 600 ? 500 : screenWidth - 48;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            _setLoading(true);
          } else {
            _setLoading(false);
          }

          if (state is AuthError) {
            _showError(state.message);
          }

          if (state is AuthOnboarding) {
            // Navigate to onboarding screen when user needs to complete onboarding
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          } else if (state is AuthAuthenticated) {
            // Navigate to home screen if user is fully authenticated and onboarding complete
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }

          // Handle email verification pending state
          if (state is AuthEmailVerificationPending) {
            _setVerificationEmailSent();

            // Automatically navigate to verification pending screen
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _navigateToEmailVerification();
              }
            });
          }

          if (state is AuthEmailAlreadyExists) {
            // Show dialog or message about existing email
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Account Already Exists'),
                content: Text(
                  'An account with email ${state.email} already exists. Would you like to log in instead?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _navigateToLogin();
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
            );
          }

          if (state is AuthNavigateToLogin) {
            // Navigate to login screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              // Wrap the Column inside the Form with AutofillGroup
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Icon
                    Center(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 80,
                        height: 80,
                      ),
                    ).animate().fadeIn(duration: 600.ms),

                    const SizedBox(height: 32),

                    // Title
                    SizedBox(
                      width: formWidth,
                      child: const Text(
                        'Join Oseer HealthBridge',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: formWidth,
                      child: const Text(
                        'Create an account to connect your health data',
                        style: TextStyle(
                          fontSize: 16,
                          color: OseerColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                    ),

                    const SizedBox(height: 24),

                    // Email Signup Form
                    SizedBox(
                      width: formWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Verification Email Sent Alert
                          if (_verificationEmailSent)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: OseerColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: OseerColors.success.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.mark_email_read_outlined,
                                        color: OseerColors.success,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Verification Email Sent',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: OseerColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'We\'ve sent a verification link to ${_emailController.text}. Please check your inbox and click the link to verify your email address.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: OseerColors.textPrimary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'If you don\'t see the email, please check your spam folder.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: OseerColors.textSecondary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms).scale(
                                  begin: const Offset(0.95, 0.95),
                                  end: const Offset(1, 1),
                                ),

                          // Name TextFormField with autofill hints
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                            enabled: !_isLoading && !_verificationEmailSent,
                          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

                          const SizedBox(height: 16),

                          // Email TextFormField with autofill hints
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            enabled: !_isLoading && !_verificationEmailSent,
                          ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                          const SizedBox(height: 16),

                          // Password TextFormField with autofill hints
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            enabled: !_isLoading && !_verificationEmailSent,
                          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

                          const SizedBox(height: 16),

                          // Confirm Password field
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: _toggleConfirmPasswordVisibility,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            obscureText: _obscureConfirmPassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            enabled: !_isLoading && !_verificationEmailSent,
                          ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

                          const SizedBox(height: 24),

                          // Sign Up button
                          if (!_verificationEmailSent)
                            ElevatedButton(
                              onPressed: _isLoading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OseerColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ).animate().fadeIn(duration: 600.ms, delay: 700.ms),

                          // Go to Login button (shown after verification email sent)
                          if (_verificationEmailSent)
                            ElevatedButton(
                              onPressed: _navigateToEmailVerification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OseerColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Go to Verification Screen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ).animate().fadeIn(duration: 400.ms),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Already have account
                    if (!_verificationEmailSent)
                      SizedBox(
                        width: formWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: OseerColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: _navigateToLogin,
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  color: OseerColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 800.ms),

                    const SizedBox(height: 16),

                    // Terms and conditions
                    if (!_verificationEmailSent)
                      SizedBox(
                        width: formWidth,
                        child: const Text(
                          'By signing up, you agree to our Terms of Service and Privacy Policy',
                          style: TextStyle(
                            fontSize: 12,
                            color: OseerColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
