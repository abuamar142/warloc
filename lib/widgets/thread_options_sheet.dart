import 'package:flutter/material.dart';
import 'package:warloc/models/chat_thread.dart';
import 'package:warloc/core/theme/app_colors.dart';
import 'package:warloc/core/widgets/atoms/user_avatar.dart';

class ThreadOptionsSheet extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onRename;
  final VoidCallback onViewMedia;
  final VoidCallback onDelete;

  const ThreadOptionsSheet({
    super.key,
    required this.thread,
    required this.onRename,
    required this.onViewMedia,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar + name
            Row(
              children: [
                UserAvatar(
                  name: thread.name,
                  radius: 24,
                  usePrimaryColor: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Saya: ${thread.meName}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey[200]),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit, color: theme.colorScheme.primary),
              title: const Text('Ganti Nama'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: Icon(Icons.perm_media, color: theme.colorScheme.primary),
              title: const Text('Lihat Media'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                onViewMedia();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text(
                'Hapus',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
