import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/database/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  // Setup FFI for SQLite tests in VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper CRUD Tests', () {
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

    test('Thread CRUD operations work correctly', () async {
      // 1. Insert Thread
      final thread = ChatThread(name: 'Alice Group', meName: 'Me');
      final id = await dbHelper.insertThread(thread);
      expect(id, isPositive);

      // 2. Get Thread
      final fetched = await dbHelper.getThread(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Alice Group');
      expect(fetched.meName, 'Me');

      // 3. Update Thread
      final updatedThread = fetched.copyWith(name: 'Alice & Bob Group');
      final rowsUpdated = await dbHelper.updateThread(updatedThread);
      expect(rowsUpdated, 1);

      final fetchedUpdated = await dbHelper.getThread(id);
      expect(fetchedUpdated!.name, 'Alice & Bob Group');

      // 4. Get all threads
      final threads = await dbHelper.getThreads();
      expect(threads.length, 1);
      expect(threads.first.id, id);

      // 5. Delete Thread
      final rowsDeleted = await dbHelper.deleteThread(id);
      expect(rowsDeleted, 1);

      final fetchedDeleted = await dbHelper.getThread(id);
      expect(fetchedDeleted, isNull);
    });

    test('Message deduplication and retrieval logic', () async {
      // Create a thread first
      final threadId = await dbHelper.insertThread(ChatThread(name: 'John', meName: 'Me'));

      final msg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'John',
        content: 'Unique message text',
        isSystem: 0,
      );

      // 1. Insert unique message
      final insertedId = await dbHelper.insertMessageIfUnique(msg);
      expect(insertedId, isNotNull);

      // 2. Attempt duplicate insert (same thread, timestamp, sender, content)
      final duplicateId = await dbHelper.insertMessageIfUnique(msg);
      expect(duplicateId, isNull); // Duplicate should be skipped

      // 3. Retrieve messages
      final messages = await dbHelper.getMessagesForThread(threadId);
      expect(messages.length, 1);
      expect(messages.first.id, insertedId);

      // 4. Message count
      final count = await dbHelper.getMessageCountForThread(threadId);
      expect(count, 1);

      // 5. Last message
      final lastMsg = await dbHelper.getLastMessageForThread(threadId);
      expect(lastMsg, isNotNull);
      expect(lastMsg!.id, insertedId);
    });

    test('Message pagination and search', () async {
      final threadId = await dbHelper.insertThread(ChatThread(name: 'Paging', meName: 'Me'));

      // Insert 5 messages with sequential timestamps
      for (int i = 1; i <= 5; i++) {
        await dbHelper.insertMessageIfUnique(ChatMessage(
          threadId: threadId,
          timestamp: 1686700000000 + i * 1000,
          sender: 'Paging',
          content: 'Message number $i keyword',
          isSystem: 0,
        ));
      }

      // Paginate: get 2 messages starting from offset 1 (skipping the absolute newest 1)
      // Order: newest (timestamp DESC) -> 5, 4, 3, 2, 1. Offset 1 starts at 4. Limit 2 returns 4 and 3.
      // And reversed at the end inside getMessagesForThreadPaginated so it returns [3, 4] chronological.
      final paged = await dbHelper.getMessagesForThreadPaginated(threadId, 2, 1);
      expect(paged.length, 2);
      expect(paged[0].content, contains('3'));
      expect(paged[1].content, contains('4'));

      // Search keyword
      final searchResults = await dbHelper.searchMessages(threadId, 'keyword');
      expect(searchResults.length, 5);

      final searchResultsSpecific = await dbHelper.searchMessages(threadId, 'number 3');
      expect(searchResultsSpecific.length, 1);
    });
  });
}
