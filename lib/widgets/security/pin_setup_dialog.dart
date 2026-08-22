import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warloc/core/widgets/molecules/app_dialog.dart';
import 'package:warloc/core/widgets/atoms/app_button.dart';
import 'package:warloc/core/theme/app_colors.dart';

class PINSetupDialog extends StatefulWidget {
  final bool isChanging;

  const PINSetupDialog({super.key, this.isChanging = false});

  @override
  State<PINSetupDialog> createState() => _PINSetupDialogState();
}

class _PINSetupDialogState extends State<PINSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _customQuestionController = TextEditingController();
  final _answerController = TextEditingController();

  final List<String> _questions = [
    "Apa nama hewan peliharaan pertama Anda?",
    "Di kota mana orang tua Anda pertama kali bertemu?",
    "Apa nama sekolah dasar pertama Anda?",
    "Siapa nama guru favorit Anda di sekolah?",
    "Tulis pertanyaan Anda sendiri",
  ];

  late String _selectedQuestion;
  bool _isCustomQuestion = false;

  @override
  void initState() {
    super.initState();
    _selectedQuestion = _questions[0];
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _customQuestionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey,
        fontSize: 13,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[600] : Colors.grey[400],
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppDialog(
      icon: Icons.security,
      iconColor: isDark ? AppColors.accent : AppColors.primary,
      title: widget.isChanging ? "Ubah Kunci PIN" : "Atur Kunci PIN",
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Tentukan PIN baru beserta pertanyaan keamanan untuk memulihkan PIN jika Anda lupa.",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey),
              ),
              const SizedBox(height: 16),
              
              // PIN Baru
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                decoration: _buildInputDecoration("PIN Baru (4 angka)", "Masukkan 4 angka"),
                validator: (val) {
                  if (val == null || val.length != 4) {
                    return "PIN harus terdiri dari 4 angka";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Konfirmasi PIN Baru
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                decoration: _buildInputDecoration("Konfirmasi PIN Baru", "Masukkan kembali PIN baru"),
                validator: (val) {
                  if (val != _pinController.text) {
                    return "Konfirmasi PIN tidak cocok";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Dropdown Pertanyaan Keamanan
              Text(
                "Pertanyaan Keamanan",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedQuestion,
                    isExpanded: true,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                    onChanged: (String? val) {
                      if (val != null) {
                        setState(() {
                          _selectedQuestion = val;
                          _isCustomQuestion = val == "Tulis pertanyaan Anda sendiri";
                        });
                      }
                    },
                    items: _questions.map((q) {
                      return DropdownMenuItem<String>(
                        value: q,
                        child: Text(
                          q, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Input Pertanyaan Kustom jika dipilih
              if (_isCustomQuestion) ...[
                TextFormField(
                  controller: _customQuestionController,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                  decoration: _buildInputDecoration("Tulis Pertanyaan Anda", "Contoh: Siapa nama cinta pertama Anda?"),
                  validator: (val) {
                    if (_isCustomQuestion && (val == null || val.trim().isEmpty)) {
                      return "Pertanyaan kustom tidak boleh kosong";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Jawaban Pertanyaan Keamanan
              TextFormField(
                controller: _answerController,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                decoration: _buildInputDecoration("Jawaban Keamanan", "Masukkan jawaban Anda"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Jawaban tidak boleh kosong";
                  }
                  return null;
                },
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final pin = _pinController.text;
              final question = _isCustomQuestion ? _customQuestionController.text.trim() : _selectedQuestion;
              final answer = _answerController.text.trim();

              Navigator.pop(context, {
                'pin': pin,
                'question': question,
                'answer': answer,
              });
            }
          },
        ),
      ],
    );
  }
}
