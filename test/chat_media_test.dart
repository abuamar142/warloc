import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  // Setup FFI for SQLite tests in VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Chat Media Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      DatabaseHelper.dbName = ':memory:';
      // Force database recreation by ensuring connection starts closed
      await dbHelper.close();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getMediaMessagesForThread returns only media messages chronologically descending', () async {
      final threadId = await dbHelper.insertThread(
        ChatThread(name: 'Sabina', meName: 'Abu Amar'),
      );

      // 1. Insert text message (no media)
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'Abu Amar',
        content: 'Hello Sabina',
        isSystem: 0,
      ));

      // 2. Insert image message (timestamp: 1686700010000)
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700010000,
        sender: 'Sabina',
        content: 'photo.jpg (file attached)',
        isSystem: 0,
        mediaPath: 'photo.jpg',
        mediaType: 'image',
      ));

      // 3. Insert video message (timestamp: 1686700020000 - newest)
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700020000,
        sender: 'Abu Amar',
        content: 'video.mp4 (file attached)',
        isSystem: 0,
        mediaPath: 'video.mp4',
        mediaType: 'video',
      ));

      // 4. Retrieve media messages
      final mediaMsgs = await dbHelper.getMediaMessagesForThread(threadId);

      // 5. Verify results
      expect(mediaMsgs.length, 2);
      
      // Sorted DESC: newest (video.mp4) first
      expect(mediaMsgs[0].mediaPath, 'video.mp4');
      expect(mediaMsgs[0].mediaType, 'video');
      expect(mediaMsgs[0].timestamp, 1686700020000);

      // Next oldest (photo.jpg)
      expect(mediaMsgs[1].mediaPath, 'photo.jpg');
      expect(mediaMsgs[1].mediaType, 'image');
      expect(mediaMsgs[1].timestamp, 1686700010000);
    });
  });
}
