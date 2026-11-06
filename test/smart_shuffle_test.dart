import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';
import 'package:tsuki_tunes_mobile/domain/logic/song_radio.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track _t(String id, {String? artist, String preview = ''}) => Track(
      id: id,
      title: 'Song $id',
      artistId: artist ?? 'a_$id',
      artistName: artist ?? 'Artist $id',
      albumId: 'al_$id',
      albumTitle: 'Album $id',
      coverUrl: '',
      previewUrl: preview,
      durationSeconds: 180,
    );

bool _all(Track _) => true;

class _SilentPlayer extends AudioPlayerService {
  @override
  Future<void> playTrack(Track track,
      {Duration? initialPosition, int maxRetries = 3}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('queue', () {
    late PlaybackQueue q;
    List<String> ids(List<int> idx) => [for (final i in idx) q.tracks[i].id];

    setUp(() {
      final own = [for (var i = 0; i < 10; i++) _t('o$i')];
      q = PlaybackQueue(random: Random(5));
      q.select(own.first, newQueue: own);
      q.toggleShuffle();
    });

    test('a recommended song comes after every N of yours', () {
      q.recommendEvery = 2;
      q.addRecommendations([_t('r1'), _t('r2'), _t('r3')]);
      final order = ids(q.upcoming(9));
      final recos = order.where((id) => id.startsWith('r')).toList();
      expect(recos, ['r1', 'r2', 'r3']);
      // Counting the song playing now: never more than 2 of yours in a
      // row while recommendations are left, never two recommendations.
      var run = 1;
      for (final id in order.takeWhile((_) => recos.isNotEmpty)) {
        if (id.startsWith('r')) {
          expect(run, 2);
          run = 0;
          recos.remove(id);
        } else {
          run++;
        }
      }
    });

    test('without recommendations on they never come up', () {
      q.addRecommendations([_t('r1'), _t('r2')]);
      final order = ids(q.upcoming(9));
      expect(order.where((id) => id.startsWith('r')), isEmpty);
    });

    test('dropping them takes out the ones not played', () {
      q.recommendEvery = 1;
      q.addRecommendations([_t('r1'), _t('r2')]);
      q.next(online: true, canPlay: _all); // r1 now plays
      expect(q.current!.id, 'r1');
      q.dropRecommendations();
      expect(q.tracks.map((t) => t.id), isNot(contains('r2')));
      expect(q.current!.id, 'r1');
    });

    test('the tempo flow decides the order', () {
      final mixed = [
        for (var i = 0; i < 4; i++) _t('fast$i'),
        for (var i = 0; i < 4; i++) _t('slow$i'),
      ];
      q = PlaybackQueue(random: Random(1));
      q.select(mixed.first, newQueue: mixed);
      q.toggleShuffle();
      bool fast(Track t) => t.id.startsWith('fast');
      // Alternate: crossing between fast and calm scores high.
      q.flowScore = (prev, next) => fast(prev) != fast(next) ? 2 : -2;
      final order = [mixed.first.id, ...ids(q.upcoming(7))];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].startsWith('fast'), isNot(order[i - 1].startsWith('fast')),
            reason: order.join(' '));
      }
    });
  });

  group('provider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
      AudioRadioController.radioFactory = (seed, mode) => SongRadio(
            seed: seed,
            mode: mode,
            similar: (_, __) async => const [],
            artistRadio: (_) async => [
              for (var i = 1; i <= 6; i++)
                _t('r$i', preview: 'https://x/r$i.mp3'),
            ],
            search: (_) async => const [],
            useLastFm: false,
          );
    });
    tearDown(() {
      AudioRadioController.radioFactory =
          (seed, mode) => SongRadio(seed: seed, mode: mode);
    });

    test('the button goes off → shuffle → recommendations → off, and only '
        'recommends songs the user does not have', () async {
      final audio = AudioProvider(service: _SilentPlayer());
      audio.isInLibrary = (id) => id == 'r1';
      final own = [for (var i = 0; i < 10; i++) _t('o$i')];
      await audio.playTrack(own.first, newQueue: own);

      expect(audio.cycleShuffle(), ShuffleMode.on);
      expect(audio.cycleShuffle(), ShuffleMode.smart);
      await Future.delayed(const Duration(milliseconds: 100));

      final ids = audio.queue.map((t) => t.id).toList();
      expect(ids, contains('r2'));
      expect(ids, isNot(contains('r1')), reason: 'already in the library');
      expect(audio.isRecommended('r2'), isTrue);
      final upcoming = [for (final i in audio.upcomingOrder(10)) audio.queue[i].id];
      expect(upcoming.any((id) => id.startsWith('r')), isTrue);

      expect(audio.cycleShuffle(), ShuffleMode.off);
      expect(audio.queue.map((t) => t.id).where((id) => id.startsWith('r')),
          isEmpty);
    });
  });

  group('artist radio', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
      Future<List<Track>> top(String id) async => [
            for (var i = 0; i < 6; i++) _t('$id-$i', artist: id, preview: 'https://x/$id-$i.mp3'),
          ];
      AudioRadioController.topTracksOf = top;
      AudioRadioController.artistRadioFactory = (seed, mode, artist) => SongRadio(
            seed: seed,
            mode: mode,
            artist: artist,
            topTracks: top,
            related: (_) async => [for (var i = 0; i < 4; i++) Artist(id: 'rel$i', name: 'Rel $i', pictureUrl: '')],
          );
    });

    test('the artist page\'s radio plays one of their hits and fills the queue', () async {
      final audio = AudioProvider(service: _SilentPlayer());
      const artist = Artist(id: 'lp', name: 'Linkin Park', pictureUrl: '');
      expect(await audio.startArtistRadio(artist), isTrue);
      expect(audio.currentTrack!.id, anyOf('lp-0', 'lp-1', 'lp-2'));
      expect(audio.radioArtist?.name, 'Linkin Park');
      final queued = audio.queue.map((t) => t.artistId).toSet();
      expect(queued, contains('lp'));
      expect(queued.any((a) => a.startsWith('rel')), isTrue);
      audio.dispose();
    });

    test('an artist with nothing playable starts nothing', () async {
      AudioRadioController.topTracksOf = (_) async => const [];
      final audio = AudioProvider(service: _SilentPlayer());
      expect(await audio.startArtistRadio(const Artist(id: 'x', name: 'X', pictureUrl: '')), isFalse);
      expect(audio.radioArtist, isNull);
      audio.dispose();
    });
  });
}
