// lib/utils/extensions.dart
import 'package:flutter/material.dart';

/// Extension methods for String
extension StringExtensions on String {
  /// Returns null if string is empty, otherwise returns the string
  String? nullIfEmpty() {
    return isEmpty ? null : this;
  }

  /// Truncates string to specified length with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return substring(0, maxLength) + '...';
  }

  /// Returns capitalized string (first letter uppercase)
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

/// Extension methods for DateTime
extension DateTimeExtensions on DateTime {
  /// Converts to ISO8601 string
  String toISOString() {
    return toUtc().toIso8601String();
  }

  /// Returns true if date is today
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if date is yesterday
  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Returns just the date part (time set to midnight)
  DateTime dateOnly() {
    return DateTime(year, month, day);
  }
}

/// Extension methods for BuildContext
extension BuildContextExtensions on BuildContext {
  /// Returns screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Returns screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Returns true if dark mode is enabled
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Returns the theme's primary color
  Color get primaryColor => Theme.of(this).primaryColor;

  /// Returns the theme's error color
  Color get errorColor => Theme.of(this).colorScheme.error;

  /// Returns text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Dismisses the keyboard
  void dismissKeyboard() => FocusScope.of(this).unfocus();
}

/// Extension methods for num
extension NumExtensions on num {
  /// Clamps value between min and max
  num clamp(num min, num max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  /// Returns value as pixels (for responsive design)
  double get px => toDouble();

  /// Returns value as percentage of screen width
  double screenWidthPercent(BuildContext context) =>
      MediaQuery.of(context).size.width * (this / 100);

  /// Returns value as percentage of screen height
  double screenHeightPercent(BuildContext context) =>
      MediaQuery.of(context).size.height * (this / 100);
}

/// Extension methods for List
extension ListExtensions<T> on List<T> {
  /// Returns the first element that matches the condition, or null
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// Returns a new list with duplicates removed
  List<T> removeDuplicates() {
    return toSet().toList();
  }

  /// Returns a random element from the list
  T? randomOrNull() {
    if (isEmpty) return null;
    return this[DateTime.now().millisecondsSinceEpoch % length];
  }
}
