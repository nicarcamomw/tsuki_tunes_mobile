import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/style_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/music_styles.dart';

Track _t(String artist, {String album = 'al'}) => Track(
      id: '$artist-1',
      title: 'Song',
      artistId: '',
      artistName: artist,
      albumId: album,
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, int> tagCalls;
  late Map<String, List<String>> tags;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tagCalls = {};
    tags = {'Ghost': ['heavy metal', 'swedish'], 'Nobody': []};
    now = DateTime(2026, 11, 6);
  });

  StyleService service() => StyleService(
        artistTags: (a) async {
          tagCalls[a] = (tagCalls[a] ?? 0) + 1;
          return tags[a] ?? [];
        },
        album: (id) async => const Album(
            id: 'al', title: 'A', coverUrl: '', artistId: '', artistName: '', genres: ['Rock']),
        clock: () => now,
      );

  test('looked up once per artist, also after a restart', () async {
    final a = service();
    final info = await a.styleOf(_t('Ghost'));
    expect(info.styles, {MusicStyle.metal});
    expect(info.countries, {'SE'});
    await a.styleOf(_t('Ghost'));
    expect(tagCalls['Ghost'], 1);

    // A new service reads the phone's cache.
    final b = service();
    expect((await b.styleOf(_t('Ghost'))).styles, {MusicStyle.metal});
    expect(tagCalls['Ghost'], 1);
  });

  test('a collaboration counts as its main artist', () async {
    final a = service();
    await a.styleOf(_t('Ghost, Someone'));
    expect(tagCalls.keys, ['Ghost']);
  });

  test('no tags: the album\'s Deezer genres, and asked again a month later', () async {
    final a = service();
    expect((await a.styleOf(_t('Nobody'))).styles, {MusicStyle.rock});

    SharedPreferences.setMockInitialValues({});
    final b = StyleService(
      artistTags: (a) async {
        tagCalls[a] = (tagCalls[a] ?? 0) + 1;
        return [];
      },
      album: (id) async => null,
      clock: () => now,
    );
    expect((await b.styleOf(_t('Nobody', album: ''))).styles, isEmpty);
    final calls = tagCalls['Nobody']!;
    await b.styleOf(_t('Nobody', album: ''));
    expect(tagCalls['Nobody'], calls, reason: 'empty answers are kept for a while');
    now = now.add(const Duration(days: 31));
    await b.styleOf(_t('Nobody', album: ''));
    expect(tagCalls['Nobody'], calls + 1);
  });

  test('two lookups of one artist at once ask once', () async {
    final a = service();
    await Future.wait([a.styleOf(_t('Ghost')), a.styleOf(_t('Ghost'))]);
    expect(tagCalls['Ghost'], 1);
  });

  test('Deezer\'s album genres are read, and only stored when there are some', () {
    final album = Album.fromDeezer({
      'id': 1,
      'title': 'A',
      'genres': {
        'data': [
          {'id': 152, 'name': 'Rock'},
          {'id': 85, 'name': 'Alternative'},
        ],
      },
    });
    expect(album.genres, ['Rock', 'Alternative']);
    expect(album.toJson()['genres'], ['Rock', 'Alternative']);
    expect(Album.fromDeezer({'id': 2, 'title': 'B'}).toJson().containsKey('genres'), isFalse);
  });

  test('lookups that fail give nothing, not an error', () async {
    final a = StyleService(
      artistTags: (_) async => throw Exception('offline'),
      album: (_) async => throw Exception('offline'),
      clock: () => now,
    );
    expect((await a.styleOf(_t('Ghost'))).isEmpty, isTrue);
  });
}
