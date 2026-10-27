import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/play_day.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/services/play_history_service.dart';

Track _t(String id, {int duration = 180}) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a$id',
      artistName: 'Artist $id',
      albumId: 'al$id',
      albumTitle: 'Album $id',
      coverUrl: 'https://img/$id.jpg',
      previewUrl: 'https://cdn/$id.mp3',
      durationSeconds: duration,
    );

void main() {
  late FakeFirebaseFirestore db;
  late PlayHistoryService history;

  setUp(() {
    db = FakeFirebaseFirestore();
    history = PlayHistoryService(db);
  });

  test('counts every play per day with hours, seconds and metadata', () async {
    final at = DateTime(2026, 10, 26, 23, 15);
    await history.recordPlay('u1', _t('1'), at: at);
    await history.recordPlay('u1', _t('1'), at: at);
    await history.recordPlay('u1', _t('2', duration: 30), at: at);

    final days = await history.loadRange('u1', DateTime(2026, 10, 26), DateTime(2026, 10, 26));
    expect(days, hasLength(1));
    final day = days.single;
    expect(day.date, '2026-10-26');
    expect(day.plays, {'1': 2, '2': 1});
    expect(day.totalPlays, 3);
    expect(day.hours[23], 3);
    expect(day.seconds, 180 * 2 + 30);
    expect(day.tracks['1']!.title, 'Song 1');
    expect(day.tracks['1']!.toTrack().previewUrl, 'https://cdn/1.mp3');
  });

  test('loads only the requested range, oldest first', () async {
    await history.recordPlay('u1', _t('1'), at: DateTime(2025, 10, 20));
    await history.recordPlay('u1', _t('1'), at: DateTime(2025, 10, 26));
    await history.recordPlay('u1', _t('1'), at: DateTime(2025, 11, 2));

    final days = await history.loadRange(
        'u1', DateTime(2025, 10, 23), DateTime(2025, 10, 29));
    expect(days.map((d) => d.date), ['2025-10-26']);
    expect(await history.firstRecordedDay('u1'), DateTime(2025, 10, 20));
  });

  test('users never see each other\'s plays', () async {
    await history.recordPlay('u1', _t('1'), at: DateTime(2026, 1, 1));
    final other = await history.loadRange('u2', DateTime(2026, 1, 1), DateTime(2026, 1, 1));
    expect(other, isEmpty);
  });

  test('day keys are zero padded so string ranges sort by date', () {
    expect(PlayDay.keyFor(DateTime(2026, 3, 7, 22)), '2026-03-07');
    expect('2026-03-07'.compareTo('2026-10-01') < 0, isTrue);
  });
}
