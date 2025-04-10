import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/constants.dart';
import '../services/logger_service.dart';

class ConnectionOptionsSheet extends StatelessWidget {
  final VoidCallback onGetConnectionCode;
  final VoidCallback onReconnect;

  const ConnectionOptionsSheet({
    Key? key,
    required this.onGetConnectionCode,
    required this.onReconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 32),

              // Option 1: Get Connection Code
              _buildOption(
                icon: Icons.qr_code_rounded,
                title: 'Get Connection Code',
                description:
                    'Generate a new code to connect this device to your Oseer account',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  onGetConnectionCode();
                },
                isPrimary: true,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slide(
                    duration: 300.ms,
                    begin: const Offset(0, 0.2),
                    end: const Offset(0, 0),
                  ),
              const SizedBox(height: 16),

              // Option 2: Reconnect
              _buildOption(
                icon: Icons.link_rounded,
                title: 'Reconnect to Oseer',
                description:
                    'Enter a reconnection code from the Oseer web app to reconnect',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  onReconnect();
                },
                isPrimary: false,
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slide(
                    duration: 300.ms,
                    begin: const Offset(0, 0.2),
                    end: const Offset(0, 0),
                  ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/oseer_logo.png',
                    width: 36,
                    height: 36,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.link,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().scale(
                    duration: 300.ms,
                    curve: Curves.easeOut,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                  ),
              const SizedBox(height: 16),
              const Text(
                'Connection Options',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect or reconnect your device to Oseer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? OseerColors.primary.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? OseerColors.primary.withOpacity(0.3)
                : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPrimary ? OseerColors.primary : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : Colors.grey[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? OseerColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPrimary ? OseerColors.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
