import 'package:audio_service/audio_service.dart';

/// Bridges the system media session (lock screen, notification, headset and
/// Bluetooth buttons, Android Auto) to [AudioProvider], which still owns
/// playback. The provider pushes state in through [mediaItem] and
/// [playbackState]; system commands come back out through the callbacks.
class TsukiAudioHandler extends BaseAudioHandler with SeekHandler {
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onStop;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;
  Future<void> Function(Duration position)? onSeek;

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> stop() async => onStop?.call();

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  /// Headset single-click toggles play/pause; double/triple click skip.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (playbackState.value.playing) {
          await pause();
        } else {
          await play();
        }
      case MediaButton.next:
        await skipToNext();
      case MediaButton.previous:
        await skipToPrevious();
    }
  }
}
