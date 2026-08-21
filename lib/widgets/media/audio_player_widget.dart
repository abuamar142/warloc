import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/audio_playback_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/show_message.dart';

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
  AudioPlayer? _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isInitialized = false;

  // Keep subscriptions to cancel them in dispose() — prevents memory leaks
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initAudioPlayer() async {
    if (_isInitialized) return;
    try {
      final player = AudioPlayer();
      _player = player;

      _durationSub = player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _positionSub = player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _stateSub = player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
          if (state != PlayerState.playing) {
            AudioPlaybackService.instance.clearPlayer(player);
          }
        }
      });

      await player.setSource(DeviceFileSource(widget.filePath));
      _isInitialized = true;
    } catch (e) {
      debugPrint("Gagal menginisialisasi audio player: $e");
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    if (_player != null) {
      AudioPlaybackService.instance.clearPlayer(_player!);
      _player!.dispose();
    }
    super.dispose();
  }

  void _togglePlay() async {
    try {
      if (!_isInitialized) {
        await _initAudioPlayer();
      }

      if (_player != null) {
        if (_isPlaying) {
          await _player!.pause();
          AudioPlaybackService.instance.clearPlayer(_player!);
        } else {
          await AudioPlaybackService.instance.registerAndPlay(_player!, () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
          });
          await _player!.play(DeviceFileSource(widget.filePath));
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, "Gagal memutar audio: $e");
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final double val = bytes / (1 << (10 * i));
    return "${val.toStringAsFixed(1)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);
    String sizeStr = "";
    if (file.existsSync()) {
      try {
        final bytes = file.lengthSync();
        sizeStr = _formatBytes(bytes);
      } catch (e) {
        debugPrint("Gagal membaca ukuran file '${widget.filePath}': $e");
      }
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
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
        color: Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent,
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
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: AppColors.accent,
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
                      _player?.seek(Duration(milliseconds: val.toInt()));
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
                            : (sizeStr.isNotEmpty 
                                ? (_duration != Duration.zero ? "$sizeStr • ${_formatDuration(_duration)}" : sizeStr)
                                : _formatDuration(_duration)),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const Icon(
                        Icons.mic,
                        size: 14,
                        color: AppColors.accent,
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
