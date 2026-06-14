import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/database/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  // Setup FFI for SQLite tests in VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Sender Merging Tests', () {
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

    test('getUniqueSendersForThread and mergeSenders work correctly', () async {
      // 1. Create a thread
      final threadId = await dbHelper.insertThread(
        ChatThread(name: 'Sabina', meName: 'Abu Amar'),
      );

      // 2. Insert messages from different senders
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'Abu Amar',
        content: 'Halo Sabina',
        isSystem: 0,
      ));

      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700010000,
        sender: 'Orang 2',
        content: 'Halo juga',
        isSystem: 0,
      ));

      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700020000,
        sender: 'Orang 3',
        content: 'Ini siapa ya?',
        isSystem: 0,
      ));

      // 3. Verify unique senders in database
      final sendersBefore = await dbHelper.getUniqueSendersForThread(threadId);
      expect(sendersBefore.length, 3);
      expect(sendersBefore, containsAll(['Abu Amar', 'Orang 2', 'Orang 3']));

      // 4. Perform merging:
      // Map 'Orang 2' to 'Abu Amar' (Me)
      // Map 'Orang 3' to 'Sabina' (Contact)
      final mappings = {
        'Abu Amar': 'Abu Amar',
        'Orang 2': 'Abu Amar',
        'Orang 3': 'Sabina',
      };

      await dbHelper.mergeSenders(
        threadId: threadId,
        newThreadName: 'Sabina',
        newMeName: 'Abu Amar',
        senderMappings: mappings,
      );

      // 5. Verify unique senders after merging
      final sendersAfter = await dbHelper.getUniqueSendersForThread(threadId);
      expect(sendersAfter.length, 2);
      expect(sendersAfter, containsAll(['Abu Amar', 'Sabina']));
      expect(sendersAfter, isNot(contains('Orang 2')));
      expect(sendersAfter, isNot(contains('Orang 3')));

      // 6. Verify messages in database are updated
      final messages = await dbHelper.getMessagesForThread(threadId);
      expect(messages.length, 3);

      expect(messages[0].sender, 'Abu Amar');
      expect(messages[0].content, 'Halo Sabina');

      expect(messages[1].sender, 'Abu Amar');
      expect(messages[1].content, 'Halo juga');

      expect(messages[2].sender, 'Sabina');
      expect(messages[2].content, 'Ini siapa ya?');
    });
  });
}
