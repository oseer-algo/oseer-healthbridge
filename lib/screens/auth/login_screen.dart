// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../services/logger_service.dart';
import '../../utils/constants.dart';
import '../../widgets/wellness_permissions_sheet.dart';
import '../../widgets/notification_permission_dialog.dart';
import '../home_screen.dart';
import '../onboarding_screen.dart';
import '../profile_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // --- FIX: Removed initState method entirely to prevent infinite permission loop ---
  // The AuthInitializeEvent is now dispatched once from main.dart when AuthBloc is created

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: OseerColors.error,
        ),
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    _clearError();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    context.read<AuthBloc>().add(
          AuthLoginEvent(
            email: email,
            password: password,
          ),
        );
  }

  void _navigateToSignup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseerColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        // New listener dedicated to showing permission dialogs on this screen.
        listener: (context, state) async {
          if (state is AuthNeedsHealthPermissions) {
            OseerLogger.info('LoginScreen: Showing health permissions sheet');
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              isDismissible: false,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: context.read<AuthBloc>(),
                child: WellnessPermissionsSheet(
                    scrollController: ScrollController()),
              ),
            );
          } else if (state is AuthNeedsNotificationsPermission) {
            OseerLogger.info(
                'LoginScreen: Showing notification permission dialog');
            final bool? shouldRequest = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BlocProvider.value(
                value: context.read<AuthBloc>(),
                child: const NotificationPermissionDialog(),
              ),
            );
            if (shouldRequest == true) {
              context
                  .read<AuthBloc>()
                  .add(const AuthNotificationsPermissionRequested());
            } else {
              context
                  .read<AuthBloc>()
                  .add(const AuthNotificationPermissionHandled(false));
            }
          }
        },
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            // Handle loading states
            if (state is AuthLoading) {
              _setLoading(true);
            } else {
              _setLoading(false);
            }

            if (state is AuthError) {
              _showError(state.message);
            }

            // Handle profile confirmation for existing users
            if (state is AuthProfileConfirmationRequired) {
              OseerLogger.info(
                  'LoginScreen: AuthProfileConfirmationRequired received. Navigating to ProfileScreen with profile data.');

              // Ensure we have profile data before navigating
              if (state.userProfile != null) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      isOnboarding: false,
                      profileForConfirmation: state.userProfile,
                    ),
                  ),
                );
              } else {
                // Fallback if no profile data - should not happen but handle gracefully
                OseerLogger.warning(
                    'LoginScreen: AuthProfileConfirmationRequired but no profile data, navigating to onboarding');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingScreen()),
                );
              }
            } else if (state is AuthOnboarding) {
              // Navigate to onboarding screen for new users
              OseerLogger.info(
                  'LoginScreen: AuthOnboarding received, navigating to onboarding');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const OnboardingScreen()),
              );
            } else if (state is AuthAuthenticated) {
              // Navigate to home screen if user is fully authenticated
              OseerLogger.info(
                  'LoginScreen: AuthAuthenticated received, navigating to home');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  OseerColors.primary.withOpacity(0.03),
                  OseerColors.primaryLight.withOpacity(0.01),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),

                          // App Icon
                          Center(
                            child: Container(
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
                                    color:
                                        OseerColors.primary.withOpacity(0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 44,
                                color: Colors.white,
                              ),
                            ),
                          )
                              .animate()
                              .scale(
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1.0, 1.0),
                              )
                              .fade(duration: 300.ms),

                          const SizedBox(height: 32),

                          // Title
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: OseerColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                          const SizedBox(height: 8),

                          Text(
                            'Sign in to continue your wellness journey',
                            style: TextStyle(
                              fontSize: 15,
                              color: OseerColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

                          const SizedBox(height: 48),

                          // Email TextFormField
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon:
                                  const Icon(Icons.email_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: OseerColors.border.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: OseerColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.username
                            ],
                            textInputAction: TextInputAction.next,
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
                            enabled: !_isLoading,
                          ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                          const SizedBox(height: 16),

                          // Password TextFormField
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: OseerColors.border.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: OseerColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            onEditingComplete: _isLoading ? null : _login,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            enabled: !_isLoading,
                          ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

                          const SizedBox(height: 16),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: (_isLoading)
                                  ? null
                                  : () {
                                      // TODO: Implement forgot password
                                    },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: OseerColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

                          const SizedBox(height: 32),

                          // Login button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
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
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(duration: 500.ms, delay: 700.ms),

                          const SizedBox(height: 24),

                          // Don't have account
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Don\'t have an account? ',
                                style: TextStyle(
                                  color: OseerColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: _navigateToSignup,
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: OseerColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 500.ms, delay: 800.ms),

                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
