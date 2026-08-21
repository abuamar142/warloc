import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/custom_app_bar.dart';
import '../theme/app_colors.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLockEnabled = false;
  bool _isBiometricsEnabled = false;
  bool _canCheckBiometrics = false;
  int _lockTimeoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final security = SecurityService.instance;
    final canCheck = await security.canCheckBiometrics;
    setState(() {
      _isLockEnabled = security.isLockEnabled;
      _isBiometricsEnabled = security.isBiometricsEnabled;
      _canCheckBiometrics = canCheck;
      _lockTimeoutSeconds = security.lockTimeoutSeconds;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _toggleLock(bool enabled) async {
    if (enabled) {
      // Setup PIN and security question
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PINSetupDialog(),
      );

      if (result != null) {
        await SecurityService.instance.setLockSettings(
          enabled: true,
          pin: result['pin']!,
          question: result['question']!,
          answer: result['answer']!,
        );
        _showSuccessSnackBar("Kunci PIN berhasil diaktifkan.");
        _loadSettings();
      } else {
        // User cancelled, keep switch OFF
        setState(() {
          _isLockEnabled = false;
        });
      }
    } else {
      // Disable PIN: ask for current PIN first
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PINConfirmDialog(
          title: "Nonaktifkan Kunci PIN",
          instruction: "Masukkan PIN Anda saat ini untuk menonaktifkan penguncian.",
        ),
      );

      if (confirmed == true) {
        await SecurityService.instance.setLockSettings(
          enabled: false,
          pin: '',
          question: '',
          answer: '',
        );
        _showSuccessSnackBar("Kunci PIN berhasil dinonaktifkan.");
        _loadSettings();
      } else {
        // User cancelled or validation failed, keep switch ON
        setState(() {
          _isLockEnabled = true;
        });
      }
    }
  }

  Future<void> _changePinAndQuestion() async {
    // 1. Confirm current PIN
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PINConfirmDialog(
        title: "Ubah PIN & Pertanyaan",
        instruction: "Masukkan PIN Anda saat ini untuk melanjutkan.",
      ),
    );

    if (verified != true) return;

    // 2. Open setup dialog to set new values
    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PINSetupDialog(isChanging: true),
    );

    if (result != null) {
      await SecurityService.instance.setLockSettings(
        enabled: true,
        pin: result['pin']!,
        question: result['question']!,
        answer: result['answer']!,
      );
      _showSuccessSnackBar("PIN & Pertanyaan Keamanan berhasil diperbarui.");
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey[200]!;

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text("Pengaturan Keamanan"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.lock_outline, color: isDark ? AppColors.accent : AppColors.primary),
                  title: const Text(
                    "Kunci Aplikasi dengan PIN",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Minta PIN untuk membuka aplikasi Warloc",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isLockEnabled,
                  onChanged: _toggleLock,
                ),
                if (_isLockEnabled && _canCheckBiometrics) ...[
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: Icon(Icons.fingerprint, color: isDark ? AppColors.accent : AppColors.primary),
                    title: const Text(
                      "Buka Kunci dengan Sidik Jari",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      "Gunakan autentikasi biometrik perangkat",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isBiometricsEnabled,
                    onChanged: (val) async {
                      await SecurityService.instance.setBiometricsEnabled(val);
                      _loadSettings();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLockEnabled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                "PENGATURAN LAINNYA",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_reset, color: isDark ? AppColors.accent : AppColors.primary),
                    title: const Text(
                      "Ubah PIN & Pertanyaan Keamanan",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      "Perbarui PIN keamanan atau pertanyaan pemulihan",
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _changePinAndQuestion,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.timer_outlined, color: isDark ? AppColors.accent : AppColors.primary),
                    title: const Text(
                      "Batas Waktu Penguncian",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      "Kunci aplikasi setelah tidak aktif",
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _lockTimeoutSeconds,
                        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                        style: TextStyle(
                          color: isDark ? AppColors.accent : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        onChanged: (int? val) async {
                          if (val != null) {
                            await SecurityService.instance.setLockTimeout(val);
                            _loadSettings();
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("Seketika")),
                          DropdownMenuItem(value: 30, child: Text("30 detik")),
                          DropdownMenuItem(value: 60, child: Text("1 menit")),
                          DropdownMenuItem(value: 300, child: Text("5 menit")),
                          DropdownMenuItem(value: 900, child: Text("15 menit")),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

class PINConfirmDialog extends StatefulWidget {
  final String title;
  final String instruction;

  const PINConfirmDialog({
    super.key,
    required this.title,
    required this.instruction,
  });

  @override
  State<PINConfirmDialog> createState() => _PINConfirmDialogState();
}

class _PINConfirmDialogState extends State<PINConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  String _errorText = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppDialog(
      icon: Icons.lock_outline,
      iconColor: isDark ? AppColors.accent : AppColors.primary,
      title: widget.title,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.instruction,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: "PIN Saat Ini",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13),
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 13),
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
              ),
              validator: (val) {
                if (val == null || val.length != 4) {
                  return "PIN harus terdiri dari 4 angka";
                }
                return null;
              },
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _errorText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Batal",
          onPressed: () => Navigator.pop(context, false),
          variant: AppButtonVariant.secondary,
        ),
        AppButton(
          label: "Verifikasi",
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final isValid = SecurityService.instance.validatePin(_pinController.text);
              if (isValid) {
                Navigator.pop(context, true);
              } else {
                setState(() {
                  _pinController.clear();
                  _errorText = "PIN yang dimasukkan salah.";
                });
              }
            }
          },
        ),
      ],
    );
  }
}
