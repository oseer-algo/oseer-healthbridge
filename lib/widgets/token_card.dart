// File path: lib/widgets/token_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A card displaying a connection token with copy functionality
class TokenCard extends StatelessWidget {
  final String token;
  final bool isExpired;
  final bool isCopied;
  final VoidCallback onCopy;

  const TokenCard({
    super.key,
    required this.token,
    this.isExpired = false,
    this.isCopied = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F5), // Light green background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFFDDF0E9), // Light green border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpired
                ? Colors.red.withOpacity(0.05)
                : const Color(0xFF47B58E).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: isExpired ? null : onCopy,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF47B58E).withOpacity(0.1),
        highlightColor: const Color(0xFF47B58E).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connection Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isExpired
                          ? Colors.red
                          : const Color(0xFF2A5F4A), // Dark green
                    ),
                  ),
                  Row(
                    children: [
                      if (isExpired)
                        _buildStatusTag(
                          text: 'EXPIRED',
                          color: Colors.red,
                          icon: Icons.timer_off,
                        )
                      else
                        _buildStatusTag(
                          text: 'ACTIVE',
                          color: const Color(0xFF4CAF50), // Success green
                          icon: Icons.check_circle,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                token,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  color: isExpired
                      ? Colors.red.withOpacity(0.7)
                      : const Color(0xFF2A5F4A), // Dark green
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isExpired) ...[
                    _buildCopyButton(context, isCopied),
                  ],
                  if (isExpired) ...[
                    Text(
                      'Generate a new code to connect',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context, bool isCopied) {
    return TextButton.icon(
      onPressed: onCopy,
      style: TextButton.styleFrom(
        backgroundColor: isCopied
            ? const Color(0xFF4CAF50).withOpacity(0.1) // Success green
            : const Color(0xFF2A5F4A).withOpacity(0.05), // Dark green
        foregroundColor:
            isCopied ? const Color(0xFF4CAF50) : const Color(0xFF2A5F4A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      icon: Icon(
        isCopied ? Icons.check : Icons.copy,
        size: 16,
      ),
      label: Text(
        isCopied ? 'Copied!' : 'Tap to copy',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    )
        .animate(target: isCopied ? 1 : 0)
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 200.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scaleXY(
          begin: 1.05,
          end: 1.0,
          duration: 200.ms,
          curve: Curves.easeInOut,
        );
  }
}
