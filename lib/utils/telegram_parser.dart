import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:warloc/models/parsed_chat_result.dart';
import 'package:warloc/utils/media_helper.dart';

class TelegramParser {
  static Future<ParsedChatResult> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File tidak ditemukan: $filePath");
    }

    final content = await file.readAsString(encoding: utf8);
    final data = jsonDecode(content);
    if (data is! Map<String, dynamic>) {
      throw const FormatException("Format JSON Telegram tidak valid (bukan JSON object)");
    }

    return parseMap(data);
  }

  static ParsedChatResult parseFileIsolate(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception("File tidak ditemukan: $filePath");
    }

    final content = file.readAsStringSync(encoding: utf8);
    final data = jsonDecode(content);
    if (data is! Map<String, dynamic>) {
      throw const FormatException("Format JSON Telegram tidak valid (bukan JSON object)");
    }

    return parseMap(data);
  }

  static ParsedChatResult parseMap(Map<String, dynamic> data) {
    final List<ParsedMessageTemp> messages = [];
    final Set<String> senders = {};

    final messagesList = data['messages'];
    if (messagesList is List) {
      for (final msg in messagesList) {
        if (msg is! Map<String, dynamic>) continue;

        // 1. Sender and System message identification
        final type = msg['type'] as String?;
        final isSystem = type == 'service';
        
        final from = msg['from'] as String?;
        final sender = (isSystem || from == null) ? '' : from.trim();

        // 2. Parse timestamp
        DateTime timestamp;
        try {
          final dateStr = msg['date'] as String?;
          if (dateStr != null) {
            timestamp = DateTime.parse(dateStr);
          } else {
            final unixTimeStr = msg['date_unixtime'] as String?;
            if (unixTimeStr != null) {
              final seconds = int.parse(unixTimeStr);
              timestamp = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            } else {
              timestamp = DateTime.now();
            }
          }
        } catch (_) {
          timestamp = DateTime.now();
        }

        // 3. Parse content (plain or rich text list)
        final textVal = msg['text'];
        final String content = _parseTelegramText(textVal);

        // 4. Parse media
        String? mediaPath;
        String? mediaType;

        String? rawMediaPath;
        if (msg.containsKey('photo') && msg['photo'] is String) {
          rawMediaPath = msg['photo'] as String;
        } else if (msg.containsKey('file') && msg['file'] is String) {
          rawMediaPath = msg['file'] as String;
        }

        if (rawMediaPath != null && rawMediaPath.isNotEmpty) {
          mediaPath = p.basename(rawMediaPath);
          
          final telegramMediaType = msg['media_type'] as String?;
          if (telegramMediaType == 'sticker') {
            mediaType = 'sticker';
          } else if (telegramMediaType == 'voice_message') {
            mediaType = 'audio';
          } else {
            mediaType = MediaHelper.getMediaTypeFromExtension(mediaPath);
          }
        }

        if (!isSystem && sender.isNotEmpty) {
          senders.add(sender);
        }

        messages.add(ParsedMessageTemp(
          timestamp: timestamp,
          sender: sender,
          content: content,
          isSystem: isSystem || sender.isEmpty,
          mediaPath: mediaPath,
          mediaType: mediaType,
        ));
      }
    }

    return ParsedChatResult(
      messages: messages,
      uniqueSenders: senders.toList()..sort(),
    );
  }

  static String _parseTelegramText(dynamic textField) {
    if (textField == null) return "";
    if (textField is String) return textField;
    if (textField is List) {
      final buffer = StringBuffer();
      for (final element in textField) {
        if (element is String) {
          buffer.write(element);
        } else if (element is Map && element.containsKey('text')) {
          buffer.write(element['text'].toString());
        }
      }
      return buffer.toString();
    }
    return textField.toString();
  }
}
