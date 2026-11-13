import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/listened_track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/library_albums.dart';

ListenedTrackData _song(String id, String albumId, String album, String artist, {int? day}) =>
    ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: artist,
      albumTitle: album,
      albumId: albumId,
      coverUrl: 'https://c/$albumId.jpg',
      duration: 200,
      listenedAt: day == null ? null : DateTime(2026, 11, day),
    );

void main() {
  final songs = [
    _song('1', 'a', 'Bloom', 'Beach House', day: 3),
    _song('2', 'b', 'Aja', 'Steely Dan', day: 9),
    _song('3', 'a', 'Bloom', 'Beach House', day: 5),
    _song('4', '', 'Loose Tape', 'Zed', day: 1),
    _song('5', 'c', 'Currents', 'Tame Impala'),
  ];

  group('grouping', () {
    test('one entry per album, songs together, the latest listen kept', () {
      final groups = LibraryAlbumList().groups(songs);

      expect(groups.map((g) => g.albumTitle), ['Bloom', 'Aja', 'Loose Tape', 'Currents']);
      final bloom = groups.first;
      expect(bloom.tracks.map((t) => t.trackId), ['1', '3']);
      expect(bloom.latestListened, DateTime(2026, 11, 5));
      expect(bloom.coverUrl, 'https://c/a.jpg');
      expect(groups.last.latestListened, isNull);
    });
  });

  group('filter and order', () {
    test('latest listen first by default; undated albums last', () {
      final view = LibraryAlbumList().view(songs, filter: '', sortBy: 'recent');
      expect(view.map((g) => g.albumTitle), ['Aja', 'Bloom', 'Loose Tape', 'Currents']);
    });

    test('by title and by artist, ignoring case', () {
      final list = LibraryAlbumList();
      expect(list.view(songs, filter: '', sortBy: 'alpha').map((g) => g.albumTitle),
          ['Aja', 'Bloom', 'Currents', 'Loose Tape']);
      expect(list.view(songs, filter: '', sortBy: 'artist').map((g) => g.artistName),
          ['Beach House', 'Steely Dan', 'Tame Impala', 'Zed']);
    });

    test('the filter matches title or artist, ignoring case', () {
      final list = LibraryAlbumList();
      expect(list.view(songs, filter: 'BLO', sortBy: 'recent').map((g) => g.albumTitle), ['Bloom']);
      expect(list.view(songs, filter: 'tame', sortBy: 'recent').map((g) => g.albumTitle), ['Currents']);
      expect(list.view(songs, filter: 'nothing', sortBy: 'recent'), isEmpty);
    });
  });

  group('memoized', () {
    test('rebuilds with nothing changed (loading the next page) get the very same list', () {
      final list = LibraryAlbumList();
      final first = list.view(songs, filter: '', sortBy: 'recent');
      expect(identical(list.view(songs, filter: '', sortBy: 'recent'), first), isTrue);
      expect(identical(list.groups(songs), list.groups(songs)), isTrue);
    });

    test('a new filter, order or song list is worked out again', () {
      final list = LibraryAlbumList();
      final first = list.view(songs, filter: '', sortBy: 'recent');

      final sorted = list.view(songs, filter: '', sortBy: 'alpha');
      expect(identical(sorted, first), isFalse);

      final filtered = list.view(songs, filter: 'aja', sortBy: 'alpha');
      expect(filtered.map((g) => g.albumTitle), ['Aja']);

      // The library hands out a new list when a song is marked.
      final more = [...songs, _song('6', 'd', 'Abbey Road', 'The Beatles', day: 20)];
      final updated = list.view(more, filter: '', sortBy: 'recent');
      expect(updated.first.albumTitle, 'Abbey Road');
      expect(list.groups(more), hasLength(5));
    });
  });
}
