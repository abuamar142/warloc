import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../models/parsed_chat_result.dart';
import '../utils/media_helper.dart';
import 'common/app_dialog.dart';
import 'common/app_button.dart';

class ImportProgressDialog extends StatefulWidget {
  final bool isNew;
  final String name;
  final String meName;
  final ChatThread? existingThread;
  final ParsedChatResult parsedData;
  final String? tempDirPath;
  final VoidCallback onComplete;

  const ImportProgressDialog({
    super.key,
    required this.isNew,
    required this.name,
    required this.meName,
    required this.existingThread,
    required this.parsedData,
    this.tempDirPath,
    required this.onComplete,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  int _importedCount = 0;
  int _skippedCount = 0;
  double _progress = 0.0;
  late final int _total;
  Map<String, List<({int timestamp, String sender})>>? _duplicateCache;

  @override
  void initState() {
    super.initState();
    _total = widget.parsedData.messages.length;
    _runImport();
  }

  Future<void> _runImport() async {
    final db = DatabaseHelper.instance;
    int threadId = 0;

    if (widget.isNew) {
      final newThread = ChatThread(name: widget.name, meName: widget.meName);
      threadId = await db.insertThread(newThread);
      _duplicateCache = {};
    } else {
      threadId = widget.existingThread!.id!;
      if (widget.existingThread!.meName != widget.meName) {
        await db.updateThread(widget.existingThread!.copyWith(meName: widget.meName));
      }
      _duplicateCache = await db.loadDuplicateCheckCache(threadId);
    }

    // Copy media files if tempDirPath is provided
    if (widget.tempDirPath != null) {
      try {
        final tempDir = Directory(widget.tempDirPath!);
        if (await tempDir.exists()) {
          final targetDir = await MediaHelper.getMediaDirectory(threadId);
          final entities = tempDir.listSync(recursive: true);
          for (final entity in entities) {
            if (entity is File) {
              final fileName = p.basename(entity.path);
              // Skip chat log files and hidden files
              if (fileName.toLowerCase().endsWith('.txt') ||
                  fileName.startsWith('__MACOSX') ||
                  fileName.startsWith('.')) {
                continue;
              }
              final targetPath = p.join(targetDir.path, fileName);
              await entity.copy(targetPath);
            }
          }
        }
      } catch (e) {
        debugPrint("Gagal menyalin file media: $e");
      }
    }

    _processNextBatch(threadId);
  }

  void _processNextBatch(int threadId) {
    if (_importedCount + _skippedCount >= _total) {
      _finishImport();
      return;
    }

    Future.delayed(const Duration(milliseconds: 50), () async {
      if (!mounted) return;

      final batchSize = 100;
      final start = _importedCount + _skippedCount;
      final end = (start + batchSize > _total) ? _total : start + batchSize;
      
      final db = DatabaseHelper.instance;
      final batchMessages = <ChatMessage>[];

      for (var i = start; i < end; i++) {
        final parsedMsg = widget.parsedData.messages[i];
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
        threadMeName: widget.existingThread?.meName ?? widget.meName,
        importMeName: widget.meName,
        duplicateCache: _duplicateCache,
      );

      if (mounted) {
        setState(() {
          _importedCount += localImported;
          _skippedCount += localSkipped;
          _progress = (_importedCount + _skippedCount) / _total;
        });
        _processNextBatch(threadId);
      }
    });
  }

  void _finishImport() {
    // Clean up temp directory if it exists
    if (widget.tempDirPath != null) {
      try {
        final tempDir = Directory(widget.tempDirPath!);
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (e) {
        debugPrint("Gagal menghapus folder temp: $e");
      }
    }

    Navigator.pop(context); // Close progress dialog
    widget.onComplete();

    // Show completion summary
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: "Import Selesai",
        content: Text(
          "Pesan berhasil diproses:\n"
          "• Diimpor (Baru): $_importedCount\n"
          "• Dilewati (Duplikat): $_skippedCount\n"
          "• Total: $_total",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          AppButton(
            label: "OK",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: "Mengimpor Chat...",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _progress,
            color: const Color(0xFF008069),
            backgroundColor: Colors.grey[200],
          ),
          const SizedBox(height: 16),
          Text(
            "${(_progress * 100).toStringAsFixed(1)}% (${_importedCount + _skippedCount} / $_total)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Baru: $_importedCount  |  Duplikat: $_skippedCount",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: const [],
    );
  }
}
