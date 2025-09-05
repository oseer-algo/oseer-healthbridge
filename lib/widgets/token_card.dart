// lib/widgets/token_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class TokenCard extends StatelessWidget {
  final String token;
  final VoidCallback? onCopy;

  const TokenCard({
    Key? key,
    required this.token,
    this.onCopy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OseerColors.primary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Connection Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: OseerColors.textPrimary,
                ),
              ),
              if (onCopy != null)
                IconButton(
                  onPressed: onCopy,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: OseerColors.primary,
                  ),
                  tooltip: 'Copy code',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: OseerColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: OseerColors.border.withOpacity(0.3),
              ),
            ),
            child: Text(
              token,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: OseerColors.textPrimary,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.0, 1.0),
                  duration: 300.ms,
                ),
          ),
        ],
      ),
    );
  }
}
