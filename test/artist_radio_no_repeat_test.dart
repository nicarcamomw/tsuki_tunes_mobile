import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/song_radio.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track _t(String id, String artist) => Track(id: id, title: 'S$id', artistId: artist, artistName: artist, albumId: 'al$id',
    albumTitle: '', coverUrl: '', previewUrl: 'https://x/$id.mp3', durationSeconds: 180);

class _Silent extends AudioPlayerService {
  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
  });

  // Skipping fast through an artist radio used to loop its first ten songs:
  // "next" at the end of the queue wrapped to the start before the radio's
  // slow top-up landed, and every skip banned another related artist until
  // the radio ran dry.
  for (final slow in [false, true]) {
    test('artist radio: skipping through doesn\'t repeat (slow=$slow)', () async {
      Future<List<Track>> top(String id) async {
        if (slow) await Future.delayed(const Duration(milliseconds: 40));
        return [for (var i = 0; i < 10; i++) _t('$id-$i', id)];
      }
      AudioRadioController.topTracksOf = top;
      AudioRadioController.artistRadioFactory = (seed, mode, artist) => SongRadio(
            seed: seed,
            mode: mode,
            artist: artist,
            topTracks: top,
            related: (_) async => [for (var i = 0; i < 12; i++) Artist(id: 'rel$i', name: 'Rel $i', pictureUrl: '')],
          );
      final audio = AudioProvider(service: _Silent());
      expect(await audio.startArtistRadio(const Artist(id: 'lp', name: 'LP', pictureUrl: '')), isTrue);
      final played = [audio.currentTrack!.id];
      for (var i = 0; i < 40; i++) {
        await audio.next();
        await Future.delayed(const Duration(milliseconds: 5));
        played.add(audio.currentTrack!.id);
      }
      expect(played.toSet(), hasLength(played.length));
      audio.dispose();
    });
  }
}
