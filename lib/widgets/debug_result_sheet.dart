import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// A sheet to display the Health Connect diagnostic results
class DebugResultSheet extends StatelessWidget {
  final Map<String, dynamic> results;

  const DebugResultSheet({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Health Connect Diagnostics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Results sections
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'These are advanced diagnostic results that can help fix your Health Connect issues. '
                  'You can take a screenshot of this screen to share with support.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),

              // App info section
              _buildSection(
                title: 'App Information',
                icon: Icons.info_outline,
                content: _buildAppInfoContent(),
              ),

              // Device info section
              _buildSection(
                title: 'Device Information',
                icon: Icons.phone_android,
                content: _buildDeviceInfoContent(),
              ),

              // Health Connect status
              _buildSection(
                title: 'Health Connect Status',
                icon: Icons.favorite_outline,
                content: _buildHealthConnectStatusContent(),
                isHighlighted: true,
              ),

              // Permission details
              if (results.containsKey('permissionDetails'))
                _buildSection(
                  title: 'Permission Details',
                  icon: Icons.vpn_key,
                  content: _buildPermissionDetailsContent(),
                ),

              // Possible solutions
              _buildSection(
                title: 'Suggested Solutions',
                icon: Icons.lightbulb_outline,
                content: _buildSuggestedSolutionsContent(),
                isHighlighted: true,
              ),

              // Copy button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: ElevatedButton.icon(
                  onPressed: () => _copyResultsToClipboard(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OseerColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy All Results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isHighlighted ? const Color(0xFFF5F8FF) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: Colors.blue.withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isHighlighted ? Colors.blue : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted ? Colors.blue : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section content
          Padding(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoContent() {
    final appName = results['appName'] ?? 'Unknown';
    final packageName = results['packageName'] ?? 'Unknown';
    final version = results['version'] ?? 'Unknown';
    final buildNumber = results['buildNumber'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('App Name:', appName),
        _buildInfoRow('Package:', packageName),
        _buildInfoRow('Version:', '$version (Build $buildNumber)'),
      ],
    );
  }

  Widget _buildDeviceInfoContent() {
    final androidVersion =
        results['androidVersion'] as Map<String, dynamic>? ?? {};

    final sdkInt = androidVersion['sdkInt']?.toString() ?? 'Unknown';
    final release = androidVersion['release'] ?? 'Unknown';
    final manufacturer = androidVersion['manufacturer'] ?? 'Unknown';
    final model = androidVersion['model'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Android Version:', '$release (SDK $sdkInt)'),
        _buildInfoRow('Device:', '$manufacturer $model'),
      ],
    );
  }

  Widget _buildHealthConnectStatusContent() {
    final healthConnectAvailable = results['healthConnectAvailable'] ?? false;
    final healthConnectAppInstalled =
        results['healthConnectAppInstalled'] ?? false;

    // Get Health Connect version info if available
    String versionDisplay = 'Unknown';
    final versionInfo =
        results['healthConnectVersionInfo'] as Map<String, dynamic>? ?? {};
    if (versionInfo.containsKey('extractedVersion')) {
      versionDisplay = versionInfo['extractedVersion'] ?? 'Unknown';
    } else if (versionInfo.containsKey('installed')) {
      versionDisplay =
          versionInfo['installed'] == true ? 'Installed' : 'Not Installed';
    }

    // Get permissions info
    final permissionsGranted =
        results['healthConnectPermissionsGranted'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow(
          'Health Connect Available:',
          healthConnectAvailable,
          details: healthConnectAvailable ? 'Yes' : 'No',
        ),
        _buildStatusRow(
          'Health Connect Installed:',
          healthConnectAppInstalled,
          details: healthConnectAppInstalled ? 'Yes' : 'No',
        ),
        _buildStatusRow(
          'Health Connect Version:',
          versionDisplay != 'Unknown',
          details: versionDisplay,
        ),
        _buildStatusRow(
          'Permissions Granted:',
          permissionsGranted == true,
          details: permissionsGranted == true ? 'Yes' : 'No',
        ),

        // Main issue detected
        if (!healthConnectAvailable ||
            !healthConnectAppInstalled ||
            permissionsGranted != true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !healthConnectAppInstalled
                          ? 'Health Connect app is not installed'
                          : !healthConnectAvailable
                              ? 'Health Connect is not available on this device'
                              : permissionsGranted != true
                                  ? 'Health Connect permissions not granted'
                                  : 'Unknown issue detected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error details if available
        if (results.containsKey('healthConnectException'))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Error Details: ${(results['healthConnectException'] as Map)['message'] ?? 'Unknown error'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionDetailsContent() {
    final permissions = results['permissionDetails'] as List<dynamic>? ?? [];

    if (permissions.isEmpty) {
      return const Text('No permission details available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: permissions.map((perm) {
        final type = perm['type'] ?? 'Unknown';
        final granted = perm['granted'] ?? false;
        final error = perm['error'];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                granted == true ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: granted == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              if (error != null)
                Tooltip(
                  message: error.toString(),
                  child: const Icon(Icons.error_outline,
                      size: 16, color: Colors.orange),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuggestedSolutionsContent() {
    // Determine the main issue
    bool healthConnectAvailable = results['healthConnectAvailable'] ?? false;
    bool healthConnectAppInstalled =
        results['healthConnectAppInstalled'] ?? false;
    bool permissionsGranted =
        results['healthConnectPermissionsGranted'] ?? false;

    List<String> suggestions = [];

    if (!healthConnectAppInstalled) {
      suggestions
          .add('Install the Health Connect app from the Google Play Store.');
      suggestions.add('After installation, restart your phone and try again.');
    } else if (!healthConnectAvailable) {
      suggestions.add(
          'Your device might not support Health Connect. Try updating your device to the latest Android version.');
      suggestions.add(
          'If using an emulator, make sure it has Google Play Services and Google Play Store installed.');
    } else if (!permissionsGranted) {
      suggestions
          .add('Open Health Connect app and grant the necessary permissions.');
      suggestions.add('Make sure to allow all requested health data types.');
      suggestions.add(
          'If permissions are still not working, try uninstalling and reinstalling the app.');
    } else {
      suggestions
          .add('Try uninstalling and reinstalling the Health Connect app.');
      suggestions.add('Make sure your device has the latest system updates.');
      suggestions
          .add('Check for any pending updates for the Health Connect app.');
    }

    // Add a common suggestion for all cases
    suggestions.add('Restart your device and try again.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: suggestions.map((suggestion) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isPositive,
      {required String details}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Icon(
            isPositive ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isPositive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details,
              style: TextStyle(
                fontSize: 14,
                color: isPositive ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyResultsToClipboard(BuildContext context) {
    final String resultsText = _formatResultsForClipboard();
    Clipboard.setData(ClipboardData(text: resultsText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostic results copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatResultsForClipboard() {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('OSEER HEALTH BRIDGE DIAGNOSTICS REPORT');
    buffer.writeln('=======================================');
    buffer.writeln('Date: ${DateTime.now().toString()}');
    buffer.writeln('');

    // App Info
    buffer.writeln('APP INFORMATION:');
    buffer.writeln('App Name: ${results['appName'] ?? 'Unknown'}');
    buffer.writeln('Package: ${results['packageName'] ?? 'Unknown'}');
    buffer.writeln(
        'Version: ${results['version'] ?? 'Unknown'} (Build ${results['buildNumber'] ?? 'Unknown'})');
    buffer.writeln('');

    // Device Info
    buffer.writeln('DEVICE INFORMATION:');
    final androidVersion =
        results['androidVersion'] as Map<String, dynamic>? ?? {};
    buffer.writeln(
        'Android Version: ${androidVersion['release'] ?? 'Unknown'} (SDK ${androidVersion['sdkInt'] ?? 'Unknown'})');
    buffer.writeln(
        'Device: ${androidVersion['manufacturer'] ?? 'Unknown'} ${androidVersion['model'] ?? 'Unknown'}');
    buffer.writeln('');

    // Health Connect Status
    buffer.writeln('HEALTH CONNECT STATUS:');
    buffer.writeln(
        'Health Connect Available: ${results['healthConnectAvailable'] ?? 'Unknown'}');
    buffer.writeln(
        'Health Connect Installed: ${results['healthConnectAppInstalled'] ?? 'Unknown'}');

    final versionInfo =
        results['healthConnectVersionInfo'] as Map<String, dynamic>? ?? {};
    String versionDisplay = 'Unknown';
    if (versionInfo.containsKey('extractedVersion')) {
      versionDisplay = versionInfo['extractedVersion'] ?? 'Unknown';
    } else if (versionInfo.containsKey('installed')) {
      versionDisplay =
          versionInfo['installed'] == true ? 'Installed' : 'Not Installed';
    }
    buffer.writeln('Health Connect Version: $versionDisplay');

    buffer.writeln(
        'Permissions Granted: ${results['healthConnectPermissionsGranted'] ?? 'Unknown'}');
    buffer.writeln('');

    // Permission Details
    if (results.containsKey('permissionDetails')) {
      buffer.writeln('PERMISSION DETAILS:');
      final permissions = results['permissionDetails'] as List<dynamic>? ?? [];
      for (final perm in permissions) {
        buffer.writeln(
            '${perm['type'] ?? 'Unknown'}: ${perm['granted'] ?? 'Unknown'}');
      }
      buffer.writeln('');
    }

    // Errors
    if (results.containsKey('healthConnectException')) {
      buffer.writeln('ERROR DETAILS:');
      final exception =
          results['healthConnectException'] as Map<String, dynamic>? ?? {};
      buffer.writeln('Code: ${exception['code'] ?? 'Unknown'}');
      buffer.writeln('Message: ${exception['message'] ?? 'Unknown'}');
      buffer.writeln('');
    }

    // Raw data for debugging
    buffer.writeln('RAW DIAGNOSTIC DATA:');
    buffer.writeln(results.toString());

    return buffer.toString();
  }
}
