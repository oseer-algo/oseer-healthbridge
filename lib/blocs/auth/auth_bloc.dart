//lib/blocs/auth/auth_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../blocs/connection/connection_bloc.dart' hide AuthStateChangedEvent;
import '../../blocs/connection/connection_event.dart' as connection;
import '../../blocs/connection/connection_state.dart' as conn;
import '../../managers/user_manager.dart';
import '../../managers/token_manager.dart';
import '../../managers/health_manager.dart';
import '../../managers/health_permission_manager.dart';
import '../../models/user_profile.dart';
import '../../models/helper_models.dart' hide ConnectionStatus;
import '../../models/sync_progress.dart';
import '../../services/auth_service.dart' hide AuthStatus;
import '../../services/logger_service.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart' as app_api;
import '../../services/background_sync_service.dart';
import '../../services/realtime_sync_service.dart';
import '../../utils/constants.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final UserManager _userManager;
  final SharedPreferences _prefs;
  final app_api.ApiService _apiService;
  ConnectionBloc? _connectionBloc;
  final TokenManager? _tokenManager;
  final NotificationService? _notificationService;
  final HealthManager? _healthManager;
  final BackgroundSyncService? _backgroundSyncService;
  RealtimeSyncService? _realtimeSyncService;

  StreamSubscription? _authSubscription;
  StreamSubscription? _userManagerSubscription;
  StreamSubscription? _connectionSubscription;

  bool _isInitialized = false;
  bool _isLoginInProgress = false;
  bool _isInitialPermissionFlowActive = false;
  String? _pendingVerificationEmail;

  // Flag ensures permission sequence runs only once per app launch
  bool _isInitialPermissionFlowComplete = false;

  AuthBloc({
    required AuthService authService,
    required UserManager userManager,
    required SharedPreferences prefs,
    required app_api.ApiService apiService,
    TokenManager? tokenManager,
    NotificationService? notificationService,
    HealthManager? healthManager,
    BackgroundSyncService? backgroundSyncService,
    RealtimeSyncService? realtimeSyncService,
  })  : _authService = authService,
        _userManager = userManager,
        _prefs = prefs,
        _apiService = apiService,
        _tokenManager = tokenManager,
        _notificationService = notificationService,
        _healthManager = healthManager,
        _backgroundSyncService = backgroundSyncService,
        _realtimeSyncService = realtimeSyncService,
        super(const AuthInitial()) {
    // Register event handlers
    on<AuthInitializeEvent>(_onInitialize);
    on<AuthCheckStoredAuthEvent>(_onCheckStoredAuth);
    on<AuthSignUpEvent>(_onSignUp);
    on<AuthLoginEvent>(_onLogin);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthCompleteOnboardingEvent>(_onCompleteOnboarding);
    on<AuthProfileConfirmedEvent>(_onProfileConfirmed);
    on<AuthUserUpdatedEvent>(_onUserUpdated);
    on<AuthNavigateToLoginEvent>(_onNavigateToLogin);
    on<AuthStateChangedEvent>(_onAuthStateChanged);
    on<AuthUserChangedEvent>(_onUserChanged);
    on<AuthResendVerificationEvent>(_onResendVerification);
    on<AuthCheckVerificationEvent>(_onCheckVerification);
    on<AuthNotificationsPermissionRequested>(
        _onNotificationsPermissionRequested);
    on<AuthProceedAfterNotificationsEvent>(_onProceedAfterNotifications);
    on<AuthHealthPermissionsRequested>(_onHealthPermissionsRequested);
    on<AuthHealthPermissionsSkipped>(_onHealthPermissionsSkipped);
    on<AuthAppResumedEvent>(_onAppResumed);
    on<AuthNotificationPermissionHandled>(_onNotificationPermissionHandled);
    on<AuthBypassInitialization>(_onBypassInitialization);
    on<AuthHandoffFinalizationRequested>(_onHandoffFinalizationRequested);
    on<AuthHealthPermissionHandled>(_onHealthPermissionHandled);
    on<AuthCheckPendingTasksEvent>(_onCheckPendingTasks);
    on<HistoricalSyncStarted>(_onHistoricalSyncStarted);
    on<AuthPrioritySyncCompleteEvent>(_onPrioritySyncComplete);

    _setupUserManagerSubscription();

    OseerLogger.info('AuthBloc: Created with UserManager listener');
  }

  void setConnectionBloc(ConnectionBloc connectionBloc) {
    _connectionBloc = connectionBloc;
    _connectionSubscription?.cancel();
    _connectionSubscription =
        _connectionBloc!.stream.listen(_onConnectionStateChanged);
    OseerLogger.info('ConnectionBloc has been set in AuthBloc.');
  }

  void setRealtimeSyncService(RealtimeSyncService realtimeSyncService) {
    _realtimeSyncService = realtimeSyncService;
    _realtimeSyncService!.listenToAuthChanges();
    OseerLogger.info('RealtimeSyncService has been set in AuthBloc.');
  }

  Future<void> _onInitialize(
      AuthInitializeEvent event, Emitter<AuthState> emit) async {
    // Check if returning from web handoff FIRST
    final bool isAwaitingHandoff =
        _prefs.getBool(OseerConstants.keyAwaitingWebHandoff) ?? false;
    if (isAwaitingHandoff) {
      OseerLogger.info(
          "App resumed during web handoff. Bypassing normal initialization.");
      await _prefs.remove(OseerConstants.keyAwaitingWebHandoff);
      add(const AuthBypassInitialization());
      return;
    }

    // Check if user needs welcome screen first
    final hasSeenWelcome =
        _prefs.getBool(OseerConstants.keyHasSeenWelcome) ?? false;
    if (!hasSeenWelcome) {
      OseerLogger.info('First time user. Emitting AuthNeedsWelcome.');
      emit(const AuthNeedsWelcome());
      return;
    }

    // Check if permission flow already complete this session
    if (_isInitialPermissionFlowComplete) {
      OseerLogger.info(
          'Permission flow already complete on this app launch. Checking stored auth.');
      add(const AuthCheckStoredAuthEvent());
      return;
    }

    OseerLogger.info(
        'AuthBloc: Starting GUARANTEED permission and auth sequence...');
    emit(const AuthLoading(message: 'Initializing...'));

    if (!_isInitialized) {
      await _authService.initialize();
      if (_notificationService != null)
        await _notificationService!.initialize();
      _setupAuthSubscription();
      _isInitialized = true;
    }

    // STEP 1: Check health permissions
    final permissionResult = await HealthPermissionManager.checkPermissions();
    if (permissionResult != HealthPermissionResult.granted) {
      OseerLogger.info(
          'Needs health permissions. Emitting state and waiting for user action.');
      emit(const AuthNeedsHealthPermissions());
      return;
    }

    OseerLogger.info('Health permissions are granted. Proceeding...');
    await _proceedToNotificationCheck(emit);
  }

  Future<void> _proceedToNotificationCheck(Emitter<AuthState> emit) async {
    if (_notificationService != null) {
      final bool enabled =
          await _notificationService!.areNotificationsEnabled();
      final bool alreadyRequested =
          _prefs.getBool('notifications_requested') ?? false;

      if (!enabled && !alreadyRequested) {
        OseerLogger.info('Needs notification permission. Emitting state.');
        emit(const AuthNeedsNotificationsPermission());
        return;
      }
    }

    OseerLogger.info(
        'Notification permissions handled. Finalizing initialization.');
    _isInitialPermissionFlowComplete = true;
    add(const AuthCheckStoredAuthEvent());
  }

  Future<void> _onHealthPermissionHandled(
      AuthHealthPermissionHandled event, Emitter<AuthState> emit) async {
    OseerLogger.info(
        'Health permissions handled by user (granted: ${event.granted}). Proceeding...');

    if (!event.granted) {
      OseerLogger.error(
          "Critical health permissions were explicitly denied or the request failed.");
      emit(const AuthStatePermissionDenied(
          'Health permissions are required for Oseer to function. Please enable them in your phone settings.'));
      return;
    }

    await _proceedToNotificationCheck(emit);
  }

  Future<void> _onHealthPermissionsRequested(
      AuthHealthPermissionsRequested event, Emitter<AuthState> emit) async {
    OseerLogger.info('Handling health permission request from UI...');
    emit(const AuthLoading(message: 'Requesting Permissions...'));

    final result = await HealthPermissionManager.requestPermissions();

    add(AuthHealthPermissionHandled(
        granted: result == HealthPermissionResult.granted ||
            result == HealthPermissionResult.partiallyGranted));
  }

  Future<void> _onHealthPermissionsSkipped(
      AuthHealthPermissionsSkipped event, Emitter<AuthState> emit) async {
    OseerLogger.warning("User skipped health permissions. Treating as denied.");
    add(const AuthHealthPermissionHandled(granted: false));
  }

  Future<void> _onProceedAfterNotifications(
      AuthProceedAfterNotificationsEvent event, Emitter<AuthState> emit) async {
    OseerLogger.info(
        'Health permissions handled. Now checking notifications...');
    await _proceedToNotificationCheck(emit);
  }

  Future<void> _onNotificationsPermissionRequested(
      AuthNotificationsPermissionRequested event,
      Emitter<AuthState> emit) async {
    OseerLogger.info('Handling OS notification permission request...');
    bool granted = false;
    if (_notificationService != null) {
      granted = await _notificationService!.requestPermissions();
      await _prefs.setBool('notifications_requested', true);
    }
    add(AuthNotificationPermissionHandled(granted));
  }

  void _onNotificationPermissionHandled(
      AuthNotificationPermissionHandled event, Emitter<AuthState> emit) {
    OseerLogger.info(
        'Notification flow complete. Checking for stored authentication.');

    _isInitialPermissionFlowActive = false;
    _isInitialPermissionFlowComplete = true;
    add(const AuthCheckStoredAuthEvent());
  }

  Future<void> _onAppResumed(
      AuthAppResumedEvent event, Emitter<AuthState> emit) async {
    OseerLogger.info("App Resumed. Re-evaluating permission state.");

    if (!_isInitialPermissionFlowComplete) {
      add(const AuthInitializeEvent());
    } else {
      OseerLogger.debug(
          "App resumed but initial permission flow is already complete. No action needed.");
    }
  }

  Future<void> _onCheckPendingTasks(
      AuthCheckPendingTasksEvent event, Emitter<AuthState> emit) async {
    OseerLogger.info('Checking for pending tasks from previous session...');

    try {
      final phase2Failed =
          _prefs.getBool('phase2_initialization_failed') ?? false;
      final phase2RetryCount = _prefs.getInt('phase2_retry_count') ?? 0;

      if (phase2Failed && phase2RetryCount < 3) {
        OseerLogger.info(
            'Found pending Phase 2 initialization (retry $phase2RetryCount/3)');

        try {
          await _apiService.invokeFunction('initialize-historical-sync', {});
          OseerLogger.info('Phase 2 initialization succeeded on retry');

          await _prefs.remove('phase2_initialization_failed');
          await _prefs.remove('phase2_retry_count');
        } catch (e) {
          OseerLogger.warning(
              'Phase 2 initialization still failing. Will retry on next app launch.',
              e);

          await _prefs.setInt('phase2_retry_count', phase2RetryCount + 1);

          if (phase2RetryCount >= 2) {
            await _prefs.remove('phase2_initialization_failed');
            await _prefs.remove('phase2_retry_count');
            OseerLogger.error(
                'Phase 2 initialization failed after 3 attempts. Manual intervention may be required.');
          }
        }
      }

      final failedMetricsBatch =
          _prefs.getString('failed_batch_raw_health_data_staging');
      final failedActivitiesBatch =
          _prefs.getString('failed_batch_raw_activities_staging');

      if (failedMetricsBatch != null || failedActivitiesBatch != null) {
        OseerLogger.info('Found failed data batches to retry');
      }

      final profileComplete =
          _prefs.getBool(OseerConstants.keyProfileComplete) ?? false;
      final isConnected =
          _prefs.getBool(OseerConstants.keyIsConnected) ?? false;

      if (profileComplete && !isConnected) {
        OseerLogger.info(
            'User has profile but no connection - may need to reconnect');
      }
    } catch (e, s) {
      OseerLogger.error('Error checking pending tasks', e, s);
    }
  }

  void _onConnectionStateChanged(conn.ConnectionState connectionState) {
    OseerLogger.info(
        "AuthBloc is observing ConnectionState: ${connectionState.status}");

    if (connectionState.status == conn.ConnectionStatus.prioritySyncComplete) {
      OseerLogger.info(
          "AuthBloc sees PrioritySyncComplete. Emitting state to UI.");
      final currentUser = _authService.getCurrentUser();
      if (currentUser != null) {
        emit(AuthPrioritySyncComplete(currentUser));
      }
    }
  }

  void _setupUserManagerSubscription() {
    _userManagerSubscription = _userManager.addListener(() {
      _handleUserManagerProfileUpdate();
    }) as StreamSubscription?;
  }

  void _handleUserManagerProfileUpdate() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    final isComplete = _userManager.isProfileComplete();
    OseerLogger.debug(
        'UserManager profile updated in background - isComplete: $isComplete');
  }

  Future<void> _determineAuthenticatedUserState(
    User user,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info(
        'AuthBloc: Determining state for authenticated user ${user.id}');

    add(const AuthCheckPendingTasksEvent());

    await _userManager.awaitProfileLoad();

    final userName = _authService.getUserName(user) ??
        user.email?.split('@').first ??
        'User';

    await _setupUserProfile(user, userName);

    final hasServerProfile = await _checkServerProfile(user);

    final currentProfile = _userManager.getUserProfileObject();
    final isProfileComplete = _userManager.isProfileComplete();

    OseerLogger.info('AuthBloc: Post-auth evaluation for ${user.id}:');
    OseerLogger.info('  - hasServerProfile: $hasServerProfile');
    OseerLogger.info('  - isProfileComplete: $isProfileComplete');
    OseerLogger.info('  - profile object exists: ${currentProfile != null}');

    final onboardingComplete =
        _prefs.getBool(OseerConstants.keyOnboardingComplete) ?? false;

    if (currentProfile != null && isProfileComplete && onboardingComplete) {
      OseerLogger.info('AuthBloc emitting: AuthAuthenticated (initialization)');
      emit(AuthAuthenticated(user));
    } else {
      OseerLogger.info('AuthBloc emitting: AuthOnboarding (initialization)');
      emit(AuthOnboarding(user));
    }
  }

  Future<bool> _checkServerProfile(User user) async {
    try {
      OseerLogger.info('Checking server profile for user ${user.id}');

      if (_userManager.shouldSyncFromServer()) {
        final success = await _userManager
            .fetchUserProfileFromServer()
            .timeout(const Duration(seconds: 10));

        OseerLogger.info(
            success ? 'Server profile loaded' : 'No server profile found');
        return success;
      }

      return true;
    } catch (e) {
      OseerLogger.warning('Server profile check failed: $e');
      return false;
    }
  }

  void _setupAuthSubscription() {
    if (_authSubscription != null) {
      OseerLogger.debug('Auth subscription already set up, skipping');
      return;
    }

    OseerLogger.info('Setting up auth state subscription');
    _authSubscription = _authService.authStateChanges.listen((authState) {
      OseerLogger.info('Auth service state changed: ${authState.runtimeType}');

      if (authState is AuthenticatedState) {
        add(const AuthStateChangedEvent(AuthStatus.authenticated));
        add(AuthUserChangedEvent(authState.user));
      } else if (authState is UnauthenticatedState) {
        add(const AuthStateChangedEvent(AuthStatus.unauthenticated));
        add(const AuthUserChangedEvent(null));
      } else if (authState is OnboardingState) {
        add(const AuthStateChangedEvent(AuthStatus.onboarding));
        add(AuthUserChangedEvent(authState.user));
      } else if (authState is EmailVerificationPendingState) {
        _pendingVerificationEmail = authState.email;
        add(const AuthStateChangedEvent(AuthStatus.emailVerificationPending));
      } else if (authState is ErrorState) {
        add(const AuthStateChangedEvent(AuthStatus.error));
      }
    });
  }

  Future<void> _onCheckStoredAuth(
    AuthCheckStoredAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Checking stored authentication status...');
    emit(const AuthLoading(message: 'Verifying session...'));

    try {
      final isAuthenticated = await _authService.isAuthenticated();
      final currentUser = _authService.getCurrentUser();

      OseerLogger.debug(
          'Auth status check complete. IsAuthenticated: $isAuthenticated, CurrentUser: ${currentUser?.id}');

      if (isAuthenticated && currentUser != null) {
        await _determineAuthenticatedUserState(currentUser, emit);
      } else {
        final hasSeenWelcome =
            _prefs.getBool(OseerConstants.keyHasSeenWelcome) ?? false;
        if (!hasSeenWelcome) {
          OseerLogger.info('First time user. Emitting AuthNeedsWelcome.');
          emit(const AuthNeedsWelcome());
        } else {
          OseerLogger.info(
              'No valid session found. Emitting AuthUnauthenticated.');
          _pendingVerificationEmail = null;
          emit(const AuthUnauthenticated());
        }
      }
    } catch (e, stack) {
      OseerLogger.error('Error during stored auth check', e, stack);
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignUp(
    AuthSignUpEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Processing signup for ${event.email}');
    emit(const AuthLoading(message: 'Creating your account...'));
    _isLoginInProgress = true;

    try {
      final user = await _authService.signUpWithEmail(
        event.email,
        event.password,
        event.name,
      );

      OseerLogger.info('Signup successful for ${event.email}');

      await _setupUserProfile(user, event.name);

      if (!_authService.isEmailVerified()) {
        OseerLogger.info('Email verification needed for ${event.email}');
        _pendingVerificationEmail = event.email;
        emit(AuthEmailVerificationPending(event.email));
        _isLoginInProgress = false;
      } else {
        OseerLogger.info('User created and verified: ${user.id}');
        await _handlePostLoginFlow(user, emit);
      }
    } catch (e) {
      if (e.toString().contains("Email not confirmed") ||
          e.toString().contains("verification required")) {
        OseerLogger.info('Email verification required for ${event.email}');
        _pendingVerificationEmail = event.email;
        emit(AuthEmailVerificationPending(event.email));
        _isLoginInProgress = false;
        return;
      }

      if (e.toString().contains("already registered") ||
          e.toString().contains("already in use") ||
          e.toString().contains("already exists") ||
          e.toString().contains("duplicate key") ||
          e.toString().contains("users_email_key") ||
          (e.toString().contains("Database error") &&
              e.toString().contains("500"))) {
        OseerLogger.info('Email already exists: ${event.email}');
        emit(AuthEmailAlreadyExists(event.email));
        _isLoginInProgress = false;
        return;
      }

      OseerLogger.error('Signup error', e);

      String errorMessage = 'Signup failed';
      if (e.toString().contains("network")) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains("timeout")) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains("invalid")) {
        errorMessage = 'Invalid email or password format.';
      } else if (e.toString().contains("weak password")) {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else {
        errorMessage = 'Signup failed: ${e.toString()}';
      }

      emit(AuthError(message: errorMessage));
      _isLoginInProgress = false;
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    OseerLogger.info('Processing login for ${event.email}');
    emit(const AuthLoading(message: 'Signing in...'));
    _isLoginInProgress = true;

    try {
      final user =
          await _authService.signInWithEmail(event.email, event.password);
      OseerLogger.info('Login successful for ${event.email}');
      await _handlePostLoginFlow(user, emit);
    } catch (e) {
      _isLoginInProgress = false;
      if (e.toString().contains("Email not confirmed") ||
          e.toString().contains("verification required")) {
        OseerLogger.info('Email verification required for ${event.email}');
        _pendingVerificationEmail = event.email;
        emit(AuthEmailVerificationPending(event.email));
      } else {
        OseerLogger.error('Error during login', e);

        String errorMessage;
        if (e.toString().contains("Invalid login credentials") ||
            e.toString().contains("Invalid email or password")) {
          errorMessage =
              'Invalid email or password. Please check your credentials and try again.';
        } else if (e.toString().contains("Too many requests")) {
          errorMessage =
              'Too many login attempts. Please wait a moment and try again.';
        } else if (e.toString().contains("network") ||
            e.toString().contains("connection")) {
          errorMessage =
              'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains("timeout")) {
          errorMessage = 'Login request timed out. Please try again.';
        } else if (e.toString().contains("Email not confirmed")) {
          errorMessage = 'Please verify your email address before logging in.';
        } else {
          errorMessage =
              'Login failed. Please try again or contact support if the problem persists.';
        }

        emit(AuthError(message: errorMessage));
      }
    }
  }

  Future<void> _onProfileConfirmed(
      AuthProfileConfirmedEvent event, Emitter<AuthState> emit) async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      OseerLogger.info(
          'Profile confirmed. Transitioning to connection and sync phase.');
      _isLoginInProgress = false;

      emit(AuthOnboardingSyncInProgress(SyncProgress.initial()));

      _connectionBloc?.add(const connection.ConnectToWebPressed());
    } else {
      OseerLogger.error('Cannot confirm profile: currentUser is null.');
      _isLoginInProgress = false;
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onHistoricalSyncStarted(
      HistoricalSyncStarted event, Emitter<AuthState> emit) async {
    final userId = _userManager.getUserId();
    if (userId != null && _backgroundSyncService != null) {
      await _backgroundSyncService!.enqueueHistoricalSync(userId);
      emit(AuthHistoricalSyncInProgress(SyncProgress.initial().copyWith(
        currentPhase: 'digitalTwin',
        bodyPrepProgress: 1.0,
        digitalTwinDaysProcessed: 0,
      )));
    }
  }

  Future<void> _onPrioritySyncComplete(
      AuthPrioritySyncCompleteEvent event, Emitter<AuthState> emit) async {
    OseerLogger.info(
        'AuthBloc received notification that priority sync is complete.');
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      emit(AuthPrioritySyncComplete(currentUser));
    }
  }

  Future<void> _handlePostLoginFlow(User user, Emitter<AuthState> emit) async {
    OseerLogger.info('Handling post-login flow for ${user.id}');
    emit(const AuthLoading(message: 'Loading your profile...'));

    try {
      final userName = _authService.getUserName(user) ??
          user.email?.split('@').first ??
          'User';
      await _setupUserProfile(user, userName);
      await _userManager.awaitProfileLoad();

      final bool fetchSuccess = await _userManager.fetchUserProfileFromServer();
      if (!fetchSuccess) {
        OseerLogger.warning(
          'Failed to fetch server profile. Proceeding with local data. Error: ${_userManager.errorMessage}',
        );
      }

      final userProfile = _userManager.getUserProfileObject();
      OseerLogger.info('Emitting AuthProfileConfirmationRequired.');
      emit(AuthProfileConfirmationRequired(user, userProfile: userProfile));
    } catch (e, stack) {
      _isLoginInProgress = false;
      OseerLogger.error('Critical error in post-login flow', e, stack);
      emit(AuthError(message: 'Failed to load profile: ${e.toString()}'));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Processing sign out');
    emit(const AuthLoading(message: 'Signing out...'));

    try {
      await _authService.signOut();
      await _userManager.clearUserData();

      _pendingVerificationEmail = null;
      _isLoginInProgress = false;
      _isInitialPermissionFlowComplete = false;

      OseerLogger.info('Sign out successful');
      emit(const AuthUnauthenticated());
    } catch (e, stack) {
      OseerLogger.error('Error during sign out', e, stack);
      _isLoginInProgress = false;
      _isInitialPermissionFlowComplete = false;
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _setupUserProfile(User user, String displayName) async {
    try {
      final storedProfile = _userManager.getUserProfileObject();

      if (storedProfile == null || storedProfile.userId != user.id) {
        OseerLogger.info('Creating new user profile for ${user.id}');

        final profile = UserProfile(
          userId: user.id,
          name: displayName,
          email: user.email ?? '',
        );

        await _userManager.saveUserProfileLocally(profile);
        OseerLogger.info('Created initial user profile for ${user.id}');
      } else {
        OseerLogger.info('Using existing profile for ${user.id}');

        final userName = _authService.getUserName(user);
        if (userName != null && userName != storedProfile.name) {
          OseerLogger.info(
              'Updating profile name from ${storedProfile.name} to $userName');

          final updatedProfile = storedProfile.copyWith(name: userName);
          await _userManager.saveUserProfileLocally(updatedProfile);

          await _authService.updateCurrentUser({'name': userName});
        }
      }
    } catch (e, stack) {
      OseerLogger.error('Error setting up user profile', e, stack);
    }
  }

  Future<void> _onCompleteOnboarding(
    AuthCompleteOnboardingEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Marking onboarding as complete');

    try {
      await _prefs.setBool(OseerConstants.keyOnboardingComplete, true);
      await _prefs.setBool(OseerConstants.keyProfileComplete, true);

      await _authService.setOnboardingStatus(true);

      final currentUser = _authService.getCurrentUser();

      if (currentUser != null) {
        OseerLogger.info('Onboarding completed for ${currentUser.id}');
        _isLoginInProgress = false;
        emit(AuthAuthenticated(currentUser));
      } else {
        OseerLogger.warning(
            'No current user found after onboarding completion');
        _isLoginInProgress = false;
        emit(const AuthUnauthenticated());
      }
    } catch (e, stack) {
      OseerLogger.error('Error completing onboarding', e, stack);
      _isLoginInProgress = false;
      emit(
          AuthError(message: 'Failed to complete onboarding: ${e.toString()}'));
    }
  }

  void _onUserUpdated(
    AuthUserUpdatedEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('User updated: ${event.user.id}');

    final userName = _authService.getUserName(event.user) ??
        event.user.email?.split('@').first ??
        'User';

    await _setupUserProfile(event.user, userName);

    if (_pendingVerificationEmail != null && _authService.isEmailVerified()) {
      OseerLogger.info('Email verification confirmed for ${event.user.email}');
      _pendingVerificationEmail = null;
      _isLoginInProgress = true;

      await _handlePostLoginFlow(event.user, emit);
    }
  }

  Future<void> _onAuthStateChanged(
    AuthStateChangedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (_isInitialPermissionFlowActive) {
      OseerLogger.info(
          'Initial permission flow is active. Ignoring background auth state change to ${event.status}.');
      return;
    }

    OseerLogger.info('Auth state changed: ${event.status}');

    if (_isLoginInProgress) {
      OseerLogger.info(
          'Login in progress, skipping auth state change processing');
      return;
    }

    final currentUser = _authService.getCurrentUser();

    switch (event.status) {
      case AuthStatus.authenticated:
        if (currentUser != null) {
          await _determineAuthenticatedUserState(currentUser, emit);
        }
        break;

      case AuthStatus.unauthenticated:
        OseerLogger.info('User is unauthenticated');
        _pendingVerificationEmail = null;
        emit(const AuthUnauthenticated());
        break;

      case AuthStatus.onboarding:
        if (currentUser != null) {
          OseerLogger.info(
              'AuthBloc: Received OnboardingState from AuthService. Re-determining user state.');
          await _determineAuthenticatedUserState(currentUser, emit);
        } else {
          OseerLogger.warning(
              'AuthBloc: OnboardingState received but currentUser is null. Emitting Unauthenticated.');
          emit(const AuthUnauthenticated());
        }
        break;

      case AuthStatus.emailVerificationPending:
        if (_pendingVerificationEmail != null) {
          OseerLogger.info(
              'Email verification pending for $_pendingVerificationEmail');
          emit(AuthEmailVerificationPending(_pendingVerificationEmail!));
        } else if (currentUser?.email != null) {
          OseerLogger.info(
              'Email verification pending for ${currentUser?.email}');
          emit(AuthEmailVerificationPending(currentUser!.email!));
        }
        break;

      case AuthStatus.error:
        OseerLogger.error('Auth error state');
        emit(const AuthUnauthenticated());
        break;

      case AuthStatus.initial:
        OseerLogger.info('Auth in initial state');
        emit(const AuthInitial());
        break;
    }
  }

  void _onUserChanged(
    AuthUserChangedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      OseerLogger.info('User changed: ${event.user!.id}');

      final userName = _authService.getUserName(event.user!) ??
          event.user!.email?.split('@').first ??
          'User';

      await _setupUserProfile(event.user!, userName);
    } else {
      OseerLogger.info('User cleared');
      _pendingVerificationEmail = null;
    }
  }

  void _onNavigateToLogin(
    AuthNavigateToLoginEvent event,
    Emitter<AuthState> emit,
  ) {
    OseerLogger.info('Navigating to login');
    _pendingVerificationEmail = null;
    emit(const AuthNavigateToLogin());
  }

  Future<void> _onResendVerification(
    AuthResendVerificationEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Resending verification email to ${event.email}');
    emit(const AuthLoading(message: 'Resending verification email...'));

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: event.email,
      );

      OseerLogger.info(
          'Verification email resent successfully to: ${event.email}');

      _pendingVerificationEmail = event.email;
      emit(AuthEmailVerificationPending(event.email));
    } catch (e, stack) {
      OseerLogger.error('Error resending verification email', e, stack);

      String errorMessage;
      if (e.toString().contains("rate limit") ||
          e.toString().contains("too many")) {
        errorMessage =
            'Please wait before requesting another verification email.';
      } else if (e.toString().contains("network")) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      } else {
        errorMessage = 'Failed to resend verification email. Please try again.';
      }

      emit(AuthError(message: errorMessage));
    }
  }

  Future<void> _onCheckVerification(
    AuthCheckVerificationEvent event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info('Checking verification status for ${event.email}');
    emit(const AuthLoading(message: 'Checking verification status...'));

    try {
      final isVerified = _authService.isEmailVerified();

      if (isVerified) {
        OseerLogger.info('Email ${event.email} is verified');
        _pendingVerificationEmail = null;
        _isLoginInProgress = true;

        final currentUser = _authService.getCurrentUser();
        if (currentUser != null) {
          await _handlePostLoginFlow(currentUser, emit);
        } else {
          _isLoginInProgress = false;
          emit(const AuthUnauthenticated());
        }
      } else {
        OseerLogger.info('Email ${event.email} still pending verification');
        _pendingVerificationEmail = event.email;
        emit(AuthEmailVerificationPending(event.email));
      }
    } catch (e, stack) {
      OseerLogger.error('Error checking verification status', e, stack);
      emit(AuthError(
          message: 'Failed to check verification status. Please try again.'));
    }
  }

  Future<void> _onBypassInitialization(
    AuthBypassInitialization event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info(
        'Auth handoff initiated via deeplink. Preparing app state...');

    emit(const AuthHandoffInProgress());

    _connectionBloc?.add(const connection.FinalizeHandoffConnection());
  }

  Future<void> _onHandoffFinalizationRequested(
    AuthHandoffFinalizationRequested event,
    Emitter<AuthState> emit,
  ) async {
    OseerLogger.info("Handling handoff finalization request.");
    emit(const AuthLoading(message: 'Finalizing connection...'));

    _connectionBloc?.add(const connection.ConnectionEstablishedViaDeeplink());
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _userManagerSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
