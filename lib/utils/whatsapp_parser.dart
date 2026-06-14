import 'dart:convert';
import 'dart:io';
import '../models/parsed_chat_result.dart';
import 'media_helper.dart';

class WhatsAppParser {
  // Matches WhatsApp date/time patterns:
  // e.g. "09/06/2026, 14:32 - " or "9/6/26, 2:32 PM - " or "09/06/2026 14:32 - "
  static final RegExp _lineStartRegex = RegExp(
    r'^(\d{1,2}/\d{1,2}/\d{2,4}),?\s+(\d{1,2}:\d{2}(?:\s?[aApP][mM])?)\s+-\s+(.*)$'
  );

  // Matches WhatsApp media attachment lines:
  // e.g. "IMG-20260609-WA0000.jpg (file attached)"
  // e.g. "STK-20260611-WA0003.webp (file attached)"
  // e.g. "VID-20260611-WA0008.mp4 (file attached)"
  // Supports "file attached", "file terlampir", "attached", "terlampir", "<attached>"
  static final RegExp _mediaAttachmentRegex = RegExp(
    r'^([\w\-. ]+\.\w{3,4})\s*(\(file attached\)|\(file terlampir\)|\(Attached\)|\(Terlampir\)|\(terlampir\)|\(Attached File\)|<attached>|<attached:.*>)$',
    caseSensitive: false
  );

  static Future<ParsedChatResult> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File tidak ditemukan: $filePath");
    }

    final lines = await file.readAsLines(encoding: utf8);
    return parseLines(lines);
  }

  static ParsedChatResult parseFileIsolate(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception("File tidak ditemukan: $filePath");
    }

    final lines = file.readAsLinesSync(encoding: utf8);
    return parseLines(lines);
  }

  static ParsedChatResult parseLines(List<String> lines) {
    final List<ParsedMessageTemp> messages = [];
    final Set<String> senders = {};

    ParsedMessageTemp? currentMessage;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty && currentMessage == null) continue;

      final match = _lineStartRegex.firstMatch(line);

      if (match != null) {
        // We found a new message line!
        // Save the previous message if it exists
        if (currentMessage != null) {
          messages.add(currentMessage);
        }

        final dateStr = match.group(1)!;
        final timeStr = match.group(2)!;
        final rest = match.group(3)!;

        // Try to parse DateTime
        DateTime timestamp;
        try {
          timestamp = _parseDateTime(dateStr, timeStr);
        } catch (e) {
          timestamp = DateTime.now(); // Fallback
        }

        // Determine if it is a system message or a sender message
        // Look for the first ": " to separate sender and content
        final colonIndex = rest.indexOf(': ');
        if (colonIndex != -1) {
          final sender = rest.substring(0, colonIndex).trim();
          final content = rest.substring(colonIndex + 2);
          
          if (sender.isNotEmpty) {
            senders.add(sender);
            
            // Check for media attachment
            final mediaMatch = _mediaAttachmentRegex.firstMatch(content.trim());
            String? mediaPath;
            String? mediaType;
            if (mediaMatch != null) {
              mediaPath = mediaMatch.group(1)!.trim();
              mediaType = MediaHelper.getMediaTypeFromExtension(mediaPath);
            }

            currentMessage = ParsedMessageTemp(
              timestamp: timestamp,
              sender: sender,
              content: content,
              isSystem: false,
              mediaPath: mediaPath,
              mediaType: mediaType,
            );
          } else {
            // Empty sender means system message
            currentMessage = ParsedMessageTemp(
              timestamp: timestamp,
              sender: '',
              content: rest,
              isSystem: true,
            );
          }
        } else {
          // No ": " found, it's a system message
          currentMessage = ParsedMessageTemp(
            timestamp: timestamp,
            sender: '',
            content: rest,
            isSystem: true,
          );
        }
      } else {
        // This is a continuation of the previous message (multi-line)
        if (currentMessage != null) {
          // Append the line to the previous message content
          currentMessage = ParsedMessageTemp(
            timestamp: currentMessage.timestamp,
            sender: currentMessage.sender,
            content: '${currentMessage.content}\n$line',
            isSystem: currentMessage.isSystem,
            mediaPath: currentMessage.mediaPath,
            mediaType: currentMessage.mediaType,
          );
        } else {
          // Trash line before any valid chat message, skip or make it a system message
          if (line.trim().isNotEmpty) {
            currentMessage = ParsedMessageTemp(
              timestamp: DateTime.now(),
              sender: '',
              content: line,
              isSystem: true,
            );
          }
        }
      }
    }

    // Don't forget to add the last message
    if (currentMessage != null) {
      messages.add(currentMessage);
    }

    return ParsedChatResult(
      messages: messages,
      uniqueSenders: senders.toList()..sort(),
    );
  }

  static DateTime _parseDateTime(String dateStr, String timeStr) {
    final dateParts = dateStr.split('/');
    if (dateParts.length != 3) {
      throw FormatException("Format tanggal salah");
    }

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    if (year < 100) {
      year += 2000;
    }

    // Swap if month > 12 (handles cases where locale is MM/dd/yyyy but format check fails)
    if (month > 12) {
      final temp = day;
      day = month;
      month = temp;
    }

    // Parse time
    int hour = 0;
    int minute = 0;

    final isPm = timeStr.toLowerCase().contains('pm');
    final isAm = timeStr.toLowerCase().contains('am');

    // Strip alphabets and spaces for time parsing
    final cleanTimeStr = timeStr.replaceAll(RegExp(r'[a-zA-Z\s ]'), '');
    final timeParts = cleanTimeStr.split(':');
    if (timeParts.length >= 2) {
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
    }

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    return DateTime(year, month, day, hour, minute);
  }
}
