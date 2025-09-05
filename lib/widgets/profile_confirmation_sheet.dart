// lib/widgets/profile_confirmation_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;

import '../models/user_profile.dart';
import '../utils/constants.dart';

class ProfileConfirmationSheet extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const ProfileConfirmationSheet({
    Key? key,
    required this.profile,
    required this.onConfirm,
    required this.onEdit,
  }) : super(key: key);

  // Check if profile has all required fields for Android
  bool get hasRequiredFields {
    bool isAndroid = Platform.isAndroid;

    // For Android, all health fields are required
    if (isAndroid) {
      return profile.name.isNotEmpty &&
          profile.email.isNotEmpty &&
          profile.age != null &&
          profile.gender != null &&
          profile.height != null &&
          profile.weight != null &&
          profile.activityLevel != null;
    }

    // For iOS, just basic info is required
    return profile.name.isNotEmpty && profile.email.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    // If on Android and missing required fields, skip this sheet and go directly to edit
    if (Platform.isAndroid && !hasRequiredFields) {
      // Schedule the edit callback for the next frame to avoid build issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop(); // Close this sheet
        onEdit(); // Go to edit mode directly
      });

      // Return a placeholder while we're dismissing
      return Container();
    }

    return Container(
      height: screenHeight,
      width: screenWidth,
      alignment: Alignment.bottomCenter,
      child: Container(
        height: screenHeight * 0.95,
        width: screenWidth,
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: OseerColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Success icon with gradient
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OseerColors.success,
                            OseerColors.success.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: OseerColors.success.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut)
                        .fade(duration: 300.ms),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Profile Data Found!',
                      style: OseerTextStyles.h2.copyWith(
                        color: OseerColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      'We found your health data and pre-filled your profile',
                      style: OseerTextStyles.bodyRegular.copyWith(
                        color: OseerColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 300.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 32),

                    // Profile data cards
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OseerColors.primary.withOpacity(0.05),
                            OseerColors.primaryLight.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: OseerColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Basic info section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildDataRow(
                                    Icons.person, 'Name', profile.name, 400),
                                const SizedBox(height: 12),
                                _buildDataRow(
                                    Icons.email, 'Email', profile.email, 450),
                              ],
                            ),
                          ),

                          // Health info section (if available)
                          if (profile.age != null ||
                              profile.gender != null ||
                              profile.height != null ||
                              profile.weight != null ||
                              profile.activityLevel != null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (profile.age != null)
                                    _buildDataRow(Icons.cake, 'Age',
                                        '${profile.age} years', 500),
                                  if (profile.age != null)
                                    const SizedBox(height: 12),
                                  if (profile.gender != null)
                                    _buildDataRow(Icons.person_outline,
                                        'Gender', profile.gender!, 550),
                                  if (profile.gender != null)
                                    const SizedBox(height: 12),
                                  if (profile.height != null)
                                    _buildDataRow(Icons.height, 'Height',
                                        '${profile.height} cm', 600),
                                  if (profile.height != null)
                                    const SizedBox(height: 12),
                                  if (profile.weight != null)
                                    _buildDataRow(Icons.fitness_center,
                                        'Weight', '${profile.weight} kg', 650),
                                  if (profile.weight != null)
                                    const SizedBox(height: 12),
                                  if (profile.activityLevel != null)
                                    _buildDataRow(
                                        Icons.directions_run,
                                        'Activity',
                                        profile.activityLevel!,
                                        700),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1, 1)),

                    const SizedBox(height: 40),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OseerColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Looks Good, Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 800.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 12),

                    // Edit button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Edit Information',
                        style: TextStyle(
                          color: OseerColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 900.ms),
                  ],
                ),
              ),
            ),
          ],
        )
            .animate()
            .slideY(
              begin: 1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutQuint,
            )
            .fade(duration: 200.ms),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value, int delay) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: OseerColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: OseerColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: OseerTextStyles.caption.copyWith(
                  color: OseerColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: OseerTextStyles.bodyBold.copyWith(
                  color: OseerColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay))
        .slideX(begin: -0.1, end: 0);
  }
}
