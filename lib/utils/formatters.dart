// lib/utils/formatters.dart
import 'package:intl/intl.dart';

/// Utility class containing various formatters for displaying data
class OseerFormatters {
  /// Format a DateTime to a human-readable string
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, yyyy, h:mm a').format(dateTime.toLocal());
  }

  /// Format a Duration to display as minutes:seconds or hours:minutes:seconds
  static String formatDuration(Duration? duration) {
    if (duration == null || duration.isNegative) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Format a Duration as a human-readable string (e.g., "15 minutes remaining")
  static String formatDurationText(Duration? duration) {
    if (duration == null || duration.isNegative) return 'Expired';
    // For short durations, show seconds
    if (duration.inMinutes < 1) {
      return "${duration.inSeconds} seconds remaining";
    }
    // For durations under an hour, show minutes and seconds
    if (duration.inHours < 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds == 0) {
        return "$minutes ${minutes == 1 ? 'minute' : 'minutes'} remaining";
      } else {
        return "$minutes min $seconds sec remaining";
      }
    }
    // For longer durations, show hours and minutes
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) {
      return "$hours ${hours == 1 ? 'hour' : 'hours'} remaining";
    } else {
      return "$hours hr $minutes min remaining";
    }
  }

  /// Format a file size in bytes to a human-readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format a number with a specified number of decimal places
  static String formatNumber(num? value, {int decimalPlaces = 1}) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(decimalPlaces);
  }

  /// Format connection token for display (add hyphens for readability)
  static String formatToken(String token) {
    if (token.length <= 4) return token;
    // Format token with hyphens for readability (e.g., XXXX-XXXX-XXXX-XXXX-XXXX-XXXX)
    const chunkSize = 4;
    final chunks = <String>[];
    for (var i = 0; i < token.length; i += chunkSize) {
      final end = (i + chunkSize < token.length) ? i + chunkSize : token.length;
      chunks.add(token.substring(i, end));
    }
    return chunks.join('-');
  }

  /// Format a time ago string (e.g., "2 hours ago")
  static String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
  }
}
