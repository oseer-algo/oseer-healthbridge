// lib/screens/onboarding_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/auth/auth_event.dart';
import '../models/user_profile.dart';
import '../models/helper_models.dart' as helper hide SyncStatus;
import '../models/sync_progress.dart';
import '../managers/user_manager.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../extensions/health_manager_extensions.dart';
import '../widgets/profile_confirmation_sheet.dart';
import '../widgets/wellness_permissions_sheet.dart';
import '../widgets/sync_loading_dialog.dart';
import 'token_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Additional controllers for health data
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedGender = '';
  String _selectedActivityLevel = '';
  bool _isLoading = false;
  bool _isExtracting = false;
  int _currentStep = 0;
  bool _healthPermissionsGranted = false;
  bool _hasRequestedPermissions = false;
  bool _backgroundSyncStarted = false;
  bool _isSyncing = false;
  SyncProgress? _syncProgress;

  // Store subscription to properly clean up
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<AuthState>? _authBlocSubscription;

  @override
  void initState() {
    super.initState();
    _loadExistingProfileData();
    _checkHealthPermissions();
    _setupAuthBlocListener();
  }

  @override
  void dispose() {
    // Cancel subscriptions to prevent callback after dispose
    _syncProgressSubscription?.cancel();
    _authBlocSubscription?.cancel();
    _syncProgressSubscription = null;
    _authBlocSubscription = null;

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Enhanced AuthBloc listener for navigation decisions
  void _setupAuthBlocListener() {
    _authBlocSubscription = context.read<AuthBloc>().stream.listen((authState) {
      if (!mounted) return;

      OseerLogger.info(
          "OnboardingScreen: AuthBloc state changed to ${authState.runtimeType}");

      if (authState is AuthAuthenticated) {
        // With new mandatory profile flow, this should not happen during onboarding
        // If it does, it means profile confirmation was completed elsewhere
        _handleAuthenticatedState();
      } else if (authState is AuthOnboarding) {
        OseerLogger.info(
            "OnboardingScreen: AuthOnboarding state. Ensuring UI reflects this.");
        _loadExistingProfileData();
        _checkHealthPermissions();
      } else if (authState is AuthLoading && !_isLoading) {
        if (mounted) setState(() => _isLoading = true);
      } else if (authState is! AuthLoading && _isLoading) {
        if (mounted) setState(() => _isLoading = false);
      }
    });

    // Initial check in case AuthBloc has already resolved its state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final initialAuthState = context.read<AuthBloc>().state;
      OseerLogger.info(
          "OnboardingScreen: Initial AuthBloc state check: ${initialAuthState.runtimeType}");

      if (initialAuthState is AuthAuthenticated) {
        _handleAuthenticatedState();
      } else if (initialAuthState is AuthOnboarding) {
        _loadExistingProfileData();
        _checkHealthPermissions();
      } else if (initialAuthState is AuthLoading) {
        if (!_isLoading && mounted) setState(() => _isLoading = true);
      }
    });
  }

  /// Handle authenticated state - with new mandatory profile flow, this should not happen during onboarding
  Future<void> _handleAuthenticatedState() async {
    if (!mounted) return;

    // With the new mandatory profile confirmation flow, users should not reach
    // AuthAuthenticated state during onboarding. If they do, it means the profile
    // confirmation was completed elsewhere, so we should navigate to TokenScreen.
    OseerLogger.info(
        "OnboardingScreen: AuthAuthenticated state received. This suggests profile confirmation was completed elsewhere. Navigating to TokenScreen.");
    _navigateToTokenScreen();
  }

  /// Load user profile from SharedPreferences on initialization
  Future<void> _loadExistingProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _nameController.text = prefs.getString(OseerConstants.keyUserName) ?? '';
      _emailController.text =
          prefs.getString(OseerConstants.keyUserEmail) ?? '';
      _phoneController.text =
          prefs.getString(OseerConstants.keyUserPhone) ?? '';

      final age = prefs.getInt(OseerConstants.keyUserAge);
      if (age != null) {
        _ageController.text = age.toString();
      }

      final height = prefs.getDouble(OseerConstants.keyUserHeight);
      if (height != null) {
        _heightController.text = height.toString();
      }

      final weight = prefs.getDouble(OseerConstants.keyUserWeight);
      if (weight != null) {
        _weightController.text = weight.toString();
      }

      _selectedGender = prefs.getString(OseerConstants.keyUserGender) ?? '';
      _selectedActivityLevel =
          prefs.getString(OseerConstants.keyUserActivityLevel) ?? '';
    });
  }

  /// Check current health permission status
  Future<void> _checkHealthPermissions() async {
    context.read<HealthBloc>().add(const CheckHealthPermissionsEvent());
  }

  /// Request health permissions
  void _requestHealthPermissions() {
    if (_hasRequestedPermissions) return; // Prevent multiple requests

    _hasRequestedPermissions = true;
    OseerLogger.info('🔑 Requesting health permissions from OnboardingScreen');

    // Add small delay to ensure UI is ready for permission dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<HealthBloc>().add(const RequestHealthPermissionsEvent());
      }
    });
  }

  /// Attempt to extract profile data from health platform
  void _attemptProfileExtraction() {
    if (_healthPermissionsGranted) {
      setState(() {
        _isExtracting = true;
      });
      context.read<HealthBloc>().add(const ExtractProfileDataEvent());
    }
  }

  void _nextStep() {
    if (_currentStep < 1) {
      // Validate current step before proceeding
      if (_currentStep == 0 && !_validateBasicInfo()) {
        return;
      }
      setState(() {
        _currentStep += 1;
      });
    } else {
      _saveProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  bool _validateBasicInfo() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return false;
    }
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return false;
    }
    return true;
  }

  /// Show sync progress dialog with option to continue in background
  void _showSyncProgressDialog(BuildContext context) {
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isSyncing = true;
    });

    // Initialize sync progress if not already set
    _syncProgress ??= SyncProgress.initial();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Update the dialog with the latest progress
            return SyncLoadingDialog(
              title: 'Sync Health Data',
              initialMessage: _syncProgress?.currentActivity ??
                  'Syncing your health data...',
              progressStream: HealthManagerSyncHelper.syncProgressStream,
              onCancel: () {
                // Mark sync as running in background and navigate to token screen
                _backgroundSyncStarted = true;
                setState(() {
                  _isSyncing = false;
                });
                Navigator.of(dialogContext).pop(); // Close the dialog
                _navigateToTokenScreen(); // Navigate to the next screen
              },
            );
          },
        );
      },
    );

    // Listen for sync progress updates
    _listenForSyncProgress();
  }

  /// Listen for sync progress updates from HealthManager
  void _listenForSyncProgress() {
    // Clean up any existing subscription
    _syncProgressSubscription?.cancel();

    // Access the syncProgressStream via the HealthManagerSyncHelper class
    _syncProgressSubscription =
        HealthManagerSyncHelper.syncProgressStream.listen((progress) {
      // Check if widget is still mounted before setState
      if (!mounted) return;

      // Update the progress state
      setState(() {
        _syncProgress = progress;
      });

      // If sync is complete, close dialog and navigate if still showing
      if (progress.isComplete && !_backgroundSyncStarted) {
        // Check if still mounted before navigating
        if (!mounted) return;

        setState(() {
          _isSyncing = false;
        });

        // Close dialog if it's still showing
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Navigate to token screen
        _navigateToTokenScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Handle authentication state in build method
        if (authState is AuthLoading &&
            ModalRoute.of(context)?.isCurrent == true) {
          OseerLogger.debug("OnboardingScreen: AuthBloc is loading.");
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (authState is AuthAuthenticated) {
          // Profile confirmation was completed elsewhere, navigate away
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              OseerLogger.info(
                  "OnboardingScreen: AuthAuthenticated in build method. Navigating.");
              _navigateToTokenScreen();
            }
          });
          // Return a loading indicator while navigation happens
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return WillPopScope(
          // Prevent back button from taking users to login screen
          onWillPop: () async => false,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Complete Your Profile'),
              backgroundColor: OseerColors.primary,
              automaticallyImplyLeading: false, // Remove back button
            ),
            body: BlocListener<HealthBloc, HealthState>(
              listener: (context, state) {
                if (state is HealthPermissionsChecked) {
                  // Check if we have the critical permissions needed
                  final criticalPermissions = [
                    'weight',
                    'height',
                    'steps',
                    'sleep_asleep'
                  ];
                  final hasCriticalPermissions = criticalPermissions.any(
                      (permission) => state.authStatus.grantedPermissions
                          .contains(permission));

                  if (!mounted) return; // Check if widget is still mounted

                  setState(() {
                    _healthPermissionsGranted = hasCriticalPermissions &&
                        (state.authStatus.status ==
                                helper.HealthPermissionStatus.granted ||
                            state.authStatus.status ==
                                helper.HealthPermissionStatus.partiallyGranted);
                  });

                  if (!_healthPermissionsGranted && !_hasRequestedPermissions) {
                    // Request permissions if critical ones are missing
                    _requestHealthPermissions();
                  } else if (_healthPermissionsGranted &&
                      _ageController.text.isEmpty) {
                    _attemptProfileExtraction();
                  }
                }

                if (state is ProfileDataExtracted) {
                  if (!mounted) return; // Check if widget is still mounted

                  setState(() => _isExtracting = false);

                  // Populate form fields with extracted profile data
                  if (_nameController.text.isEmpty &&
                      state.profile.name.isNotEmpty) {
                    _nameController.text = state.profile.name;
                  }
                  if (_emailController.text.isEmpty &&
                      state.profile.email.isNotEmpty) {
                    _emailController.text = state.profile.email;
                  }
                  if (_phoneController.text.isEmpty &&
                      state.profile.phone != null) {
                    _phoneController.text = state.profile.phone!;
                  }
                  if (_ageController.text.isEmpty &&
                      state.profile.age != null) {
                    _ageController.text = state.profile.age.toString();
                  }
                  if (_heightController.text.isEmpty &&
                      state.profile.height != null) {
                    _heightController.text = state.profile.height.toString();
                  }
                  if (_weightController.text.isEmpty &&
                      state.profile.weight != null) {
                    _weightController.text = state.profile.weight.toString();
                  }
                  if (_selectedGender.isEmpty && state.profile.gender != null) {
                    setState(() => _selectedGender = state.profile.gender!);
                  }
                  if (_selectedActivityLevel.isEmpty &&
                      state.profile.activityLevel != null) {
                    setState(() =>
                        _selectedActivityLevel = state.profile.activityLevel!);
                  }

                  _showProfileConfirmationSheet(context, state.profile);
                }

                if (state is ProfileDataExtractionFailed) {
                  if (!mounted) return; // Check if widget is still mounted

                  setState(() => _isExtracting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Could not extract profile data')),
                  );
                }

                // Handle sync state changes
                if (state is HealthDataSynced) {
                  // Use direct constants for sync status comparison
                  const syncStatusSuccess = SyncStatus.success;
                  const syncStatusFailure = SyncStatus.failure;

                  // Get the state's syncStatus
                  final syncStatus = state.syncStatus;

                  // Check if it's a success state
                  if (syncStatus == syncStatusSuccess &&
                      !_backgroundSyncStarted) {
                    // If sync was successful and we're not in background mode
                    if (!mounted) return; // Check if widget is still mounted

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health data synchronized successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Close progress dialog if it's showing
                    if (_isSyncing && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }

                    setState(() {
                      _isSyncing = false;
                    });

                    // Navigate to token screen
                    _navigateToTokenScreen();
                  } else if (syncStatus == syncStatusFailure &&
                      !_backgroundSyncStarted) {
                    // Only show error if we're not in background mode
                    if (!mounted) return; // Check if widget is still mounted

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Sync failed: ${state.errorMessage ?? "Unknown error"}'),
                        backgroundColor: Colors.red,
                      ),
                    );

                    // Close progress dialog if it's showing
                    if (_isSyncing && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }

                    setState(() {
                      _isSyncing = false;
                    });
                  }
                } else if (state is HealthLoading && !_isLoading) {
                  if (mounted) setState(() => _isLoading = true);
                } else if (state is! HealthLoading &&
                    _isLoading &&
                    mounted &&
                    !(context.read<AuthBloc>().state is AuthLoading)) {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        // Use context.watch<UserManager>() to observe profile changes
                        final userManager = context.watch<UserManager>();
                        final userProfile = userManager.userProfile;

                        // Set form field values directly from userManager.userProfile
                        if (userProfile != null && !_isExtracting) {
                          // This ensures form population happens after the build cycle
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _populateFormFromUserProfile(userProfile);
                            }
                          });
                        }

                        return Stepper(
                          currentStep: _currentStep,
                          onStepContinue: _isLoading ? null : _nextStep,
                          onStepCancel: _isLoading ? null : _previousStep,
                          controlsBuilder: (context, controls) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : controls.onStepContinue,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: OseerColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                      child: _isLoading && _currentStep == 1
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ))
                                          : Text(
                                              _currentStep == 1
                                                  ? 'Save & Continue'
                                                  : 'Continue',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white),
                                            ),
                                    ),
                                  ),
                                  if (_currentStep > 0) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : controls.onStepCancel,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        child: const Text('Back'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                          steps: [
                            Step(
                              title: const Text('Basic Information'),
                              content: _buildBasicInfoStep(),
                              isActive: _currentStep >= 0,
                              state: _currentStep > 0
                                  ? StepState.complete
                                  : StepState.indexed,
                            ),
                            Step(
                              title: const Text('Health Information'),
                              content: _buildHealthInfoStep(),
                              isActive: _currentStep >= 1,
                              state: _currentStep > 1
                                  ? StepState.complete
                                  : StepState.indexed,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Populate form from UserManager profile data
  void _populateFormFromUserProfile(UserProfile profile) {
    if (_nameController.text.isEmpty && profile.name.isNotEmpty) {
      _nameController.text = profile.name;
    }
    if (_emailController.text.isEmpty && profile.email.isNotEmpty) {
      _emailController.text = profile.email;
    }
    if (_phoneController.text.isEmpty &&
        profile.phone != null &&
        profile.phone!.isNotEmpty) {
      _phoneController.text = profile.phone!;
    }
    if (_ageController.text.isEmpty && profile.age != null) {
      _ageController.text = profile.age.toString();
    }
    if (_heightController.text.isEmpty && profile.height != null) {
      _heightController.text = profile.height.toString();
    }
    if (_weightController.text.isEmpty && profile.weight != null) {
      _weightController.text = profile.weight.toString();
    }
    if (_selectedGender.isEmpty &&
        profile.gender != null &&
        profile.gender!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedGender = profile.gender!;
        });
      }
    }
    if (_selectedActivityLevel.isEmpty &&
        profile.activityLevel != null &&
        profile.activityLevel!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedActivityLevel = profile.activityLevel!;
        });
      }
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_healthPermissionsGranted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OseerColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: OseerColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Health permissions not granted',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'We can\'t pre-fill your information without permissions.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _requestHealthPermissions,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Grant permissions'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OseerColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: OseerColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isExtracting
                            ? 'Fetching your health data...'
                            : 'Health permissions granted',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (_isExtracting)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            OseerColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy Note:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your personal information is kept private and secure. We use it only to provide personalized Wellness insights and to connect with the Oseer web platform.',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthInfoStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OseerColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: OseerColors.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'This information helps us personalize your wellness insights and recommendations.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
              hintText: 'Optional',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
              hintText: 'Optional',
            ),
            value: _selectedGender.isEmpty ? null : _selectedGender,
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
              DropdownMenuItem(
                  value: 'Prefer not to say', child: Text('Prefer not to say')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedGender = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.height),
              hintText: 'Optional',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center),
              hintText: 'Optional',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Activity Level',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_run),
              hintText: 'Optional',
            ),
            value:
                _selectedActivityLevel.isEmpty ? null : _selectedActivityLevel,
            items: const [
              DropdownMenuItem(
                  value: 'Sedentary',
                  child: Text('Sedentary (little to no exercise)')),
              DropdownMenuItem(
                  value: 'Light',
                  child: Text('Light (exercise 1-3 days/week)')),
              DropdownMenuItem(
                  value: 'Moderate',
                  child: Text('Moderate (exercise 3-5 days/week)')),
              DropdownMenuItem(
                  value: 'Active',
                  child: Text('Active (exercise 6-7 days/week)')),
              DropdownMenuItem(
                  value: 'Very Active',
                  child: Text('Very Active (heavy exercise/physical job)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedActivityLevel = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why We Ask For This Info:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                SizedBox(height: 8),
                Text(
                  'Your age, height, weight, and activity level help us provide more accurate wellness insights and personalized recommendations for your health journey.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show profile confirmation sheet with extracted data
  void _showProfileConfirmationSheet(
      BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileConfirmationSheet(
        profile: profile,
        onConfirm: () async {
          Navigator.pop(context);
          _saveProfile(confirmedProfile: profile);
        },
        onEdit: () => Navigator.pop(context),
      ),
    );
  }

  // Enhanced save profile for onboarding flow
  Future<void> _saveProfile({UserProfile? confirmedProfile}) async {
    UserProfile? profileToSave = confirmedProfile;

    if (profileToSave == null) {
      bool isValid = false;
      if (_currentStep == 0) {
        isValid = _validateBasicInfo();
      } else if (_currentStep == 1) {
        // Form key is for basic info, but we should validate all fields are reasonable
        isValid = _formKey.currentState?.validate() ?? true;
      }
      if (!isValid) return;

      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();

        // Get userId from AuthBloc state (should be available during onboarding)
        String userId = '';
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthOnboarding) {
          userId = authState.user.id;
        } else if (authState is AuthAuthenticated) {
          userId = authState.user.id;
        } else {
          // Fallback to stored user ID or generate new one
          userId =
              prefs.getString(OseerConstants.keyUserId) ?? const Uuid().v4();
        }

        int? age = _ageController.text.trim().isNotEmpty
            ? int.tryParse(_ageController.text.trim())
            : null;
        double? height = _heightController.text.trim().isNotEmpty
            ? double.tryParse(_heightController.text.trim())
            : null;
        double? weight = _weightController.text.trim().isNotEmpty
            ? double.tryParse(_weightController.text.trim())
            : null;

        profileToSave = UserProfile(
          userId: userId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          age: age,
          gender: _selectedGender.isEmpty ? null : _selectedGender,
          height: height,
          weight: weight,
          activityLevel:
              _selectedActivityLevel.isEmpty ? null : _selectedActivityLevel,
        );
      } catch (e) {
        OseerLogger.error('Error preparing profile for saving', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error preparing profile data: ${e.toString()}')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    if (profileToSave != null) {
      try {
        final userManager = context.read<UserManager>();
        await userManager.saveUserProfileLocally(profileToSave);
        OseerLogger.info('Profile saved successfully locally via UserManager.');

        final prefs = await SharedPreferences.getInstance();

        // Save core profile data to SharedPreferences
        await prefs.setString(OseerConstants.keyUserName, profileToSave.name);
        await prefs.setString(OseerConstants.keyUserEmail, profileToSave.email);
        await prefs.setString(OseerConstants.keyUserId, profileToSave.userId);

        // Save optional profile data
        if (profileToSave.phone != null) {
          await prefs.setString(
              OseerConstants.keyUserPhone, profileToSave.phone!);
        }
        if (profileToSave.age != null) {
          await prefs.setInt(OseerConstants.keyUserAge, profileToSave.age!);
        }
        if (profileToSave.gender != null) {
          await prefs.setString(
              OseerConstants.keyUserGender, profileToSave.gender!);
        }
        if (profileToSave.height != null) {
          await prefs.setDouble(
              OseerConstants.keyUserHeight, profileToSave.height!);
        }
        if (profileToSave.weight != null) {
          await prefs.setDouble(
              OseerConstants.keyUserWeight, profileToSave.weight!);
        }
        if (profileToSave.activityLevel != null) {
          await prefs.setString(OseerConstants.keyUserActivityLevel,
              profileToSave.activityLevel!);
        }

        // Mark profile as complete
        await prefs.setBool(OseerConstants.keyProfileComplete, true);
        await prefs.setBool(OseerConstants.keyOnboardingComplete, true);

        OseerLogger.info(
            "OnboardingScreen: Profile completed - showing sync dialog.");

        // Always show sync dialog for new users
        _showSyncProgressDialog(context);

        // Start health data sync
        context.read<HealthBloc>().add(const SyncHealthDataEvent());
      } catch (e, s) {
        OseerLogger.error('Error saving profile', e, s);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving profile: ${e.toString()}')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _navigateToTokenScreen() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TokenScreen(),
        ),
      );
    }
  }
}
