// File path: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/health/health_bloc.dart';
import 'managers/health_manager.dart';
import 'managers/token_manager.dart';
import 'services/api_service.dart';
import 'services/logger_service.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize logger
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );
  OseerLogger.init(logger);

  // Log app start
  OseerLogger.info(
      'Starting app: ${OseerConstants.appName} v${OseerConstants.appVersion}');

  // Create our services
  final apiService = ApiService(prefs); // Fixed: Pass prefs to constructor

  // Create the token manager
  final tokenManager = TokenManager(apiService, prefs);

  // Create the health manager
  final healthManager = HealthManager(apiService, prefs);

  // Create the navigator key for global access
  final navigatorKey = GlobalKey<NavigatorState>();

  // Check onboarding and profile status to determine initial route
  final initialRoute = await determineInitialRoute(prefs, tokenManager);
  OseerLogger.info('Initial route determined: $initialRoute');

  // Start the app with providers
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>(
          create: (context) => prefs,
        ),
        RepositoryProvider<ApiService>(
          create: (context) => apiService,
        ),
        RepositoryProvider<TokenManager>(
          create: (context) => tokenManager,
        ),
        RepositoryProvider<HealthManager>(
          create: (context) => healthManager,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<HealthBloc>(
            create: (context) => HealthBloc(
              healthManager: healthManager,
              tokenManager: tokenManager,
              prefs: prefs,
            ),
          ),
          BlocProvider<ConnectionBloc>(
            create: (context) => ConnectionBloc(
              healthManager: healthManager,
              apiService: apiService,
              prefs: prefs,
              tokenManager: tokenManager,
            ),
          ),
        ],
        child: OseerApp(
          navigatorKey: navigatorKey,
          initialRoute: initialRoute,
        ),
      ),
    ),
  );
}

/// Determine the initial route based on onboarding and profile completion status
Future<String> determineInitialRoute(
    SharedPreferences prefs, TokenManager tokenManager) async {
  // Check if onboarding was completed
  final isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  if (!isOnboardingComplete) {
    // User hasn't completed onboarding yet, so show the intro screen
    return '/onboarding/intro';
  }

  // Check if profile is complete
  final isProfileComplete = await OseerConstants.isProfileComplete();
  if (!isProfileComplete) {
    // User has completed onboarding but not profile, show profile screen
    return '/profile/onboarding';
  }

  // Check if we have a connection token
  final hasToken = tokenManager.getCurrentToken() != null;
  if (!hasToken) {
    // User has completed profile but doesn't have a token, show token screen
    return '/token';
  }

  // User has completed all setup steps, show main screen
  return '/home';
}
