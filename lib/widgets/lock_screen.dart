import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_text_field.dart';
import '../theme/app_colors.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String _errorMessage = '';
  bool _isBiometricChecking = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on load if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuto();
    });
  }

  Future<void> _checkBiometricAuto() async {
    final security = SecurityService.instance;
    if (security.isBiometricsEnabled) {
      final canAuth = await security.canCheckBiometrics;
      if (canAuth) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isBiometricChecking) return;
    setState(() {
      _isBiometricChecking = true;
    });

    final success = await SecurityService.instance.authenticateBiometric(
      reason: 'Buka kunci aplikasi Warloc',
    );

    setState(() {
      _isBiometricChecking = false;
    });

    if (success) {
      widget.onUnlocked();
    }
  }

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = '';
      if (_enteredPin.length < SecurityService.instance.pinCode.length) {
        _enteredPin += val;
      }
    });

    // Auto submit when length is reached
    if (_enteredPin.length == SecurityService.instance.pinCode.length) {
      _submitPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _submitPin() {
    final isValid = SecurityService.instance.validatePin(_enteredPin);
    if (isValid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = 'PIN yang Anda masukkan salah.';
      });
    }
  }

  void _showRecoveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.security,
        iconColor: AppColors.primary,
        title: "Pemulihan Kunci",
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Pilih metode pemulihan untuk membuka kunci aplikasi:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: "Jawab Pertanyaan Keamanan",
              onPressed: () {
                Navigator.pop(context); // Close recovery dialog
                _showSecurityQuestionDialog();
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: "Setel Ulang Aplikasi (Hapus Data)",
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context); // Close recovery dialog
                _showResetAppDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showSecurityQuestionDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String questionErr = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AppDialog(
            icon: Icons.help_outline,
            iconColor: AppColors.primary,
            title: "Pertanyaan Keamanan",
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Jawab pertanyaan di bawah untuk membuka kunci:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SecurityService.instance.securityQuestion,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: controller,
                    hintText: "Masukkan jawaban Anda",
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Jawaban tidak boleh kosong";
                      }
                      return null;
                    },
                  ),
                  if (questionErr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      questionErr,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
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
                label: "Verifikasi",
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final isValid = SecurityService.instance.validateSecurityAnswer(controller.text);
                    if (isValid) {
                      Navigator.pop(context); // Close dialog
                      widget.onUnlocked(); // Unlock app
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Berhasil masuk. Silakan ubah PIN Anda di pengaturan."),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    } else {
                      setStateDialog(() {
                        questionErr = "Jawaban salah. Harap coba lagi.";
                      });
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetAppDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AppDialog(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.redAccent,
            title: "Setel Ulang Aplikasi",
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PERINGATAN: Tindakan ini akan menghapus seluruh riwayat chat, media terimpor, dan pengaturan secara permanen dari perangkat ini.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Ketik kata \"HAPUS\" untuk melanjutkan:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: controller,
                    hintText: "HAPUS",
                    validator: (val) {
                      if (val != 'HAPUS') {
                        return "Konfirmasi kata salah";
                      }
                      return null;
                    },
                  ),
                  if (isResetting) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 10),
                        Text("Sedang menyetel ulang...", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              AppButton(
                label: "Batal",
                onPressed: isResetting ? null : () => Navigator.pop(context),
                variant: AppButtonVariant.secondary,
              ),
              AppButton(
                label: "Hapus Semua Data",
                onPressed: isResetting
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setStateDialog(() {
                            isResetting = true;
                          });
                          try {
                            await SecurityService.instance.resetApplicationData();
                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              widget.onUnlocked(); // Open app clean
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Aplikasi telah disetel ulang."),
                                  backgroundColor: Colors.black87,
                                ),
                              );
                            }
                          } catch (_) {
                            setStateDialog(() {
                              isResetting = false;
                            });
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 70,
        width: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetLength = SecurityService.instance.pinCode.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Lock Icon
            const Icon(
              Icons.lock,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              "Aplikasi Terkunci",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Masukkan PIN keamanan Anda",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // PIN dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(targetLength, (index) {
                final filled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  height: 16,
                  width: 16,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.primary : Colors.grey[300],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: filled ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                );
              }),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],

            const Spacer(flex: 1),

            // Keyboard grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9'].map(_buildKey).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Biometric button (or empty spacer)
                      SecurityService.instance.isBiometricsEnabled
                          ? IconButton(
                              icon: const Icon(Icons.fingerprint, size: 36, color: AppColors.primary),
                              onPressed: _authenticate,
                            )
                          : const SizedBox(width: 48, height: 48),
                      _buildKey('0'),
                      // Backspace button
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, size: 28, color: Colors.grey),
                        onPressed: _onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            TextButton(
              onPressed: _showRecoveryDialog,
              child: const Text(
                "Lupa PIN?",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
