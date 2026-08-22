import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  // Setup FFI for SQLite tests in VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Chat Search Tests', () {
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

    test('getMessageIndexInThread and searchMessagesPaginated work correctly', () async {
      final threadId = await dbHelper.insertThread(
        ChatThread(name: 'Sabina', meName: 'Abu Amar'),
      );

      final List<int> messageIds = [];

      // 1. Insert 10 sequential messages
      for (int i = 1; i <= 10; i++) {
        final id = await dbHelper.insertMessageIfUnique(ChatMessage(
          threadId: threadId,
          timestamp: 1686700000000 + i * 1000,
          sender: i % 2 == 0 ? 'Sabina' : 'Abu Amar',
          content: 'Ini pesan keyword $i',
          isSystem: 0,
        ));
        expect(id, isNotNull);
        messageIds.add(id!);
      }

      // 2. Test getMessageIndexInThread for the 5th message (messageIds[4], timestamp: 1686700005000)
      // Since it's sorted DESC (newest first), the number of newer messages should be exactly 5 (messages 6, 7, 8, 9, 10 are newer)
      final index = await dbHelper.getMessageIndexInThread(
        threadId,
        messageIds[4],
        1686700000000 + 5 * 1000,
      );
      expect(index, 5);

      // 3. Test searchMessagesPaginated
      // Query "keyword" returns all 10 messages.
      // With limit 3, offset 1, it should skip the newest one (10) and return 9, 8, 7.
      final searchResults = await dbHelper.searchMessagesPaginated(
        threadId: threadId,
        query: 'keyword',
        limit: 3,
        offset: 1,
      );

      expect(searchResults.length, 3);
      expect(searchResults[0].content, contains('9'));
      expect(searchResults[1].content, contains('8'));
      expect(searchResults[2].content, contains('7'));
    });
  });
}
