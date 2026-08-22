import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
import 'package:warloc/widgets/chat_thread_tile.dart';
import 'package:warloc/widgets/import_config_dialog.dart';
import 'package:warloc/services/backup_service.dart';
import 'package:warloc/services/chat_import_service.dart';
import 'package:warloc/widgets/import_task_card.dart';
import 'package:warloc/utils/show_message.dart';
import 'package:warloc/core/theme/app_colors.dart';
import 'package:warloc/core/widgets/atoms/loading_indicator.dart';
import 'package:warloc/core/widgets/molecules/empty_state_widget.dart';
import 'package:warloc/core/widgets/molecules/app_dialog.dart';
import 'package:warloc/core/widgets/atoms/app_button.dart';
import 'package:warloc/screens/chat_room_screen.dart';
import 'package:warloc/screens/security_settings_screen.dart';
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
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    ChatImportService.instance.addListener(_onImportServiceChanged);
    _initShareIntent();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    ChatImportService.instance.removeListener(_onImportServiceChanged);
    super.dispose();
  }

  void _initShareIntent() {
    // Cold start: app killed then opened via share
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty && mounted) {
        debugPrint('[Warloc] getInitialMedia received ${files.length} file(s)');
        _handleSharedFiles(files);
      }
      // Tell the library we have consumed the intent so it is not redelivered.
      ReceiveSharingIntent.instance.reset();
    });

    // Warm: app already running (singleTop)
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty && mounted) {
          debugPrint('[Warloc] getMediaStream received ${files.length} file(s)');
          _handleSharedFiles(files);
        }
        // Clear stream event after handling
        ReceiveSharingIntent.instance.reset();
      },
      onError: (e) => debugPrint('[Warloc] share stream error $e'),
    );
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (_handlingShare) {
      debugPrint('[Warloc] _handleSharedFiles skipped — already handling');
      return;
    }
    _handlingShare = true;
    try {
      if (!mounted) return;
      debugPrint('[Warloc] _handleSharedFiles handling ${files.length} file(s)');

      for (final file in files) {
        if (!mounted) return;
        final sharedPath = file.path;
        if (sharedPath.isEmpty) {
          debugPrint('[Warloc] shared file path empty, skip type=${file.type} mime=${file.mimeType}');
          continue;
        }

        debugPrint('[Warloc] processing shared file: $sharedPath type=${file.type} mime=${file.mimeType}');

        final isZip = p.extension(sharedPath).toLowerCase() == '.zip';
        bool isDialogShown = false;
        String? tempDirPath;
        Directory? tempDirFile;

        try {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const CustomLoadingIndicator(),
          );
          isDialogShown = true;

          if (isZip) {
            final tempDir = await getTemporaryDirectory();
            tempDirPath = p.join(
              tempDir.path,
              'warloc_temp_${DateTime.now().millisecondsSinceEpoch}',
            );
            tempDirFile = Directory(tempDirPath);
            await tempDirFile.create(recursive: true);

            final chatLogPath = await MediaHelper.extractZipAndFindChatLog(
              sharedPath,
              tempDirFile,
            );
            if (chatLogPath == null) {
              throw 'Chat log tidak ditemukan di zip';
            }

            final isJson = chatLogPath.toLowerCase().endsWith('.json');
            debugPrint('[Warloc] zip extracted chatLog=$chatLogPath isJson=$isJson');
            final parsed = await compute(
              isJson ? TelegramParser.parseFileIsolate : WhatsAppParser.parseFileIsolate,
              chatLogPath,
            );

            if (!mounted) {
              if (tempDirFile.existsSync()) {
                await tempDirFile.delete(recursive: true);
              }
              return;
            }
            if (isDialogShown && mounted) {
              Navigator.of(context).pop();
              isDialogShown = false;
            }

            if (parsed.messages.isEmpty) {
              debugPrint('[Warloc] parsed empty messages for $chatLogPath');
              await tempDirFile.delete(recursive: true);
              if (!mounted) return;
              showInfoSnackBar(context, 'Tidak ada pesan valid yang ditemukan dalam file ini.');
              continue;
            }

            if (!mounted) return;
            _showImportConfigDialog(chatLogPath, parsed, tempDirPath: tempDirPath);
          } else {
            // Direct txt/json (WA txt export or Telegram json)
            final isJson = sharedPath.toLowerCase().endsWith('.json');
            debugPrint('[Warloc] direct file isJson=$isJson path=$sharedPath');
            final parsed = await compute(
              isJson ? TelegramParser.parseFileIsolate : WhatsAppParser.parseFileIsolate,
              sharedPath,
            );

            if (!mounted) return;
            if (isDialogShown && mounted) {
              Navigator.of(context).pop();
              isDialogShown = false;
            }

            if (parsed.messages.isEmpty) {
              debugPrint('[Warloc] parsed empty messages for $sharedPath');
              if (!mounted) return;
              showInfoSnackBar(
                context,
                'Tidak ada pesan valid yang ditemukan dalam file ini.',
              );
              continue;
            }

            if (!mounted) return;
            _showImportConfigDialog(sharedPath, parsed);
          }
        } catch (e, st) {
          debugPrint('[Warloc] _handleSharedFiles error for $sharedPath: $e\n$st');
          if (isDialogShown && mounted) {
            // Ensure loading is dismissed
            try {
              Navigator.of(context).pop();
            } catch (_) {}
            isDialogShown = false;
          }
          // Cleanup temp dir if created for this file
          if (tempDirFile != null) {
            try {
              if (await tempDirFile.exists()) {
                await tempDirFile.delete(recursive: true);
              }
            } catch (_) {}
          } else if (tempDirPath != null) {
            try {
              final dir = Directory(tempDirPath);
              if (await dir.exists()) {
                await dir.delete(recursive: true);
              }
            } catch (_) {}
          }
          if (!mounted) return;
          showErrorSnackBar(context, 'Gagal memproses file share: $e');
        } finally {
          // Ensure loading dialog is dismissed if still shown and we didn't already
          if (isDialogShown && mounted) {
            try {
              Navigator.of(context).pop();
            } catch (_) {}
          }
        }

        // WA typically sends 1 file; break after first successfully shown config
        // but continue loop would handle multiple SEND_MULTIPLE. For now process only first
        // to avoid stacking dialogs. If SEND_MULTIPLE, user can share again.
        break;
      }
    } finally {
      // Debounce to avoid double handling from both initial + stream on same share
      Future.delayed(const Duration(milliseconds: 500), () {
        _handlingShare = false;
        debugPrint('[Warloc] _handlingShare reset');
      });
    }
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
        onConfirm: (isNew, name, meName, existingThread) async {
          await _startImportProcess(
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

  Future<void> _startImportProcess(
    bool isNew,
    String name,
    String meName,
    ChatThread? existingThread,
    ParsedChatResult parsedData, {
    String? tempDirPath,
  }) async {
    await ChatImportService.instance.startImport(
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
