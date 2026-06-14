import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat_thread.dart';

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              "Konfirmasi Penggabungan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Apakah Anda yakin ingin melakukan penggabungan ini? Perubahan pada nama pengirim dan pesan akan diterapkan secara permanen ke database.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008069),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Ya, Gabungkan"),
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

      _showSnackBar("Kontak dan pengirim berhasil digabungkan!", const Color(0xFF008069));
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.people_outline, color: Color(0xFF008069)),
          SizedBox(width: 8),
          Text(
            "Detail Chat & Penggabungan",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF008069)),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit Thread Name
                    const Text(
                      "Nama Kontak (Lawan Bicara):",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _threadNameController,
                      decoration: InputDecoration(
                        hintText: "Masukkan nama kontak",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF008069), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Nama kontak tidak boleh kosong";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Edit Me Name
                    const Text(
                      "Nama Saya (Me):",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _meNameController,
                      decoration: InputDecoration(
                        hintText: "Masukkan nama Anda",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF008069), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Nama saya tidak boleh kosong";
                        }
                        return null;
                      },
                    ),
                    const Divider(height: 32),

                    // List of Senders and Mappings
                    const Text(
                      "Gabungkan Pengirim Obrolan:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Pilih letak pesan pengirim (Kanan = Saya, Kiri = Kontak).",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    _uniqueSenders.isEmpty
                        ? const Text(
                            "Tidak ada pengirim terdeteksi di chat ini.",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ChoiceChip(
                                            label: const Center(
                                              child: Text("Kontak (Kiri)"),
                                            ),
                                            selected: currentRole == 'contact',
                                            selectedColor: const Color(0x20008069),
                                            checkmarkColor: const Color(0xFF008069),
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
                                          child: ChoiceChip(
                                            label: const Center(
                                              child: Text("Saya (Kanan)"),
                                            ),
                                            selected: currentRole == 'me',
                                            selectedColor: const Color(0x20008069),
                                            checkmarkColor: const Color(0xFF008069),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _confirmAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF008069),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Simpan"),
        ),
      ],
    );
  }
}
