import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double blurX;
  final double blurY;
  final Color? color;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurX = 10.0,
    this.blurY = 10.0,
    this.color,
    this.border,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBgColor = isDark
        ? const Color(0xFF1A242D).withOpacity(0.65)
        : Colors.white.withOpacity(0.65);

    final defaultBorderColor = isDark
        ? const Color(0xFF2E3B46).withOpacity(0.4)
        : Colors.grey[200]!.withOpacity(0.4);

    final finalBorder = border ?? Border.all(color: defaultBorderColor, width: 1.5);
    final radius = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? defaultBgColor,
            borderRadius: radius,
            border: finalBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
