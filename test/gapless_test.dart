import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://example.com/$id.mp3',
      durationSeconds: 30,
    );

/// The service as the provider sees it: what was queued, and a way to say
/// the queued song started by itself.
class _GaplessService extends AudioPlayerService {
  final played = <String>[];
  final queued = <String?>[];
  Track? _next;
  final _advances = StreamController<Track>.broadcast();

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    played.add(track.id);
    _next = null;
  }

  @override
  Future<bool> setGaplessNext(Track? next) async {
    queued.add(next?.id);
    _next = next;
    return next != null;
  }

  @override
  Track? get gaplessNext => _next;

  @override
  Stream<Track> get gaplessAdvances => _advances.stream;

  /// The player moved into the queued song.
  Future<void> advance() async {
    final next = _next!;
    _next = null;
    _advances.add(next);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Just enough of a player for the playlist bookkeeping, no platform.
class _FakePlayer implements AudioPlayer {
  final _seq = StreamController<SequenceState?>.broadcast();
  AudioSource? source;
  IndexedAudioSource? _current;
  final volumes = <double>[];
  final speeds = <double>[];

  @override
  Stream<SequenceState?> get sequenceStateStream => _seq.stream;
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
  Future<Duration?> setAudioSource(AudioSource source,
      {bool preload = true, int? initialIndex, Duration? initialPosition}) async {
    this.source = source;
    _current = source.sequence.first;
    return const Duration(seconds: 30);
  }

  @override
  Future<Duration?> setUrl(String url,
          {Map<String, String>? headers, Duration? initialPosition, bool preload = true, dynamic tag}) async =>
      const Duration(seconds: 30);

  /// Where the playing song is in the playlist, which shifts when songs
  /// before it are removed (like the real player).
  @override
  int? get currentIndex => source?.sequence.indexOf(_current!);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  ConcatenatingAudioSource get playlist => source! as ConcatenatingAudioSource;

  /// The player went on to the song at [i] of its playlist.
  Future<void> moveTo(int i) async {
    _current = playlist.sequence[i];
    _seq.add(SequenceState(playlist.sequence, i, const [0, 1], false, LoopMode.off));
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async {
        if (call.method == 'init') {
          final id = (call.arguments as Map)['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (call) async => {},
          );
        }
        return {};
      },
    );
  });

  group('the player (AudioPlayerService)', () {
    test('the next song joins the playlist, and starting it is announced', () async {
      final a = _FakePlayer();
      final service = AudioPlayerService.withPlayers(a, _FakePlayer())
        ..loudnessFor = ((t) => t.id == 'b' ? 0.5 : 1.0)
        ..speedFor = ((t) => t.id == 'b' ? 1.1 : 1.0);
      final started = <String>[];
      service.gaplessAdvances.listen((t) => started.add(t.id));

      await service.playTrack(_t('a'));
      expect(a.playlist.length, 1);

      expect(await service.setGaplessNext(_t('b')), isTrue);
      expect(a.playlist.length, 2);
      expect(service.gaplessNext?.id, 'b');

      // Changed mind before the end: the queued song is replaced.
      expect(await service.setGaplessNext(_t('c')), isTrue);
      expect(a.playlist.length, 2);
      expect(service.gaplessNext?.id, 'c');

      await a.moveTo(1);
      expect(started, ['c']);
      expect(service.gaplessNext, isNull);
      expect(a.playlist.length, 1, reason: 'the finished song leaves the playlist');

      // Taking it back.
      await service.setGaplessNext(_t('d'));
      await service.setGaplessNext(null);
      expect(a.playlist.length, 1);
      expect(service.gaplessNext, isNull);
    });

    test('the new song gets its own volume and speed when it starts', () async {
      final a = _FakePlayer();
      final service = AudioPlayerService.withPlayers(a, _FakePlayer())
        ..loudnessFor = ((t) => t.id == 'b' ? 0.5 : 1.0)
        ..speedFor = ((t) => t.id == 'b' ? 1.1 : 1.0);
      await service.playTrack(_t('a'));
      await service.setGaplessNext(_t('b'));
      a.volumes.clear();
      a.speeds.clear();

      await a.moveTo(1);
      expect(a.volumes, [0.5]);
      expect(a.speeds, [1.1]);
    });

    test('a new song played meanwhile drops the queued one', () async {
      final a = _FakePlayer();
      final service = AudioPlayerService.withPlayers(a, _FakePlayer());
      await service.playTrack(_t('a'));
      await service.setGaplessNext(_t('b'));

      await service.playTrack(_t('x'));
      expect(service.gaplessNext, isNull);
      expect(a.playlist.length, 1);
    });

    test('nothing is queued during a crossfade', () async {
      final service = AudioPlayerService.withPlayers(_FakePlayer(), _FakePlayer());
      await service.playTrack(_t('a'));
      await service.crossfadeTo(_t('b'), 6);
      expect(await service.setGaplessNext(_t('c')), isFalse);
      await service.stop();
    });
  });

  group('the queue (AudioProvider)', () {
    late _GaplessService service;
    late AudioProvider provider;
    final tracks = [_t('a'), _t('b'), _t('c')];

    Future<void> playing({int crossfade = 0}) async {
      service = _GaplessService();
      provider = AudioProvider(service: service, storage: StorageService());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await provider.setCrossfadeSeconds(crossfade);
      await provider.playTrack(tracks.first, newQueue: tracks);
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> at(int seconds) async {
      provider.checkGapless(Duration(seconds: seconds));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    test('in the last 15 s the next song is put right after this one', () async {
      await playing();
      await at(10);
      expect(service.queued, isEmpty, reason: 'too early');

      await at(16);
      expect(service.queued, ['b']);

      await at(20);
      expect(service.queued, ['b'], reason: 'once');
    });

    test('when it starts, the queue and screen follow with no new play', () async {
      await playing();
      await at(20);
      final before = List.of(service.played);

      await service.advance();

      expect(provider.currentTrack?.id, 'b');
      expect(service.played, before, reason: 'a new play would bring the gap back');

      // And the one after follows the same way.
      await at(20);
      expect(service.queued.last, 'c');
    });

    test('a queue edit near the end changes the song put there', () async {
      await playing();
      await at(20);
      expect(service.queued, ['b']);

      provider.playNext(_t('z'));
      await at(21);
      expect(service.queued.last, 'z');
    });

    test('with crossfade on, songs crossfade instead', () async {
      await playing(crossfade: 3);
      await at(20);
      expect(service.queued, isEmpty);
    });

    test('repeat-one loops the song with no gap', () async {
      await playing();
      provider.setRepeatMode(PlaybackRepeatMode.one);
      await at(20);
      expect(service.queued, ['a']);

      await service.advance();
      expect(provider.currentTrack?.id, 'a');
    });

    test('at the end of the queue nothing is put there', () async {
      service = _GaplessService();
      provider = AudioProvider(service: service, storage: StorageService());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await provider.setCrossfadeSeconds(0);
      await provider.playTrack(tracks.last, newQueue: tracks);
      await at(20);
      expect(service.queued.whereType<String>(), isEmpty);
    });
  });
}
