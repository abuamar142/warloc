import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (variant == AppButtonVariant.secondary) {
      if (icon != null) {
        return TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          label: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      return TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Primary
    final style = ElevatedButton.styleFrom(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: style,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
