import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(
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
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _player.setSource(DeviceFileSource(widget.filePath));

      _player.onDurationChanged.listen((d) {
        if (mounted) {
          setState(() {
            _duration = d;
          });
        }
      });

      _player.onPositionChanged.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
          });
        }
      });

      _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });
    } catch (e) {
      debugPrint("Gagal menginisialisasi audio player: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(DeviceFileSource(widget.filePath));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memutar audio: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              "Audio tidak ditemukan",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
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
                    min: 0.0,
                    max: _duration.inMilliseconds.toDouble() > 0.0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds.toDouble() > 0.0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                        ),
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isPlaying || _position.inMilliseconds > 0
                            ? "${_formatDuration(_position)} / ${_formatDuration(_duration)}"
                            : (sizeStr.isNotEmpty ? "$sizeStr • ${_formatDuration(_duration)}" : _formatDuration(_duration)),
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

class FullScreenVideoPlayer extends StatefulWidget {
  final String filePath;
  final String fileName;

  const FullScreenVideoPlayer({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = _controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video display
            if (isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A884)),
              ),

            // AppBar / Top bar control
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.only(top: 40, bottom: 10, left: 10, right: 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom bar controls
            if (_showControls && isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Video progress indicator slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: const Color(0xFF00A884),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFF00A884),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: _controller.value.duration.inMilliseconds.toDouble(),
                          value: _controller.value.position.inMilliseconds.toDouble().clamp(
                            0.0,
                            _controller.value.duration.inMilliseconds.toDouble(),
                          ),
                          onChanged: (val) {
                            _controller.seekTo(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play / Pause button
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _togglePlay,
                              ),
                              const SizedBox(width: 8),
                              // Duration display
                              Text(
                                "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                          // Volume / Mute button
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: _toggleMute,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Big Play/Pause icon in the center if paused
            if (_showControls && isInitialized && !_controller.value.isPlaying)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
