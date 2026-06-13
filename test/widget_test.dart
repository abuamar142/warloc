import 'package:flutter_test/flutter_test.dart';
import 'package:warloc/utils/whatsapp_parser.dart';

void main() {
  group('WhatsAppParser Tests', () {
    test('Parse simple chat lines', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: Hello Alice!',
        '09/06/2026, 14:33 - Alice: Hi John! How are you?',
        '09/06/2026, 14:35 - Alice: Let\'s meet tomorrow.',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 3);
      expect(result.uniqueSenders, containsAll(['John Doe', 'Alice']));
      expect(result.messages[0].sender, 'John Doe');
      expect(result.messages[0].content, 'Hello Alice!');
      expect(result.messages[0].isSystem, false);
      expect(result.messages[1].sender, 'Alice');
      expect(result.messages[1].content, 'Hi John! How are you?');
      expect(result.messages[1].isSystem, false);
    });

    test('Parse multi-line message', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: Line 1',
        'Line 2 of message',
        'Line 3 of message',
        '09/06/2026, 14:33 - Alice: Replying to John',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.messages[0].sender, 'John Doe');
      expect(result.messages[0].content, 'Line 1\nLine 2 of message\nLine 3 of message');
      expect(result.messages[1].sender, 'Alice');
      expect(result.messages[1].content, 'Replying to John');
    });

    test('Parse system messages', () {
      final lines = [
        '09/06/2026, 14:32 - Messages and calls are end-to-end encrypted.',
        '09/06/2026, 14:33 - John Doe: Hello!',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.messages[0].isSystem, true);
      expect(result.messages[0].content, 'Messages and calls are end-to-end encrypted.');
      expect(result.messages[1].isSystem, false);
      expect(result.messages[1].sender, 'John Doe');
      expect(result.messages[1].content, 'Hello!');
    });

    test('Parse media attachments', () {
      final lines = [
        '09/06/2026, 14:32 - John Doe: IMG-20260609-WA0000.jpg (file attached)',
        '09/06/2026, 14:33 - Alice: VID-20260611-WA0008.mp4 (file terlampir)',
      ];

      final result = WhatsAppParser.parseLines(lines);

      expect(result.messages.length, 2);
      expect(result.messages[0].mediaPath, 'IMG-20260609-WA0000.jpg');
      expect(result.messages[0].mediaType, 'image');
      expect(result.messages[1].mediaPath, 'VID-20260611-WA0008.mp4');
      expect(result.messages[1].mediaType, 'video');
    });
  });
}
