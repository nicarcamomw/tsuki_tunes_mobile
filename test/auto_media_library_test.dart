import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/playlist.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/services/auto_media_library.dart';
import 'package:tsuki_tunes_mobile/services/media_session_handler.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

Track _t(String id, {String title = 'Song'}) => Track(
      id: id,
      title: '$title $id',
      artistId: '1',
      artistName: 'Bad Bunny',
      albumId: '9',
      albumTitle: 'Album',
      coverUrl: 'https://e/$id.jpg',
      previewUrl: 'https://e/$id.mp3',
      durationSeconds: 200,
    );

Map<String, dynamic> _deezer(String id) => {
      'id': int.parse(id),
      'title': 'Hit $id',
      'duration': 200,
      'rank': 900000,
      'preview': 'https://e/$id.mp3',
      'artist': {'id': 1, 'name': 'Bad Bunny'},
      'album': {'id': 9, 'title': 'Album', 'cover_medium': 'https://e/$id.jpg'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  late List<(Track, List<Track>)> played;
  late AutoMediaLibrary library;

  final client = MockClient((req) async {
    final body = req.url.path.startsWith('/search/track')
        ? {'data': [_deezer('71'), _deezer('72')]}
        : {'data': [_deezer('81'), _deezer('82'), _deezer('83')]};
    return http.Response(jsonEncode(body), 200);
  });

  AutoMediaLibrary newLibrary() => AutoMediaLibrary(
        play: (track, queue) async => played.add((track, queue)),
        currentUid: () async => 'u1',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await storage.saveFavoriteTracks([_t('1'), _t('2'), _t('3')]);
    await storage.saveRecentTracks([_t('5'), _t('6')]);
    final now = DateTime(2026, 10, 30);
    await storage.saveCachedPlaylists('u1', [
      Playlist(id: 'p1', name: 'Gym', tracks: [_t('7'), _t('8')], createdAt: now, updatedAt: now).toJson(),
      Playlist(id: 'p2', name: 'Empty', tracks: const [], createdAt: now, updatedAt: now).toJson(),
    ]);
    played = [];
    library = newLibrary();
  });

  test('the root lists the four sections in the app language', () async {
    final root = await library.children(AudioService.browsableRootId);
    expect(root.map((i) => i.title), ['Recientes', 'Favoritos', 'Mis playlists', 'Top mundial']);
    expect(root.every((i) => !i.playable!), isTrue);
  });

  test('a favorite plays with the favorites as its queue', () async {
    final favs = await library.children(AutoMediaLibrary.favoritesId);
    expect(favs.map((i) => i.title), ['Song 1', 'Song 2', 'Song 3']);
    await library.playFromMediaId(favs[1].id);
    expect(played.single.$1.id, '2');
    expect(played.single.$2.map((t) => t.id), ['1', '2', '3']);
  });

  test('playlists open as folders (empty ones hidden) and play their songs', () async {
    final playlists = await library.children(AutoMediaLibrary.playlistsId);
    expect(playlists.map((i) => i.title), ['Gym']);
    final songs = await library.children(playlists.single.id);
    await library.playFromMediaId(songs.last.id);
    expect(played.single.$1.id, '8');
    expect(played.single.$2.map((t) => t.id), ['7', '8']);
  });

  test('an id kept from before a restart still plays', () async {
    final favs = await library.children(AutoMediaLibrary.favoritesId);
    await newLibrary().playFromMediaId(favs.first.id);
    expect(played.single.$1.id, '1');
  });

  test('the top chart and voice search come from Deezer', () async {
    await http.runWithClient(() async {
      final top = await library.children(AutoMediaLibrary.topId);
      expect(top.map((i) => i.title), ['Hit 81', 'Hit 82', 'Hit 83']);

      final hits = await library.search('bad bunny');
      expect(hits.length, 2);
      await library.playFromMediaId(hits.last.id);
      expect(played.last.$1.id, '72');

      expect(await library.playFromSearch('bad bunny'), isTrue);
      expect(played.last.$1.id, '71');
      expect(played.last.$2.map((t) => t.id), ['71', '72']);
    }, () => client);
  });

  test('"resume" offers the last song played', () async {
    await storage.savePlaybackState([_t('4'), _t('5')], 1, 3000, false);
    final recent = await library.children(AudioService.recentRootId);
    expect(recent.single.title, 'Song 5');
  });

  test('the media session passes browsing to the library; empty voice query resumes', () async {
    final handler = TsukiAudioHandler()..library = library;
    var resumed = 0;
    handler.onPlay = () async => resumed++;

    final root = await handler.getChildren(AudioService.browsableRootId);
    expect(root.length, 4);
    await handler.playFromSearch('');
    expect(resumed, 1);
    expect(played, isEmpty);
  });
}
