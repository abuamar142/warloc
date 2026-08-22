import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String dbName = 'warloc_chats.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final String path;
    if (filePath == ':memory:') {
      path = ':memory:';
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
      await db.rawQuery('PRAGMA synchronous = NORMAL');
    } catch (e) {
      debugPrint("Gagal mengatur mode journal database: $e");
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN mediaPath TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN mediaType TEXT');
    }
    if (oldVersion < 3) {
      // Add index to speed up content-based duplicate checks during import
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_messages_content ON messages (threadId, content)'
        );
      } catch (e) {
        debugPrint("Gagal membuat indeks pencarian duplikat: $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS search_history (
            query TEXT PRIMARY KEY,
            createdAt INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        debugPrint("Gagal membuat tabel riwayat pencarian: $e");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    // Table threads
    await db.execute('''
      CREATE TABLE threads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        meName TEXT NOT NULL
      )
    ''');

    // Table messages
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        threadId INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        isSystem INTEGER NOT NULL,
        mediaPath TEXT,
        mediaType TEXT,
        FOREIGN KEY (threadId) REFERENCES threads (id) ON DELETE CASCADE
      )
    ''');

    // Indexes for fast lookup during deduplication and viewing
    await db.execute(
      'CREATE INDEX idx_messages_thread_time ON messages (threadId, timestamp)'
    );
    await db.execute(
      'CREATE INDEX idx_messages_lookup ON messages (threadId, timestamp, sender, content)'
    );
    await db.execute(
      'CREATE INDEX idx_messages_content ON messages (threadId, content)'
    );

    await db.execute('''
      CREATE TABLE search_history (
        query TEXT PRIMARY KEY,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  // THREAD OPERATIONS
  Future<int> insertThread(ChatThread thread) async {
    final db = await instance.database;
    return await db.insert('threads', thread.toMap());
  }

  Future<List<ChatThread>> getThreads() async {
    final db = await instance.database;
    final result = await db.query('threads', orderBy: 'id DESC');
    return result.map((json) => ChatThread.fromMap(json)).toList();
  }

  Future<ChatThread?> getThread(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'threads',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ChatThread.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateThread(ChatThread thread) async {
    final db = await instance.database;
    return await db.update(
      'threads',
      thread.toMap(),
      where: 'id = ?',
      whereArgs: [thread.id],
    );
  }

  Future<int> deleteThread(int id) async {
    final db = await instance.database;
    return await db.delete(
      'threads',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMessage(int id) async {
    final db = await instance.database;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MESSAGE OPERATIONS
  /// Inserts a message if it doesn't already exist with the exact same threadId, timestamp, sender, and content.
  /// If [threadMeName] and [importMeName] are provided, it performs a smart duplicate check comparing sender roles
  /// ('me' vs 'other') and using a 60-second time tolerance.
  /// Returns the inserted ID if successful, or null if skipped (duplicate).
  Future<int?> insertMessageIfUnique(
    ChatMessage message, {
    String? threadMeName,
    String? importMeName,
  }) async {
    final db = await instance.database;
    return await _insertIfUniqueInTxn(
      db,
      message,
      threadMeName: threadMeName,
      importMeName: importMeName,
    );
  }

  Future<int?> _insertIfUniqueInTxn(
    DatabaseExecutor txn,
    ChatMessage message, {
    String? threadMeName,
    String? importMeName,
    Map<String, List<({int timestamp, String sender})>>? duplicateCache,
  }) async {
    // If cache is provided, perform in-memory deduplication checks
    if (duplicateCache != null) {
      if (threadMeName == null || importMeName == null) {
        final List<({int timestamp, String sender})>? list = duplicateCache[message.content];
        if (list != null) {
          for (final dup in list) {
            if (dup.timestamp == message.timestamp && dup.sender == message.sender) {
              return null; // Duplicate found, skip
            }
          }
        }
        final id = await txn.insert('messages', message.toMap());
        duplicateCache.putIfAbsent(message.content, () => []).add((
          timestamp: message.timestamp,
          sender: message.sender,
        ));
        return id;
      }

      final bool isMessageMe = message.sender == importMeName;
      final List<({int timestamp, String sender})>? list = duplicateCache[message.content];

      if (list != null) {
        for (final dup in list) {
          final bool isDupMe = dup.sender == threadMeName;
          if (isMessageMe == isDupMe) {
            if ((dup.timestamp - message.timestamp).abs() < 60000) {
              return null; // Duplicate found, skip
            }
          }
        }
      }

      // No duplicate in cache, insert and update cache
      final id = await txn.insert('messages', message.toMap());
      duplicateCache.putIfAbsent(message.content, () => []).add((
        timestamp: message.timestamp,
        sender: message.sender,
      ));
      return id;
    }

    // Fallback to normal SQLite duplicate queries if cache is null
    if (threadMeName == null || importMeName == null) {
      final duplicate = await txn.query(
        'messages',
        where: 'threadId = ? AND timestamp = ? AND sender = ? AND content = ?',
        whereArgs: [message.threadId, message.timestamp, message.sender, message.content],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        return null;
      }
      return await txn.insert('messages', message.toMap());
    }

    final bool isMessageMe = message.sender == importMeName;

    final potentialDuplicates = await txn.query(
      'messages',
      where: 'threadId = ? AND content = ?',
      whereArgs: [message.threadId, message.content],
      limit: 10,
    );

    for (final dup in potentialDuplicates) {
      final dupSender = dup['sender'] as String;
      final dupTime = dup['timestamp'] as int;
      final bool isDupMe = dupSender == threadMeName;

      if (isMessageMe == isDupMe) {
        if ((dupTime - message.timestamp).abs() < 60000) {
          return null;
        }
      }
    }

    return await txn.insert('messages', message.toMap());
  }

  Future<(int imported, int skipped)> insertBatchIfUnique(
    List<ChatMessage> messages, {
    String? threadMeName,
    String? importMeName,
    Map<String, List<({int timestamp, String sender})>>? duplicateCache,
  }) async {
    final db = await instance.database;
    int imported = 0;
    int skipped = 0;

    // Load batch-specific duplicate check cache if none provided
    final Map<String, List<({int timestamp, String sender})>> effectiveCache;
    if (duplicateCache == null && messages.isNotEmpty) {
      final threadId = messages.first.threadId;
      final contents = messages.map((m) => m.content).toList();
      effectiveCache = await loadDuplicateCheckCacheForBatch(threadId, contents);
    } else {
      effectiveCache = duplicateCache ?? {};
    }

    await db.transaction((txn) async {
      for (final msg in messages) {
        final id = await _insertIfUniqueInTxn(
          txn,
          msg,
          threadMeName: threadMeName,
          importMeName: importMeName,
          duplicateCache: effectiveCache,
        );
        if (id != null) {
          imported++;
        } else {
          skipped++;
        }
      }
    });
    return (imported, skipped);
  }

  Future<Map<String, List<({int timestamp, String sender})>>> loadDuplicateCheckCacheForBatch(
    int threadId,
    List<String> contents,
  ) async {
    if (contents.isEmpty) return {};
    final db = await instance.database;

    final placeholders = List.filled(contents.length, '?').join(',');
    final result = await db.query(
      'messages',
      columns: ['timestamp', 'sender', 'content'],
      where: 'threadId = ? AND content IN ($placeholders)',
      whereArgs: [threadId, ...contents],
    );

    final Map<String, List<({int timestamp, String sender})>> cache = {};
    for (final row in result) {
      final content = row['content'] as String;
      final timestamp = row['timestamp'] as int;
      final sender = row['sender'] as String;
      cache.putIfAbsent(content, () => []).add((timestamp: timestamp, sender: sender));
    }
    return cache;
  }

  Future<Map<String, List<({int timestamp, String sender})>>> loadDuplicateCheckCache(int threadId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      columns: ['timestamp', 'sender', 'content'],
      where: 'threadId = ?',
      whereArgs: [threadId],
    );

    final Map<String, List<({int timestamp, String sender})>> cache = {};
    for (final row in result) {
      final content = row['content'] as String;
      final timestamp = row['timestamp'] as int;
      final sender = row['sender'] as String;
      cache.putIfAbsent(content, () => []).add((timestamp: timestamp, sender: sender));
    }
    return cache;
  }

  Future<List<ChatMessage>> getMessagesForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'timestamp ASC, id ASC',
    );
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  Future<List<ChatMessage>> getMessagesForThreadPaginated(int threadId, int limit, int offset) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => ChatMessage.fromMap(json)).toList().reversed.toList();
  }

  Future<List<ChatMessage>> searchMessages(int threadId, String query) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ? AND content LIKE ? AND isSystem = 0',
      whereArgs: [threadId, '%$query%'],
      orderBy: 'timestamp ASC, id ASC',
    );
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  Future<ChatMessage?> getLastMessageForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return ChatMessage.fromMap(result.first);
    }
    return null;
  }

  /// Returns a map of threadId -> last ChatMessage for ALL threads in one query.
  Future<Map<int, ChatMessage?>> getAllLastMessages() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT m.* FROM messages m
      INNER JOIN (
        SELECT threadId, MAX(id) as maxId FROM messages GROUP BY threadId
      ) latest ON m.id = latest.maxId
    ''');
    final Map<int, ChatMessage?> map = {};
    for (final row in result) {
      final msg = ChatMessage.fromMap(row);
      map[msg.threadId] = msg;
    }
    return map;
  }

  /// Returns a map of threadId -> message count for ALL threads in one query.
  Future<Map<int, int>> getAllMessageCounts() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT threadId, COUNT(*) as count FROM messages GROUP BY threadId'
    );
    final Map<int, int> map = {};
    for (final row in result) {
      map[row['threadId'] as int] = row['count'] as int;
    }
    return map;
  }

  Future<int> getMessageCountForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE threadId = ?',
      [threadId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getUniqueSendersForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT sender FROM messages WHERE threadId = ? AND isSystem = 0',
      [threadId],
    );
    return result.map((row) => row['sender'] as String).toList();
  }

  Future<void> mergeSenders({
    required int threadId,
    required String newThreadName,
    required String newMeName,
    required Map<String, String> senderMappings,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Update thread details in threads table
      await txn.update(
        'threads',
        {'name': newThreadName, 'meName': newMeName},
        where: 'id = ?',
        whereArgs: [threadId],
      );

      // 2. Update message senders in messages table
      for (final entry in senderMappings.entries) {
        final oldSender = entry.key;
        final newSender = entry.value;
        if (oldSender != newSender) {
          await txn.update(
            'messages',
            {'sender': newSender},
            where: 'threadId = ? AND sender = ?',
            whereArgs: [threadId, oldSender],
          );
        }
      }
    });
  }

  /// Applies a sender merge from role-based mappings, as chosen in the
  /// manage-senders dialog.
  ///
  /// [senderRoles] maps each original sender name to its target role:
  /// `'me'` renames the sender to [newMeName], anything else (typically
  /// `'contact'`) renames it to [newThreadName]. Thread and message updates
  /// run in the same transaction as [mergeSenders].
  Future<void> applySenderMerge({
    required int threadId,
    required String newThreadName,
    required String newMeName,
    required Map<String, String> senderRoles,
  }) async {
    final Map<String, String> senderMappings = {};
    for (final entry in senderRoles.entries) {
      senderMappings[entry.key] = (entry.value == 'me') ? newMeName : newThreadName;
    }

    await mergeSenders(
      threadId: threadId,
      newThreadName: newThreadName,
      newMeName: newMeName,
      senderMappings: senderMappings,
    );
  }

  Future<List<ChatMessage>> getMediaMessagesForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ? AND mediaPath IS NOT NULL AND mediaPath != ?',
      whereArgs: [threadId, ''],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  Future<int> getMessageIndexInThread(int threadId, int messageId, int timestamp) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE threadId = ? AND (timestamp > ? OR (timestamp = ? AND id > ?))',
      [threadId, timestamp, timestamp, messageId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<ChatMessage>> searchMessagesPaginated({
    required int threadId,
    required String query,
    required int limit,
    required int offset,
  }) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'threadId = ? AND content LIKE ? AND isSystem = 0',
      whereArgs: [threadId, '%$query%'],
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  // SEARCH HISTORY (S6: persistent, replaces in-memory static list)
  Future<void> addSearchHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'search_history',
      {'query': q, 'createdAt': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Cap at 20 most recent.
    await db.rawDelete(
      'DELETE FROM search_history WHERE query NOT IN '
      '(SELECT query FROM search_history ORDER BY createdAt DESC LIMIT 20)',
    );
  }

  Future<List<String>> getSearchHistory() async {
    final db = await instance.database;
    final rows = await db.query(
      'search_history',
      columns: ['query'],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => r['query'] as String).toList();
  }

  Future<void> removeSearchHistory(String query) async {
    final db = await instance.database;
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
  }

  Future<void> clearSearchHistory() async {
    final db = await instance.database;
    await db.delete('search_history');
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
