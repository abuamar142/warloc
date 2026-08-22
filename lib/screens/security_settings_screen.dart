import 'package:flutter/material.dart';
import 'package:warloc/services/security_service.dart';
import 'package:warloc/utils/show_message.dart';
import 'package:warloc/core/widgets/molecules/custom_app_bar.dart';
import 'package:warloc/widgets/security/pin_setup_dialog.dart';
import 'package:warloc/widgets/security/pin_confirm_dialog.dart';
import 'package:warloc/core/theme/app_colors.dart';

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
        if (!mounted) return;
        showSuccessSnackBar(context, "Kunci PIN berhasil diaktifkan.");
        _loadSettings();      } else {
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
        if (!mounted) return;
        showSuccessSnackBar(context, "Kunci PIN berhasil dinonaktifkan.");
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
      if (!mounted) return;
      showSuccessSnackBar(context, "PIN & Pertanyaan Keamanan berhasil diperbarui.");
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

