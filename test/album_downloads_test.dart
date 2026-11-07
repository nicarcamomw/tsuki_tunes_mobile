import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/album_downloads.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_precache_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

Track _t(String id, {String preview = 'https://cdn.example/p.mp3'}) => Track(
      id: id,
      title: 'Song $id',
      artistName: 'Artist',
      artistId: '1',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: preview.isEmpty ? '' : '$preview?id=$id',
      durationSeconds: 200,
    );

Album _album(String id, List<Track> tracks) =>
    Album(id: id, title: 'Album $id', coverUrl: '', artistId: '1', artistName: 'Artist', tracks: tracks);

void main() {
  late Directory tmp;
  final store = AlbumDownloads.instance;
  final mp3 = Uint8List(20000);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('downloads_test');
    AlbumDownloads.baseDir = () async => tmp;
    store.resetForTesting();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<bool> download(Album a, {Set<String> failing = const {}}) {
    final client = MockClient((r) async =>
        failing.contains(r.url.queryParameters['id']) ? http.Response('no', 403) : http.Response.bytes(mp3, 200));
    return http.runWithClient(() => store.download(a), () => client);
  }

  test('a downloaded album keeps its songs for the player, and opens offline', () async {
    final album = _album('a1', [_t('1'), _t('2'), _t('3', preview: '')]);
    expect(await download(album), isTrue);
    expect(store.isDownloaded('a1'), isTrue);
    expect(store.pathFor('1'), isNotNull);
    expect(store.pathFor('3'), isNull, reason: 'no preview to save');
    // The player finds it where it looks for cached songs.
    expect(AudioPrecacheService().getCachedFilePath('2'), store.pathFor('2'));
    expect(store.album('a1')!.tracks.map((t) => t.id), ['1', '2', '3']);
  });

  test('it survives a restart: the index and the files are read back', () async {
    await download(_album('a1', [_t('1')]));
    store.resetForTesting();
    await store.ready();
    expect(store.isDownloaded('a1'), isTrue);
    expect(store.pathFor('1'), isNotNull);
  });

  test('a song that fails leaves the rest saved', () async {
    expect(await download(_album('a1', [_t('1'), _t('2')]), failing: {'2'}), isFalse);
    expect(store.isDownloaded('a1'), isTrue);
    expect(store.pathFor('1'), isNotNull);
    expect(store.pathFor('2'), isNull);
  });

  test('removing an album keeps the songs another downloaded album has', () async {
    await download(_album('a1', [_t('1'), _t('2')]));
    await download(_album('a2', [_t('2'), _t('3')]));
    await store.remove('a1');
    expect(store.isDownloaded('a1'), isFalse);
    expect(store.pathFor('1'), isNull);
    expect(store.pathFor('2'), isNotNull, reason: 'a2 has it too');
    expect(store.pathFor('3'), isNotNull);
  });
}
