import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:warloc/data/database_helper.dart';
import 'package:warloc/models/chat_thread.dart';
import 'package:warloc/models/chat_message.dart';
import 'package:warloc/models/parsed_chat_result.dart';
import 'package:warloc/utils/whatsapp_parser.dart';
import 'package:warloc/utils/telegram_parser.dart';
import 'package:warloc/utils/media_helper.dart';
import '../widgets/chat_thread_tile.dart';
import '../widgets/import_config_dialog.dart';
import 'package:warloc/services/backup_service.dart';
import 'package:warloc/services/chat_import_service.dart';
import '../widgets/import_task_card.dart';
import 'package:warloc/utils/show_message.dart';
import 'package:warloc/core/theme/app_colors.dart';
import 'package:warloc/core/widgets/atoms/loading_indicator.dart';
import 'package:warloc/core/widgets/molecules/empty_state_widget.dart';
import 'package:warloc/core/widgets/molecules/app_dialog.dart';
import 'package:warloc/core/widgets/atoms/app_button.dart';
import 'chat_room_screen.dart';
import 'security_settings_screen.dart';
import 'package:warloc/core/widgets/molecules/custom_app_bar.dart';

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
          if (!mounted) return;
          showErrorSnackBar(context, "Tidak ada file log chat (.txt atau .json) di dalam file zip.");
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
        if (!mounted) return;
        showErrorSnackBar(
          context,
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
        showErrorSnackBar(context, "Gagal membaca file: $e");
      }
    }
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
        showInfoSnackBar(context, "Chat \"${thread.name}\" berhasil dihapus");
      }
    }
  }

  Future<void> _exportBackup() => BackupService.exportBackup(context);

  Future<void> _importBackup() =>
      BackupService.importBackup(context, onRestoreSuccess: _loadThreads);

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
