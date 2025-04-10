import 'package:flutter/material.dart';

/// Extension methods for BuildContext
extension BuildContextExtensions on BuildContext {
  /// Get the theme
  ThemeData get theme => Theme.of(this);
  
  /// Get the color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  /// Get the text theme
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  /// Get the media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  
  /// Get screen size
  Size get screenSize => mediaQuery.size;
  
  /// Get screen width
  double get screenWidth => screenSize.width;
  
  /// Get screen height
  double get screenHeight => screenSize.height;
  
  /// Check if the device is in dark mode
  bool get isDarkMode => mediaQuery.platformBrightness == Brightness.dark;
  
  /// Show a snackbar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
          ? Theme.of(this).colorScheme.error 
          : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension methods for strings
extension StringExtensions on String {
  /// Capitalize the first letter of the string
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
  
  /// Truncate the string to a maximum length with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}
