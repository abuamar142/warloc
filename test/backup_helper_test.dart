import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/chat_thread.dart';
import 'package:warloc/data/backup_helper.dart';

void main() {
  // Initialize Flutter binding first
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for local SQLite tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('BackupHelper Tests', () {
    late Directory tempDocsDir;
    late String backupPath;
    late String testDbName;

    setUp(() async {
      // Create isolated temporary directory representing app documents dir
      tempDocsDir = await Directory.systemTemp.createTemp('warloc_backup_test_dir');
      backupPath = p.join(tempDocsDir.path, 'backup.wlb');
      testDbName = 'warloc_chats_backup_test.db';

      // Set testing db name
      DatabaseHelper.dbName = testDbName;
      // Close any active instance connections
      await DatabaseHelper.instance.close();

      // Clean databases directory to prevent test pollution
      final localDbPath = p.join(await getDatabasesPath(), testDbName);
      await deleteDatabase(localDbPath);

      // Mock PathProvider to return our isolated folder
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory' ||
              methodCall.method == 'getTemporaryDirectory') {
            return tempDocsDir.path;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      await DatabaseHelper.instance.close();
      if (await tempDocsDir.exists()) {
        await tempDocsDir.delete(recursive: true);
      }
    });

    test('createBackup packs SQLite db and media folder recursively', () async {
      // 1. Initialize database and insert test records
      final dbHelper = DatabaseHelper.instance;
      final threadId = await dbHelper.insertThread(ChatThread(name: 'Alice', meName: 'Me'));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId,
        timestamp: 1686700000000,
        sender: 'Alice',
        content: 'Hi Bob',
        isSystem: 0,
      ));

      // 2. Create media files under our mock documents dir
      final mediaDir = Directory(p.join(tempDocsDir.path, 'media', threadId.toString()));
      await mediaDir.create(recursive: true);
      final sampleMedia = File(p.join(mediaDir.path, 'photo.jpg'));
      await sampleMedia.writeAsBytes([1, 2, 3, 4, 5]);

      // Close connection so SQLite writes all data to disk cleanly before we back it up
      await dbHelper.close();

      // 3. Create the backup file
      await BackupHelper.createBackup(backupPath);

      // Verify the backup file was created
      final backupFile = File(backupPath);
      expect(await backupFile.exists(), true);

      // Verify backup is a valid ZIP with expected internal layout
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      bool foundDb = false;
      bool foundMedia = false;

      for (final file in archive) {
        if (file.name == 'warloc_chats.db') {
          foundDb = true;
        } else if (file.name == 'media/$threadId/photo.jpg') {
          foundMedia = true;
        }
      }

      expect(foundDb, true);
      expect(foundMedia, true);
    });

    test('restoreBackupOverwrite replaces existing db and media completely', () async {
      final dbHelper = DatabaseHelper.instance;

      // 1. Set up source data
      final sourceThreadId = await dbHelper.insertThread(ChatThread(name: 'Source', meName: 'Me'));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: sourceThreadId,
        timestamp: 1686700000000,
        sender: 'Source',
        content: 'Source Message',
        isSystem: 0,
      ));
      final sourceMediaDir = Directory(p.join(tempDocsDir.path, 'media', sourceThreadId.toString()));
      await sourceMediaDir.create(recursive: true);
      await File(p.join(sourceMediaDir.path, 'photo.jpg')).writeAsBytes([9, 8, 7]);

      await dbHelper.close();
      await BackupHelper.createBackup(backupPath);

      // 2. Clear out local state and populate with newer different/garbage data
      final freshDbHelper = DatabaseHelper.instance;
      final newThreadId = await freshDbHelper.insertThread(ChatThread(name: 'Garbage', meName: 'Me'));
      final newMediaDir = Directory(p.join(tempDocsDir.path, 'media', newThreadId.toString()));
      await newMediaDir.create(recursive: true);
      await File(p.join(newMediaDir.path, 'trash.txt')).writeAsBytes([0]);

      // 3. Perform Overwrite Restore
      final success = await BackupHelper.restoreBackupOverwrite(backupPath);
      expect(success, true);

      // 4. Verify local state matches the backup exactly
      final activeThreads = await DatabaseHelper.instance.getThreads();
      expect(activeThreads.length, 1);
      expect(activeThreads.first.name, 'Source');

      // Verify garbage media was deleted and backup media was restored
      expect(await Directory(p.join(tempDocsDir.path, 'media', newThreadId.toString())).exists(), false);
      expect(await File(p.join(tempDocsDir.path, 'media', sourceThreadId.toString(), 'photo.jpg')).exists(), true);
    });

    test('restoreBackupMerge merges threads, deduplicates messages, and copies media', () async {
      final dbHelper = DatabaseHelper.instance;

      // 1. Build initial dataset and back it up
      final threadId1 = await dbHelper.insertThread(ChatThread(name: 'Shared Thread', meName: 'Me'));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId1,
        timestamp: 1000,
        sender: 'Alice',
        content: 'Common message',
        isSystem: 0,
      ));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: threadId1,
        timestamp: 2000,
        sender: 'Alice',
        content: 'Backup-only message with media',
        isSystem: 0,
        mediaPath: 'pic.jpg',
        mediaType: 'image',
      ));
      final mediaDir1 = Directory(p.join(tempDocsDir.path, 'media', threadId1.toString()));
      await mediaDir1.create(recursive: true);
      await File(p.join(mediaDir1.path, 'pic.jpg')).writeAsBytes([1, 1, 1]);

      await dbHelper.close();
      await BackupHelper.createBackup(backupPath);

      // 2. Modify local database: delete backup-only msg, keep common, and add a local-only message
      await DatabaseHelper.instance.database; // Reopen
      // Clear media directories to verify copy media behavior later
      await mediaDir1.delete(recursive: true);

      // The database was closed, let's reopen and recreate states
      await dbHelper.close();
      final localDbPath = p.join(await getDatabasesPath(), testDbName);
      await deleteDatabase(localDbPath);

      // Repopulate local DB with shared thread and common message, plus a new local-only message
      final localThreadId = await dbHelper.insertThread(ChatThread(name: 'Shared Thread', meName: 'Me'));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: localThreadId,
        timestamp: 1000,
        sender: 'Alice',
        content: 'Common message', // Identical duplicate
        isSystem: 0,
      ));
      await dbHelper.insertMessageIfUnique(ChatMessage(
        threadId: localThreadId,
        timestamp: 3000,
        sender: 'Alice',
        content: 'Local-only unique message',
        isSystem: 0,
      ));

      // 3. Perform Merge
      final success = await BackupHelper.restoreBackupMerge(backupPath);
      expect(success, true);

      // 4. Verify results
      final threads = await dbHelper.getThreads();
      expect(threads.length, 1); // No duplicate threads by name

      final messages = await dbHelper.getMessagesForThread(localThreadId);
      // Expected messages:
      // 1. Common message (timestamp: 1000)
      // 2. Backup-only message (timestamp: 2000) - MERGED
      // 3. Local-only unique message (timestamp: 3000) - KEPT
      expect(messages.length, 3);
      
      expect(messages[0].content, 'Common message');
      expect(messages[1].content, 'Backup-only message with media');
      expect(messages[2].content, 'Local-only unique message');

      // Verify media file was copied to localThreadId media folder
      final expectedMediaPath = p.join(tempDocsDir.path, 'media', localThreadId.toString(), 'pic.jpg');
      expect(await File(expectedMediaPath).exists(), true);
    });
  });
}
