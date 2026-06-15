import 'package:audioplayers/audioplayers.dart';

class AudioPlaybackService {
  static final AudioPlaybackService instance = AudioPlaybackService._internal();

  AudioPlaybackService._internal();

  AudioPlayer? _activePlayer;
  void Function()? _onStopCallback;

  /// Registers a player and its stop/pause callback.
  /// If there is an active player registered already, it pauses it before setting the new one.
  Future<void> registerAndPlay(AudioPlayer player, void Function() onStop) async {
    if (_activePlayer != null && _activePlayer != player) {
      try {
        await _activePlayer!.pause();
        _onStopCallback?.call();
      } catch (_) {}
    }
    _activePlayer = player;
    _onStopCallback = onStop;
  }

  /// Clears the active player reference if it matches the current player (e.g. when stopped/paused/disposed).
  void clearPlayer(AudioPlayer player) {
    if (_activePlayer == player) {
      _activePlayer = null;
      _onStopCallback = null;
    }
  }
}
