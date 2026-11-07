import 'package:audio_service/audio_service.dart';

import '../../core/logger.dart';

/// What the system asked for (car, speaker, headset, lock screen, Android
/// Auto), kept in the playback log so a skip that went wrong can be traced.
final _log = Log.named('MediaSession');

/// What the media browser (Android Auto) can list and play; see
/// AutoMediaLibrary.
abstract class MediaLibrarySource {
  Future<List<MediaItem>> children(String parentId);
  Future<List<MediaItem>> search(String query);
  Future<void> playFromMediaId(String mediaId);

  /// False when nothing matched.
  Future<bool> playFromSearch(String query);
}

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
  Future<void> Function(int index)? onSkipToQueueItem;

  /// Browsing and voice commands from Android Auto.
  MediaLibrarySource? library;

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) async =>
      await library?.children(parentMediaId) ?? const [];

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async =>
      await library?.search(query) ?? const [];

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async =>
      library?.playFromMediaId(mediaId);

  /// "Ok Google, play X on Tsuki Tunes". Nothing found (or no words): just
  /// resume.
  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    if (query.trim().isEmpty) return play(); // "play Tsuki Tunes": resume
    final played = await library?.playFromSearch(query) ?? false;
    if (!played) await play();
  }

  @override
  Future<void> play() async {
    _log.info('system: play');
    await onPlay?.call();
  }

  @override
  Future<void> pause() async {
    _log.info('system: pause');
    await onPause?.call();
  }

  @override
  Future<void> stop() async {
    _log.info('system: stop');
    await onStop?.call();
  }

  @override
  Future<void> skipToNext() async {
    _log.info('system: next');
    await onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    _log.info('system: previous');
    await onSkipToPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    _log.info('system: seek to ${position.inSeconds}s');
    await onSeek?.call(position);
  }

  /// A song picked in the queue Android Auto shows ([queue]).
  @override
  Future<void> skipToQueueItem(int index) async {
    _log.info('system: queue item $index');
    await onSkipToQueueItem?.call(index);
  }

  /// The user swiped the app away from recents: stop like Spotify does.
  @override
  Future<void> onTaskRemoved() async {
    await onStop?.call();
  }

  /// Headset single-click toggles play/pause; double/triple click skip.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    _log.info('system: button ${button.name}');
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
