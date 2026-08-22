import 'package:flutter/material.dart';
import 'package:warloc/services/security_service.dart';
import 'package:warloc/core/widgets/molecules/app_dialog.dart';
import 'package:warloc/core/widgets/atoms/app_button.dart';
import 'package:warloc/core/widgets/atoms/app_text_field.dart';
import 'package:warloc/core/theme/app_colors.dart';
import 'package:warloc/utils/show_message.dart';

void showRecoveryDialog(BuildContext context, VoidCallback onUnlocked) {
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
              showSecurityQuestionDialog(context, onUnlocked);
            },
          ),
          const SizedBox(height: 10),
          AppButton(
            label: "Setel Ulang Aplikasi (Hapus Data)",
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.pop(context); // Close recovery dialog
              showResetAppDialog(context, onUnlocked);
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

void showSecurityQuestionDialog(BuildContext context, VoidCallback onUnlocked) {
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
                    onUnlocked(); // Unlock app
                    showSuccessSnackBar(context, "Berhasil masuk. Silakan ubah PIN Anda di pengaturan.");
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

void showResetAppDialog(BuildContext context, VoidCallback onUnlocked) {
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
                            onUnlocked(); // Open app clean
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
