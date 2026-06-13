import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

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
            builder: (context) => FullScreenImageViewer(
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
    } catch (_) {}

    Widget videoCard = Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Play icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
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
                if (timestampOverlay != null) timestampOverlay!,
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _openFile(context, filePath),
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
    } catch (_) {}

    final extension = p.extension(fileName).toUpperCase().replaceAll('.', '');

    return GestureDetector(
      onTap: () => _openFile(context, filePath),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal membuka file: ${result.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
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

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AudioPlayerWidget({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;

  void _togglePlay() async {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    // Open using external system player
    final result = await OpenFilex.open(widget.filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal memutar audio: ${result.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    // Reset indicator back to pause after a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);
    String sizeStr = "";
    if (file.existsSync()) {
      try {
        final bytes = file.lengthSync();
        sizeStr = MediaBubbleRenderer._formatBytes(bytes);
      } catch (_) {}
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00A884),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Waveform placeholder / slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: const Color(0xFF00A884),
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: const Color(0xFF00A884),
                  ),
                  child: Slider(
                    value: 0.0,
                    onChanged: (val) {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sizeStr.isNotEmpty ? sizeStr : "Audio",
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const Icon(
                        Icons.mic,
                        size: 14,
                        color: Color(0xFF00A884),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String filePath;
  final String fileName;

  const FullScreenImageViewer({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Hero(
          tag: filePath,
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            maxScale: 4.0,
            child: Image.file(
              File(filePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  "Gagal memuat gambar",
                  style: TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
