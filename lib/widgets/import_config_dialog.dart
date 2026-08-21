import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/chat_thread.dart';
import '../models/parsed_chat_result.dart';
import '../theme/app_colors.dart';
import 'common/app_dialog.dart';
import 'common/app_choice_chip.dart';
import 'common/app_button.dart';
import 'common/app_text_field.dart';

class ImportConfigDialog extends StatefulWidget {
  final String filePath;
  final ParsedChatResult parsedData;
  final List<ChatThread> existingThreads;
  final String? tempDirPath;
  final Function(bool isNew, String name, String meName, ChatThread? existingThread) onConfirm;

  const ImportConfigDialog({
    super.key,
    required this.filePath,
    required this.parsedData,
    required this.existingThreads,
    this.tempDirPath,
    required this.onConfirm,
  });

  @override
  State<ImportConfigDialog> createState() => _ImportConfigDialogState();
}

class _ImportConfigDialogState extends State<ImportConfigDialog> {
  late final TextEditingController _nameController;
  late String _selectedMe;
  ChatThread? _selectedExistingThread;
  bool _createNewThread = true;

  @override
  void initState() {
    super.initState();
    final senders = widget.parsedData.uniqueSenders;

    String defaultContactName = "WhatsApp Chat";
    if (senders.isNotEmpty) {
      defaultContactName = senders.join(" & ");
      if (senders.length == 2) {
        defaultContactName = senders[0];
      }
    }

    _nameController = TextEditingController(text: defaultContactName);
    _selectedMe = senders.isNotEmpty ? senders[0] : '';
    
    if (widget.existingThreads.isNotEmpty) {
      _selectedExistingThread = widget.existingThreads[0];
      _createNewThread = false; // Default to merge if existing threads exist
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.filePath);
    final senders = widget.parsedData.uniqueSenders;
    final theme = Theme.of(context);

    return AppDialog(
      icon: Icons.import_export,
      iconColor: AppColors.primary,
      title: "Konfigurasi Import",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "File: $fileName",
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "Total pesan terdeteksi: ${widget.parsedData.messages.length}",
              style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
            const Divider(height: 24),

            if (widget.existingThreads.isNotEmpty) ...[
              Text(
                "Tujuan Import:",
                style: theme.textTheme.titleSmall,
              ),
              Row(
                children: [
                  AppChoiceChip(
                    label: const Text("Thread Baru"),
                    selected: _createNewThread,
                    onSelected: (val) {
                      setState(() {
                        _createNewThread = true;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  AppChoiceChip(
                    label: const Text("Gabung Thread"),
                    selected: !_createNewThread,
                    onSelected: (val) {
                      setState(() {
                        _createNewThread = false;
                        if (_selectedExistingThread == null && widget.existingThreads.isNotEmpty) {
                          _selectedExistingThread = widget.existingThreads[0];
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (_createNewThread) ...[
              Text(
                "Nama Kontak / Chat:",
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _nameController,
                hintText: "Masukkan nama kontak",
              ),
            ] else ...[
              Text(
                "Pilih Thread untuk Digabungkan:",
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ChatThread>(
                    value: _selectedExistingThread,
                    isExpanded: true,
                    onChanged: (ChatThread? val) {
                      setState(() {
                        _selectedExistingThread = val;
                        if (val != null && senders.contains(val.meName)) {
                          _selectedMe = val.meName;
                        }
                      });
                    },
                    items: widget.existingThreads.map((thread) {
                      return DropdownMenuItem<ChatThread>(
                        value: thread,
                        child: Text(thread.name),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Text(
              "Pilih Siapa \"Saya\" (Me):",
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              "Pesan dari nama ini akan diposisikan di sebelah kanan (hijau).",
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 6),
            senders.isEmpty
                ? const Text("Tidak ada pengirim terdeteksi", style: TextStyle(color: Colors.red))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMe,
                        isExpanded: true,
                        onChanged: (String? val) {
                          setState(() {
                            _selectedMe = val!;
                          });
                        },
                        items: senders.map((sender) {
                          return DropdownMenuItem<String>(
                            value: sender,
                            child: Text(sender),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Batal",
          onPressed: () => Navigator.pop(context),
          variant: AppButtonVariant.secondary,
        ),
        AppButton(
          label: "Mulai Import",
          onPressed: () {
            final contactName = _createNewThread 
                ? _nameController.text.trim()
                : _selectedExistingThread?.name ?? "Merged Chat";
            
            if (contactName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Nama kontak tidak boleh kosong."),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }
            
            Navigator.pop(context);
            widget.onConfirm(
              _createNewThread,
              contactName,
              _selectedMe,
              _selectedExistingThread,
            );
          },
        ),
      ],
    );
  }
}
