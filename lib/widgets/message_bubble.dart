import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String meName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.meName,
  });

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF2F4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x0A000000)),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isMe = message.sender == meName;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isMe ? 64 : 16,
          right: isMe ? 16 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name (only for other speakers)
            if (!isMe) ...[
              Text(
                message.sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF075E54), // Whatsapp dark green for user names
                ),
              ),
              const SizedBox(height: 2),
            ],
            // Message content layout with trailing time
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0x66000000),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.blue[400],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
