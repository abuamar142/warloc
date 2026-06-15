import 'package:flutter_test/flutter_test.dart';
import 'package:warloc/utils/whatsapp_parser.dart';

void main() {
  group('WhatsAppParser Unit Tests', () {
    test('Parse simple 24-hour format lines', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: Hello Alice!',
        '09/06/2026, 14:33 - Alice: Hi John! How are you?',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.uniqueSenders, containsAll(['John Doe', 'Alice']));
      expect(result.messages[0].sender, 'John Doe');
      expect(result.messages[0].content, 'Hello Alice!');
      expect(result.messages[0].timestamp, DateTime(2026, 6, 9, 14, 32));
      expect(result.messages[1].sender, 'Alice');
      expect(result.messages[1].content, 'Hi John! How are you?');
      expect(result.messages[1].timestamp, DateTime(2026, 6, 9, 14, 33));
    });

    test('Parse 12-hour AM/PM format lines', () {
      final lines = [
        '9/6/26, 2:32 PM - John Doe: Afternoon message',
        '09/06/2026, 12:15 AM - Alice: Midnight message',
        '9/6/2026, 12:15 PM - Alice: Noon message',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 3);
      expect(result.messages[0].timestamp, DateTime(2026, 6, 9, 14, 32)); // 2:32 PM -> 14:32
      expect(result.messages[1].timestamp, DateTime(2026, 6, 9, 0, 15));  // 12:15 AM -> 00:15
      expect(result.messages[2].timestamp, DateTime(2026, 6, 9, 12, 15)); // 12:15 PM -> 12:15
    });

    test('Parse multi-line message', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: Line 1',
        'Line 2 of message',
        '   Line 3 with spacing',
        '09/06/2026, 14:33 - Alice: Next message',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.messages[0].sender, 'John Doe');
      expect(result.messages[0].content, 'Line 1\nLine 2 of message\n   Line 3 with spacing');
      expect(result.messages[1].sender, 'Alice');
      expect(result.messages[1].content, 'Next message');
    });

    test('Parse system messages', () {
      final lines = [
        '09/06/2026, 14:32 - Messages and calls are end-to-end encrypted.',
        '09/06/2026, 14:33 - John Doe: Hello!',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.messages[0].isSystem, true);
      expect(result.messages[0].sender, '');
      expect(result.messages[0].content, 'Messages and calls are end-to-end encrypted.');
      expect(result.messages[1].isSystem, false);
      expect(result.messages[1].sender, 'John Doe');
      expect(result.messages[1].content, 'Hello!');
    });

    test('Parse media attachments with different suffixes', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: IMG-20260609-WA0000.jpg (file attached)',
        '09/06/2026, 14:33 - Alice: VID-22.mp4 (file terlampir)',
        '09/06/2026, 14:34 - Bob: STK-3.webp <attached>',
        '09/06/2026, 14:35 - Charlie: doc.pdf (Attached)',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 4);

      expect(result.messages[0].mediaPath, 'IMG-20260609-WA0000.jpg');
      expect(result.messages[0].mediaType, 'image');

      expect(result.messages[1].mediaPath, 'VID-22.mp4');
      expect(result.messages[1].mediaType, 'video');

      expect(result.messages[2].mediaPath, 'STK-3.webp');
      expect(result.messages[2].mediaType, 'sticker');

      expect(result.messages[3].mediaPath, 'doc.pdf');
      expect(result.messages[3].mediaType, 'document');
    });

    test('Parser handles fallback for malformed date string gracefully', () {
      // Line with invalid date/time parts
      final lines = [
        'invalid_date, 14:32 - John Doe: Message 1',
        '09/06/2026, 14:32 - Bob: Message 2',
      ];

      final result = WhatsAppParser.parseLines(lines);

      // The first line doesn't match date/time regex, so it is treated as trash or multi-line.
      // Message 2 should be parsed normally.
      expect(result.messages.length, 2);
      expect(result.messages[0].isSystem, true);
      expect(result.messages[0].content, 'invalid_date, 14:32 - John Doe: Message 1');
      
      expect(result.messages[1].sender, 'Bob');
      expect(result.messages[1].content, 'Message 2');
    });

    test('Parse iOS format lines and media attachments', () {
      final lines = [
        '[09/06/2026, 14:32:01] John Doe: Hello Alice!',
        '[09.06.26, 14:33:05 PM] Alice: <attached: IMG-123.jpg>',
        '[09/06/2026, 14:34:10] Bob: Normal chat log',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 3);
      expect(result.uniqueSenders, containsAll(['John Doe', 'Alice', 'Bob']));
      
      expect(result.messages[0].sender, 'John Doe');
      expect(result.messages[0].content, 'Hello Alice!');
      expect(result.messages[0].timestamp, DateTime(2026, 6, 9, 14, 32));
      expect(result.messages[0].mediaPath, isNull);

      expect(result.messages[1].sender, 'Alice');
      expect(result.messages[1].content, '<attached: IMG-123.jpg>');
      expect(result.messages[1].timestamp, DateTime(2026, 6, 9, 14, 33)); // 14:33 PM -> 14:33
      expect(result.messages[1].mediaPath, 'IMG-123.jpg');
      expect(result.messages[1].mediaType, 'image');

      expect(result.messages[2].sender, 'Bob');
      expect(result.messages[2].content, 'Normal chat log');
      expect(result.messages[2].timestamp, DateTime(2026, 6, 9, 14, 34));
    });
  });
}
