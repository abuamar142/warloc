import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/chat_message.dart';
import 'video_player_view.dart';

/// Unified fullscreen media viewer.
///
/// - [MediaViewerScreen.single] shows one image (hero-compatible, opened from
///   chat bubbles).
/// - [MediaViewerScreen.gallery] shows a swipeable PageView over a thread's
///   media messages (images, stickers, videos, fallback placeholders).
class MediaViewerScreen extends StatefulWidget {
  final List<ChatMessage>? _mediaMessages;
  final int _initialIndex;
  final String? _mediaDirPath;
  final String? _singleFilePath;
  final String? _singleFileName;

  const MediaViewerScreen.single({
    super.key,
    required String filePath,
    required String fileName,
  })  : _singleFilePath = filePath,
        _singleFileName = fileName,
        _mediaMessages = null,
        _initialIndex = 0,
        _mediaDirPath = null;

  const MediaViewerScreen.gallery({
    super.key,
    required List<ChatMessage> mediaMessages,
    required int initialIndex,
    required String mediaDirPath,
  })  : _mediaMessages = mediaMessages,
        _initialIndex = initialIndex,
        _mediaDirPath = mediaDirPath,
        _singleFilePath = null,
        _singleFileName = null;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController? _pageController;
  late int _currentIndex;

  bool get _isGallery => widget._mediaMessages != null;

  @override
  void initState() {
    super.initState();
    if (_isGallery) {
      _currentIndex = widget._initialIndex;
      _pageController = PageController(initialPage: widget._initialIndex);
    } else {
      _currentIndex = 0;
      _pageController = null;
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGallery) {
      return _buildSingle(context);
    }
    return _buildGallery(context);
  }

  /// Single-image mode (was FullScreenImageViewer).
  Widget _buildSingle(BuildContext context) {
    final filePath = widget._singleFilePath!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget._singleFileName!,
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

  /// Swipeable gallery mode (was FullScreenGalleryViewer).
  Widget _buildGallery(BuildContext context) {
    final messages = widget._mediaMessages!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messages[_currentIndex].sender.isNotEmpty
                  ? messages[_currentIndex].sender
                  : "Sistem",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              messages[_currentIndex].mediaPath ?? "",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                "${_currentIndex + 1} / ${messages.length}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: messages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final msg = messages[index];
          final filePath = p.join(widget._mediaDirPath!, msg.mediaPath!);
          final file = File(filePath);

          if (!file.existsSync()) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white24),
                  SizedBox(height: 8),
                  Text("Berkas tidak ditemukan", style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          if (msg.mediaType == 'video') {
            return VideoPlayerView(filePath: filePath, showControls: false);
          } else if (msg.mediaType == 'image' || msg.mediaType == 'sticker') {
            return InteractiveViewer(
              maxScale: 4.0,
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    msg.mediaType == 'audio' ? Icons.mic : Icons.insert_drive_file,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    msg.mediaPath ?? "",
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
