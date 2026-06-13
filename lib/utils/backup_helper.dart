import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/chat_message.dart';

class BackupHelper {
  /// Packs the SQLite database and all media files into a ZIP backup at [outputPath]
  static Future<void> createBackup(String outputPath) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    // 1. Add database file
    final dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('warloc_chats.db', dbBytes.length, dbBytes));
    }

    // 2. Add media folder recursively
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media'));
    if (await mediaDir.exists()) {
      final List<FileSystemEntity> entities = mediaDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: appDir.path);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }
    }

    final zipBytes = encoder.encode(archive);
    final outFile = File(outputPath);
    await outFile.create(recursive: true);
    await outFile.writeAsBytes(zipBytes);
  }

  /// Restores the backup by CLOSING the active database, DELETING all current data,
  /// and replacing it completely with the backup contents.
  static Future<bool> restoreBackupOverwrite(String backupPath) async {
    try {
      final bytes = await File(backupPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify backup contains the database
      bool hasDb = false;
      for (final file in archive) {
        if (file.name == 'warloc_chats.db') {
          hasDb = true;
          break;
        }
      }

      if (!hasDb) return false;

      // Close the current database connection
      await DatabaseHelper.instance.close();

      final dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
      final appDir = await getApplicationDocumentsDirectory();

      // Delete existing media directory to do a clean overwrite
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }

      // Write files from backup
      for (final file in archive) {
        final data = file.content as List<int>;
        if (file.name == 'warloc_chats.db') {
          await deleteDatabase(dbPath);
          final dbFile = File(dbPath);
          await dbFile.create(recursive: true);
          await dbFile.writeAsBytes(data);
        } else if (file.name.startsWith('media/')) {
          final targetPath = p.join(appDir.path, file.name);
          final mediaFile = File(targetPath);
          await mediaFile.create(recursive: true);
          await mediaFile.writeAsBytes(data);
        }
      }

      // Re-initialize/open the database
      await DatabaseHelper.instance.database;
      return true;
    } catch (e) {
      debugPrint("Gagal memulihkan cadangan (overwrite): $e");
      // Attempt to re-open the database anyway to avoid leaving the app in a broken state
      try {
        await DatabaseHelper.instance.database;
      } catch (_) {}
      return false;
    }
  }

  /// Restores the backup by extracting the backup database to a temporary location,
  /// reading its threads/messages, and merging them into the active database.
  /// Skips duplicate messages and copies only new/unique media files.
  static Future<bool> restoreBackupMerge(String backupPath) async {
    Directory? tempDir;
    Database? tempDb;
    try {
      final bytes = await File(backupPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Verify backup contains database
      bool hasDb = false;
      for (final file in archive) {
        if (file.name == 'warloc_chats.db') {
          hasDb = true;
          break;
        }
      }

      if (!hasDb) return false;

      // 2. Extract backup contents to temporary cache folder
      final systemTempDir = await getTemporaryDirectory();
      tempDir = Directory(p.join(systemTempDir.path, 'warloc_merge_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);

      for (final file in archive) {
        final data = file.content as List<int>;
        final targetPath = p.join(tempDir.path, file.name);
        final fileEntity = File(targetPath);
        await fileEntity.create(recursive: true);
        await fileEntity.writeAsBytes(data);
      }

      // 3. Open temporary database connection
      final tempDbPath = p.join(tempDir.path, 'warloc_chats.db');
      tempDb = await openDatabase(tempDbPath);

      // 4. Query threads from temporary backup database
      final List<Map<String, dynamic>> tempThreadsMap = await tempDb.query('threads');
      final dbHelper = DatabaseHelper.instance;
      final mainDb = await dbHelper.database;
      final appDir = await getApplicationDocumentsDirectory();

      for (final threadMap in tempThreadsMap) {
        final oldThreadId = threadMap['id'] as int;
        final threadName = threadMap['name'] as String;
        final threadMeName = threadMap['meName'] as String;

        // Check if thread already exists in the active database
        final existingThreads = await mainDb.query(
          'threads',
          where: 'name = ?',
          whereArgs: [threadName],
        );

        int targetThreadId;
        if (existingThreads.isNotEmpty) {
          targetThreadId = existingThreads.first['id'] as int;
        } else {
          // Insert new thread into the active database
          targetThreadId = await mainDb.insert('threads', {
            'name': threadName,
            'meName': threadMeName,
          });
        }

        // Query messages of this thread from the temporary database
        final List<Map<String, dynamic>> tempMessagesMap = await tempDb.query(
          'messages',
          where: 'threadId = ?',
          whereArgs: [oldThreadId],
        );

        for (final msgMap in tempMessagesMap) {
          // Construct message without preserving database ID so that target DB autoincrements it.
          // Map it to our new target thread ID.
          final ChatMessage msg = ChatMessage(
            threadId: targetThreadId,
            timestamp: msgMap['timestamp'] as int,
            sender: msgMap['sender'] as String,
            content: msgMap['content'] as String,
            isSystem: msgMap['isSystem'] as int,
            mediaPath: msgMap['mediaPath'] as String?,
            mediaType: msgMap['mediaType'] as String?,
          );

          // Insert if unique
          final insertedId = await dbHelper.insertMessageIfUnique(msg);

          // Copy media if inserted successfully and the message has media
          if (insertedId != null && msg.hasMedia) {
            final sourceMediaFile = File(p.join(tempDir.path, 'media', oldThreadId.toString(), msg.mediaPath!));
            if (await sourceMediaFile.exists()) {
              final targetMediaDir = Directory(p.join(appDir.path, 'media', targetThreadId.toString()));
              if (!await targetMediaDir.exists()) {
                await targetMediaDir.create(recursive: true);
              }
              final targetMediaPath = p.join(targetMediaDir.path, msg.mediaPath!);
              await sourceMediaFile.copy(targetMediaPath);
            }
          }
        }
      }

      // 5. Clean up temporary resources
      await tempDb.close();
      tempDb = null;
      await tempDir.delete(recursive: true);
      tempDir = null;

      return true;
    } catch (e) {
      debugPrint("Gagal menggabungkan cadangan: $e");
      if (tempDb != null) {
        try {
          await tempDb.close();
        } catch (_) {}
      }
      if (tempDir != null && tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
      return false;
    }
  }
}
