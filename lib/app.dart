// lib/app.dart

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/connection/connection_bloc.dart' as connection;
import 'screens/splash_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/token_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/email_verification_pending_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/logger_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';
import 'widgets/wellness_permissions_sheet.dart';
import 'widgets/notification_permission_dialog.dart';

class OseerApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const OseerApp({
    Key? key,
    required this.navigatorKey,
  }) : super(key: key);

  @override
  State<OseerApp> createState() => _OseerAppState();
}

class _OseerAppState extends State<OseerApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Animate.defaultDuration = OseerConstants.mediumAnimDuration;
    Animate.defaultCurve = Curves.easeOut;
    _initDeepLinks();

    // -- START: THIS IS THE CRITICAL FIX --
    // Dispatch the initial event here, after the widget is built and
    // the BlocListener is guaranteed to be listening.
    context.read<AuthBloc>().add(const AuthInitializeEvent());
    // -- END: THIS IS THE CRITICAL FIX --
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Sets up the listener for incoming deeplinks from the OS.
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      OseerLogger.info('🚀 Received deeplink via stream: $uri');

      if (uri.scheme == 'oseerbridge' && uri.host == 'onboarding') {
        // This is our success link from the web. Tell AuthBloc to handle it.
        OseerLogger.info("Dispatching AuthBypassInitialization to AuthBloc.");
        context.read<AuthBloc>().add(const AuthBypassInitialization());
      } else {
        OseerLogger.info(
            'Received a non-onboarding deeplink, ignoring for now.');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    OseerLogger.debug('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      // This is the ONLY place we should re-check permissions.
      context.read<AuthBloc>().add(const AuthAppResumedEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return MaterialApp(
      title: OseerConstants.appName,
      navigatorKey: widget.navigatorKey,
      theme: AppTheme.getTheme(),
      debugShowCheckedModeBanner: false,
      // The builder is the single source of truth for navigation.
      builder: (context, child) {
        return BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            _handleNavigation(state, widget.navigatorKey.currentState);
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      // The app ALWAYS starts at the SplashScreen.
      home: const SplashScreen(),
    );
  }

  // This navigation logic is now definitive.
  void _handleNavigation(AuthState state, NavigatorState? navigator) {
    if (navigator == null) return;

    OseerLogger.info(
        'Root Navigation Listener: Auth state changed to ${state.runtimeType}');

    // Determine the current route to avoid redundant navigations
    String? currentRouteName;
    navigator.popUntil((route) {
      currentRouteName = route.settings.name;
      return true;
    });

    // Handle permission dialogs
    if (state is AuthNeedsHealthPermissions &&
        currentRouteName != 'WellnessPermissionsSheet') {
      showModalBottomSheet<void>(
        context: navigator.context,
        isScrollControlled: true,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) => WellnessPermissionsSheet(
              scrollController: scrollController,
            ),
          ),
        ),
        routeSettings: const RouteSettings(name: 'WellnessPermissionsSheet'),
      );
      return;
    }

    if (state is AuthNeedsNotificationsPermission &&
        currentRouteName != 'NotificationPermissionDialog') {
      showDialog<bool>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: const NotificationPermissionDialog(),
        ),
        routeSettings:
            const RouteSettings(name: 'NotificationPermissionDialog'),
      ).then((shouldRequest) {
        if (shouldRequest == true) {
          context
              .read<AuthBloc>()
              .add(const AuthNotificationsPermissionRequested());
        } else {
          context
              .read<AuthBloc>()
              .add(const AuthNotificationPermissionHandled(false));
        }
      });
      return;
    }

    // Handle permission denied state
    if (state is AuthStatePermissionDenied) {
      // Show an alert dialog for permission denied
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Permissions Required'),
          content: Text(state.message),
          actions: [
            TextButton(
              onPressed: () {
                // Close the dialog and go to login
                Navigator.of(navigator.context).pop();
                navigator.pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                        settings: const RouteSettings(name: 'LoginScreen')),
                    (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Navigation logic
    if (state is AuthNeedsWelcome && currentRouteName != 'WelcomeScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const WelcomeScreen(),
              settings: const RouteSettings(name: 'WelcomeScreen')),
          (route) => false);
    } else if (state is AuthUnauthenticated &&
        currentRouteName != 'LoginScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const LoginScreen(),
              settings: const RouteSettings(name: 'LoginScreen')),
          (route) => false);
    } else if (state is AuthNavigateToLogin &&
        currentRouteName != 'LoginScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const LoginScreen(),
              settings: const RouteSettings(name: 'LoginScreen')),
          (route) => false);
    } else if (state is AuthEmailVerificationPending &&
        currentRouteName != 'EmailVerificationPendingScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) =>
                  EmailVerificationPendingScreen(email: state.email),
              settings:
                  const RouteSettings(name: 'EmailVerificationPendingScreen')),
          (route) => false);
    } else if (state is AuthProfileConfirmationRequired &&
        currentRouteName != 'ProfileScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => ProfileScreen(
                  isOnboarding: false,
                  profileForConfirmation: state.userProfile),
              settings: const RouteSettings(name: 'ProfileScreen')),
          (route) => false);
    } else if (state is AuthNeedsConnection &&
        currentRouteName != 'TokenScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const TokenScreen(),
              settings: const RouteSettings(name: 'TokenScreen')),
          (route) => false);
    } else if ((state is AuthHandoffInProgress ||
            state is AuthAuthenticated ||
            state is AuthOnboardingSyncInProgress ||
            state is AuthOnboardingComplete ||
            state is AuthPrioritySyncComplete) &&
        currentRouteName != 'HomeScreen') {
      navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const HomeScreen(),
              settings: const RouteSettings(name: 'HomeScreen')),
          (route) => false);
    }
  }
}
