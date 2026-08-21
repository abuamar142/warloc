import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../theme/app_colors.dart';
import 'common/app_dialog.dart';
import 'common/app_text_field.dart';
import 'common/app_choice_chip.dart';
import 'common/app_button.dart';
import 'common/loading_indicator.dart';

class ManageSendersDialog extends StatefulWidget {
  final ChatThread thread;
  final VoidCallback onSuccess;

  const ManageSendersDialog({
    super.key,
    required this.thread,
    required this.onSuccess,
  });

  @override
  State<ManageSendersDialog> createState() => _ManageSendersDialogState();
}

class _ManageSendersDialogState extends State<ManageSendersDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _threadNameController;
  late final TextEditingController _meNameController;
  List<String> _uniqueSenders = [];
  Map<String, String> _senderMappings = {}; // key: sender, value: 'me' or 'contact'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _threadNameController = TextEditingController(text: widget.thread.name);
    _meNameController = TextEditingController(text: widget.thread.meName);
    _loadSenders();
  }

  @override
  void dispose() {
    _threadNameController.dispose();
    _meNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSenders() async {
    try {
      final db = DatabaseHelper.instance;
      final senders = await db.getUniqueSendersForThread(widget.thread.id!);

      final Map<String, String> mappings = {};
      for (final sender in senders) {
        if (sender == widget.thread.meName) {
          mappings[sender] = 'me';
        } else {
          mappings[sender] = 'contact';
        }
      }

      setState(() {
        _uniqueSenders = senders;
        _senderMappings = mappings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal memuat pengirim: $e", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newThreadName = _threadNameController.text.trim();
    final newMeName = _meNameController.text.trim();

    // 1. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
        title: "Konfirmasi Penggabungan",
        content: Text(
          "Apakah Anda yakin ingin melakukan penggabungan ini? Perubahan pada nama pengirim dan pesan akan diterapkan secara permanen ke database.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          AppButton(
            label: "Batal",
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: "Ya, Gabungkan",
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. Perform database transaction
    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;

      // Construct final mappings to apply
      final Map<String, String> finalMappings = {};
      for (final entry in _senderMappings.entries) {
        final oldSender = entry.key;
        final targetRole = entry.value;
        finalMappings[oldSender] = (targetRole == 'me') ? newMeName : newThreadName;
      }

      await db.mergeSenders(
        threadId: widget.thread.id!,
        newThreadName: newThreadName,
        newMeName: newMeName,
        senderMappings: finalMappings,
      );

      _showSnackBar("Kontak dan pengirim berhasil digabungkan!", AppColors.primary);
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Gagal menyimpan perubahan: $e", Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog(
      icon: Icons.people_outline,
      iconColor: AppColors.primary,
      title: "Detail Chat & Penggabungan",
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: CustomLoadingIndicator(),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit Thread Name
                    Text(
                      "Nama Kontak (Lawan Bicara):",
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _threadNameController,
                      hintText: "Masukkan nama kontak",
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Nama kontak tidak boleh kosong";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Edit Me Name
                    Text(
                      "Nama Saya (Me):",
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _meNameController,
                      hintText: "Masukkan nama Anda",
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Nama saya tidak boleh kosong";
                        }
                        return null;
                      },
                    ),
                    const Divider(height: 32),

                    // List of Senders and Mappings
                    Text(
                      "Gabungkan Pengirim Obrolan:",
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Pilih letak pesan pengirim (Kanan = Saya, Kiri = Kontak).",
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    _uniqueSenders.isEmpty
                        ? Text(
                            "Tidak ada pengirim terdeteksi di chat ini.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(_uniqueSenders.length, (index) {
                              final sender = _uniqueSenders[index];
                              final currentRole = _senderMappings[sender] ?? 'contact';

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _uniqueSenders.length - 1 ? 0 : 16.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sender,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppChoiceChip(
                                            label: const Center(
                                              child: Text("Kontak (Kiri)"),
                                            ),
                                            selected: currentRole == 'contact',
                                            onSelected: (val) {
                                              if (val) {
                                                setState(() {
                                                  _senderMappings[sender] = 'contact';
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AppChoiceChip(
                                            label: const Center(
                                              child: Text("Saya (Kanan)"),
                                            ),
                                            selected: currentRole == 'me',
                                            onSelected: (val) {
                                              if (val) {
                                                setState(() {
                                                  _senderMappings[sender] = 'me';
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                  ],
                ),
              ),
            ),
      actions: [
        AppButton(
          label: "Batal",
          onPressed: () => Navigator.pop(context),
          variant: AppButtonVariant.secondary,
        ),
        AppButton(
          label: "Simpan",
          onPressed: _confirmAndSave,
        ),
      ],
    );
  }
}
