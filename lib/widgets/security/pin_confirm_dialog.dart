import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/app_dialog.dart';
import '../common/app_button.dart';
import '../../theme/app_colors.dart';
import '../../services/security_service.dart';

class PINConfirmDialog extends StatefulWidget {
  final String title;
  final String instruction;

  const PINConfirmDialog({
    super.key,
    required this.title,
    required this.instruction,
  });

  @override
  State<PINConfirmDialog> createState() => _PINConfirmDialogState();
}

class _PINConfirmDialogState extends State<PINConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppDialog(
      icon: Icons.lock_outline,
      iconColor: isDark ? AppColors.accent : AppColors.primary,
      title: widget.title,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.instruction,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: "PIN Saat Ini",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13),
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey[400]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (val) {
                if (val == null || val.length != 4) {
                  return "PIN harus terdiri dari 4 angka";
                }
                return null;
              },
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _errorText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Batal",
          onPressed: () => Navigator.pop(context, false),
          variant: AppButtonVariant.secondary,
        ),
        AppButton(
          label: "Verifikasi",
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final isValid = SecurityService.instance.validatePin(_pinController.text);
              if (isValid) {
                Navigator.pop(context, true);
              } else {
                setState(() {
                  _pinController.clear();
                  _errorText = "PIN yang dimasukkan salah.";
                });
              }
            }
          },
        ),
      ],
    );
  }
}
