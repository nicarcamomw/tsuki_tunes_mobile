import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/listened_track.dart';

// A5: a listened song is read from this phone's database (fromJson) and
// from the server (fromStored). They were two hand-written copies of the
// same reading that had drifted apart (only one understood a server
// timestamp); now there's one.

void main() {
  final song = ListenedTrackData(
    trackId: '3135556',
    title: 'Harder, Better, Faster, Stronger',
    artistName: 'Daft Punk',
    albumTitle: 'Discovery',
    albumId: '302127',
    coverUrl: 'https://c/302127.jpg',
    previewUrl: 'https://p/3135556.mp3',
    duration: 224,
    listenedAt: DateTime.utc(2026, 11, 12, 20, 30),
    artists: const ['Daft Punk'],
  );

  void expectSame(ListenedTrackData a, ListenedTrackData b) {
    expect(a.toJson(), b.toJson());
    expect(a.artists, b.artists);
    expect(a.hasArtistList, b.hasArtistList);
  }

  test('what the phone saves reads back exactly', () {
    expectSame(ListenedTrackData.fromJson(song.toJson()), song);
  });

  test('both readings give the same song from the same data', () {
    final data = song.toJson();
    expectSame(ListenedTrackData.fromJson(data), ListenedTrackData.fromStored(data));
  });

  test('every form of the date is understood by both', () {
    final at = DateTime.utc(2026, 11, 12, 20, 30);
    for (final listenedAt in <Object>[
      at.toIso8601String(),
      at,
      {'seconds': at.millisecondsSinceEpoch ~/ 1000},
      {'_seconds': at.millisecondsSinceEpoch ~/ 1000},
    ]) {
      final data = {...song.toJson(), 'listenedAt': listenedAt};
      expect(ListenedTrackData.fromJson(data).listenedAt!.isAtSameMomentAs(at), isTrue,
          reason: '$listenedAt');
      expect(ListenedTrackData.fromStored(data).listenedAt!.isAtSameMomentAs(at), isTrue,
          reason: '$listenedAt');
    }
  });

  test('old songs without the artist list still guess it from the name', () {
    final data = song.toJson()..remove('artists');
    data['artistName'] = 'Bad Bunny, J Balvin';
    final read = ListenedTrackData.fromJson(data);
    expect(read.hasArtistList, isFalse);
    expect(read.artists, ['Bad Bunny', 'J Balvin']);
  });

  test('missing or odd fields fall back safely; the server doc id fills a missing trackId', () {
    final read = ListenedTrackData.fromStored({'duration': 'long'}, docId: '42');
    expect(read.trackId, '42');
    expect(read.duration, 0);
    expect(read.title, '');
    expect(read.listenedAt, isNull);
  });
}
