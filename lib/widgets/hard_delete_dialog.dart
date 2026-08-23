import 'dart:math';
import 'package:flutter/material.dart';
import 'package:warloc/core/theme/app_colors.dart';

class HardDeleteConfirmDialog extends StatefulWidget {
  final String threadName;
  final int messageCount;
  final int mediaCount;

  const HardDeleteConfirmDialog({
    super.key,
    required this.threadName,
    required this.messageCount,
    required this.mediaCount,
  });

  @override
  State<HardDeleteConfirmDialog> createState() => _HardDeleteConfirmDialogState();
}

class _HardDeleteConfirmDialogState extends State<HardDeleteConfirmDialog> {
  late final String _code;
  final TextEditingController _controller = TextEditingController();
  bool _isMatch = false;

  static const String _charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';

  @override
  void initState() {
    super.initState();
    _code = _generateCode();
  }

  String _generateCode() {
    final rnd = Random.secure();
    return List.generate(5, (_) => _charset[rnd.nextInt(_charset.length)]).join();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final match = value == _code;
    if (match != _isMatch) {
      setState(() => _isMatch = match);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hapus Permanen?',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.threadName}"',
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Akan menghapus ${widget.messageCount} pesan dan ${widget.mediaCount} media, tidak dapat dibatalkan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ketik kode berikut untuk mengonfirmasi:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              alignment: Alignment.center,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
                ),
              ),
              child: Text(
                _code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan kode',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 14,
                  letterSpacing: 0,
                  fontFamily: null,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                fillColor: isDark ? AppColors.darkBorder.withValues(alpha: 0.3) : Colors.grey[100],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isMatch ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            disabledForegroundColor: isDark ? Colors.grey[500] : Colors.grey[500],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text(
            'Hapus Permanen',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
