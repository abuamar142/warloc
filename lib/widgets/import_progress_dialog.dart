import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../utils/whatsapp_parser.dart';
import '../utils/media_helper.dart';

class ImportProgressDialog extends StatefulWidget {
  final bool isNew;
  final String name;
  final String meName;
  final ChatThread? existingThread;
  final WhatsAppParsedResult parsedData;
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
    } else {
      threadId = widget.existingThread!.id!;
      if (widget.existingThread!.meName != widget.meName) {
        await db.updateThread(widget.existingThread!.copyWith(meName: widget.meName));
      }
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
      
      int localImported = 0;
      int localSkipped = 0;

      final db = DatabaseHelper.instance;

      for (var i = start; i < end; i++) {
        final parsedMsg = widget.parsedData.messages[i];
        final chatMsg = ChatMessage(
          threadId: threadId,
          timestamp: parsedMsg.timestamp.millisecondsSinceEpoch,
          sender: parsedMsg.sender,
          content: parsedMsg.content,
          isSystem: parsedMsg.isSystem ? 1 : 0,
          mediaPath: parsedMsg.mediaPath,
          mediaType: parsedMsg.mediaType,
        );

        final insertedId = await db.insertMessageIfUnique(chatMsg);
        if (insertedId != null) {
          localImported++;
        } else {
          localSkipped++;
        }
      }

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Import Selesai", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Pesan berhasil diproses:\n"
          "• Diimpor (Baru): $_importedCount\n"
          "• Dilewati (Duplikat): $_skippedCount\n"
          "• Total: $_total",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008069),
              foregroundColor: Colors.white,
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Mengimpor Chat...", style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
