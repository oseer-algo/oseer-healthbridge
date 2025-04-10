// File path: lib/widgets/action_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

enum ActionButtonType {
  primary,
  secondary,
  danger,
  text,
}

enum ActionButtonSize {
  small,
  medium,
  large,
}

/// A standardized button component with consistent styling
class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final ActionButtonType type;
  final ActionButtonSize size;
  final bool isLoading;
  final bool fullWidth;

  const ActionButton({
    Key? key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.type = ActionButtonType.primary,
    this.size = ActionButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Button styling based on type
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    BoxShadow? boxShadow;

    switch (type) {
      case ActionButtonType.primary:
        backgroundColor = OseerColors.primary;
        textColor = Colors.white;
        borderColor = OseerColors.primary;
        boxShadow = BoxShadow(
          color: OseerColors.primary.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        );
        break;
      case ActionButtonType.secondary:
        backgroundColor = Colors.white;
        textColor = OseerColors.primary;
        borderColor = OseerColors.primary.withOpacity(0.3);
        boxShadow = BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        );
        break;
      case ActionButtonType.danger:
        backgroundColor = OseerColors.error;
        textColor = Colors.white;
        borderColor = OseerColors.error;
        boxShadow = BoxShadow(
          color: OseerColors.error.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        );
        break;
      case ActionButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = OseerColors.primary;
        borderColor = Colors.transparent;
        boxShadow = null;
        break;
    }

    // Button size configuration
    double verticalPadding;
    double horizontalPadding;
    double borderRadius;
    double fontSize;
    double iconSize;

    switch (size) {
      case ActionButtonSize.small:
        verticalPadding = 8;
        horizontalPadding = 12;
        borderRadius = 8;
        fontSize = 14;
        iconSize = 16;
        break;
      case ActionButtonSize.medium:
        verticalPadding = 12;
        horizontalPadding = 20;
        borderRadius = 12;
        fontSize = 16;
        iconSize = 18;
        break;
      case ActionButtonSize.large:
        verticalPadding = 16;
        horizontalPadding = 28;
        borderRadius = 14;
        fontSize = 18;
        iconSize = 20;
        break;
    }

    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: type != ActionButtonType.text
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: boxShadow != null ? [boxShadow] : null,
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: textColor.withOpacity(0.1),
          highlightColor: textColor.withOpacity(0.05),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: type != ActionButtonType.text
                  ? Border.all(color: borderColor, width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(
                    icon,
                    color: textColor,
                    size: iconSize,
                  ),
                ],
                if ((icon != null || isLoading) && label.isNotEmpty)
                  SizedBox(width: 10),
                if (label.isNotEmpty)
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(
        begin: 0.98, end: 1, duration: 300.ms, curve: Curves.easeOutQuad);
  }
}
