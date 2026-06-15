import 'package:flutter/material.dart';
import 'glass_container.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: BorderRadius.zero,
      blurX: 10.0,
      blurY: 10.0,
      border: Border(
        bottom: BorderSide(
          color: isDark
              ? const Color(0xFF2E3B46).withOpacity(0.3)
              : Colors.grey[200]!.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: AppBar(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
