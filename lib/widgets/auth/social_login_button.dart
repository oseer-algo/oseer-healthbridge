// lib/widgets/auth/social_login_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/constants.dart';

enum SocialButtonType { google, apple }

class SocialLoginButton extends StatelessWidget {
  final SocialButtonType type;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double height;
  final double fontSize;
  final EdgeInsets padding;

  const SocialLoginButton({
    Key? key,
    required this.type,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = true,
    this.height = 50.0,
    this.fontSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: isOutlined ? Colors.white : _getBackgroundColor(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: isOutlined
              ? BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.0,
                )
              : BorderSide.none,
        ),
        elevation: isOutlined ? 0 : 1,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12.0),
          splashColor: isOutlined
              ? Colors.grey.withOpacity(0.1)
              : Colors.white.withOpacity(0.1),
          highlightColor: isOutlined
              ? Colors.grey.withOpacity(0.05)
              : Colors.white.withOpacity(0.05),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOutlined ? _getLogoColor() : Colors.white,
                      ),
                    ),
                  )
                else
                  _buildLogo(),

                SizedBox(width: 12),

                // Text
                Text(
                  _getButtonText(),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: isOutlined ? Colors.black87 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOutQuint,
          duration: 400.ms,
        );
  }

  Widget _buildLogo() {
    switch (type) {
      case SocialButtonType.google:
        // Use the asset image - make sure google_logo.png exists in assets/icons/
        return Image.asset(
          'assets/icons/google_logo.png',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon if asset is missing
            return Icon(
              Icons.g_mobiledata,
              size: 24,
              color: _getLogoColor(),
            );
          },
        );
      case SocialButtonType.apple:
        return Icon(
          Icons.apple,
          size: 24,
          color: _getLogoColor(),
        );
    }
  }

  Color _getBackgroundColor() {
    switch (type) {
      case SocialButtonType.google:
        return Colors.white;
      case SocialButtonType.apple:
        return Colors.black;
    }
  }

  Color _getLogoColor() {
    if (!isOutlined) {
      return type == SocialButtonType.apple ? Colors.white : Colors.black;
    }

    switch (type) {
      case SocialButtonType.google:
        return Colors.red;
      case SocialButtonType.apple:
        return Colors.black;
    }
  }

  String _getButtonText() {
    switch (type) {
      case SocialButtonType.google:
        return 'Continue with Google';
      case SocialButtonType.apple:
        return 'Continue with Apple';
    }
  }
}
