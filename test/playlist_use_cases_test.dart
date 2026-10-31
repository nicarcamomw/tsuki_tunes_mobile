import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/playlist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/playlist_repository.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/add_track_to_playlist.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/create_playlist.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/remove_track_from_playlist.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/rename_playlist.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

/// In-memory playlists.
class _FakePlaylists implements PlaylistRepository {
  final _byId = <String, Playlist>{};
  var _next = 0;

  Playlist byId(String id) => _byId[id]!;

  @override
  List<Playlist> get playlists => _byId.values.toList();

  @override
  Future<Playlist?> createPlaylist(String name, {List<Track> tracks = const []}) async {
    final now = DateTime(2026);
    final p = Playlist(id: 'p${_next++}', name: name, tracks: tracks, createdAt: now, updatedAt: now);
    return _byId[p.id] = p;
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newName) async =>
      _byId[playlistId] = byId(playlistId).copyWith(name: newName);

  @override
  Future<void> deletePlaylist(String playlistId) async => _byId.remove(playlistId);

  @override
  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    _byId[playlistId] = byId(playlistId).copyWith(tracks: [...byId(playlistId).tracks, track]);
    return true;
  }

  @override
  Future<bool> insertTrackAt(String playlistId, Track track, int index) async {
    final tracks = [...byId(playlistId).tracks]..insert(index, track);
    _byId[playlistId] = byId(playlistId).copyWith(tracks: tracks);
    return true;
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async =>
      _byId[playlistId] = byId(playlistId)
          .copyWith(tracks: byId(playlistId).tracks.where((t) => t.id != trackId).toList());

  @override
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex) async {}
}

void main() {
  late _FakePlaylists repo;
  setUp(() => repo = _FakePlaylists());

  test('a blank name creates nothing; names are trimmed', () async {
    expect(await CreatePlaylist(repo)('   '), isNull);
    final p = await CreatePlaylist(repo)('  Noche  ', tracks: [_t('1')]);
    expect(p?.name, 'Noche');
    expect(p?.tracks.single.id, '1');
  });

  test('renaming to a blank name keeps the old one', () async {
    final p = (await CreatePlaylist(repo)('Noche'))!;
    await RenamePlaylist(repo)(p.id, ' ');
    expect(repo.byId(p.id).name, 'Noche');
    await RenamePlaylist(repo)(p.id, ' Día ');
    expect(repo.byId(p.id).name, 'Día');
  });

  test('adding says when the song is there already or the playlist is full', () async {
    final add = AddTrackToPlaylist(repo);
    final p = (await CreatePlaylist(repo)('Noche', tracks: [_t('1')]))!;

    expect(add.check(p, _t('1')), AddToPlaylistResult.alreadyThere);
    expect(await add(p, _t('2')), AddToPlaylistResult.added);
    expect(repo.byId(p.id).tracks.map((t) => t.id), ['1', '2']);

    final full = p.copyWith(tracks: [for (var i = 0; i < Playlist.maxTracks; i++) _t('$i!')]);
    expect(full.isFull, isTrue);
    expect(await add(full, _t('new')), AddToPlaylistResult.full);
  });

  test('removing returns an undo that puts the song back in its place', () async {
    final p = (await CreatePlaylist(repo)('Noche', tracks: [_t('1'), _t('2'), _t('3')]))!;
    final undo = RemoveTrackFromPlaylist(repo)(p.id, _t('2'), 1);
    await pumpEventQueue();
    expect(repo.byId(p.id).tracks.map((t) => t.id), ['1', '3']);

    await undo();
    expect(repo.byId(p.id).tracks.map((t) => t.id), ['1', '2', '3']);
  });
}
