import 'dart:async';
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
      version: 2,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN mediaPath TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN mediaType TEXT');
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
    await db.execute('''
      CREATE INDEX idx_messages_thread_time ON messages (threadId, timestamp)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_messages_lookup ON messages (threadId, timestamp, sender, content)
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

  // MESSAGE OPERATIONS
  /// Inserts a message if it doesn't already exist with the exact same threadId, timestamp, sender, and content.
  /// Returns the inserted ID if successful, or null if skipped (duplicate).
  Future<int?> insertMessageIfUnique(ChatMessage message) async {
    final db = await instance.database;

    // Check if duplicate exists
    final duplicate = await db.query(
      'messages',
      where: 'threadId = ? AND timestamp = ? AND sender = ? AND content = ?',
      whereArgs: [message.threadId, message.timestamp, message.sender, message.content],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      // Duplicate found, skip
      return null;
    }

    // No duplicate, insert
    return await db.insert('messages', message.toMap());
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

  Future<int> getMessageCountForThread(int threadId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE threadId = ?',
      [threadId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
