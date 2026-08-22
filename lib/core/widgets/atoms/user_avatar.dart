import 'package:flutter/material.dart';
import 'package:warloc/core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final bool isMe;
  final bool usePrimaryColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.isMe = false,
    this.usePrimaryColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;

    if (usePrimaryColor) {
      backgroundColor = isDark
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
          : theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
    } else if (isMe) {
      backgroundColor = isDark
          ? theme.colorScheme.secondary.withValues(alpha: 0.2)
          : AppColors.myMessageBubble;
      textColor = isDark
          ? theme.colorScheme.secondary
          : AppColors.myAvatarText;
    } else {
      backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.otherAvatarBackground;
      textColor = isDark ? Colors.white70 : Colors.black87;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75, // Responsive font size based on radius
        ),
      ),
    );
  }
}
