import 'package:flutter/material.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../utils/date_formatter.dart';
import 'common/user_avatar.dart';

class ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final ChatMessage? lastMessage;
  final int messageCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ChatThreadTile({
    super.key,
    required this.thread,
    required this.lastMessage,
    required this.messageCount,
    required this.onTap,
    required this.onDelete,
  });

  String _formatMessageTime(int? timestamp) {
    if (timestamp == null) return '';
    return DateFormatter.formatThreadTime(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: theme.cardTheme.shape is RoundedRectangleBorder
            ? (theme.cardTheme.shape as RoundedRectangleBorder).side
            : Border.all(color: isDark ? const Color(0xFF2E3B46) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: UserAvatar(
            name: thread.name,
            radius: 26,
            usePrimaryColor: true,
          ),
          title: Text(
            thread.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              lastMessage != null
                  ? (lastMessage!.isSystemMessage
                      ? lastMessage!.content
                      : "${lastMessage!.sender}: ${lastMessage!.content.replaceAll('\n', ' ')}")
                  : "Tidak ada pesan",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMessageTime(lastMessage?.timestamp),
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$messageCount pesan",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
