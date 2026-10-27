import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/play_day.dart';
import '../models/track.dart';

/// Per-play listening log, one Firestore document per day. Unlike
/// `listenedTracks` (one entry per song, first listen only) this counts
/// every play, which Wrapped and the Time Machine need.
class PlayHistoryService {
  PlayHistoryService(this._db);

  final FirebaseFirestore _db;
  final Map<String, ({DateTime at, List<PlayDay> days})> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  CollectionReference<Map<String, dynamic>> _days(String uid) =>
      _db.collection('users').doc(uid).collection('playDays');

  /// Merges one play into today's document. Offline, Firestore queues the
  /// write and the counters still add up when it syncs.
  Future<void> recordPlay(String uid, Track track, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final seconds = track.durationSeconds > 0 ? track.durationSeconds : 30;
    _cache.removeWhere((key, _) => key.startsWith('$uid|'));
    await _days(uid).doc(PlayDay.keyFor(now)).set({
      'date': PlayDay.keyFor(now),
      'plays': {track.id: FieldValue.increment(1)},
      'hours': {'${now.hour}': FieldValue.increment(1)},
      'seconds': FieldValue.increment(seconds),
      'tracks': {track.id: PlayDayTrack.fromTrack(track).toMap()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Days between [from] and [to] inclusive, oldest first.
  Future<List<PlayDay>> loadRange(String uid, DateTime from, DateTime to) async {
    final fromKey = PlayDay.keyFor(from);
    final toKey = PlayDay.keyFor(to);
    final cacheKey = '$uid|$fromKey|$toKey';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.days;
    }

    final snap = await _days(uid)
        .where('date', isGreaterThanOrEqualTo: fromKey)
        .where('date', isLessThanOrEqualTo: toKey)
        .get();
    final days = snap.docs
        .map((d) => PlayDay.fromFirestore(d.data(), id: d.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    _cache[cacheKey] = (at: DateTime.now(), days: days);
    return days;
  }

  /// The first day with recorded plays, to explain gaps in older history.
  Future<DateTime?> firstRecordedDay(String uid) async {
    final snap = await _days(uid).orderBy('date').limit(1).get();
    if (snap.docs.isEmpty) return null;
    return DateTime.tryParse('${snap.docs.first.data()['date']}');
  }
}
