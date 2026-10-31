import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/utils/deezer_preview.dart';
import 'package:tsuki_tunes_mobile/models/album.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/services/spotify_service.dart';

ListenedTrackData _listened(String id, String albumId, {String artist = 'A'}) =>
    ListenedTrackData(
      trackId: id,
      title: 't$id',
      artistName: artist,
      albumTitle: 'album',
      albumId: albumId,
      coverUrl: '',
      duration: 100,
    );

Album _album(String id, {int tracksCount = 0}) => Album(
      id: id,
      title: 'Album $id',
      coverUrl: '',
      artistId: '1',
      artistName: 'A',
      tracksCount: tracksCount,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SpotifyService.normalizeTitle', () {
    test('strips version decorations so variants compare equal', () {
      final base = SpotifyService.normalizeTitle('Song');
      expect(SpotifyService.normalizeTitle('Song - Remastered 2011'), base);
      expect(SpotifyService.normalizeTitle('Song (Remastered)'), base);
      expect(SpotifyService.normalizeTitle('Song [Live]'), base);
      expect(SpotifyService.normalizeTitle('Song (feat. Someone)'), base);
      expect(SpotifyService.normalizeTitle('Song feat. Someone'), base);
    });

    test('keeps different songs different', () {
      expect(SpotifyService.normalizeTitle('Intro'),
          isNot(SpotifyService.normalizeTitle('Outro')));
      expect(SpotifyService.normalizeTitle('Song - Part Two'),
          isNot(SpotifyService.normalizeTitle('Song')));
    });

    test('ignores accents and punctuation', () {
      expect(SpotifyService.normalizeTitle('Canción, Ñandú!'),
          SpotifyService.normalizeTitle('cancion nandu'));
    });
  });

  group('DeezerPreview', () {
    String url(DateTime exp) =>
        'https://cdnt-preview.dzcdn.net/api/1/1/a/b/c/0/abc.mp3'
        '?hdnea=exp=${exp.millisecondsSinceEpoch ~/ 1000}~acl=/api/*~hmac=x';

    test('detects expired signed URLs', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(DeezerPreview.isDeezerUrl(url(past)), isTrue);
      expect(DeezerPreview.isExpired(url(past)), isTrue);
    });

    test('treats URLs close to expiry as expired', () {
      final soon = DateTime.now().add(const Duration(seconds: 30));
      expect(DeezerPreview.isExpired(url(soon)), isTrue);
    });

    test('valid and unsigned URLs are not expired', () {
      final future = DateTime.now().add(const Duration(hours: 2));
      expect(DeezerPreview.isExpired(url(future)), isFalse);
      expect(DeezerPreview.isExpired('https://example.com/a.mp3'), isFalse);
      expect(DeezerPreview.isDeezerUrl('https://example.com/a.mp3'), isFalse);
    });
  });

  group('Track ISRC', () {
    test('parses isrc from Deezer JSON and survives storage round-trip', () {
      final track = Track.fromDeezer({
        'id': 1,
        'title': 'T',
        'isrc': 'USUM71703861',
        'artist': {'id': 2, 'name': 'A'},
        'album': {'id': 3, 'title': 'Al'},
      });
      expect(track.isrc, 'USUM71703861');
      expect(Track.fromJson(track.toJson()).isrc, 'USUM71703861');
    });

    test('missing or empty isrc is null', () {
      expect(Track.fromDeezer({'id': 1, 'title': 'T'}).isrc, isNull);
      expect(Track.fromDeezer({'id': 1, 'title': 'T', 'isrc': ''}).isrc, isNull);
    });
  });

  group('LibraryProvider album index', () {
    test('isAlbumCompleted and counters follow listened tracks', () async {
      final library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      library.setListenedTracksForTesting([
        _listened('1', 'alb1'),
        _listened('2', 'alb1'),
        _listened('3', 'alb2', artist: 'B'),
      ]);

      expect(library.listenedCountForAlbum('alb1'), 2);
      expect(library.isAlbumCompleted('alb1', albumTracksCount: 2), isTrue);
      expect(library.isAlbumCompleted('alb1', albumTracksCount: 3), isFalse);
      expect(library.uniqueAlbumsCount, 2);
      expect(library.uniqueArtistsCount, 2);

      library.setListenedTracksForTesting([_listened('1', 'alb1')]);
      expect(library.listenedCountForAlbum('alb1'), 1);
      expect(library.isAlbumCompleted('alb1', albumTracksCount: 2), isFalse);
      expect(library.uniqueAlbumsCount, 1);
    });

    test('ensureAlbumTrackCounts fetches each listened album once', () async {
      final library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      library.setListenedTracksForTesting([
        _listened('1', 'alb1'),
        _listened('2', 'alb1'),
      ]);

      final requested = <String>[];
      Future<Album?> fetch(String id) async {
        requested.add(id);
        return _album(id, tracksCount: 2);
      }

      final albums = [_album('alb1'), _album('unlistened')];
      library.ensureAlbumTrackCounts(albums, fetch);
      library.ensureAlbumTrackCounts(albums, fetch);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(requested, ['alb1']);
      expect(library.getAlbumTracksCount('alb1'), 2);
      expect(library.isAlbumCompleted('alb1'), isTrue);
    });
  });
}
