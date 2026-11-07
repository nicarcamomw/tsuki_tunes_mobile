import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/genre.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/search_suggestions.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/genre_catalog.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_genre_page.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_genres.dart';
import 'package:tsuki_tunes_mobile/presentation/state/search_provider.dart';

class _Genres implements GenreCatalog {
  bool offline = false;

  @override
  Future<List<Genre>> getGenres() async =>
      offline ? throw Exception('offline') : const [Genre(id: '152', name: 'Rock')];

  @override
  Future<List<Artist>> getGenreArtists(String genreId) async => offline
      ? throw Exception('offline')
      : [Artist(id: 'a$genreId', name: 'Band', pictureUrl: '')];

  @override
  Future<List<Track>> getGenreChartTracks(String genreId) async => const [];
}

List<String> _texts(List<SearchSuggestion> s) => [for (final x in s) x.text];

void main() {
  group('fold', () {
    test('drops case, accents and punctuation', () {
      expect(SearchSuggestions.fold('Beyoncé - Halo!'), 'beyonce halo');
      expect(SearchSuggestions.fold('  Ñandú  '), 'nandu');
      expect(SearchSuggestions.fold('米津玄師'), '米津玄師');
    });
  });

  group('suggestions while typing', () {
    test('recent searches first, then the library, then the catalog', () {
      final s = SearchSuggestions.suggest(
        'met',
        history: ['metallica live', 'bad bunny'],
        library: ['Metallica', 'Metric'],
        catalog: ['Metro Boomin', 'Metallica'],
      );
      expect(_texts(s), ['metallica live', 'Metallica', 'Metric', 'Metro Boomin']);
      expect(s.first.source, SuggestionSource.history);
      expect(s[1].source, SuggestionSource.library);
      expect(s.last.source, SuggestionSource.catalog);
    });

    test('accents, word order and a word in the middle match too', () {
      expect(_texts(SearchSuggestions.suggest('beyon', library: ['Beyoncé'])),
          ['Beyoncé']);
      expect(_texts(SearchSuggestions.suggest('bunny bad', library: ['Bad Bunny'])),
          ['Bad Bunny']);
      expect(_texts(SearchSuggestions.suggest('pony', library: ['White Pony'])),
          ['White Pony']);
    });

    test('names starting with the query go before ones that only contain it',
        () {
      final s = SearchSuggestions.suggest('ton',
          library: ['Deftones', 'Tones and I', 'Tonight Tonight']);
      expect(_texts(s), ['Tones and I', 'Tonight Tonight', 'Deftones']);
    });

    test('the query itself, repeats and too short "contains" are left out', () {
      final s = SearchSuggestions.suggest(
        'korn',
        history: ['Korn'],
        library: ['Korn', 'Korn Ferry'],
        catalog: ['KORN FERRY'],
      );
      expect(_texts(s), ['Korn Ferry']);
      expect(SearchSuggestions.suggest('on', library: ['Deftones']), isEmpty);
    });

    test('at most three recent searches and six in all', () {
      final s = SearchSuggestions.suggest(
        'a',
        history: ['a1', 'a2', 'a3', 'a4'],
        library: ['ab', 'ac', 'ad', 'ae'],
      );
      expect(_texts(s), ['a1', 'a2', 'a3', 'ab', 'ac', 'ad']);
    });
  });

  group('did you mean', () {
    const vocab = ['Metallica', 'Bad Bunny', 'The Weeknd', 'Rosalía', 'One'];

    test('distance counts a swap of two letters as one', () {
      expect(SearchSuggestions.distance('metalica', 'metallica'), 1);
      expect(SearchSuggestions.distance('metlalica', 'metallica'), 1);
      expect(SearchSuggestions.distance('kitten', 'sitting'), 3);
    });

    test('a misspelled name gets the name', () {
      expect(SearchSuggestions.didYouMean('metalica', vocabulary: vocab), 'Metallica');
      expect(SearchSuggestions.didYouMean('bad buny', vocabulary: vocab), 'Bad Bunny');
      expect(SearchSuggestions.didYouMean('badbunny', vocabulary: vocab), 'Bad Bunny');
      expect(SearchSuggestions.didYouMean('the weekend', vocabulary: vocab),
          'The Weeknd');
      expect(SearchSuggestions.didYouMean('rosalia', vocabulary: vocab), isNull,
          reason: 'only the accent differs: that search already works');
    });

    test('with nothing found, each word is fixed on its own', () {
      expect(SearchSuggestions.didYouMean('metalica one', vocabulary: vocab),
          'metallica one');
    });

    test('nothing when the query is right, too short or too far off', () {
      expect(SearchSuggestions.didYouMean('Metallica', vocabulary: vocab), isNull);
      expect(SearchSuggestions.didYouMean('bnny', vocabulary: vocab), isNull);
      expect(SearchSuggestions.didYouMean('mtllc', vocabulary: vocab), isNull);
      expect(SearchSuggestions.didYouMean('xyz', vocabulary: vocab), isNull);
    });

    test('nothing when the results already match the query', () {
      expect(
        SearchSuggestions.didYouMean('metalica',
            vocabulary: vocab, resultNames: ['Metalica (tribute band)']),
        isNull,
      );
    });

    test('with results, only whole names are offered, not word fixes', () {
      expect(
        SearchSuggestions.didYouMean('metalica one',
            vocabulary: vocab, resultNames: ['Something else']),
        isNull,
      );
      expect(
        SearchSuggestions.didYouMean('the weekend',
            vocabulary: vocab, resultNames: ['Weekend Vibes']),
        'The Weeknd',
      );
    });
  });

  test('a Deezer genre reads its id, name and picture', () {
    final g = Genre.fromDeezer(
        {'id': 116, 'name': 'Rap/Hip Hop', 'picture_medium': 'https://x/p.jpg'});
    expect((g.id, g.name, g.pictureUrl), ('116', 'Rap/Hip Hop', 'https://x/p.jpg'));
  });

  test('genres: an empty list offline; a page fails so it can be retried',
      () async {
    final catalog = _Genres();
    expect((await GetGenres(catalog)()).single.name, 'Rock');
    final page = await GetGenrePage(catalog)('152');
    expect(page.artists.single.id, 'a152');
    expect(page.isEmpty, isFalse);

    catalog.offline = true;
    expect(await GetGenres(catalog)(), isEmpty);
    await expectLater(GetGenrePage(catalog)('152'), throwsA(anything));
  });

  group('search provider', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final empty = MockClient((_) async => http.Response('{"data":[]}', 200));

    test('a search with no results offers the closest name the user knows',
        () async {
      SharedPreferences.setMockInitialValues({});
      final search = SearchProvider(fuzzyArtistNames: (_) async => const []);
      search.setLibraryNames(['Deftones', 'System of a Down']);
      await http.runWithClient(() async {
        await search.search('deftnoes');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, () => empty);
      expect(search.didYouMean, 'Deftones');

      search.clear();
      expect(search.didYouMean, isNull);
    });

    test('with nothing close in the library, asks the typo-tolerant search',
        () async {
      SharedPreferences.setMockInitialValues({});
      final asked = <String>[];
      final search = SearchProvider(fuzzyArtistNames: (q) async {
        asked.add(q);
        return ['Rammstein'];
      });
      await http.runWithClient(() async {
        await search.search('ramstein');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, () => empty);
      expect(asked, ['ramstein']);
      expect(search.didYouMean, 'Rammstein');
    });
  });
}
