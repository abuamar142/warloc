import 'package:flutter_test/flutter_test.dart';
import 'package:warloc/models/chat_message.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('Constructor creates instance with correct properties', () {
      final msg = ChatMessage(
        id: 1,
        threadId: 2,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hello World',
        isSystem: 0,
        mediaPath: 'image.jpg',
        mediaType: 'image',
      );

      expect(msg.id, 1);
      expect(msg.threadId, 2);
      expect(msg.timestamp, 1686700000000);
      expect(msg.sender, 'Alice');
      expect(msg.content, 'Hello World');
      expect(msg.isSystem, 0);
      expect(msg.mediaPath, 'image.jpg');
      expect(msg.mediaType, 'image');
    });

    test('isSystemMessage getter returns true when isSystem is 1', () {
      final msg1 = ChatMessage(
        threadId: 1,
        timestamp: 1686700000000,
        sender: '',
        content: 'Security notification',
        isSystem: 1,
      );
      final msg2 = ChatMessage(
        threadId: 1,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hi',
        isSystem: 0,
      );

      expect(msg1.isSystemMessage, true);
      expect(msg2.isSystemMessage, false);
    });

    test('hasMedia getter returns true when mediaPath is present and not empty', () {
      final msgWithMedia = ChatMessage(
        threadId: 1,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Check this out',
        isSystem: 0,
        mediaPath: 'pic.png',
        mediaType: 'image',
      );
      final msgNoMedia = ChatMessage(
        threadId: 1,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hi',
        isSystem: 0,
      );
      final msgEmptyMedia = ChatMessage(
        threadId: 1,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hi',
        isSystem: 0,
        mediaPath: '',
      );

      expect(msgWithMedia.hasMedia, true);
      expect(msgNoMedia.hasMedia, false);
      expect(msgEmptyMedia.hasMedia, false);
    });

    test('toMap() converts object into map correctly', () {
      final msg1 = ChatMessage(
        id: 10,
        threadId: 2,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Test message',
        isSystem: 0,
        mediaPath: 'file.pdf',
        mediaType: 'document',
      );
      final map1 = msg1.toMap();

      expect(map1['id'], 10);
      expect(map1['threadId'], 2);
      expect(map1['timestamp'], 1686700000000);
      expect(map1['sender'], 'Alice');
      expect(map1['content'], 'Test message');
      expect(map1['isSystem'], 0);
      expect(map1['mediaPath'], 'file.pdf');
      expect(map1['mediaType'], 'document');

      final msgNoId = ChatMessage(
        threadId: 2,
        timestamp: 1686700000000,
        sender: 'Bob',
        content: 'No ID message',
        isSystem: 0,
      );
      final mapNoId = msgNoId.toMap();
      expect(mapNoId.containsKey('id'), false);
    });

    test('fromMap() constructs instance from map correctly', () {
      final Map<String, dynamic> map = {
        'id': 100,
        'threadId': 3,
        'timestamp': 1686700000000,
        'sender': 'Bob',
        'content': 'JSON test',
        'isSystem': 0,
        'mediaPath': 'audio.opus',
        'mediaType': 'audio',
      };
      final msg = ChatMessage.fromMap(map);

      expect(msg.id, 100);
      expect(msg.threadId, 3);
      expect(msg.timestamp, 1686700000000);
      expect(msg.sender, 'Bob');
      expect(msg.content, 'JSON test');
      expect(msg.isSystem, 0);
      expect(msg.mediaPath, 'audio.opus');
      expect(msg.mediaType, 'audio');
    });

    test('copyWith() returns new instance with updated properties', () {
      final msg = ChatMessage(
        id: 1,
        threadId: 2,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hi',
        isSystem: 0,
      );

      final updatedMsg = msg.copyWith(
        id: 99,
        content: 'Hello',
        mediaPath: 'test.png',
        mediaType: 'image',
      );

      // Verify updated properties
      expect(updatedMsg.id, 99);
      expect(updatedMsg.content, 'Hello');
      expect(updatedMsg.mediaPath, 'test.png');
      expect(updatedMsg.mediaType, 'image');

      // Verify unchanged properties are kept
      expect(updatedMsg.threadId, 2);
      expect(updatedMsg.timestamp, 1686700000000);
      expect(updatedMsg.sender, 'Alice');
      expect(updatedMsg.isSystem, 0);
    });
  });
}
