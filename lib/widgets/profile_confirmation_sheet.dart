// File path: lib/widgets/profile_confirmation_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/health/health_bloc.dart';
import '../blocs/health/health_event.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Bottom sheet that shows extracted profile data and asks for confirmation
class ProfileConfirmationSheet extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const ProfileConfirmationSheet({
    Key? key,
    required this.profile,
    required this.onConfirm,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<ProfileConfirmationSheet> createState() =>
      _ProfileConfirmationSheetState();
}

class _ProfileConfirmationSheetState extends State<ProfileConfirmationSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSheetHeader(),
            const SizedBox(height: 16),
            _buildProfileData(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Gray drag handle at top
        Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Icon with text
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: OseerColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline,
            color: OseerColors.primary,
            size: 30,
          ),
        ).animate().scale(
              duration: 300.ms,
              curve: Curves.easeOut,
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
            ),

        const SizedBox(height: 16),
        Text(
          'Confirm Your Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve extracted this information from your wellness data. Is it correct?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildProfileData() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileRow('Name', widget.profile.name),
          _buildProfileRow('Email', widget.profile.email),
          if (widget.profile.age != null)
            _buildProfileRow('Age', '${widget.profile.age} years'),
          if (widget.profile.gender != null)
            _buildProfileRow('Gender', widget.profile.gender!),
          if (widget.profile.height != null)
            _buildProfileRow('Height', '${widget.profile.height} cm'),
          if (widget.profile.weight != null)
            _buildProfileRow('Weight', '${widget.profile.weight} kg'),
          if (widget.profile.activityLevel != null)
            _buildProfileRow('Activity Level', widget.profile.activityLevel!),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slide(
          begin: const Offset(0, 0.1),
          end: const Offset(0, 0),
          duration: 400.ms,
          delay: 200.ms,
        );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  try {
                    setState(() {
                      _isLoading = true;
                    });

                    // Provide haptic feedback
                    HapticFeedback.mediumImpact();

                    // Dispatch profile update event
                    if (context.mounted) {
                      context.read<HealthBloc>().add(
                            ProfileUpdatedEvent(profile: widget.profile),
                          );
                    }

                    // Short delay for feedback
                    await Future.delayed(const Duration(milliseconds: 300));

                    // Call confirm callback
                    widget.onConfirm();
                  } catch (e) {
                    // Handle error
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: OseerColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Looks Good, Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : widget.onEdit,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Edit Information',
            style: TextStyle(
              color: OseerColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
