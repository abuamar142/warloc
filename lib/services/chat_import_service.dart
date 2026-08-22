import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_thread.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/parsed_chat_result.dart';
import 'package:warloc/utils/media_helper.dart';

enum ImportStatus { importing, completed, failed }

class ImportTask {
  final String id;
  final String threadName;
  final int totalMessages;
  int importedCount;
  int skippedCount;
  double progress;
  ImportStatus status;
  String? errorMessage;

  ImportTask({
    required this.id,
    required this.threadName,
    required this.totalMessages,
    this.importedCount = 0,
    this.skippedCount = 0,
    this.progress = 0.0,
    this.status = ImportStatus.importing,
    this.errorMessage,
  });
}

class ChatImportService extends ChangeNotifier {
  static final ChatImportService instance = ChatImportService._internal();

  ChatImportService._internal();

  final List<ImportTask> _tasks = [];

  List<ImportTask> get tasks => List.unmodifiable(_tasks);

  bool get hasActiveImports => _tasks.any((task) => task.status == ImportStatus.importing);

  void clearCompletedTasks() {
    _tasks.removeWhere((task) => task.status != ImportStatus.importing);
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  Future<void> startImport({
    required bool isNew,
    required String name,
    required String meName,
    required ChatThread? existingThread,
    required ParsedChatResult parsedData,
    required String? tempDirPath,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final total = parsedData.messages.length;
    final task = ImportTask(
      id: taskId,
      threadName: name,
      totalMessages: total,
    );

    _tasks.add(task);
    notifyListeners();

    // Start background importing execution
    await _runImportTask(
      task: task,
      isNew: isNew,
      name: name,
      meName: meName,
      existingThread: existingThread,
      parsedData: parsedData,
      tempDirPath: tempDirPath,
    );
  }

  Future<void> _runImportTask({
    required ImportTask task,
    required bool isNew,
    required String name,
    required String meName,
    required ChatThread? existingThread,
    required ParsedChatResult parsedData,
    required String? tempDirPath,
  }) async {
    final db = DatabaseHelper.instance;
    int threadId = 0;
    Map<String, List<({int timestamp, String sender, String? mediaPath})>>? duplicateCache;

    try {
      if (isNew) {
        final newThread = ChatThread(name: name, meName: meName);
        threadId = await db.insertThread(newThread);
        duplicateCache = {}; // Empty cache for new threads, since we know there are no existing messages
      } else {
        threadId = existingThread!.id!;
        if (existingThread.meName != meName) {
          await db.updateThread(existingThread.copyWith(meName: meName));
        }
        duplicateCache = null; // Set to null so it loads batch-scoped cache during batch inserts
      }

      // Copy media files if tempDirPath is provided
      if (tempDirPath != null) {
        try {
          if (!await Directory(tempDirPath).exists()) {
            debugPrint("tempDir missing $tempDirPath");
          } else {
            final targetDir = await MediaHelper.getMediaDirectory(threadId);
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }
            final files = Directory(tempDirPath).listSync(recursive: true).whereType<File>().toList();
            int copied = 0;
            for (final f in files) {
              final bn = p.basename(f.path);
              final lower = bn.toLowerCase();
              if (lower.endsWith('.txt') || lower.endsWith('.json') || bn.startsWith('__MACOSX') || bn.startsWith('.')) continue;
              try {
                await f.copy(p.join(targetDir.path, bn));
                copied++;
              } catch (e) {
                debugPrint("Gagal menyalin $bn: $e");
              }
            }
            debugPrint("media copied $copied to ${targetDir.path}");
          }
        } catch (e) {
          debugPrint("Gagal menyalin file media di background: $e");
        }
      }

      // Process in batch loop asynchronously to keep main thread responsive
      final batchSize = 100;
      final total = task.totalMessages;

      while (task.importedCount + task.skippedCount < total) {
        final start = task.importedCount + task.skippedCount;
        final end = (start + batchSize > total) ? total : start + batchSize;

        final batchMessages = <ChatMessage>[];
        for (var i = start; i < end; i++) {
          final parsedMsg = parsedData.messages[i];
          batchMessages.add(ChatMessage(
            threadId: threadId,
            timestamp: parsedMsg.timestamp.millisecondsSinceEpoch,
            sender: parsedMsg.sender,
            content: parsedMsg.content,
            isSystem: parsedMsg.isSystem ? 1 : 0,
            mediaPath: parsedMsg.mediaPath,
            mediaType: parsedMsg.mediaType,
          ));
        }

        final (localImported, localSkipped) = await db.insertBatchIfUnique(
          batchMessages,
          threadMeName: existingThread?.meName ?? meName,
          importMeName: meName,
          duplicateCache: duplicateCache,
        );

        task.importedCount += localImported;
        task.skippedCount += localSkipped;
        task.progress = (task.importedCount + task.skippedCount) / total;
        notifyListeners();

        // Brief yield to keep UI frame rate perfect (60fps)
        await Future.delayed(const Duration(milliseconds: 10));
      }

      task.status = ImportStatus.completed;
      notifyListeners();
    } catch (e) {
      debugPrint("Error importing: $e");
      task.status = ImportStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    } finally {
      // Clean up temp directory if it exists
      if (tempDirPath != null) {
        try {
          final tempDir = Directory(tempDirPath);
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (e) {
          debugPrint("Gagal menghapus folder temp: $e");
        }
      }
    }
  }
}
