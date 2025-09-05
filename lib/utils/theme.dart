// lib/utils/theme.dart

import 'package:flutter/material.dart';
import 'constants.dart';

/// App theme configuration
class AppTheme {
  /// Get the main app theme
  static ThemeData getTheme() {
    return ThemeData(
      primaryColor: OseerColors.primary,
      primaryColorLight: OseerColors.primaryLight,
      primaryColorDark: OseerColors.primaryDark,
      colorScheme: ColorScheme.light(
        primary: OseerColors.primary,
        secondary: OseerColors.secondary,
        error: OseerColors.error,
        background: OseerColors.background,
        surface: OseerColors.surface,
      ),
      scaffoldBackgroundColor: OseerColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: OseerColors.textPrimary),
        titleTextStyle: TextStyle(
          color: OseerColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Geist',
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OseerSpacing.cardRadius),
        ),
      ),
      textTheme: TextTheme(
        // Headings
        headlineLarge: OseerTextStyles.h1,
        headlineMedium: OseerTextStyles.h2,
        headlineSmall: OseerTextStyles.h3,

        // Body text
        bodyLarge: OseerTextStyles.bodyRegular,
        bodyMedium: OseerTextStyles.bodyRegular,
        bodySmall: OseerTextStyles.bodySmall,

        // Other text
        labelLarge: OseerTextStyles.buttonText,
        labelMedium: OseerTextStyles.bodySmall,
        labelSmall: OseerTextStyles.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OseerSpacing.inputRadius),
          borderSide: const BorderSide(color: OseerColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OseerSpacing.inputRadius),
          borderSide: const BorderSide(color: OseerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OseerSpacing.inputRadius),
          borderSide: BorderSide(color: OseerColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OseerSpacing.inputRadius),
          borderSide: BorderSide(color: OseerColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OseerColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OseerSpacing.buttonRadius),
          ),
          textStyle: OseerTextStyles.buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OseerColors.primary,
          side: BorderSide(color: OseerColors.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OseerSpacing.buttonRadius),
          ),
          textStyle: OseerTextStyles.buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OseerColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: OseerColors.divider,
        thickness: 1,
        space: 1,
      ),
      fontFamily: 'Inter',
    );
  }
}
