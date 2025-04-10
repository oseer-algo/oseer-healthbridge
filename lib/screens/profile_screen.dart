// File path: lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../blocs/health/health_state.dart' as health_state;
import '../models/user_profile.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../widgets/profile_confirmation_sheet.dart';
import '../widgets/wellness_permissions_sheet.dart';
import 'token_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOnboarding;

  const ProfileScreen({
    Key? key,
    this.isOnboarding = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _attemptProfileExtraction();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Load existing profile data
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString(OseerConstants.keyUserName);
    final email = prefs.getString(OseerConstants.keyUserEmail);

    if (name != null && name.isNotEmpty) {
      setState(() {
        _nameController.text = name;
      });
    }

    if (email != null && email.isNotEmpty) {
      setState(() {
        _emailController.text = email;
      });
    }
  }

  /// Attempt to extract profile data from health platform
  Future<void> _attemptProfileExtraction() async {
    setState(() {
      _isExtracting = true;
    });

    try {
      // Dispatch event to extract profile data
      context.read<HealthBloc>().add(
            const ExtractProfileDataEvent(),
          );
    } catch (e) {
      OseerLogger.error('Error extracting profile data', e);
    } finally {
      setState(() {
        _isExtracting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: OseerColors.primary,
      ),
      body: BlocConsumer<HealthBloc, health_state.HealthState>(
        listener: (context, state) {
          if (state is health_state.ProfileDataExtracted) {
            // Populate the form with extracted data
            setState(() {
              _nameController.text = state.profile.name;
              _emailController.text = state.profile.email;
            });

            // Show confirmation sheet
            _showProfileConfirmationSheet(context, state.profile);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Profile icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: OseerColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: OseerColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title and description
                  const Text(
                    'Your Wellness Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please provide your information to personalize your Wellness insights.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Extraction status
                  if (_isExtracting)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OseerColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  OseerColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Looking for your health data to pre-fill this form...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isExtracting) const SizedBox(height: 24),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        // Simple email validation
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Privacy note
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
                  const SizedBox(height: 32),

                  // Continue button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OseerColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
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
          // Close the sheet
          Navigator.pop(context);

          // Proceed to health permissions
          await _showHealthPermissionsSheet(context);
        },
        onEdit: () {
          // Close the sheet
          Navigator.pop(context);

          // Form is already populated with extracted data
          // User can edit as needed
        },
      ),
    );
  }

  /// Show health permissions sheet
  Future<void> _showHealthPermissionsSheet(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WellnessPermissionsSheet(
        onGranted: () {
          // Close the sheet
          Navigator.pop(context);

          // Navigate to token screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TokenScreen(),
            ),
          );
        },
        onSkip: () {
          // Close the sheet
          Navigator.pop(context);

          // Navigate to token screen anyway
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TokenScreen(),
            ),
          );
        },
      ),
    );
  }

  // Save profile and proceed to token generation
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final prefs = await SharedPreferences.getInstance();

        // Save user profile data
        final name = _nameController.text.trim();
        final email = _emailController.text.trim();

        await prefs.setString(OseerConstants.keyUserName, name);
        if (email.isNotEmpty) {
          await prefs.setString(OseerConstants.keyUserEmail, email);
        }

        OseerLogger.info('Profile saved: Name=$name, Email=$email');

        // Create profile object
        final profile = context.read<HealthBloc>().state
                is health_state.ProfileDataExtracted
            ? (context.read<HealthBloc>().state
                    as health_state.ProfileDataExtracted)
                .profile
                .copyWith(name: name, email: email)
            : UserProfile(name: name, email: email);

        // Show confirmation sheet
        if (mounted) {
          _showProfileConfirmationSheet(context, profile);
        }
      } catch (e) {
        OseerLogger.error('Error saving profile', e);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error saving profile')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Helper method to proceed to the next step after profile confirmation
  void _proceedToNextStep() async {
    // Proceed to health permissions
    await _showHealthPermissionsSheet(context);
  }
}
