import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_album.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_track_listened.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_album_listened.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_follow_artist.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_track_listened.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/unmark_album.dart';

import 'helpers/fake_library_repository.dart';

Track _t(String id, {String album = 'alb'}) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: album,
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

Album _album(List<Track> tracks, {int tracksCount = 0}) => Album(
      id: 'alb',
      title: 'Album',
      coverUrl: '',
      artistId: 'a',
      artistName: 'Artist',
      tracksCount: tracksCount,
      tracks: tracks,
    );

void main() {
  late FakeLibraryRepository library;
  setUp(() => library = FakeLibraryRepository());

  group('songs', () {
    test('toggling marks, then unmarks', () async {
      final toggle = ToggleTrackListened(library);
      expect(await toggle(_t('1')), isTrue);
      expect(library.isTrackListened('1'), isTrue);
      expect(await toggle(_t('1')), isFalse);
      expect(library.isTrackListened('1'), isFalse);
    });

    test('the player marking a listened song writes nothing', () async {
      library.listened.add('1');
      await MarkTrackListened(library)(_t('1'));
      expect(library.markCalls, isEmpty);
    });
  });

  group('albums', () {
    test('marking writes only the missing songs, with the album size', () async {
      library.listened.add('1');
      await MarkAlbum(library)(_album([_t('1'), _t('2'), _t('3')], tracksCount: 12));
      expect(library.markCalls, [
        ['2', '3'],
      ]);
      expect(library.albumCounts, {'alb': 12});
    });

    test('without a size from Deezer, the loaded songs are the album', () async {
      await MarkAlbum(library)(_album([_t('1'), _t('2')]));
      expect(library.albumCounts, {'alb': 2});
    });

    test('a fully listened album writes nothing', () async {
      library.listened.addAll(['1', '2']);
      await MarkAlbum(library)(_album([_t('1'), _t('2')]));
      expect(library.markCalls, isEmpty);
    });

    test('unmarking takes every song off', () async {
      library.listened.addAll(['1', '2', 'other']);
      await UnmarkAlbum(library)(_album([_t('1'), _t('2')]));
      expect(library.listened, {'other'});
    });

    test('the album button marks the rest, then unmarks it all', () async {
      final toggle = ToggleAlbumListened(library);
      final album = _album([_t('1'), _t('2')]);
      library.listened.add('1');

      expect(toggle.isAllListened(album), isFalse);
      expect(await toggle(album), isTrue);
      expect(toggle.isAllListened(album), isTrue);
      expect(await toggle(album), isFalse);
      expect(library.listened, isEmpty);
    });
  });

  test('following toggles and says where it ended', () async {
    const artist = Artist(id: 'x', name: 'X', pictureUrl: '');
    final toggle = ToggleFollowArtist(library);
    expect(await toggle(artist), isTrue);
    expect(library.isArtistFollowed('x'), isTrue);
    expect(await toggle(artist), isFalse);
    expect(library.isArtistFollowed('x'), isFalse);
  });
}
