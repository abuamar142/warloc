import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF008069);
  static const Color primaryLight = Color(0xFFE6F5F3);
  static const Color primaryTransparent = Color(0x20008069);
  static const Color accent = Color(0xFF00A884);
  
  static const Color chatBackground = Color(0xFFEFEAE2);
  static const Color myMessageBubble = Color(0xFFDCF8C6);
  static const Color otherMessageBubble = Colors.white;
  
  static const Color myAvatarText = Color(0xFF075E54);
  static const Color otherAvatarBackground = Color(0xFFE0E0E0);
  
  static const Color highlightBackground = Color(0xFFFFF9C4);
  static const Color highlightBackgroundDark = Color(0xFF5C4B00);

  static const Color audioBubbleBackground = Color(0xFFE7FFDB);

  // Dark-theme surfaces & borders (mirror darkTheme in app_theme.dart).
  static const Color darkBackground = Color(0xFF0B141A);
  static const Color darkSurface = Color(0xFF1F2C34);
  static const Color darkBorder = Color(0xFF2E3B46);

  // Chat wallpaper gradient, light-mode edge tone
  // (center stop Color(0xFFE2E8F0) is single-use and stays inline).
  static const Color chatWallpaperLight = Color(0xFFEDF2F7);
}
