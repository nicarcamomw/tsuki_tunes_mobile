import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/spotify_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/external_library.dart';
import 'package:tsuki_tunes_mobile/domain/entities/playlist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/track_matcher.dart';
import 'package:tsuki_tunes_mobile/presentation/state/spotify_import_controller.dart';

Track _t(String id, String title, String artist, {int secs = 200}) => Track(
      id: id,
      title: title,
      artistName: artist,
      artistId: 'a',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://p/$id.mp3',
      durationSeconds: secs,
    );

void main() {
  group('matching a song', () {
    test('the ISRC first; then title and artist, but never a cover or a different length', () async {
      final m = TrackMatcher(
        byIsrc: (isrc) async => isrc == 'USX9P0700001' ? _t('1', 'Chop Suey!', 'System Of A Down') : null,
        search: (q) async => [
          _t('2', 'Toxicity (Live)', 'System Of A Down'),
          _t('3', 'Toxicity', 'Some Cover Band'),
          _t('4', 'Toxicity', 'System of a Down', secs: 400),
          _t('5', 'Toxicity', 'System Of A Down', secs: 219),
        ],
      );
      expect((await m.match(const ExternalTrack(title: 'Chop Suey!', artists: ['SOAD'], isrc: 'USX9P0700001')))!.id, '1');
      final byName = await m.match(const ExternalTrack(
          title: 'Toxicity - Remastered', artists: ['System Of A Down'], isrc: 'NOTFOUND0000', durationMs: 218000));
      expect(byName!.id, '5');
      expect(await m.match(const ExternalTrack(title: 'Aerials', artists: ['SOAD'])), isNull);
    });
  });

  group('reading Spotify', () {
    test('the saved songs come first, then the playlists; episodes are skipped', () async {
      final svc = SpotifyService()..accessTokenForTesting = 't';
      final client = MockClient((r) async {
        final p = r.url.path;
        if (p == '/v1/me/tracks') {
          if (r.url.queryParameters['limit'] == '1') return http.Response(jsonEncode({'total': 2}), 200);
          return http.Response(
              jsonEncode({
                'items': [
                  {'track': {'name': 'A', 'type': 'track', 'duration_ms': 1000, 'artists': [{'name': 'X'}], 'external_ids': {'isrc': 'ISRC00000001'}}},
                  {'track': {'name': 'Pod', 'type': 'episode', 'artists': []}},
                ],
                'next': null,
              }),
              200);
        }
        if (p == '/v1/me/playlists') {
          return http.Response(
              jsonEncode({
                'items': [
                  {'id': 'p1', 'name': 'Noche', 'tracks': {'total': 12}, 'images': [{'url': 'https://i/1.jpg'}]},
                ],
                'next': null,
              }),
              200);
        }
        return http.Response('', 404);
      });
      final lists = await http.runWithClient(svc.getImportablePlaylists, () => client);
      expect(lists.map((l) => l.id), ['liked', 'p1']);
      expect(lists.first.liked, isTrue);
      expect(lists.last.total, 12);
      final tracks = await http.runWithClient(() => svc.getImportTracks(lists.first), () => client);
      expect(tracks.map((t) => t.title), ['A']);
      expect(tracks.single.isrc, 'ISRC00000001');
    });

    test('an old sign-in without the playlist permission asks to connect again', () async {
      final svc = SpotifyService()..accessTokenForTesting = 't';
      final client = MockClient((r) async => http.Response('{"error":{"status":403}}', 403));
      final lists = await http.runWithClient(svc.getImportablePlaylists, () => client);
      expect(lists, isEmpty);
      expect(svc.importNeedsReconnect, isTrue);
    });
  });

  test('the chosen playlists become Tsuki playlists with the songs found', () async {
    final created = <String, List<Track>>{};
    final c = SpotifyImportController(
      loadPlaylists: () async => const [
        ExternalPlaylist(id: 'liked', name: 'Liked', total: 2, liked: true),
        ExternalPlaylist(id: 'p1', name: 'Noche', total: 3),
      ],
      loadTracks: (p) async => p.liked
          ? const [ExternalTrack(title: 'A', artists: ['X'], isrc: 'ISRC00000001'), ExternalTrack(title: 'Nope', artists: ['Y'])]
          : const [ExternalTrack(title: 'B', artists: ['X'], isrc: 'ISRC00000002')],
      needsReconnect: () => false,
      matcher: TrackMatcher(
        byIsrc: (isrc) async => _t(isrc, 'Song', 'X'),
        search: (q) async => const [],
      ),
      createPlaylist: (name, tracks) async {
        created[name] = tracks;
        return Playlist(id: 'new-$name', name: name, tracks: tracks, createdAt: DateTime(2026), updatedAt: DateTime(2026));
      },
      likedName: 'Me gusta (Spotify)',
      gap: Duration.zero,
    );
    await c.load();
    c.toggle('liked');
    await c.run();
    expect(created.keys, ['Me gusta (Spotify)']);
    expect(created['Me gusta (Spotify)']!.map((t) => t.id), ['ISRC00000001']);
    expect(c.results.single.found, 1);
    expect(c.results.single.total, 2);
    expect(c.selectedCount, 0);
  });
}
