import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../models/parsed_chat_result.dart';
import '../utils/whatsapp_parser.dart';
import '../utils/telegram_parser.dart';
import '../utils/media_helper.dart';
import '../widgets/chat_thread_tile.dart';
import '../widgets/import_config_dialog.dart';
import '../widgets/import_progress_dialog.dart';
import '../utils/backup_helper.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatThread> _threads = [];
  Map<int, ChatMessage?> _lastMessages = {};
  Map<int, int> _messageCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final threads = await db.getThreads();

    final Map<int, ChatMessage?> lastMessages = {};
    final Map<int, int> messageCounts = {};

    for (final thread in threads) {
      if (thread.id != null) {
        lastMessages[thread.id!] = await db.getLastMessageForThread(thread.id!);
        messageCounts[thread.id!] = await db.getMessageCountForThread(
          thread.id!,
        );
      }
    }

    setState(() {
      _threads = threads;
      _lastMessages = lastMessages;
      _messageCounts = messageCounts;
      _isLoading = false;
    });
  }

  Future<void> _pickAndImportFile() async {
    bool isDialogShown = false;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'zip', 'json'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final isZip = path.toLowerCase().endsWith('.zip');

      if (!mounted) return;
      // Show loading while parsing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF008069)),
        ),
      );
      isDialogShown = true;

      String? targetPathToParse;
      String? tempDirPath;

      if (isZip) {
        final tempDir = await getTemporaryDirectory();
        tempDirPath = p.join(tempDir.path, 'warloc_temp_${DateTime.now().millisecondsSinceEpoch}');
        final tempDirFile = Directory(tempDirPath);
        await tempDirFile.create(recursive: true);

        final chatLogPath = await MediaHelper.extractZipAndFindChatLog(path, tempDirFile);
        if (chatLogPath == null) {
          if (mounted && isDialogShown) {
            Navigator.pop(context); // Dismiss loading
            isDialogShown = false;
          }
          await tempDirFile.delete(recursive: true);
          _showErrorSnackBar("Tidak ada file log chat (.txt atau .json) di dalam file zip.");
          return;
        }
        targetPathToParse = chatLogPath;
      } else {
        targetPathToParse = path;
      }

      final ParsedChatResult parsedResult;
      if (targetPathToParse.toLowerCase().endsWith('.json')) {
        parsedResult = await TelegramParser.parseFile(targetPathToParse);
      } else {
        parsedResult = await WhatsAppParser.parseFile(targetPathToParse);
      }

      if (mounted && isDialogShown) {
        Navigator.pop(context); // Dismiss parsing loading
        isDialogShown = false;
      }

      if (parsedResult.messages.isEmpty) {
        if (tempDirPath != null) {
          await Directory(tempDirPath).delete(recursive: true);
        }
        _showErrorSnackBar(
          "Tidak ada pesan valid yang ditemukan dalam file ini.",
        );
        return;
      }

      _showImportConfigDialog(path, parsedResult, tempDirPath: tempDirPath);
    } catch (e) {
      if (mounted) {
        if (isDialogShown) {
          Navigator.pop(context);
        }
        _showErrorSnackBar("Gagal membaca file: $e");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showImportConfigDialog(
    String filePath,
    ParsedChatResult parsedData, {
    String? tempDirPath,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportConfigDialog(
        filePath: filePath,
        parsedData: parsedData,
        existingThreads: _threads,
        tempDirPath: tempDirPath,
        onConfirm: (isNew, name, meName, existingThread) {
          _startImportProcess(
            isNew,
            name,
            meName,
            existingThread,
            parsedData,
            tempDirPath: tempDirPath,
          );
        },
      ),
    );
  }

  void _startImportProcess(
    bool isNew,
    String name,
    String meName,
    ChatThread? existingThread,
    ParsedChatResult parsedData, {
    String? tempDirPath,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportProgressDialog(
        isNew: isNew,
        name: name,
        meName: meName,
        existingThread: existingThread,
        parsedData: parsedData,
        tempDirPath: tempDirPath,
        onComplete: _loadThreads,
      ),
    );
  }

  Future<void> _deleteThread(ChatThread thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Chat"),
        content: Text(
          "Apakah Anda yakin ingin menghapus semua riwayat chat dengan \"${thread.name}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && thread.id != null) {
      await DatabaseHelper.instance.deleteThread(thread.id!);
      _loadThreads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Chat \"${thread.name}\" berhasil dihapus")),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    bool isDialogShown = false;
    try {
      // 1. Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF008069)),
        ),
      );
      isDialogShown = true;

      // 2. Generate backup locally in internal temporary folder (scoped storage safe)
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'warloc_backup_${DateTime.now().millisecondsSinceEpoch}.wlb');
      await BackupHelper.createBackup(tempPath);

      final backupBytes = await File(tempPath).readAsBytes();

      // Close loading dialog before opening native save dialog
      if (mounted && isDialogShown) {
        Navigator.pop(context);
        isDialogShown = false;
      }

      // 3. Prompt user to select save destination and write bytes natively
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Simpan Cadangan Warloc',
        fileName: 'warloc_backup_${DateTime.now().millisecondsSinceEpoch}.wlb',
        type: FileType.custom,
        allowedExtensions: ['wlb', 'zip'],
        bytes: backupBytes,
      );

      // Clean up temporary file
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      if (outputPath == null) return; // User cancelled

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cadangan data berhasil diekspor!"),
            backgroundColor: Color(0xFF008069),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (isDialogShown) {
          Navigator.pop(context);
        }
        _showErrorSnackBar("Gagal mengekspor cadangan: $e");
      }
    }
  }

  Future<void> _importBackup() async {
    bool isDialogShown = false;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wlb', 'zip'],
      );

      if (result == null || result.files.single.path == null) return;
      final backupPath = result.files.single.path!;

      if (!mounted) return;

      final importMode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String selectedMode = 'merge'; // Default to merge
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.restore, color: Color(0xFF008069)),
                    SizedBox(width: 8),
                    Text(
                      "Pilih Mode Impor",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bagaimana Anda ingin memulihkan cadangan data ini?",
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ChoiceChip(
                      label: const Text("Gabung Chat (Rekomendasi)"),
                      selected: selectedMode == 'merge',
                      selectedColor: const Color(0x20008069),
                      checkmarkColor: const Color(0xFF008069),
                      onSelected: (val) {
                        setStateDialog(() {
                          selectedMode = 'merge';
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Menggabungkan riwayat chat tanpa menghapus pesan yang ada. Pesan duplikat akan dilewati secara otomatis.",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ChoiceChip(
                      label: const Text("Timpa Semua Data"),
                      selected: selectedMode == 'overwrite',
                      selectedColor: const Color(0x20008069),
                      checkmarkColor: const Color(0xFF008069),
                      onSelected: (val) {
                        setStateDialog(() {
                          selectedMode = 'overwrite';
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "PERINGATAN: Menghapus semua chat dan media saat ini, lalu menggantinya secara total dengan isi cadangan.",
                      style: TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, selectedMode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008069),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Impor"),
                  ),
                ],
              );
            },
          );
        },
      );

      if (importMode == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF008069)),
        ),
      );
      isDialogShown = true;

      bool success = false;
      if (importMode == 'overwrite') {
        success = await BackupHelper.restoreBackupOverwrite(backupPath);
      } else {
        success = await BackupHelper.restoreBackupMerge(backupPath);
      }

      if (mounted && isDialogShown) {
        Navigator.pop(context); // Dismiss loading dialog
        isDialogShown = false;
      }

      if (success) {
        _loadThreads();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cadangan data berhasil dipulihkan!"),
              backgroundColor: Color(0xFF008069),
            ),
          );
        }
      } else {
        _showErrorSnackBar("Gagal memulihkan cadangan. Pastikan format file cadangan valid.");
      }
    } catch (e) {
      if (mounted) {
        if (isDialogShown) {
          Navigator.pop(context); // Dismiss loading dialog
        }
        _showErrorSnackBar("Gagal mengimpor cadangan: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Warloc",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF008069),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadThreads,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'export') {
                _exportBackup();
              } else if (value == 'import') {
                _importBackup();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.backup, color: Color(0xFF008069)),
                    SizedBox(width: 8),
                    Text("Ekspor Cadangan (.wlb)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Color(0xFF008069)),
                    SizedBox(width: 8),
                    Text("Impor Cadangan (.wlb)"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF008069)),
            )
          : _threads.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Belum ada chat terimpor",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Silakan klik tombol '+' di bawah untuk memilih file .txt ekspor WhatsApp Anda.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickAndImportFile,
                      icon: const Icon(Icons.add),
                      label: const Text("Impor Chat Sekarang"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008069),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              itemCount: _threads.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final thread = _threads[index];
                final lastMsg = _lastMessages[thread.id];
                final count = _messageCounts[thread.id] ?? 0;

                return ChatThreadTile(
                  thread: thread,
                  lastMessage: lastMsg,
                  messageCount: count,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(thread: thread),
                      ),
                    ).then((_) => _loadThreads());
                  },
                  onDelete: () => _deleteThread(thread),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndImportFile,
        backgroundColor: const Color(0xFF00A884),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
