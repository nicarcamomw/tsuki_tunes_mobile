import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artistId: 'a',
      artistName: 'A',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: 'https://example.com/$id.mp3',
      durationSeconds: 30,
    );

/// Just enough of a player for the decks' bookkeeping, no platform.
class _FakePlayer implements AudioPlayer {
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Future<Duration?> setUrl(String url,
          {Map<String, String>? headers, Duration? initialPosition, bool preload = true, dynamic tag}) async =>
      const Duration(seconds: 30);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, cut) in [
    ('a seek', (AudioPlayerService s) => s.seek(const Duration(seconds: 5))),
    ('a new song', (AudioPlayerService s) => s.playTrack(_t('c'))),
    ('stop', (AudioPlayerService s) => s.stop()),
  ]) {
    test('$name in the middle of a crossfade keeps the UI on the deck that plays', () async {
      final service = AudioPlayerService.withPlayers(_FakePlayer(), _FakePlayer());
      await service.playTrack(_t('a'));
      await service.crossfadeTo(_t('b'), 6);
      expect(service.isCrossfading, isTrue);
      expect(service.followsActiveDeck, isFalse, reason: 'the incoming song is shown');

      await cut(service);

      expect(service.isCrossfading, isFalse);
      expect(service.followsActiveDeck, isTrue);
    });
  }
}
