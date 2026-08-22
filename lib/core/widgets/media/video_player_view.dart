import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:warloc/core/theme/app_colors.dart';

/// Unified video player.
///
/// [showControls] = true renders a standalone fullscreen route with top/bottom
/// control bars (back button, seek slider, play/pause, duration, mute).
/// [showControls] = false renders an embedded player without chrome, used
/// inside the media gallery PageView.
class VideoPlayerView extends StatefulWidget {
  final String filePath;
  final String? fileName;
  final bool showControls;

  const VideoPlayerView({
    super.key,
    required this.filePath,
    this.fileName,
    this.showControls = true,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
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
    // NOTE: No addListener here — we use ValueListenableBuilder in build()
    // to avoid setState being called on every video frame (60fps).
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
    if (!widget.showControls) {
      return _buildEmbedded();
    }
    return _buildFullscreenChrome();
  }

  /// Chrome-less player for embedding (e.g. gallery PageView page).
  Widget _buildEmbedded() {
    return Center(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, videoValue, child) {
          if (!videoValue.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          return Center(
            child: AspectRatio(
              aspectRatio: videoValue.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: AnimatedOpacity(
                        opacity: videoValue.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            videoValue.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fullscreen route with control chrome.
  Widget _buildFullscreenChrome() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, videoValue, child) {
            final isInitialized = videoValue.isInitialized;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Video display
                if (isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: videoValue.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
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
                              widget.fileName ?? "",
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
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.accent,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: videoValue.duration.inMilliseconds.toDouble(),
                              value: videoValue.position.inMilliseconds.toDouble().clamp(
                                0.0,
                                videoValue.duration.inMilliseconds.toDouble(),
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
                                      videoValue.isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: _togglePlay,
                                  ),
                                  const SizedBox(width: 8),
                                  // Duration display
                                  Text(
                                    "${_formatDuration(videoValue.position)} / ${_formatDuration(videoValue.duration)}",
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
                if (_showControls && isInitialized && !videoValue.isPlaying)
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
            );
          },
        ),
      ),
    );
  }
}
