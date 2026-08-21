import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Centralized SnackBar helpers.
///
/// Visual styles match the patterns previously hand-written at each call site:
/// errors use [Colors.redAccent], successes use [AppColors.primary], and info
/// messages use the default theme styling.
///
/// Uses [ScaffoldMessenger.maybeOf] so calls made after a widget is unmounted
/// are silently skipped instead of throwing.

void _show(BuildContext context, SnackBar snackBar) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
}

/// Shows an error message with a red accent background.
void showErrorSnackBar(BuildContext context, String message) {
  _show(
    context,
    SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
  );
}

/// Shows a success message with the primary brand color background.
void showSuccessSnackBar(BuildContext context, String message) {
  _show(
    context,
    SnackBar(content: Text(message), backgroundColor: AppColors.primary),
  );
}

/// Shows an informational message with default theme styling.
void showInfoSnackBar(BuildContext context, String message) {
  _show(context, SnackBar(content: Text(message)));
}
