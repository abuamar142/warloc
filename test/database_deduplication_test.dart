import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/database/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  // Setup FFI for SQLite tests in VM
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Smart Deduplication Tests', () {
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

    test('Normal backward-compatible exact duplicate check works (no meNames passed)', () async {
      final threadId = await dbHelper.insertThread(ChatThread(name: 'John', meName: 'Me'));

      final msg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'John',
        content: 'Unique message text',
        isSystem: 0,
      );

      final insertedId = await dbHelper.insertMessageIfUnique(msg);
      expect(insertedId, isNotNull);

      // Duplicate should be skipped
      final duplicateId = await dbHelper.insertMessageIfUnique(msg);
      expect(duplicateId, isNull);
    });

    test('Smart role-based deduplication matches duplicates within 60 seconds with same role', () async {
      final threadId = await dbHelper.insertThread(ChatThread(name: 'Syila', meName: 'Abu Amar'));

      // 1. WhatsApp-like message: seconds are 00 (timestamp: 1686700000000)
      // Sender: "Abu Amar" (matches thread's meName -> 'me' role)
      final waMsg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000, // 2023-06-13 23:46:40 UTC
        sender: 'Abu Amar',
        content: 'Halo apa kabar',
        isSystem: 0,
      );
      final waId = await dbHelper.insertMessageIfUnique(
        waMsg,
        threadMeName: 'Abu Amar',
        importMeName: 'Abu Amar',
      );
      expect(waId, isNotNull);

      // 2. Telegram-like message: seconds are non-zero (timestamp: 1686700000000 + 15000 -> 15 seconds later)
      // Sender: "Abu Amar" (matches importMeName -> 'me' role)
      final teleMsg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000 + 15000, // 15 seconds later
        sender: 'Abu Amar',
        content: 'Halo apa kabar',
        isSystem: 0,
      );
      final teleId = await dbHelper.insertMessageIfUnique(
        teleMsg,
        threadMeName: 'Abu Amar',
        importMeName: 'Abu Amar',
      );
      expect(teleId, isNull); // Must be detected as a duplicate and skipped!

      // 3. Telegram-like message: different sender role ('other' role)
      // Sender: "Syila" (does not match importMeName -> 'other' role)
      final otherMsg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000 + 15000,
        sender: 'Syila',
        content: 'Halo apa kabar',
        isSystem: 0,
      );
      final otherId = await dbHelper.insertMessageIfUnique(
        otherMsg,
        threadMeName: 'Abu Amar',
        importMeName: 'Abu Amar',
      );
      expect(otherId, isNotNull); // Inserted successfully because the roles are different!
    });

    test('Smart role-based deduplication allows messages beyond 60 seconds with same content', () async {
      final threadId = await dbHelper.insertThread(ChatThread(name: 'Syila', meName: 'Abu Amar'));

      final firstMsg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'Abu Amar',
        content: 'Halo',
        isSystem: 0,
      );
      final id1 = await dbHelper.insertMessageIfUnique(
        firstMsg,
        threadMeName: 'Abu Amar',
        importMeName: 'Abu Amar',
      );
      expect(id1, isNotNull);

      // Second message sent 61 seconds later (61000ms)
      final secondMsg = ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000 + 61000,
        sender: 'Abu Amar',
        content: 'Halo',
        isSystem: 0,
      );
      final id2 = await dbHelper.insertMessageIfUnique(
        secondMsg,
        threadMeName: 'Abu Amar',
        importMeName: 'Abu Amar',
      );
      expect(id2, isNotNull); // Inserted successfully because time gap > 60 seconds!
    });
  });
}
