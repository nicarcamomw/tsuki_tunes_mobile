import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/playlist_provider.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: 'A',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistProvider playlists;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    playlists = PlaylistProvider();
    await playlists.initLocalOnly('guest_test');
  });

  test('a new playlist can be created with its first song in one go', () async {
    final created = await playlists.createPlaylist('Mix', tracks: [_t('1')]);
    expect(created!.tracks.single.id, '1');
  });

  test('names are capped at 100 characters', () async {
    final created = await playlists.createPlaylist('x' * 150);
    expect(created!.name.length, 100);
    await playlists.renamePlaylist(created.id, 'y' * 120);
    expect(playlists.playlists.first.name, 'y' * 100);
  });

  test('a playlist stops at 1000 songs', () async {
    final created = await playlists.createPlaylist(
      'Big',
      tracks: [for (var i = 0; i < 1005; i++) _t('$i')],
    );
    expect(created!.tracks.length, 1000);
    expect(await playlists.addTrackToPlaylist(created.id, _t('new')), isFalse);
  });

  test('undoing a removal puts the song back where it was', () async {
    final created = await playlists.createPlaylist(
        'Mix', tracks: [_t('1'), _t('2'), _t('3')]);
    await playlists.removeTrackFromPlaylist(created!.id, '2');
    expect(await playlists.insertTrackAt(created.id, _t('2'), 1), isTrue);
    expect(playlists.getPlaylist(created.id)!.tracks.map((t) => t.id),
        ['1', '2', '3']);
    // Already there: nothing changes.
    expect(await playlists.insertTrackAt(created.id, _t('2'), 0), isFalse);
  });
}
