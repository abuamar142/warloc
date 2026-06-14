import 'package:flutter_test/flutter_test.dart';
import 'package:warloc/utils/telegram_parser.dart';

void main() {
  group('TelegramParser Unit Tests', () {
    test('Parse simple personal chat messages', () {
      final data = {
        "name": "Syila",
        "type": "personal_chat",
        "id": 12345,
        "messages": [
          {
            "id": 1,
            "type": "message",
            "date": "2026-04-11T21:52:06",
            "from": "Syila",
            "from_id": "user123",
            "text": "p"
          },
          {
            "id": 2,
            "type": "message",
            "date": "2026-04-11T21:52:26",
            "from": "Abu Amar",
            "from_id": "user456",
            "text": "halo"
          }
        ]
      };

      final result = TelegramParser.parseMap(data);

      expect(result.messages.length, 2);
      expect(result.uniqueSenders, containsAll(['Syila', 'Abu Amar']));
      expect(result.messages[0].sender, 'Syila');
      expect(result.messages[0].content, 'p');
      expect(result.messages[0].timestamp, DateTime(2026, 4, 11, 21, 52, 6));
      expect(result.messages[0].isSystem, false);

      expect(result.messages[1].sender, 'Abu Amar');
      expect(result.messages[1].content, 'halo');
      expect(result.messages[1].timestamp, DateTime(2026, 4, 11, 21, 52, 26));
      expect(result.messages[1].isSystem, false);
    });

    test('Parse rich text list entities', () {
      final data = {
        "name": "Syila",
        "type": "personal_chat",
        "id": 12345,
        "messages": [
          {
            "id": 3,
            "type": "message",
            "date": "2026-04-11T21:52:35",
            "from": "Syila",
            "from_id": "user123",
            "text": [
              "CHAT GPT PLUS PRIV 1 BULAN\n\n Email: ",
              {
                "type": "email",
                "text": "scan0@bandtoo.com"
              },
              "\n- Password: megahditerima123"
            ]
          }
        ]
      };

      final result = TelegramParser.parseMap(data);

      expect(result.messages.length, 1);
      expect(result.messages[0].content, "CHAT GPT PLUS PRIV 1 BULAN\n\n Email: scan0@bandtoo.com\n- Password: megahditerima123");
    });

    test('Parse system/service messages', () {
      final data = {
        "name": "Syila",
        "type": "personal_chat",
        "id": 12345,
        "messages": [
          {
            "id": 4,
            "type": "service",
            "date": "2026-04-11T21:52:35",
            "text": "Abu Amar joined the group"
          },
          {
            "id": 5,
            "type": "message",
            "date": "2026-04-11T21:53:00",
            "text": "Generic message with no sender"
          }
        ]
      };

      final result = TelegramParser.parseMap(data);

      expect(result.messages.length, 2);
      expect(result.messages[0].isSystem, true);
      expect(result.messages[0].sender, '');
      expect(result.messages[0].content, 'Abu Amar joined the group');

      expect(result.messages[1].isSystem, true);
      expect(result.messages[1].sender, '');
      expect(result.messages[1].content, 'Generic message with no sender');
    });

    test('Parse media attachments (photos, files, stickers, voice)', () {
      final data = {
        "name": "Syila",
        "type": "personal_chat",
        "id": 12345,
        "messages": [
          {
            "id": 6,
            "type": "message",
            "date": "2026-04-11T21:54:20",
            "from": "Abu Amar",
            "photo": "photos/photo_1@11-04-2026_21-54-20.jpg",
            "text": ""
          },
          {
            "id": 7,
            "type": "message",
            "date": "2026-04-11T21:55:00",
            "from": "Syila",
            "file": "stickers/animated_sticker.webp",
            "media_type": "sticker",
            "text": ""
          },
          {
            "id": 8,
            "type": "message",
            "date": "2026-04-11T21:56:00",
            "from": "Syila",
            "file": "audio/voice.ogg",
            "media_type": "voice_message",
            "text": ""
          }
        ]
      };

      final result = TelegramParser.parseMap(data);

      expect(result.messages.length, 3);
      
      expect(result.messages[0].mediaPath, 'photo_1@11-04-2026_21-54-20.jpg');
      expect(result.messages[0].mediaType, 'image');

      expect(result.messages[1].mediaPath, 'animated_sticker.webp');
      expect(result.messages[1].mediaType, 'sticker');

      expect(result.messages[2].mediaPath, 'voice.ogg');
      expect(result.messages[2].mediaType, 'audio');
    });
  });
}
