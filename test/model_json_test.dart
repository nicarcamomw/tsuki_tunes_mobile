import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/mappers/playlist_firestore.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/playlist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/radar_release.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/entities/wrapped_data.dart';

// The stored JSON of these models lives in SharedPreferences and, for
// playlists, in Firestore: its shape must not change, and old or odd
// entries must still load.

Track _track({List<Contributor> contributors = const []}) => Track(
      id: '1',
      title: 'Song',
      artistId: 'a1',
      artistName: 'Artist',
      albumId: 'al1',
      albumTitle: 'Album',
      coverUrl: 'https://c/1.jpg',
      previewUrl: 'https://p/1.mp3',
      durationSeconds: 200,
      rank: 5,
      isExplicit: true,
      contributors: contributors,
      link: 'https://deezer.com/track/1',
      isrc: 'USRC1',
    );

void main() {
  group('Track', () {
    test('stores every field under its storage key', () {
      final t = _track(contributors: [
        const Contributor(id: 'a1', name: 'Artist', role: 'Main'),
        const Contributor(id: 'a2', name: 'Guest'),
      ]);
      expect(t.toJson(), {
        'id': '1',
        'title': 'Song',
        'artistId': 'a1',
        'artistName': 'Artist',
        'albumId': 'al1',
        'albumTitle': 'Album',
        'coverUrl': 'https://c/1.jpg',
        'previewUrl': 'https://p/1.mp3',
        'durationSeconds': 200,
        'rank': 5,
        'isExplicit': true,
        'contributors': [
          {'id': 'a1', 'name': 'Artist', 'role': 'Main'},
          {'id': 'a2', 'name': 'Guest', 'role': null},
        ],
        'link': 'https://deezer.com/track/1',
        'isrc': 'USRC1',
      });
    });

    test('loads back what it stored', () {
      final t = _track(contributors: [const Contributor(id: 'a2', name: 'Guest')]);
      expect(Track.fromJson(t.toJson()).toJson(), t.toJson());
    });

    test('loads old or partial entries with defaults', () {
      final t = Track.fromJson({
        'id': 42,
        'artistId': 7,
        'isExplicit': 'yes',
        'isrc': 123,
        'contributors': [
          <dynamic, dynamic>{'id': 9, 'name': 'X'},
        ],
      });
      expect(t.id, '42');
      expect(t.title, 'Unknown Track');
      expect(t.artistId, '7');
      expect(t.artistName, 'Unknown Artist');
      expect(t.albumId, '');
      expect(t.coverUrl, '');
      expect(t.durationSeconds, 30);
      expect(t.rank, isNull);
      expect(t.isExplicit, isFalse);
      expect(t.isrc, '123');
      expect(t.contributors.single.id, '9');
      expect(t.contributors.single.name, 'X');
    });

    test('reads a Deezer track', () {
      final t = Track.fromDeezer({
        'id': 3135556,
        'title': 'Harder, Better, Faster, Stronger',
        'duration': 224,
        'rank': 900000,
        'explicit_lyrics': false,
        'preview': 'https://p/3.mp3',
        'link': 'https://deezer.com/track/3135556',
        'isrc': 'GBDUW0000059',
        'artist': {'id': 27, 'name': 'Daft Punk'},
        'album': {'id': 302127, 'title': 'Discovery', 'cover_medium': 'https://c/m.jpg'},
        'contributors': [
          {'id': 27, 'name': 'Daft Punk', 'role': 'Main'},
          {'id': 99, 'name': 'Guest', 'role': 'Featured'},
        ],
      });
      expect(t.id, '3135556');
      expect(t.artistId, '27');
      expect(t.artistName, 'Daft Punk, Guest');
      expect(t.albumId, '302127');
      expect(t.albumTitle, 'Discovery');
      expect(t.coverUrl, 'https://c/m.jpg');
      expect(t.durationSeconds, 224);
      expect(t.isrc, 'GBDUW0000059');
      expect(t.contributors, hasLength(2));
      expect(t.fullArtistName, 'Daft Punk, Guest');
    });

    test('copyWith changes only what it is given', () {
      final t = _track().copyWith(previewUrl: 'new');
      expect(t.previewUrl, 'new');
      expect(t.toJson()..remove('previewUrl'),
          _track().toJson()..remove('previewUrl'));
    });
  });

  group('Artist', () {
    test('stores and loads back', () {
      final a = const Artist(
        id: '27',
        name: 'Daft Punk',
        pictureUrl: 'https://p/b.jpg',
        pictureSmall: 'https://p/s.jpg',
        pictureXl: 'https://p/xl.jpg',
        fansCount: 10,
        albumsCount: 3,
      );
      expect(a.toJson(), {
        'id': '27',
        'name': 'Daft Punk',
        'pictureUrl': 'https://p/b.jpg',
        'pictureSmall': 'https://p/s.jpg',
        'pictureMedium': null,
        'pictureBig': null,
        'pictureXl': 'https://p/xl.jpg',
        'fansCount': 10,
        'albumsCount': 3,
      });
      expect(Artist.fromJson(a.toJson()).toJson(), a.toJson());
    });

    test('loads old or partial entries with defaults', () {
      final a = Artist.fromJson({'id': 5});
      expect(a.id, '5');
      expect(a.name, 'Unknown Artist');
      expect(a.pictureUrl, '');
      expect(a.fansCount, 0);
      expect(a.albumsCount, 0);
    });

    test('reads a Deezer artist', () {
      final a = Artist.fromDeezer({
        'id': 27,
        'name': 'Daft Punk',
        'picture_medium': 'https://p/m.jpg',
        'picture_big': 'https://p/b.jpg',
        'nb_fan': 100,
        'nb_album': 'x',
      });
      expect(a.id, '27');
      expect(a.pictureUrl, 'https://p/b.jpg');
      expect(a.getBestImage(size: 'medium'), 'https://p/m.jpg');
      expect(a.fansCount, 100);
      expect(a.albumsCount, 0);
    });
  });

  group('Album', () {
    final album = const Album(
      id: '302127',
      title: 'Discovery',
      coverUrl: 'https://c/m.jpg',
      coverXl: 'https://c/xl.jpg',
      artistId: '27',
      artistName: 'Daft Punk',
      releaseDate: '2001-03-07',
      fansCount: 50,
      tracksCount: 14,
      link: 'https://deezer.com/album/302127',
    );

    test('stores without tracks when it has none', () {
      expect(album.toJson(), {
        'id': '302127',
        'title': 'Discovery',
        'coverUrl': 'https://c/m.jpg',
        'coverXl': 'https://c/xl.jpg',
        'artistId': '27',
        'artistName': 'Daft Punk',
        'releaseDate': '2001-03-07',
        'recordType': 'album',
        'fansCount': 50,
        'tracksCount': 14,
        'link': 'https://deezer.com/album/302127',
      });
    });

    test('stores its tracks and loads them back', () {
      final withTracks = album.copyWith(tracks: [_track()]);
      final json = withTracks.toJson();
      expect(json['tracks'], [_track().toJson()]);
      expect(Album.fromJson(json).toJson(), json);
    });

    test('loads old or partial entries with defaults', () {
      final a = Album.fromJson({'id': 1, 'artistId': 2});
      expect(a.id, '1');
      expect(a.title, 'Unknown Album');
      expect(a.artistId, '2');
      expect(a.artistName, 'Unknown Artist');
      expect(a.releaseDate, '');
      expect(a.recordType, 'album');
      expect(a.tracksCount, 0);
      expect(a.tracks, isEmpty);
    });

    test('reads a Deezer album and gives its tracks the album data', () {
      final a = Album.fromDeezer({
        'id': 302127,
        'title': 'Discovery',
        'cover_medium': 'https://c/m.jpg',
        'release_date': '2001-03-07',
        'record_type': 'album',
        'artist': {'id': 27, 'name': 'Daft Punk'},
        'tracks': {
          'data': [
            {'id': 1, 'title': 'One More Time', 'duration': 320},
          ],
        },
      });
      expect(a.id, '302127');
      expect(a.tracksCount, 1);
      expect(a.year, '2001');
      final t = a.tracks.single;
      expect(t.albumId, '302127');
      expect(t.albumTitle, 'Discovery');
      expect(t.coverUrl, 'https://c/m.jpg');
      expect(t.artistName, 'Daft Punk');
    });
  });

  group('Playlist', () {
    final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updated = DateTime.utc(2026, 2, 3, 4, 5, 6);
    final playlist = Playlist(
      id: 'p1',
      name: 'Mix',
      tracks: [_track()],
      createdAt: created,
      updatedAt: updated,
    );

    test('stores and loads back', () {
      expect(playlist.toJson(), {
        'id': 'p1',
        'name': 'Mix',
        'tracks': [_track().toJson()],
        'createdAt': '2026-01-02T03:04:05.000Z',
        'updatedAt': '2026-02-03T04:05:06.000Z',
      });
      expect(Playlist.fromJson(playlist.toJson()).toJson(), playlist.toJson());
    });

    test('a missing or broken date falls back to now', () {
      final before = DateTime.now();
      final p = Playlist.fromJson({'id': 7, 'name': 3, 'createdAt': 'nope'});
      expect(p.id, '7');
      expect(p.name, '3');
      expect(p.tracks, isEmpty);
      expect(p.createdAt.isBefore(before), isFalse);
      expect(p.updatedAt.isBefore(before), isFalse);
    });

    test('Firestore: tracks as stored JSON, dates as timestamps', () {
      final fs = playlist.toFirestore();
      expect(fs['name'], 'Mix');
      expect(fs['tracks'], [_track().toJson()]);
      expect(fs['createdAt'], Timestamp.fromDate(created));
      expect(fs.containsKey('id'), isFalse);

      final back = playlistFromFirestore({
        'name': 'Mix',
        'tracks': [_track().toJson()],
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': {'_seconds': updated.millisecondsSinceEpoch ~/ 1000},
      }, docId: 'p1');
      expect(back.id, 'p1');
      expect(back.createdAt, created.toLocal());
      expect(back.updatedAt, updated.toLocal());
      expect(back.tracks.single.toJson(), _track().toJson());
    });
  });

  group('RadarRelease', () {
    test('stores and loads back', () {
      final r = RadarRelease(
        albumId: 'al1',
        title: 'New',
        artistId: 'a1',
        artistName: 'Artist',
        coverUrl: 'https://c/1.jpg',
        releaseDate: '2026-10-01',
        recordType: 'single',
        detectedAt: DateTime.utc(2026, 10, 2),
        isNew: true,
        read: false,
      );
      expect(r.toJson(), {
        'albumId': 'al1',
        'title': 'New',
        'artistId': 'a1',
        'artistName': 'Artist',
        'coverUrl': 'https://c/1.jpg',
        'releaseDate': '2026-10-01',
        'recordType': 'single',
        'detectedAt': '2026-10-02T00:00:00.000Z',
        'isNew': true,
        'read': false,
      });
      expect(RadarRelease.fromJson(r.toJson()).toJson(), r.toJson());
      expect(r.copyWith(read: true).read, isTrue);
    });

    test('loads old or partial entries with defaults', () {
      final r = RadarRelease.fromJson({'albumId': 3});
      expect(r.albumId, '3');
      expect(r.title, '');
      expect(r.recordType, 'album');
      expect(r.detectedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(r.isNew, isFalse);
      expect(r.read, isTrue);
    });
  });

  group('WrappedData', () {
    final data = WrappedData(
      year: 2026,
      topTracks: const [
        WrappedTrackEntry(
          trackId: '1',
          title: 'Song',
          artistName: 'Artist',
          albumTitle: 'Album',
          coverUrl: 'https://c/1.jpg',
          playCount: 9,
          totalSeconds: 1800,
        ),
      ],
      topArtists: const [
        WrappedArtistEntry(name: 'Artist', playCount: 9, totalSeconds: 1800),
      ],
      totalMinutesListened: 30,
      totalTracksPlayed: 9,
      uniqueTracksCount: 1,
      uniqueArtistsCount: 1,
      favoriteHour: 22,
      hourDistribution: const {22: 9, 7: 1},
      funFacts: const [
        WrappedFunFact(key: 'night_owl', data: {'pct': 80}),
      ],
      generatedAt: DateTime.utc(2026, 12, 1),
    );

    test('stores and loads back', () {
      expect(data.toJson(), {
        'year': 2026,
        'activeDays': 0,
        'periodDays': 0,
        'topTracks': [
          {
            'trackId': '1',
            'title': 'Song',
            'artistName': 'Artist',
            'albumTitle': 'Album',
            'coverUrl': 'https://c/1.jpg',
            'playCount': 9,
            'totalSeconds': 1800,
          },
        ],
        'topArtists': [
          {'name': 'Artist', 'playCount': 9, 'totalSeconds': 1800, 'coverUrl': null},
        ],
        'totalMinutesListened': 30,
        'totalTracksPlayed': 9,
        'uniqueTracksCount': 1,
        'uniqueArtistsCount': 1,
        'favoriteHour': 22,
        'hourDistribution': {'22': 9, '7': 1},
        'funFacts': [
          {'key': 'night_owl', 'data': {'pct': 80}},
        ],
        'generatedAt': '2026-12-01T00:00:00.000Z',
        'basedOnPlays': false,
      });
      expect(WrappedData.fromJson(data.toJson()).toJson(), data.toJson());
    });

    test('stores playsSince only when known', () {
      final withSince = WrappedData.fromJson({
        ...data.toJson(),
        'basedOnPlays': true,
        'playsSince': '2026-03-01T00:00:00.000Z',
      });
      expect(withSince.basedOnPlays, isTrue);
      expect(withSince.toJson()['playsSince'], '2026-03-01T00:00:00.000Z');
    });

    test('loads an empty entry with defaults', () {
      final before = DateTime.now();
      final w = WrappedData.fromJson({});
      expect(w.year, 0);
      expect(w.topTracks, isEmpty);
      expect(w.hourDistribution, isEmpty);
      expect(w.isEmpty, isTrue);
      expect(w.basedOnPlays, isFalse);
      expect(w.playsSince, isNull);
      expect(w.generatedAt.isBefore(before), isFalse);
    });
  });
}
