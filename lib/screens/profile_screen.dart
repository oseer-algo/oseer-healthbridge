// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../managers/user_manager.dart';
import '../models/user_profile.dart';
import '../services/logger_service.dart';
import '../services/toast_service.dart';
import '../utils/constants.dart';
import '../widgets/profile_confirmation_sheet.dart';
import '../widgets/sync_loading_dialog.dart';
import 'token_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOnboarding;
  final UserProfile? profileForConfirmation;

  const ProfileScreen({
    Key? key,
    this.isOnboarding = false,
    this.profileForConfirmation,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedGender = '';
  String _selectedActivityLevel = '';

  bool _isLoading = false;
  bool _isExtracting = false;
  UserProfile? _loadedProfile;
  bool _hasAutoPopulated = false;
  bool _isProfileDataLoaded = false;
  String? _errorMessage;
  bool _autoExtractFailed = false;
  bool _heightExtracted = false;
  bool _weightExtracted = false;
  bool _activityLevelExtracted = false;
  UserManager? _userManagerRef;

  bool get isAndroid => Platform.isAndroid;

  bool get _isMandatoryProfileCompleted {
    if (_loadedProfile != null && _loadedProfile!.isComplete()) {
      return true;
    }
    final hasBasicInfo = _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _emailController.text.contains('@');
    if (!hasBasicInfo) {
      return false;
    }
    if (isAndroid && widget.isOnboarding) {
      final hasAllRequiredFields = _ageController.text.trim().isNotEmpty &&
          _heightController.text.trim().isNotEmpty &&
          _weightController.text.trim().isNotEmpty &&
          _selectedGender.isNotEmpty &&
          _selectedActivityLevel.isNotEmpty;
      return hasAllRequiredFields;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileDataSynchronously();
    if (!isAndroid &&
        widget.isOnboarding &&
        widget.profileForConfirmation == null) {
      _attemptProfileExtraction();
    }
  }

  @override
  void dispose() {
    try {
      if (_userManagerRef != null) {
        _userManagerRef!.removeListener(_onUserManagerUpdate);
        _userManagerRef = null;
      }
    } catch (e) {
      OseerLogger.debug(
          'Error removing UserManager listener during disposal: $e');
    }
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _loadProfileDataSynchronously() {
    setState(() => _isLoading = true);
    try {
      if (widget.profileForConfirmation != null) {
        _populateFormWithProfileSync(widget.profileForConfirmation!);
        _hasAutoPopulated = true;
        _isProfileDataLoaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showProfileLoadedFeedback('Profile loaded from server');
        });
        setState(() => _isLoading = false);
        _setupUserManagerListener();
        return;
      }
      if (!widget.isOnboarding) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthProfileConfirmationRequired &&
            authState.userProfile != null) {
          _populateFormWithProfileSync(authState.userProfile!);
          _hasAutoPopulated = true;
          _isProfileDataLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              _showProfileLoadedFeedback('Profile loaded from server');
          });
          setState(() => _isLoading = false);
          _setupUserManagerListener();
          return;
        }
      }
      final userManager = context.read<UserManager>();
      final existingProfile = userManager.getUserProfileObject();
      if (existingProfile != null && !_hasAutoPopulated) {
        _populateFormWithProfileSync(existingProfile);
        _hasAutoPopulated = true;
        _isProfileDataLoaded = true;
        if (existingProfile.isComplete() && !widget.isOnboarding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              _showProfileLoadedFeedback('Profile loaded from local storage');
          });
        }
        setState(() => _isLoading = false);
        _setupUserManagerListener();
        if (!existingProfile.isComplete() ||
            userManager.shouldSyncFromServer()) {
          _fetchFromServer(userManager);
        }
        return;
      }
      _fetchFromServer(userManager);
    } catch (e, stack) {
      OseerLogger.error('Error in synchronous profile data loading', e, stack);
      _showError('Failed to load profile data: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFromServer(UserManager userManager) async {
    try {
      await userManager.awaitProfileLoad();
      final fetchSuccess = await userManager.fetchUserProfileFromServer();
      if (fetchSuccess) {
        final fetchedProfile = userManager.getUserProfileObject();
        if (fetchedProfile != null && !_hasAutoPopulated) {
          _populateFormWithProfileSync(fetchedProfile);
          _hasAutoPopulated = true;
          _isProfileDataLoaded = true;
          if (mounted) _showProfileLoadedFeedback('Profile loaded from server');
        }
      } else {
        if (!widget.isOnboarding)
          _showError(
              'Could not load profile from server. Please check your connection.');
      }
      setState(() {
        _isLoading = false;
        _isProfileDataLoaded = true;
      });
      _setupUserManagerListener();
    } catch (e, stack) {
      OseerLogger.error('Error fetching profile from server', e, stack);
      _showError('Failed to load profile from server: ${e.toString()}');
      setState(() {
        _isLoading = false;
        _isProfileDataLoaded = true;
      });
      _setupUserManagerListener();
    }
  }

  void _setupUserManagerListener() {
    try {
      if (mounted) {
        _userManagerRef = context.read<UserManager>();
        _userManagerRef!.addListener(_onUserManagerUpdate);
      }
    } catch (e) {
      OseerLogger.debug('Error setting up UserManager listener: $e');
    }
  }

  void _onUserManagerUpdate() {
    if (!mounted || _userManagerRef == null) return;
    try {
      final profile = _userManagerRef!.getUserProfileObject();
      final hasChanged = _userManagerRef!.hasProfileChanged;
      if (profile != null && hasChanged && !_hasAutoPopulated) {
        _populateFormWithProfileSync(profile);
        _hasAutoPopulated = true;
        _isProfileDataLoaded = true;
        _showProfileLoadedFeedback('Profile updated from server');
      }
    } catch (e) {
      OseerLogger.debug('Error in UserManager update handler: $e');
    }
  }

  void _populateFormWithProfileSync(UserProfile profile) {
    setState(() {
      _loadedProfile = profile;
      if (profile.name.isNotEmpty) {
        _nameController.text = profile.name;
      }
      if (profile.email.isNotEmpty) {
        _emailController.text = profile.email;
      }
      if (profile.phone != null && profile.phone!.isNotEmpty) {
        _phoneController.text = profile.phone!;
      }
      if (profile.age != null && profile.age! > 0) {
        _ageController.text = profile.age.toString();
      }
      if (profile.height != null && profile.height! > 0) {
        _heightController.text = profile.height.toString();
        _heightExtracted = !isAndroid;
      }
      if (profile.weight != null && profile.weight! > 0) {
        _weightController.text = profile.weight.toString();
        _weightExtracted = !isAndroid;
      }
      if (profile.gender != null && profile.gender!.isNotEmpty) {
        _selectedGender = profile.gender!;
      }
      if (profile.activityLevel != null && profile.activityLevel!.isNotEmpty) {
        _selectedActivityLevel = profile.activityLevel!;
        _activityLevelExtracted = !isAndroid;
      }
    });
  }

  void _showProfileLoadedFeedback(String message) {
    if (mounted) {
      ToastService.success(message);
    }
  }

  Future<void> _attemptProfileExtraction() async {
    if (_isExtracting || isAndroid) return;
    setState(() {
      _isExtracting = true;
      _autoExtractFailed = false;
    });
    try {
      context.read<HealthBloc>().add(const ExtractProfileDataEvent());
    } catch (e, stack) {
      OseerLogger.error('Error dispatching ExtractProfileDataEvent', e, stack);
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _autoExtractFailed = true;
          _errorMessage = 'Failed to extract profile data: ${e.toString()}';
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
      ToastService.error(message);
    }
  }

  void _clearError() {
    if (mounted && _errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const TokenScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: OseerColors.background,
        body: BlocListener<HealthBloc, HealthState>(
          listener: _handleHealthStateChanges,
          child: BlocBuilder<HealthBloc, HealthState>(
            builder: (context, healthState) {
              final bool isCurrentlyLoading =
                  (healthState is HealthLoading) || _isLoading;

              return Builder(
                builder: (context) {
                  final userManager = context.watch<UserManager>();
                  final latestProfile = userManager.userProfile;

                  if (latestProfile != null && !_isExtracting) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _populateFormWithProfileReactive(latestProfile);
                      }
                    });
                  }

                  return CustomScrollView(
                    slivers: [
                      _buildAppBar(),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Status indicators
                                if (_hasAutoPopulated && !widget.isOnboarding)
                                  _buildStatusCard(
                                    icon: Icons.check_circle,
                                    color: OseerColors.success,
                                    message:
                                        'Profile information loaded from your account',
                                  ),
                                if (_hasAutoPopulated && !widget.isOnboarding)
                                  const SizedBox(height: 16),

                                if (_errorMessage != null)
                                  _buildStatusCard(
                                    icon: Icons.error_outline,
                                    color: OseerColors.error,
                                    message: _errorMessage!,
                                    onClose: _clearError,
                                  ),
                                if (_errorMessage != null)
                                  const SizedBox(height: 16),

                                // Basic Information Section
                                _buildSectionHeader(
                                  'Basic Information',
                                  Icons.person,
                                  OseerColors.primary,
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name *',
                                  icon: Icons.person,
                                  validator: (value) {
                                    if (_loadedProfile != null &&
                                        value == _loadedProfile!.name &&
                                        _loadedProfile!.name.isNotEmpty)
                                      return null;
                                    if (value == null || value.trim().isEmpty)
                                      return 'Please enter your name';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email *',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (_loadedProfile != null &&
                                        value == _loadedProfile!.email &&
                                        _loadedProfile!.email.isNotEmpty)
                                      return null;
                                    if (value == null || value.trim().isEmpty)
                                      return 'Please enter your email';
                                    if (!value.contains('@') ||
                                        !value.contains('.'))
                                      return 'Please enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone (Optional)',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                ),

                                const SizedBox(height: 32),

                                // Health Information Section
                                _buildSectionHeader(
                                  'Health Information',
                                  Icons.favorite,
                                  OseerColors.error,
                                  subtitle: !isAndroid
                                      ? 'Some fields may be auto-filled from Health app'
                                      : null,
                                ),
                                const SizedBox(height: 8),

                                if (isAndroid && widget.isOnboarding)
                                  _buildInfoCard(
                                    'All health information is required for Android users',
                                    Icons.info_outline,
                                    OseerColors.info,
                                  ),

                                const SizedBox(height: 20),

                                // Age field
                                _buildTextField(
                                  controller: _ageController,
                                  label: isAndroid && widget.isOnboarding
                                      ? 'Age *'
                                      : 'Age',
                                  icon: Icons.cake,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (value) {
                                    if (_loadedProfile?.age != null &&
                                        value?.trim() ==
                                            _loadedProfile!.age.toString())
                                      return null;
                                    if (isAndroid &&
                                        widget.isOnboarding &&
                                        (value == null || value.trim().isEmpty))
                                      return 'Age is required';
                                    if (value != null &&
                                        value.trim().isNotEmpty) {
                                      final age = int.tryParse(value.trim());
                                      if (age == null || age < 1 || age > 120)
                                        return 'Please enter a valid age';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Gender dropdown
                                _buildDropdown(
                                  label: isAndroid && widget.isOnboarding
                                      ? 'Gender *'
                                      : 'Gender',
                                  icon: Icons.person_outline,
                                  value: _selectedGender.isEmpty
                                      ? null
                                      : _selectedGender,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Male', child: Text('Male')),
                                    DropdownMenuItem(
                                        value: 'Female', child: Text('Female')),
                                    DropdownMenuItem(
                                        value: 'Non-binary',
                                        child: Text('Non-binary')),
                                    DropdownMenuItem(
                                        value: 'Prefer not to say',
                                        child: Text('Prefer not to say'))
                                  ],
                                  onChanged: (value) {
                                    if (value != null)
                                      setState(() => _selectedGender = value);
                                  },
                                  validator: (value) {
                                    if (_loadedProfile?.gender != null &&
                                        value == _loadedProfile!.gender)
                                      return null;
                                    if (isAndroid &&
                                        widget.isOnboarding &&
                                        (value == null || value.isEmpty))
                                      return 'Gender is required';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Height and Weight in row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _heightController,
                                        label: isAndroid && widget.isOnboarding
                                            ? 'Height (cm) *'
                                            : 'Height (cm)',
                                        icon: Icons.height,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*$'))
                                        ],
                                        validator: (value) {
                                          if (_loadedProfile?.height != null &&
                                              value?.trim() ==
                                                  _loadedProfile!.height
                                                      .toString()) return null;
                                          if (isAndroid &&
                                              widget.isOnboarding &&
                                              (value == null ||
                                                  value.trim().isEmpty))
                                            return 'Required';
                                          if (value != null &&
                                              value.trim().isNotEmpty) {
                                            final height =
                                                double.tryParse(value.trim());
                                            if (height == null ||
                                                height < 50 ||
                                                height > 250) return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _weightController,
                                        label: isAndroid && widget.isOnboarding
                                            ? 'Weight (kg) *'
                                            : 'Weight (kg)',
                                        icon: Icons.fitness_center,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*$'))
                                        ],
                                        validator: (value) {
                                          if (_loadedProfile?.weight != null &&
                                              value?.trim() ==
                                                  _loadedProfile!.weight
                                                      .toString()) return null;
                                          if (isAndroid &&
                                              widget.isOnboarding &&
                                              (value == null ||
                                                  value.trim().isEmpty))
                                            return 'Required';
                                          if (value != null &&
                                              value.trim().isNotEmpty) {
                                            final weight =
                                                double.tryParse(value.trim());
                                            if (weight == null ||
                                                weight < 20 ||
                                                weight > 500) return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Activity Level
                                _buildDropdown(
                                  label: isAndroid && widget.isOnboarding
                                      ? 'Activity Level *'
                                      : 'Activity Level',
                                  icon: Icons.directions_run,
                                  value: _selectedActivityLevel.isEmpty
                                      ? null
                                      : _selectedActivityLevel,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Sedentary',
                                        child: Text('Sedentary')),
                                    DropdownMenuItem(
                                        value: 'Light', child: Text('Light')),
                                    DropdownMenuItem(
                                        value: 'Moderate',
                                        child: Text('Moderate')),
                                    DropdownMenuItem(
                                        value: 'Active', child: Text('Active')),
                                    DropdownMenuItem(
                                        value: 'Very Active',
                                        child: Text('Very Active'))
                                  ],
                                  onChanged: (value) {
                                    if (value != null)
                                      setState(
                                          () => _selectedActivityLevel = value);
                                  },
                                  validator: (value) {
                                    if (_loadedProfile?.activityLevel != null &&
                                        value == _loadedProfile!.activityLevel)
                                      return null;
                                    if (isAndroid &&
                                        widget.isOnboarding &&
                                        (value == null || value.isEmpty))
                                      return 'Activity Level is required';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 32),

                                // Privacy note
                                _buildPrivacyNote(),

                                const Spacer(),
                                const SizedBox(height: 24),

                                // Save button
                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isCurrentlyLoading
                                        ? null
                                        : _saveProfile,
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
                                    child: isCurrentlyLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            widget.isOnboarding
                                                ? 'Continue'
                                                : 'Confirm & Continue',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ).animate().fadeIn(duration: 600.ms).scale(
                                      begin: const Offset(0.98, 0.98),
                                      end: const Offset(1.0, 1.0),
                                      duration: 300.ms,
                                      curve: Curves.easeOut,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                OseerColors.primary,
                OseerColors.primaryLight,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      duration: 4000.ms,
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.1, 1.1),
                    )
                    .then()
                    .scale(
                      duration: 4000.ms,
                      begin: const Offset(1.1, 1.1),
                      end: const Offset(0.9, 0.9),
                    ),
              ),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white,
                        ),
                      ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                          ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: Text(
                          widget.isOnboarding
                              ? 'Your Wellness Profile'
                              : 'Confirm Your Profile',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color,
      {String? subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: OseerColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: OseerColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.error, width: 2),
        ),
        filled: true,
        fillColor: OseerColors.background,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OseerColors.error, width: 2),
        ),
        filled: true,
        fillColor: OseerColors.background,
      ),
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String message,
    VoidCallback? onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildInfoCard(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OseerColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OseerColors.border.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            size: 20,
            color: OseerColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy Note',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your personal information is kept private and secure. We use it only to provide personalized wellness insights.',
                  style: TextStyle(
                    fontSize: 12,
                    color: OseerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _populateFormWithProfileReactive(UserProfile profile) {
    bool hasUpdates = false;

    if (_nameController.text.isEmpty && profile.name.isNotEmpty) {
      _nameController.text = profile.name;
      hasUpdates = true;
    }
    if (_emailController.text.isEmpty && profile.email.isNotEmpty) {
      _emailController.text = profile.email;
      hasUpdates = true;
    }
    if (_phoneController.text.isEmpty &&
        profile.phone != null &&
        profile.phone!.isNotEmpty) {
      _phoneController.text = profile.phone!;
      hasUpdates = true;
    }
    if (_ageController.text.isEmpty && profile.age != null) {
      _ageController.text = profile.age.toString();
      hasUpdates = true;
    }
    if (_heightController.text.isEmpty && profile.height != null) {
      _heightController.text = profile.height.toString();
      hasUpdates = true;
    }
    if (_weightController.text.isEmpty && profile.weight != null) {
      _weightController.text = profile.weight.toString();
      hasUpdates = true;
    }
    if (_selectedGender.isEmpty &&
        profile.gender != null &&
        profile.gender!.isNotEmpty) {
      setState(() => _selectedGender = profile.gender!);
      hasUpdates = true;
    }
    if (_selectedActivityLevel.isEmpty &&
        profile.activityLevel != null &&
        profile.activityLevel!.isNotEmpty) {
      setState(() => _selectedActivityLevel = profile.activityLevel!);
      hasUpdates = true;
    }

    if (hasUpdates) {
      setState(() {
        _loadedProfile = profile;
        _hasAutoPopulated = true;
        _isProfileDataLoaded = true;
      });
    }
  }

  void _handleHealthStateChanges(BuildContext context, HealthState state) {
    if (state is HealthLoading) {
      if (!_isLoading) setState(() => _isLoading = true);
    } else if (_isLoading) {
      setState(() => _isLoading = false);
    }
    if (state is ProfileDataExtracted && !isAndroid) {
      setState(() {
        if (state.profile.height != null) {
          _heightController.text = state.profile.height.toString();
          _heightExtracted = true;
        }
        if (state.profile.weight != null) {
          _weightController.text = state.profile.weight.toString();
          _weightExtracted = true;
        }
        if (state.profile.activityLevel != null) {
          _selectedActivityLevel = state.profile.activityLevel!;
          _activityLevelExtracted = true;
        }
      });

      List<String> extractedItems = [];
      if (state.profile.height != null) extractedItems.add("height");
      if (state.profile.weight != null) extractedItems.add("weight");
      if (state.profile.activityLevel != null)
        extractedItems.add("activity level");

      if (extractedItems.isNotEmpty) {
        String message =
            "Successfully extracted ${extractedItems.join(', ')} from Health data.";
        ToastService.success(message);
      } else {
        ToastService.info(
            'No health metrics found. Please enter your information manually.');
      }

      if (widget.isOnboarding) {
        _showProfileConfirmationSheet(context, state.profile);
      }
    }

    if (state is ProfileDataExtractionFailed) {
      setState(() {
        _autoExtractFailed = true;
        _isExtracting = false;
      });
    }
    if (state is HealthError) {
      _showError(state.message);
      setState(() => _isLoading = false);
    }
    if (state is ProfileUpdated) {
      setState(() => _isLoading = false);
      if (widget.isOnboarding) {
        _completeOnboarding();
      } else {
        ToastService.success('Profile confirmed successfully!');
        _completeOnboarding();
      }
    }
  }

  void _showProfileConfirmationSheet(
      BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<HealthBloc>(context),
        child: ProfileConfirmationSheet(
          profile: profile,
          onConfirm: () {
            Navigator.pop(context);
            _saveProfile(confirmedProfile: profile);
          },
          onEdit: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    context.read<AuthBloc>().add(const AuthCompleteOnboardingEvent());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OseerConstants.keyOnboardingComplete, true);
    await prefs.setBool(OseerConstants.keyProfileComplete, true);
  }

  Future<void> _saveProfile({UserProfile? confirmedProfile}) async {
    if (confirmedProfile == null &&
        !(_formKey.currentState?.validate() ?? false)) {
      ToastService.warning('Please correct the errors before saving.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userManager = context.read<UserManager>();
      final currentUserId = userManager.userProfile?.userId;

      if (currentUserId == null || currentUserId.isEmpty) {
        ToastService.error('Error: User identifier missing. Cannot save.');
        setState(() => _isLoading = false);
        return;
      }

      final profileToSave = confirmedProfile ??
          UserProfile(
            userId: currentUserId,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            age: _ageController.text.trim().isNotEmpty
                ? int.tryParse(_ageController.text.trim())
                : null,
            gender: _selectedGender.isNotEmpty ? _selectedGender : null,
            height: _heightController.text.trim().isNotEmpty
                ? double.tryParse(_heightController.text.trim())
                : null,
            weight: _weightController.text.trim().isNotEmpty
                ? double.tryParse(_weightController.text.trim())
                : null,
            activityLevel: _selectedActivityLevel.isNotEmpty
                ? _selectedActivityLevel
                : null,
          );

      final bool success = await userManager.updateUserProfile(profileToSave);

      if (mounted) {
        if (success) {
          ToastService.success('Profile Saved!');
          if (widget.isOnboarding) {
            context.read<AuthBloc>().add(const AuthCompleteOnboardingEvent());
          } else {
            context.read<AuthBloc>().add(const AuthProfileConfirmedEvent());
          }
        } else {
          ToastService.error(userManager.errorMessage ??
              'Failed to save profile. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.error('An unexpected error occurred.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
