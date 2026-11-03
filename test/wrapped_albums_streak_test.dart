import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/wrapped_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/play_day.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/wrapped/story_image.dart';

PlayDayTrack _song(String id, String album) => PlayDayTrack(
      id: id,
      title: 'Song $id',
      artistName: 'Artist $album',
      albumId: album,
      albumTitle: 'Album $album',
      coverUrl: 'https://img/$album.jpg',
      durationSeconds: 200,
    );

/// [plays] by track id; each id is the album, a dot and the song ('x.1').
PlayDay _day(String date, Map<String, int> plays) => PlayDay(
      date: date,
      plays: plays,
      tracks: {for (final id in plays.keys) id: _song(id, id.split('.').first)},
      hours: {20: plays.values.fold(0, (s, v) => s + v)},
      seconds: plays.values.fold(0, (s, v) => s + v * 200),
    );

Track _track(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: '',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

Album _album(String id, int songs, {String type = 'album', bool withTracks = true}) => Album(
      id: id,
      title: 'Album $id',
      coverUrl: '',
      artistId: '',
      artistName: '',
      recordType: type,
      tracksCount: songs,
      tracks: withTracks ? [for (var i = 1; i <= songs; i++) _track('$id.$i')] : const [],
    );

void main() {
  final service = WrappedService();

  group('longest streak', () {
    test('the most days in a row, and when it started', () {
      final (days, from) = WrappedService.longestStreak([
        '2026-10-01', '2026-10-02', // 2
        '2026-10-05', '2026-10-06', '2026-10-07', // 3
        '2026-10-09',
      ]);
      expect(days, 3);
      expect(from, DateTime(2026, 10, 5));
    });

    test('across the end of a month, out of order and repeated', () {
      final (days, from) =
          WrappedService.longestStreak(['2026-11-01', '2026-10-31', '2026-10-30', '2026-10-31']);
      expect(days, 3);
      expect(from, DateTime(2026, 10, 30));
    });

    test('none', () {
      expect(WrappedService.longestStreak(const []), (0, null));
    });

    test('in the recap, from the days with plays', () {
      final w = service.generate(
        days: [
          _day('2026-10-01', {'a.1': 10}),
          _day('2026-10-02', {'a.2': 10}),
          _day('2026-10-03', {'a.1': 10}),
          _day('2026-10-10', {'a.1': 5}),
        ],
        listened: const [],
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 20),
      );
      expect(w.basedOnPlays, isTrue);
      expect(w.longestStreak, 3);
      expect(w.streakStart, DateTime(2026, 10, 1));
    });

    test('from discoveries too', () {
      ListenedTrackData heard(String id, DateTime at) => ListenedTrackData(
          trackId: id, title: id, artistName: 'A', albumTitle: '', albumId: '', coverUrl: '', duration: 180, listenedAt: at);
      final w = service.generate(
        days: const [],
        listened: [heard('1', DateTime(2026, 3, 1)), heard('2', DateTime(2026, 3, 2)), heard('3', DateTime(2026, 3, 9))],
        year: 2026,
      );
      expect(w.basedOnPlays, isFalse);
      expect(w.longestStreak, 2);
    });
  });

  group('top albums', () {
    final days = [
      _day('2026-10-01', {'x.1': 10, 'x.2': 4, 'y.1': 30, 'z.1': 3, 'z.2': 3, 'z.3': 3}),
    ];
    final w = service.generate(days: days, listened: const [], year: 2026, month: 10, now: DateTime(2026, 10, 2));

    test('ranked by plays of their songs', () {
      expect(w.topAlbums.map((a) => a.albumId), ['x', 'z']);
      expect(w.topAlbums.first.playCount, 14);
      expect(w.topAlbums.first.tracksHeard, 2);
      expect(w.topAlbums.first.title, 'Album x');
    });

    test('one song played a lot is a top song, not an album', () {
      expect(w.topAlbums.map((a) => a.albumId), isNot(contains('y')));
    });
  });

  group('albums heard whole', () {
    // x: all 6 songs; y: 5 of 6; s: a single of 5 songs, all heard.
    final w = service.generate(
      days: [
        _day('2026-10-01', {for (var i = 1; i <= 6; i++) 'x.$i': 3}),
        _day('2026-10-02', {for (var i = 1; i <= 5; i++) 'y.$i': 3}),
        _day('2026-10-03', {for (var i = 1; i <= 5; i++) 's.$i': 3}),
      ],
      listened: const [],
      year: 2026,
      month: 10,
      now: DateTime(2026, 10, 4),
    );
    final catalog = {'x': _album('x', 6), 'y': _album('y', 6), 's': _album('s', 5, type: 'single')};

    test('every song heard, on real albums of five songs or more', () async {
      final looked = <String>[];
      final done = await service.withCompletedAlbums(w, (id) async {
        looked.add(id);
        return catalog[id];
      });
      expect(done.completedAlbums.map((a) => a.albumId), ['x']);
      expect(done.completedAlbums.single.totalTracks, 6);
      expect(looked, containsAll(['x', 'y', 's']));
      expect(done.topAlbums, w.topAlbums, reason: 'the rest stays as it was');
    });

    test('albums with fewer than five songs heard are not looked up', () async {
      final small = service.generate(
        days: [_day('2026-10-01', {'x.1': 20, 'x.2': 20, 'x.3': 20})],
        listened: const [],
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 2),
      );
      var lookups = 0;
      final done = await service.withCompletedAlbums(small, (id) async {
        lookups++;
        return _album('x', 3);
      });
      expect(lookups, 0);
      expect(done.completedAlbums, isEmpty);
    });

    test('the same songs, not just as many', () async {
      // Heard 6 songs of x, but the catalog lists a different 6th song.
      final other = _album('x', 6).copyWith(tracks: [
        for (var i = 1; i <= 5; i++) _track('x.$i'),
        _track('x.bonus'),
      ]);
      final done = await service.withCompletedAlbums(w, (id) async => id == 'x' ? other : catalog[id]);
      expect(done.completedAlbums, isEmpty);
    });

    test('without a tracklist the count decides', () async {
      final done = await service.withCompletedAlbums(
          w, (id) async => id == 'x' ? _album('x', 6, withTracks: false) : null);
      expect(done.completedAlbums.map((a) => a.albumId), ['x']);
    });

    test('a failed lookup is skipped, not fatal', () async {
      final done = await service.withCompletedAlbums(w, (id) async {
        if (id == 'y') throw Exception('offline');
        return catalog[id];
      });
      expect(done.completedAlbums.map((a) => a.albumId), ['x']);
    });
  });

  testWidgets('a slide becomes a 1080×1920 story, whole and in the middle', (tester) async {
    await tester.runAsync(() async {
      // A tall phone-shaped slide (9:20), solid green.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 900, 2000), Paint()..color = const Color(0xFF00FF00));
      final slide = await recorder.endRecording().toImage(900, 2000);

      final story = await composeStory(slide);
      expect(story.width, 1080);
      expect(story.height, 1920);

      final bytes = (await story.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      Color at(int x, int y) {
        final i = (y * story.width + x) * 4;
        return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
      }

      final middle = at(540, 900);
      expect(middle.g, greaterThan(0.9), reason: 'the slide itself');
      expect(middle.r, lessThan(0.1));
      // Above the slide: the darkened background, not the slide.
      expect(at(540, 20).g, lessThan(0.5));
      // The slide fits between the margins: 2000 tall → 1660 px.
      expect(at(540, 85).g, greaterThan(0.9));
      expect(at(540, 1735).g, greaterThan(0.9));
      slide.dispose();
      story.dispose();
    });
  });
}
