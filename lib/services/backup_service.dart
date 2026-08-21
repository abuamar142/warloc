import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';
import '../utils/backup_helper.dart';
import '../utils/show_message.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_choice_chip.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/loading_indicator.dart';

/// Orchestrates full-backup export and restore flows.
///
/// Owns everything that used to live in [ChatListScreen]'s backup menu
/// actions: progress dialogs, native save/pick prompts, temporary file
/// cleanup, and success/error surfacing. The actual zip/database work is
/// delegated to [BackupHelper].
class BackupService {
  BackupService._();

  /// Generates a `.wlb` backup in a temporary folder and prompts the user
  /// for a save destination. Cleans up the temporary file afterwards.
  static Future<void> exportBackup(BuildContext context) async {
    bool isDialogShown = false;
    try {
      // 1. Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CustomLoadingIndicator(),
      );
      isDialogShown = true;

      // 2. Generate backup locally in internal temporary folder (scoped storage safe)
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'warloc_backup_${DateTime.now().millisecondsSinceEpoch}.wlb');
      await BackupHelper.createBackup(tempPath);

      final backupBytes = await File(tempPath).readAsBytes();

      // Close loading dialog before opening native save dialog
      if (context.mounted && isDialogShown) {
        Navigator.pop(context);
        isDialogShown = false;
      }

      // 3. Prompt user to select save destination and write bytes natively
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Simpan Cadangan Warloc',
        fileName: 'warloc_backup_${DateTime.now().millisecondsSinceEpoch}.wlb',
        type: FileType.custom,
        allowedExtensions: ['wlb', 'zip'],
        bytes: backupBytes,
      );

      // Clean up temporary file
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint("Gagal membersihkan file cadangan sementara: $e");
      }

      if (outputPath == null) return; // User cancelled

      if (context.mounted) {
        showSuccessSnackBar(context, "Cadangan data berhasil diekspor!");
      }
    } catch (e) {
      if (context.mounted) {
        if (isDialogShown) {
          Navigator.pop(context);
        }
        showErrorSnackBar(context, "Gagal mengekspor cadangan: $e");
      }
    }
  }

  /// Picks a `.wlb`/`.zip` backup file, asks the user for a restore mode
  /// (merge or overwrite), restores it via [BackupHelper], and reports the
  /// outcome.
  ///
  /// [onRestoreSuccess] is invoked after a successful restore so callers can
  /// refresh their data (e.g. reload the thread list).
  static Future<void> importBackup(
    BuildContext context, {
    required VoidCallback onRestoreSuccess,
  }) async {
    bool isDialogShown = false;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wlb', 'zip'],
      );

      if (result == null || result.files.single.path == null) return;
      final backupPath = result.files.single.path!;

      if (!context.mounted) return;

      final importMode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String selectedMode = 'merge'; // Default to merge
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AppDialog(
        icon: Icons.restore,
        iconColor: AppColors.primary,
        title: "Pilih Mode Impor",
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bagaimana Anda ingin memulihkan cadangan data ini?",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppChoiceChip(
              label: const Text("Gabung Chat (Rekomendasi)"),
              selected: selectedMode == 'merge',
              onSelected: (val) {
                setStateDialog(() {
                  selectedMode = 'merge';
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              "Menggabungkan riwayat chat tanpa menghapus pesan yang ada. Pesan duplikat akan dilewati secara otomatis.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            AppChoiceChip(
              label: const Text("Timpa Semua Data"),
              selected: selectedMode == 'overwrite',
              onSelected: (val) {
                setStateDialog(() {
                  selectedMode = 'overwrite';
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              "PERINGATAN: Menghapus semua chat dan media saat ini, lalu menggantinya secara total dengan isi cadangan.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: "Batal",
            onPressed: () => Navigator.pop(context),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: "Impor",
            onPressed: () => Navigator.pop(context, selectedMode),
          ),
        ],
      );
            },
          );
        },
      );

      if (importMode == null) return;

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CustomLoadingIndicator(),
      );
      isDialogShown = true;

      bool success = false;
      if (importMode == 'overwrite') {
        success = await BackupHelper.restoreBackupOverwrite(backupPath);
      } else {
        success = await BackupHelper.restoreBackupMerge(backupPath);
      }

      if (context.mounted && isDialogShown) {
        Navigator.pop(context); // Dismiss loading dialog
        isDialogShown = false;
      }

      if (success) {
        onRestoreSuccess();
        if (context.mounted) {
          showSuccessSnackBar(context, "Cadangan data berhasil dipulihkan!");
        }
      } else {
        if (!context.mounted) return;
        showErrorSnackBar(context, "Gagal memulihkan cadangan. Pastikan format file cadangan valid.");
      }
    } catch (e) {
      if (context.mounted) {
        if (isDialogShown) {
          Navigator.pop(context); // Dismiss loading dialog
        }
        showErrorSnackBar(context, "Gagal mengimpor cadangan: $e");
      }
    }
  }
}
