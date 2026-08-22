import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:warloc/utils/show_message.dart';
import 'package:warloc/core/widgets/media/audio_player_widget.dart';
import 'package:warloc/core/widgets/media/media_viewer_screen.dart';
import 'package:warloc/core/widgets/media/video_player_view.dart';

class MediaBubbleRenderer extends StatelessWidget {
  final String mediaPath;
  final String mediaType;
  final String mediaDirPath;
  final Widget? timestampOverlay; // Used to overlay timestamp on images/videos

  const MediaBubbleRenderer({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaDirPath,
    this.timestampOverlay,
  });

  String get _absolutePath => p.join(mediaDirPath, mediaPath);

  @override
  Widget build(BuildContext context) {
    switch (mediaType) {
      case 'image':
        return _buildImage(context, _absolutePath, mediaPath);
      case 'sticker':
        return _buildSticker(context, _absolutePath, mediaPath);
      case 'video':
        return _buildVideo(context, _absolutePath, mediaPath);
      case 'audio':
        return AudioPlayerWidget(filePath: _absolutePath, fileName: mediaPath);
      case 'document':
      default:
        return _buildDocument(context, _absolutePath, mediaPath);
    }
  }

  Widget _buildImage(BuildContext context, String filePath, String fileName) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return _buildMissingMediaPlaceholder(fileName);
    }

    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        cacheWidth: 600,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder("Gagal memuat gambar");
        },
      ),
    );

    if (timestampOverlay != null) {
      imageWidget = Stack(
        children: [
          imageWidget,
          Positioned(
            bottom: 4,
            right: 4,
            child: timestampOverlay!,
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewerScreen.single(
              filePath: filePath,
              fileName: fileName,
            ),
          ),
        );
      },
      child: Hero(
        tag: filePath,
        child: imageWidget,
      ),
    );
  }

  Widget _buildSticker(BuildContext context, String filePath, String fileName) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return _buildMissingMediaPlaceholder(fileName);
    }

    return Image.file(
      file,
      width: 130,
      height: 130,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder("Gagal memuat stiker");
      },
    );
  }

  Widget _buildVideo(BuildContext context, String filePath, String fileName) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return _buildMissingMediaPlaceholder(fileName);
    }

    String sizeStr = "";
    try {
      final bytes = file.lengthSync();
      sizeStr = _formatBytes(bytes);
    } catch (e) {
      debugPrint("Gagal membaca ukuran file video '$fileName': $e");
    }

    Widget videoCard = Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Play icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
          // Info header
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Size and Timestamp overlay at bottom
          Positioned(
            bottom: 6,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sizeStr.isNotEmpty)
                  Text(
                    sizeStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ?timestampOverlay,
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerView(
              filePath: filePath,
              fileName: fileName,
            ),
          ),
        );
      },
      child: videoCard,
    );
  }

  Widget _buildDocument(BuildContext context, String filePath, String fileName) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return _buildMissingMediaPlaceholder(fileName);
    }

    String sizeStr = "";
    try {
      final bytes = file.lengthSync();
      sizeStr = _formatBytes(bytes);
    } catch (e) {
      debugPrint("Gagal membaca ukuran file dokumen '$fileName': $e");
    }

    final extension = p.extension(fileName).toUpperCase().replaceAll('.', '');

    return GestureDetector(
      onTap: () => _openFile(context, filePath),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.insert_drive_file,
                color: Colors.red[700],
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${sizeStr.isNotEmpty ? '$sizeStr • ' : ''}$extension",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingMediaPlaceholder(String fileName) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[800], size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Media tidak ditemukan",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder(String message) {
    return Container(
      height: 150,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _openFile(BuildContext context, String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      showErrorSnackBar(context, "Gagal membuka file: ${result.message}");
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final double val = bytes / (1 << (10 * i));
    return "${val.toStringAsFixed(1)} ${suffixes[i]}";
  }
}
