import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:warloc/core/theme/app_colors.dart';
import 'package:warloc/data/backup_helper.dart';
import 'package:warloc/utils/show_message.dart';
import 'package:warloc/core/widgets/atoms/app_button.dart';
import 'package:warloc/core/widgets/atoms/app_choice_chip.dart';
import 'package:warloc/core/widgets/molecules/app_dialog.dart';
import 'package:warloc/core/widgets/atoms/loading_indicator.dart';

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

      final f = File(tempPath);
      if (!await f.exists() || await f.length() == 0) {
        debugPrint('File cadangan kosong: $tempPath tidak ada atau 0 byte');
        if (context.mounted) {
          showErrorSnackBar(context, 'File cadangan kosong');
        }
        throw Exception('File cadangan kosong');
      }
      final tempSize = await f.length();
      if (tempSize < 100) {
        debugPrint('File cadangan terlalu kecil: $tempSize byte');
        if (context.mounted) {
          showErrorSnackBar(context, 'File cadangan rusak (terlalu kecil)');
        }
        throw Exception('Backup terlalu kecil');
      }
      debugPrint('Backup temp created: $tempPath size=$tempSize');

      // Close loading dialog before opening native save dialog
      if (context.mounted && isDialogShown) {
        Navigator.pop(context);
        isDialogShown = false;
      }

      // 3. Prompt user to select save destination — avoid loading full file into RAM.
      // Previous code used `bytes: backupBytes` (readAsBytes 703 MB → OOM over MethodChannel).
      // Now we get outputPath first, then stream-copy temp file to destination.
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Simpan Cadangan Warloc',
        fileName: 'warloc_backup_${DateTime.now().millisecondsSinceEpoch}.wlb',
        type: FileType.custom,
        allowedExtensions: ['wlb', 'zip'],
      );

      if (outputPath == null) {
        // User cancelled — cleanup temp
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
        return;
      }

      // Stream-copy temp file to user-chosen path (avoids 703 MB heap allocation)
      try {
        final outFile = File(outputPath);
        // If saveFile returned a content:// URI, File API will fail — fallback to bytes is not viable for huge files.
        // For now handle filesystem path; for content URI, log and show error to guide user to pick Downloads.
        if (outputPath.startsWith('content://')) {
          debugPrint('Output is content URI, attempting fallback via bytes (may OOM for huge files)');
          // Fallback: try streaming via openRead/openWrite if underlying file is accessible via FileUtils path
          // If still content URI, we cannot handle 703 MB without OOM — show guidance
          throw Exception('Penyimpanan content:// belum didukung untuk file besar. Pilih folder Download/internal storage.');
        }
        await f.copy(outputPath);
        // Verify copy
        final outLen = await outFile.length();
        debugPrint('Backup copied to $outputPath size=$outLen');
        if (outLen != tempSize) {
          debugPrint('Warning: copied size mismatch temp=$tempSize out=$outLen');
        }
      } catch (e) {
        debugPrint('Gagal menyalin backup ke $outputPath: $e');
        if (context.mounted) {
          showErrorSnackBar(context, 'Gagal menyimpan cadangan: $e');
        }
        // Keep temp for retry? cleanup anyway
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
        return;
      }

      // Clean up temporary file
      try {
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint("Gagal membersihkan file cadangan sementara: $e");
      }

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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wlb', 'zip'],
    );

    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;
    final backupPath = result.files.single.path!;
    await importBackupWithPath(
      context,
      backupPath,
      onRestoreSuccess: onRestoreSuccess,
    );
  }

  /// Restores a backup from an already-known file [backupPath] (e.g. from
  /// file picker or share intent) without re-prompting for a file. Validates
  /// that the archive contains `warloc_chats.db`, asks for merge/overwrite,
  /// and delegates to [BackupHelper].
  static Future<void> importBackupWithPath(
    BuildContext context,
    String backupPath, {
    required VoidCallback onRestoreSuccess,
  }) async {
    bool isDialogShown = false;
    try {

      // --- Validasi file backup sebelum menampilkan dialog mode ---
      final file = File(backupPath);
      if (!await file.exists() || await file.length() == 0) {
        if (context.mounted) {
          showErrorSnackBar(context, 'File kosong (0 byte)');
        }
        return;
      }
      Archive archive;
      try {
        final bytes = await file.readAsBytes();
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        debugPrint('File bukan zip/wlb valid: $e');
        if (context.mounted) {
          showErrorSnackBar(context, 'File bukan zip/wlb valid');
        }
        return;
      }
      final hasDb = archive.any((e) => e.name == 'warloc_chats.db');
      if (!hasDb) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Backup tidak mengandung warloc_chats.db — bukan file .wlb valid');
        }
        return;
      }

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
        if (!context.mounted) return;
        showSuccessSnackBar(context, "Cadangan data berhasil dipulihkan!");
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
