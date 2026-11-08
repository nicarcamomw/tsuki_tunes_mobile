import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

class _FakeService extends AudioPlayerService {
  final played = <String>[];
  bool playFails = false;
  bool crossfadeFails = false;

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    if (playFails) throw Exception('Response code: 403');
    played.add(track.id);
  }

  @override
  Future<void> crossfadeTo(Track nextTrack, int durationSeconds) async {
    if (crossfadeFails) throw Exception('crossfade failed');
    played.add(nextTrack.id);
  }
}

Track _t(String id) => Track(
      id: id,
      title: 'Track $id',
      artistId: 'a_$id',
      artistName: 'Artist $id',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://example.com/$id.mp3',
      durationSeconds: 180,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeService service;
  late AudioProvider audio;
  final album = [_t('t1'), _t('t2'), _t('t3'), _t('t4')];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.${call.arguments['id']}'), (_) async => {});
      }
      return {};
    });
    service = _FakeService();
    audio = AudioProvider(service: service, storage: StorageService());
  });

  test('play after stop picks up the song it was on, not the first one', () async {
    // The notification's close (or "stop") on song 3 of an album...
    await audio.playTrack(album[2], newQueue: album);
    await audio.stop();
    expect(audio.currentTrack, isNull);

    // ...then play on the headphones or in the car.
    await audio.togglePlay();
    expect(audio.currentTrack?.id, 't3');
    expect(service.played.last, 't3');
  });

  test('a crossfade that fails and whose fallback fails too says so, not silence', () async {
    await audio.playTrack(album[0], newQueue: album);
    await audio.setCrossfadeSeconds(3);
    service
      ..crossfadeFails = true
      ..playFails = true;

    audio.checkCrossfade(const Duration(seconds: 178));
    await pumpEventQueue();

    expect(audio.currentTrack?.id, 't2');
    expect(audio.lastPlaybackError, isNotNull, reason: 'nothing plays: the user must be told');
    expect(audio.isBuffering, isFalse);
  });

  test('a crossfade whose start fails still plays the next song', () async {
    await audio.playTrack(album[0], newQueue: album);
    await audio.setCrossfadeSeconds(3);
    service.crossfadeFails = true;

    audio.checkCrossfade(const Duration(seconds: 178));
    await pumpEventQueue();

    expect(audio.currentTrack?.id, 't2');
    expect(service.played.last, 't2');
    expect(audio.lastPlaybackError, isNull);
  });
}
