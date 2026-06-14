import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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

    Color backgroundColor;
    Color textColor;

    if (usePrimaryColor) {
      backgroundColor = AppColors.primaryLight;
      textColor = AppColors.primary;
    } else if (isMe) {
      backgroundColor = AppColors.myMessageBubble;
      textColor = AppColors.myAvatarText;
    } else {
      backgroundColor = AppColors.otherAvatarBackground;
      textColor = Colors.black87;
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
