import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'media_bubble_renderer.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String meName;
  final String? mediaDirPath;
  final bool isHighlighted;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.meName,
    this.mediaDirPath,
    this.isHighlighted = false,
    this.onLongPress,
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

  Widget _buildRichTextWithLinks(String text, TextStyle baseStyle) {
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: const Color(0xFF007AFF), // iOS/WhatsApp premium blue for links
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onLongPress: onLongPress,
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
        ),
      );
    }

    final isMe = message.sender == meName;
    final isSticker = message.mediaType == 'sticker';

    // 1. Sticker Rendering (Transparent, no bubble background)
    if (isSticker && message.hasMedia) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final timestampColor = (isImageOrVideo && !hasCaption)
        ? Colors.white.withValues(alpha: 0.9)
        : (isDark ? Colors.white60 : Colors.black54);

    final checkColor = (isImageOrVideo && !hasCaption)
        ? Colors.lightBlueAccent[100]
        : (isDark ? Colors.lightBlueAccent[200] : Colors.blue[400]);

    // Build the timestamp widget
    Widget timestampWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: timestampColor,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all,
            size: 14,
            color: checkColor,
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

    // Premium dynamic bubble background colors
    final bubbleColor = isHighlighted
        ? (isDark ? const Color(0xFF3E3B1C) : const Color(0xFFFFF9C4))
        : (isMe
            ? (isDark ? const Color(0xFF005B41).withValues(alpha: 0.8) : const Color(0xFFDCF8C6))
            : (isDark ? const Color(0xFF1F2C34) : Colors.white));

    final bubbleBorder = isHighlighted
        ? Border.all(color: Colors.amber, width: 1.5)
        : Border.all(
            color: isDark
                ? (isMe ? const Color(0xFF007A58).withValues(alpha: 0.3) : const Color(0xFF2E3B46).withValues(alpha: 0.5))
                : (isMe ? const Color(0xFFC7EBB4) : Colors.grey[200]!),
            width: 1,
          );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 64 : 12,
            right: isMe ? 12 : 64,
          ),
          padding: bubblePadding,
          decoration: BoxDecoration(
            color: bubbleColor,
            border: bubbleBorder,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isMe ? 16 : 4),
              topRight: Radius.circular(isMe ? 4 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03),
                offset: const Offset(0, 2),
                blurRadius: 4,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? theme.colorScheme.secondary : const Color(0xFF075E54),
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
                if (hasCaption) const SizedBox(height: 6),
              ],

              // Content text & timestamp layout
              if (!isImageOrVideo || hasCaption) ...[
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildRichTextWithLinks(
                      displayContent,
                      TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
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
      ),
    );
  }
}
