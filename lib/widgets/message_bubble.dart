import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import 'media_bubble_renderer.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String meName;
  final String? mediaDirPath;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.meName,
    this.mediaDirPath,
    this.isHighlighted = false,
  });

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(dateTime);
  }

  String _getDisplayContent() {
    if (!message.hasMedia) return message.content;
    
    // Split lines and check if the first line is the media attachment line
    final lines = message.content.split('\n');
    if (lines.isEmpty) return "";
    
    final firstLine = lines.first.trim();
    // Regex matching the media attachment pattern
    final mediaRegex = RegExp(
      r'^([\w\-. ]+\.\w{3,4})\s*(\(file attached\)|\(file terlampir\)|\(Attached\)|\(Terlampir\)|\(terlampir\)|\(Attached File\)|<attached>|<attached:.*>)$',
      caseSensitive: false
    );
    
    if (mediaRegex.hasMatch(firstLine)) {
      // Return the remaining lines as the caption
      return lines.skip(1).join('\n').trim();
    }
    
    return message.content;
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
    final isSticker = message.mediaType == 'sticker';

    // 1. Sticker Rendering (Transparent, no bubble background)
    if (isSticker && message.hasMedia) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: isMe ? 64 : 16,
            right: isMe ? 16 : 64,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Text(
                  message.sender,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF075E54),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, right: 20),
                    child: MediaBubbleRenderer(
                      mediaPath: message.mediaPath!,
                      mediaType: 'sticker',
                      mediaDirPath: mediaDirPath ?? '',
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
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

    // 2. Regular Bubble Rendering (For text, images, videos, audio, documents)
    final displayContent = _getDisplayContent();
    final hasCaption = displayContent.isNotEmpty;
    final isImageOrVideo = message.mediaType == 'image' || message.mediaType == 'video';
    
    // Bubble padding
    final bubblePadding = (isImageOrVideo && !hasCaption)
        ? const EdgeInsets.all(3)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    // Build the timestamp widget
    Widget timestampWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: (isImageOrVideo && !hasCaption)
                ? Colors.white.withValues(alpha: 0.9)
                : const Color(0x66000000),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all,
            size: 14,
            color: (isImageOrVideo && !hasCaption)
                ? Colors.lightBlueAccent[100]
                : Colors.blue[400],
          ),
        ],
      ],
    );

    // If it is an image/video with no caption, we overlay the timestamp with a semi-transparent black background
    if (isImageOrVideo && !hasCaption) {
      timestampWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: timestampWidget,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isMe ? 64 : 16,
          right: isMe ? 16 : 64,
        ),
        padding: bubblePadding,
        decoration: BoxDecoration(
          color: isHighlighted 
              ? const Color(0xFFFFF9C4) 
              : (isMe ? const Color(0xFFE7FFDB) : Colors.white),
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
            
            // Media file section (if any)
            if (message.hasMedia) ...[
              MediaBubbleRenderer(
                mediaPath: message.mediaPath!,
                mediaType: message.mediaType!,
                mediaDirPath: mediaDirPath ?? '',
                timestampOverlay: (isImageOrVideo && !hasCaption) ? timestampWidget : null,
              ),
              if (hasCaption) const SizedBox(height: 4),
            ],

            // Content text & timestamp layout
            if (!isImageOrVideo || hasCaption) ...[
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    displayContent,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: timestampWidget,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
