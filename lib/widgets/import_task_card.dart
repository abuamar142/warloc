import 'package:flutter/material.dart';
import 'package:warloc/services/chat_import_service.dart';
import 'package:warloc/core/theme/app_colors.dart';

class ImportTaskCard extends StatelessWidget {
  final ImportTask task;

  const ImportTaskCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final bool isImporting = task.status == ImportStatus.importing;
    final bool isCompleted = task.status == ImportStatus.completed;
    final bool isFailed = task.status == ImportStatus.failed;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.downloading;
    String statusTitle = "Mengimpor \"${task.threadName}\"...";

    if (isCompleted) {
      statusColor = AppColors.accent;
      statusIcon = Icons.check_circle_outline;
      statusTitle = "Impor \"${task.threadName}\" Selesai";
    } else if (isFailed) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline;
      statusTitle = "Impor \"${task.threadName}\" Gagal";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isImporting)
                IconButton(
                  icon: Icon(Icons.close, color: onSurface.withValues(alpha: 0.5), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ChatImportService.instance.removeTask(task.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isImporting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Baru: ${task.importedCount}  |  Duplikat: ${task.skippedCount}",
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "${(task.progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ] else if (isCompleted) ...[
            Text(
              "Total diproses: ${task.totalMessages} pesan. Baru: ${task.importedCount}, Duplikat: ${task.skippedCount}.",
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else if (isFailed) ...[
            Text(
              task.errorMessage ?? "Terjadi kesalahan yang tidak diketahui saat mengimpor.",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
