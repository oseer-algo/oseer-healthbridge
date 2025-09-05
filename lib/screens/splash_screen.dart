// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../utils/constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The splash screen no longer handles navigation.
    // It simply shows a UI and relies on the root BlocListener in `app.dart`
    // to navigate away when the AuthBloc emits a non-initial/loading state.

    return Scaffold(
      backgroundColor: OseerColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 120,
              height: 120,
            ).animate().scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 24),
            Text(
              'Oseer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: OseerColors.primary,
                fontFamily: 'Geist',
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
            const SizedBox(height: 16),
            Text(
              'Your wellness companion',
              style: TextStyle(
                fontSize: 16,
                color: OseerColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 600)),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(OseerColors.primary),
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 800)),
            const SizedBox(height: 16),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                // Display a status message based on the current auth state
                String message = 'Initializing...';
                if (state is AuthHandoffInProgress) {
                  message = 'Finalizing Connection...';
                } else if (state is AuthLoading) {
                  message = state.message ?? 'Loading...';
                }

                return Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: OseerColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ).animate(key: ValueKey(message)).fadeIn();
              },
            ),
          ],
        ),
      ),
    );
  }
}
