import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/listened_track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/album_track_order.dart';
import 'package:tsuki_tunes_mobile/presentation/state/library_albums.dart';

ListenedTrackData _song(String id, {String album = 'a', String title = '', String artist = 'Artist'}) =>
    ListenedTrackData(
      trackId: id,
      title: title.isEmpty ? 'Song $id' : title,
      artistName: artist,
      albumTitle: 'Album $album',
      albumId: album,
      coverUrl: '',
      duration: 200,
    );

LibraryAlbumGroup _album(String id, List<String> songIds) => LibraryAlbumGroup(
      albumId: id,
      albumTitle: 'Album $id',
      artistName: 'Artist',
      coverUrl: '',
      // As the library keeps them: the latest marked first.
      tracks: [for (final s in songIds) _song(s, album: id)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sortByAlbum', () {
    // Marked 3rd, then 1st, then 2nd; the library lists the latest first.
    final marked = [_song('t2'), _song('t1'), _song('t3')];

    test("the album's order", () {
      expect(sortByAlbum(marked, ['t1', 't2', 't3', 't4']).map((t) => t.trackId), ['t1', 't2', 't3']);
    });

    test('without it, the order they were marked, oldest first', () {
      expect(sortByAlbum(marked, null).map((t) => t.trackId), ['t3', 't1', 't2']);
    });

    test("songs the album doesn't list go last, oldest marked first", () {
      expect(sortByAlbum(marked, ['t2', 't1']).map((t) => t.trackId), ['t2', 't1', 't3']);
    });
  });

  group('AlbumTrackOrder', () {
    test('asks the catalog once per album, and keeps the answer on the phone', () async {
      var asked = 0;
      final order = AlbumTrackOrder(fetch: (id) async {
        asked++;
        return ['t1', 't2', 't3'];
      });
      final results = await Future.wait([order.ensure('a'), order.ensure('a')]);
      await order.ensure('a');
      expect(asked, 1);
      expect(results.first, ['t1', 't2', 't3']);
      expect(order.numberOf('a', 't3'), 3);
      expect(order.numberOf('a', 'nope'), isNull);

      order.dispose(); // saves what was pending
      await pumpEventQueue();
      final saved = (await SharedPreferences.getInstance()).getString(AlbumTrackOrder.storageKey);
      expect(json.decode(saved!), {
        'a': ['t1', 't2', 't3'],
      });
    });

    test('a saved order needs no network', () async {
      SharedPreferences.setMockInitialValues({
        AlbumTrackOrder.storageKey: json.encode({
          'a': ['t1', 't2'],
        }),
      });
      final order = AlbumTrackOrder(fetch: (_) async => fail('no request expected'));
      expect(await order.ensure('a'), ['t1', 't2']);
      expect(order.orderOf('a'), ['t1', 't2']);
      order.dispose();
    });

    test('an album the catalog can\'t give is not asked again; no id, no request', () async {
      var asked = 0;
      final order = AlbumTrackOrder(fetch: (id) async {
        asked++;
        throw Exception('offline');
      });
      expect(await order.ensure('a'), isNull);
      expect(await order.ensure('a'), isNull);
      expect(await order.ensure(''), isNull);
      expect(asked, 1);
      order.dispose();
    });

    test('tells its listeners when an order arrives', () async {
      final order = AlbumTrackOrder(fetch: (_) async => ['t1']);
      var told = 0;
      order.addListener(() => told++);
      await order.ensure('a');
      expect(told, greaterThanOrEqualTo(1));
      order.dispose();
    });
  });

  group('libraryAlbumQueue', () {
    final albums = [
      _album('a', ['a3', 'a2', 'a1']),
      _album('b', ['b2', 'b1']),
      _album('c', ['c1']),
    ];
    List<ListenedTrackData> ordered(LibraryAlbumGroup g) => sortByAlbum(g.tracks, null);

    test('the whole album in order from the song, then the next albums', () {
      final (:queue, :start) = libraryAlbumQueue(albums, 0, 'a2', ordered: ordered);
      expect(queue.map((t) => t.trackId), ['a1', 'a2', 'a3', 'b1', 'b2', 'c1']);
      expect(queue[start].trackId, 'a2');
    });

    test('from an album in the middle, only the albums after it follow', () {
      final (:queue, :start) = libraryAlbumQueue(albums, 1, 'b1', ordered: ordered);
      expect(queue.map((t) => t.trackId), ['b1', 'b2', 'c1']);
      expect(start, 0);
    });

    test('stops adding albums once enough songs follow', () {
      final many = [for (var i = 0; i < 50; i++) _album('x$i', ['x$i-2', 'x$i-1'])];
      final (:queue, :start) = libraryAlbumQueue(many, 0, 'x0-1', ordered: ordered, ahead: 9);
      expect(queue.length - start - 1, inInclusiveRange(9, 10));
    });
  });

  group('LibrarySongList', () {
    final songs = [
      _song('3', title: 'Cherry', artist: 'Zed', album: 'z'),
      _song('2', title: 'apple', artist: 'Beach House', album: 'bloom'),
      _song('1', title: 'Banana', artist: 'Beach House', album: 'bloom'),
    ];

    test('latest marked first; by title; by artist then album, oldest marked first', () {
      final list = LibrarySongList();
      expect(list.view(songs, filter: '', sortBy: 'recent').map((t) => t.trackId), ['3', '2', '1']);
      expect(list.view(songs, filter: '', sortBy: 'alpha').map((t) => t.title), ['apple', 'Banana', 'Cherry']);
      expect(list.view(songs, filter: '', sortBy: 'artist').map((t) => t.trackId), ['1', '2', '3']);
    });

    test('the filter matches title, artist or album; the same view comes back unchanged', () {
      final list = LibrarySongList();
      expect(list.view(songs, filter: 'BEACH', sortBy: 'recent').map((t) => t.trackId), ['2', '1']);
      expect(list.view(songs, filter: 'album z', sortBy: 'recent').map((t) => t.trackId), ['3']);
      final a = list.view(songs, filter: '', sortBy: 'alpha');
      expect(identical(list.view(songs, filter: '', sortBy: 'alpha'), a), isTrue);
    });
  });
}
