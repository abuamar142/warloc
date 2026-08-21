import 'dart:io';
import 'package:flutter/foundation.dart';
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
import '../services/chat_import_service.dart';
import '../widgets/import_task_card.dart';
import '../utils/backup_helper.dart';
import '../theme/app_colors.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_choice_chip.dart';
import '../widgets/common/app_button.dart';
import 'chat_room_screen.dart';
import 'security_settings_screen.dart';
import '../widgets/common/custom_app_bar.dart';

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
  final Set<String> _reloadedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadThreads();
    ChatImportService.instance.addListener(_onImportServiceChanged);
  }

  @override
  void dispose() {
    ChatImportService.instance.removeListener(_onImportServiceChanged);
    super.dispose();
  }

  void _onImportServiceChanged() {
    final tasks = ChatImportService.instance.tasks;
    bool needsReload = false;
    for (final task in tasks) {
      if (task.status == ImportStatus.completed && !_reloadedTaskIds.contains(task.id)) {
        _reloadedTaskIds.add(task.id);
        needsReload = true;
      }
    }
    if (needsReload) {
      _loadThreads();
    }
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;

    // 3 queries total instead of N×2+1 — eliminates N+1 problem
    final results = await Future.wait([
      db.getThreads(),
      db.getAllLastMessages(),
      db.getAllMessageCounts(),
    ]);

    setState(() {
      _threads = results[0] as List<ChatThread>;
      _lastMessages = results[1] as Map<int, ChatMessage?>;
      _messageCounts = results[2] as Map<int, int>;
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
        builder: (context) => const CustomLoadingIndicator(),
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
        parsedResult = await compute(TelegramParser.parseFileIsolate, targetPathToParse);
      } else {
        parsedResult = await compute(WhatsAppParser.parseFileIsolate, targetPathToParse);
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
    ChatImportService.instance.startImport(
      isNew: isNew,
      name: name,
      meName: meName,
      existingThread: existingThread,
      parsedData: parsedData,
      tempDirPath: tempDirPath,
    );
  }

  Future<void> _deleteThread(ChatThread thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: "Hapus Chat",
        content: Text(
          "Apakah Anda yakin ingin menghapus semua riwayat chat dengan \"${thread.name}\"?",
        ),
        actions: [
          AppButton(
            label: "Batal",
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.secondary,
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
        builder: (context) => const CustomLoadingIndicator(),
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
            backgroundColor: AppColors.primary,
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
              return AppDialog(
        icon: Icons.restore,
        iconColor: AppColors.primary,
        title: "Pilih Mode Impor",
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bagaimana Anda ingin memulihkan cadangan data ini?",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppChoiceChip(
              label: const Text("Gabung Chat (Rekomendasi)"),
              selected: selectedMode == 'merge',
              onSelected: (val) {
                setStateDialog(() {
                  selectedMode = 'merge';
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              "Menggabungkan riwayat chat tanpa menghapus pesan yang ada. Pesan duplikat akan dilewati secara otomatis.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            AppChoiceChip(
              label: const Text("Timpa Semua Data"),
              selected: selectedMode == 'overwrite',
              onSelected: (val) {
                setStateDialog(() {
                  selectedMode = 'overwrite';
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              "PERINGATAN: Menghapus semua chat dan media saat ini, lalu menggantinya secara total dengan isi cadangan.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: "Batal",
            onPressed: () => Navigator.pop(context),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: "Impor",
            onPressed: () => Navigator.pop(context, selectedMode),
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
        builder: (context) => const CustomLoadingIndicator(),
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
              backgroundColor: AppColors.primary,
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
      appBar: CustomAppBar(
        title: const Text("Warloc"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadThreads,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportBackup();
              } else if (value == 'import') {
                _importBackup();
              } else if (value == 'security') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
                ).then((_) => _loadThreads());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.backup, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text("Ekspor Cadangan (.wlb)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text("Impor Cadangan (.wlb)"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'security',
                child: Row(
                  children: [
                    Icon(Icons.security, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text("Pengaturan Keamanan"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const CustomLoadingIndicator()
          : Column(
              children: [
                ListenableBuilder(
                  listenable: ChatImportService.instance,
                  builder: (context, _) {
                    final tasks = ChatImportService.instance.tasks;
                    if (tasks.isEmpty) return const SizedBox.shrink();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tasks.map((t) => ImportTaskCard(task: t)).toList(),
                    );
                  },
                ),
                Expanded(
                  child: _threads.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.chat_bubble_outline,
                          title: "Belum ada chat terimpor",
                          description: "Silakan klik tombol '+' di bawah untuk memilih file .txt ekspor WhatsApp Anda.",
                          actionButton: AppButton(
                            onPressed: _pickAndImportFile,
                            icon: Icons.add,
                            label: "Impor Chat Sekarang",
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _threads.length,
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
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndImportFile,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
