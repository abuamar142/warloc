import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_message.dart';

class BackupHelper {
  /// Packs the SQLite database and all media files into a ZIP backup at [outputPath]
  static Future<void> createBackup(String outputPath) async {
    final dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
    final appDir = await getApplicationDocumentsDirectory();

    await compute(_createBackupIsolate, (
      dbPath: dbPath,
      appDirPath: appDir.path,
      outputPath: outputPath,
    ));
  }

  static void _createBackupIsolate(({String dbPath, String appDirPath, String outputPath}) params) {
    final encoder = ZipEncoder();
    final archive = Archive();

    // 1. Add database file
    final dbFile = File(params.dbPath);
    if (dbFile.existsSync()) {
      final dbBytes = dbFile.readAsBytesSync();
      archive.addFile(ArchiveFile('warloc_chats.db', dbBytes.length, dbBytes));
    }

    // 2. Add media folder recursively
    final mediaDir = Directory(p.join(params.appDirPath, 'media'));
    if (mediaDir.existsSync()) {
      final List<FileSystemEntity> entities = mediaDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: params.appDirPath);
          final bytes = entity.readAsBytesSync();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }
    }

    final zipBytes = encoder.encode(archive);
    final outFile = File(params.outputPath);
    outFile.createSync(recursive: true);
    outFile.writeAsBytesSync(zipBytes);
  }

  /// Restores the backup by CLOSING the active database, DELETING all current data,
  /// and replacing it completely with the backup contents.
  static Future<bool> restoreBackupOverwrite(String backupPath) async {
    try {
      // Close the current database connection
      await DatabaseHelper.instance.close();

      final dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
      final appDir = await getApplicationDocumentsDirectory();

      // Delete existing media directory to do a clean overwrite
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }

      await deleteDatabase(dbPath);

      final success = await compute(_restoreBackupIsolate, (
        backupPath: backupPath,
        dbPath: dbPath,
        appDirPath: appDir.path,
      ));

      // Re-initialize/open the database
      await DatabaseHelper.instance.database;
      return success;
    } catch (e) {
      debugPrint("Gagal memulihkan cadangan (overwrite): $e");
      // Attempt to re-open the database anyway to avoid leaving the app in a broken state
      try {
        await DatabaseHelper.instance.database;
      } catch (e) {
        debugPrint("Gagal membuka kembali database setelah pemulihan gagal: $e");
      }
      return false;
    }
  }

  static bool _restoreBackupIsolate(({String backupPath, String dbPath, String appDirPath}) params) {
    try {
      final bytes = File(params.backupPath).readAsBytesSync();
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

      // Write files from backup
      for (final file in archive) {
        final data = file.content as List<int>;
        if (file.name == 'warloc_chats.db') {
          final dbFile = File(params.dbPath);
          dbFile.createSync(recursive: true);
          dbFile.writeAsBytesSync(data);
        } else if (file.name.startsWith('media/')) {
          final targetPath = p.join(params.appDirPath, file.name);
          final mediaFile = File(targetPath);
          mediaFile.createSync(recursive: true);
          mediaFile.writeAsBytesSync(data);
        }
      }
      return true;
    } catch (e) {
      debugPrint("Isolate restore error: $e");
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
      // Extract backup contents to temporary cache folder using isolate
      final systemTempDir = await getTemporaryDirectory();
      tempDir = Directory(p.join(systemTempDir.path, 'warloc_merge_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);

      final extractSuccess = await compute(_extractZipIsolate, (
        backupPath: backupPath,
        targetDir: tempDir.path,
      ));

      if (!extractSuccess) {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
        return false;
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

        // Process message inserts in transactional batches for speed!
        final List<ChatMessage> batchMessages = [];
        for (final msgMap in tempMessagesMap) {
          batchMessages.add(ChatMessage(
            threadId: targetThreadId,
            timestamp: msgMap['timestamp'] as int,
            sender: msgMap['sender'] as String,
            content: msgMap['content'] as String,
            isSystem: msgMap['isSystem'] as int,
            mediaPath: msgMap['mediaPath'] as String?,
            mediaType: msgMap['mediaType'] as String?,
          ));
        }

        if (batchMessages.isNotEmpty) {
          await dbHelper.insertBatchIfUnique(
            batchMessages,
            threadMeName: threadMeName,
            importMeName: threadMeName, // Inside same thread context
          );
        }

        // Copy media if the message has media
        for (final msgMap in tempMessagesMap) {
          final mediaPath = msgMap['mediaPath'] as String?;
          if (mediaPath != null && mediaPath.isNotEmpty) {
            final sourceMediaFile = File(p.join(tempDir.path, 'media', oldThreadId.toString(), mediaPath));
            if (await sourceMediaFile.exists()) {
              final targetMediaDir = Directory(p.join(appDir.path, 'media', targetThreadId.toString()));
              if (!await targetMediaDir.exists()) {
                await targetMediaDir.create(recursive: true);
              }
              final targetMediaPath = p.join(targetMediaDir.path, mediaPath);
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
        } catch (e) {
          debugPrint("Gagal menutup database sementara: $e");
        }
      }
      if (tempDir != null && tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          debugPrint("Gagal menghapus direktori sementara: $e");
        }
      }
      return false;
    }
  }

  static bool _extractZipIsolate(({String backupPath, String targetDir}) params) {
    try {
      final bytes = File(params.backupPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      bool hasDb = false;
      for (final file in archive) {
        if (file.name == 'warloc_chats.db') {
          hasDb = true;
          break;
        }
      }

      if (!hasDb) return false;

      for (final file in archive) {
        final data = file.content as List<int>;
        final targetPath = p.join(params.targetDir, file.name);
        final fileEntity = File(targetPath);
        fileEntity.createSync(recursive: true);
        fileEntity.writeAsBytesSync(data);
      }
      return true;
    } catch (e) {
      debugPrint("Isolate extract zip error: $e");
      return false;
    }
  }
}
