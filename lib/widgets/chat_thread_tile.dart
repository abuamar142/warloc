import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';

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
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Kemarin';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFE6F5F3),
        child: Text(
          thread.name.isNotEmpty ? thread.name.substring(0, 1).toUpperCase() : '',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF008069),
          ),
        ),
      ),
      title: Text(
        thread.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          lastMessage != null
              ? (lastMessage!.isSystemMessage
                  ? lastMessage!.content
                  : "${lastMessage!.sender}: ${lastMessage!.content.replaceAll('\n', ' ')}")
              : "Tidak ada pesan",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatMessageTime(lastMessage?.timestamp),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$messageCount pesan",
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
