import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_disk_cache.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist_albums_page.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

const _artist = Artist(id: '1', name: 'Band', pictureUrl: 'https://e/a.jpg');
const _album = Album(
  id: '2',
  title: 'Record',
  coverUrl: 'https://e/c.jpg',
  artistId: '1',
  artistName: 'Band',
);
const _track = Track(
  id: '3',
  title: 'Song',
  artistId: '1',
  artistName: 'Band',
  albumId: '2',
  albumTitle: 'Record',
  coverUrl: 'https://e/c.jpg',
  previewUrl: 'https://e/p.mp3',
  durationSeconds: 200,
);

/// The cache is one per app (a singleton, set up once): the whole file
/// shares one folder, which starts with leftovers from an earlier run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory base;
  late Directory folder;
  final cache = DeezerDiskCache();

  String fileFor(String key) =>
      '${folder.path}/${md5.convert(utf8.encode(key))}.json';

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  setUpAll(() async {
    base = Directory.systemTemp.createTempSync('tsuki_deezer_cache_');
    folder = Directory('${base.path}/deezer_api')..createSync();
    // Left by an earlier run: one expired, one unreadable, one still good.
    File(fileFor('old')).writeAsStringSync(jsonEncode({
      't': 'artist',
      'e': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'd': _artist.toJson(),
    }));
    File(fileFor('broken')).writeAsStringSync('{not json');
    File(fileFor('kept')).writeAsStringSync(jsonEncode({
      't': 'artist',
      'e': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      'd': _artist.toJson(),
    }));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => base.path,
    );
    expect(cache.isReady, isFalse);
    expect(await cache.read('kept'), isNull, reason: 'not set up yet');
    await cache.init();
    await settle();
  });

  tearDownAll(() => base.deleteSync(recursive: true));

  test('setting up drops what expired or can\'t be read', () {
    expect(cache.isReady, isTrue);
    expect(File(fileFor('old')).existsSync(), isFalse);
    expect(File(fileFor('broken')).existsSync(), isFalse);
    expect(File(fileFor('kept')).existsSync(), isTrue);
  });

  test('what is written is read back until it expires', () async {
    final expiry = DateTime.now().add(const Duration(hours: 1));
    cache.write('artist:1', 'artist', DeezerDiskCache.serialize('artist', _artist), expiry);
    await settle();

    final hit = await cache.read('artist:1');
    expect(hit?.type, 'artist');
    expect(DeezerDiskCache.deserialize(hit!.type, hit.data), _artist);
    expect(hit.expiry.millisecondsSinceEpoch, expiry.millisecondsSinceEpoch);
    expect(await cache.read('artist:missing'), isNull);
  });

  test('an expired entry is a miss, and is removed', () async {
    cache.write('gone', 'artist', _artist.toJson(),
        DateTime.now().subtract(const Duration(seconds: 1)));
    await settle();

    expect(await cache.read('gone'), isNull);
    await settle();
    expect(File(fileFor('gone')).existsSync(), isFalse);
  });

  test('a big entry is read too', () async {
    final many = [for (var i = 0; i < 200; i++) _track.copyWith(id: '$i')];
    cache.write('tracks:big', 'tracks', DeezerDiskCache.serialize('tracks', many),
        DateTime.now().add(const Duration(hours: 1)));
    await settle();

    final hit = await cache.read('tracks:big');
    expect(DeezerDiskCache.deserialize('tracks', hit!.data), many);
  });

  test('an unreadable entry is a miss', () async {
    File(fileFor('corrupt')).writeAsStringSync('nope');
    expect(await cache.read('corrupt'), isNull);
  });

  test('clear empties the folder', () async {
    cache.write('x', 'artist', _artist.toJson(), DateTime.now().add(const Duration(hours: 1)));
    await settle();
    await cache.clear();

    expect(folder.listSync(), isEmpty);
    expect(await cache.read('x'), isNull);
  });

  group('serialization', () {
    const page = ArtistAlbumsPage(items: [_album], total: 5, hasMore: true, nextIndex: 1);
    final search = <String, dynamic>{
      'artists': [_artist],
      'albums': [_album],
      'tracks': [_track],
    };
    final cases = <String, Object>{
      'artist': _artist,
      'album': _album,
      'track': _track,
      'artists': [_artist],
      'albums': [_album],
      'tracks': [_track],
    };

    test('every kind is tagged and survives a round trip through JSON', () {
      for (final MapEntry(key: tag, value: data) in cases.entries) {
        expect(DeezerDiskCache.typeTagFor(data), tag);
        final raw = jsonDecode(jsonEncode(DeezerDiskCache.serialize(tag, data)));
        expect(DeezerDiskCache.deserialize(tag, raw), data, reason: tag);
      }
    });

    test('album pages and search results too', () {
      expect(DeezerDiskCache.typeTagFor(page), 'albums_page');
      final back = DeezerDiskCache.deserialize(
              'albums_page', jsonDecode(jsonEncode(DeezerDiskCache.serialize('albums_page', page))))
          as ArtistAlbumsPage;
      expect(back.items, page.items);
      expect(back.total, 5);
      expect(back.hasMore, isTrue);
      expect(back.nextIndex, 1);

      expect(DeezerDiskCache.typeTagFor(search), 'search');
      final found = DeezerDiskCache.deserialize(
              'search', jsonDecode(jsonEncode(DeezerDiskCache.serialize('search', search))))
          as Map<String, dynamic>;
      expect(found['artists'], [_artist]);
      expect(found['albums'], [_album]);
      expect(found['tracks'], [_track]);
    });

    test('anything else is not cached', () {
      expect(DeezerDiskCache.typeTagFor('text'), isNull);
      expect(DeezerDiskCache.serialize('unknown', 1), isNull);
    });
  });
}
