import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/album_completion_index.dart';
import 'package:tsuki_tunes_mobile/data/repositories/listened_tracks_repository.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album_progress.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/logic/completion_recommendations.dart';

ListenedTrackData _song(String id, String album,
        {String artist = 'Artist', int minutesAgo = 0}) =>
    ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: artist,
      albumTitle: 'Album $album',
      albumId: album,
      coverUrl: 'cover_$album',
      duration: 100,
      listenedAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minutesAgo)),
    );

List<ListenedTrackData> _songs(String album, int n,
        {String artist = 'Artist', int minutesAgo = 0}) =>
    [
      for (var i = 0; i < n; i++)
        _song('$album-$i', album, artist: artist, minutesAgo: minutesAgo)
    ];

AlbumProgress _done(String id, String artist) => AlbumProgress(
      albumId: id,
      title: 'Album $id',
      artistName: artist,
      coverUrl: '',
      listened: 10,
      total: 10,
    );

Artist _a(String id, [String? name]) =>
    Artist(id: id, name: name ?? 'Artist $id', pictureUrl: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('almost complete albums', () {
    late List<ListenedTrackData> listened;
    late AlbumCompletionIndex index;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      listened = [];
      index = AlbumCompletionIndex(
        storage: StorageService(),
        listenedTracks: () => listened,
        listenedLoaded: () => true,
        onChanged: () => index.invalidate(),
      );
    });

    test('lists albums a few songs short, fewest missing first', () {
      listened = [
        ..._songs('a', 8), // 2 of 10 missing
        ..._songs('b', 11), // 1 of 12 missing
        ..._songs('c', 10), // complete
        ..._songs('d', 3), // 7 of 10 missing: too far
        ..._songs('e', 1), // 1 of 2: half, counts
        ..._songs('f', 5), // size unknown
      ];
      index.registerAll({'a': 10, 'b': 12, 'c': 10, 'd': 10, 'e': 2});

      final albums = index.almostComplete();
      expect(albums.map((p) => p.albumId), ['b', 'e', 'a']);
      expect(albums.first.missing, 1);
      expect(albums.last.missing, 2);
      expect(albums.last.title, 'Album a');
      expect(albums.last.coverUrl, 'cover_a');
      expect(albums.last.artistName, 'Artist');
    });

    test('a tie goes to the album listened most recently', () {
      listened = [
        ..._songs('old', 9, minutesAgo: 60),
        ..._songs('new', 9, minutesAgo: 1),
      ];
      index.registerAll({'old': 10, 'new': 10});
      expect(index.almostComplete().map((p) => p.albumId), ['new', 'old']);
    });

    test('the album artist is the one most of its songs are by', () {
      listened = [
        ..._songs('a', 3, artist: 'Main'),
        _song('feat', 'a', artist: 'Guest'),
      ];
      index.registerAll({'a': 5});
      expect(index.almostComplete().single.artistName, 'Main');
    });

    test('a new listened song moves the album along', () {
      listened = _songs('a', 8);
      index.registerAll({'a': 10});
      expect(index.almostComplete().single.missing, 2);

      listened = [...listened, _song('a-8', 'a')];
      index.invalidate();
      expect(index.almostComplete().single.missing, 1);

      listened = [...listened, _song('a-9', 'a')];
      index.invalidate();
      expect(index.almostComplete(), isEmpty);
      expect(index.completed().single.albumId, 'a');
    });

    test('completed albums come most recent first', () {
      listened = [
        ..._songs('old', 4, minutesAgo: 90),
        ..._songs('new', 4, minutesAgo: 5),
        ..._songs('half', 2),
      ];
      index.registerAll({'old': 4, 'new': 4, 'half': 4});
      expect(index.completed().map((p) => p.albumId), ['new', 'old']);
    });

    test('asks for the song count of the latest listened albums only once',
        () async {
      listened = [
        ..._songs('known', 2),
        ..._songs('a', 3, minutesAgo: 1),
        ..._songs('b', 3, minutesAgo: 2),
      ];
      index.registerAll({'known': 5});
      final asked = <String>[];
      Future<Album?> fetch(String id) async {
        asked.add(id);
        return Album(
            id: id, title: '', coverUrl: '', artistId: '', artistName: '',
            tracksCount: 4);
      }

      index.ensureRecentTrackCounts(fetch);
      await Future<void>.delayed(Duration.zero);
      expect(asked, unorderedEquals(['a', 'b']));
      expect(index.trackCount('a'), 4);
      expect(index.almostComplete().map((p) => p.albumId), ['a', 'b']);

      index.ensureRecentTrackCounts(fetch);
      await Future<void>.delayed(Duration.zero);
      expect(asked, hasLength(2));
    });
  });

  group('because you completed', () {
    final catalog = {
      'Deftones': _a('deftones', 'Deftones'),
      'Korn': _a('korn', 'Korn'),
    };
    final related = {
      'deftones': [_a('1'), _a('2'), _a('3'), _a('korn', 'Korn'), _a('4')],
      'korn': [_a('2'), _a('5'), _a('6'), _a('7')],
    };

    CompletionRecommendations recs({int minPerSeed = 3}) =>
        CompletionRecommendations(
          findArtist: (name) async => catalog[name],
          relatedArtists: (id) async => related[id] ?? const [],
          minPerSeed: minPerSeed,
        );

    test('one row per artist of the latest completed albums, '
        'without artists already heard or already shown', () async {
      final rows = await recs().build(
        completed: [
          _done('white-pony', 'Deftones'),
          _done('around-the-fur', 'Deftones'), // same artist: skipped
          _done('issues', 'Korn'),
        ],
        knownArtistNames: {'artist 3'},
      );
      expect(rows.map((r) => r.album.albumId), ['white-pony', 'issues']);
      // Korn is a seed later on, but has not been shown yet at this point.
      expect(rows[0].artists.map((a) => a.id), ['1', '2', 'korn', '4']);
      // 2 was suggested by Deftones already; Korn itself never shows.
      expect(rows[1].artists.map((a) => a.id), ['5', '6', '7']);
    });

    test('at most two rows', () async {
      catalog['Tool'] = _a('tool', 'Tool');
      related['tool'] = [_a('8'), _a('9'), _a('10')];
      final rows = await recs().build(completed: [
        _done('a', 'Deftones'),
        _done('b', 'Korn'),
        _done('c', 'Tool'),
      ]);
      expect(rows, hasLength(2));
    });

    test('a row with too few artists, or an artist not found, is skipped',
        () async {
      final rows = await recs().build(
        completed: [_done('x', 'Nobody'), _done('issues', 'Korn')],
        excludeIds: {'5', '6'},
      );
      expect(rows, isEmpty);
    });

    test('a seed that fails to load does not stop the others', () async {
      final rows = await CompletionRecommendations(
        findArtist: (name) async =>
            name == 'Broken' ? throw Exception('offline') : catalog[name],
        relatedArtists: (id) async => related[id] ?? const [],
      ).build(completed: [_done('a', 'Broken'), _done('b', 'Korn')]);
      expect(rows.single.album.albumId, 'b');
    });
  });
}
