import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/firebase_service.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/weekly_challenge.dart';
import '../../domain/logic/artist_names.dart';
import '../../domain/logic/moon_calculator.dart';

export '../../domain/entities/oni_mask.dart';
export '../../domain/entities/weekly_challenge.dart';

/// Achievement engine for the Oni mask collection.
///
/// Unlocked masks and the equipped one live in the user's Firestore document
/// (one small write per unlock or equip). Progress counters stay on the
/// device: they change on every play and would cost far more writes.
class MaskProvider extends ChangeNotifier {
  static const _unlockedKey = 'masks_unlocked_v1';
  static const _equippedKey = 'masks_equipped_v1';
  static const _statsKey = 'masks_stats_v1';
  static const int rainGoalSeconds = 10 * 3600;

  final DateTime Function() _clock;
  final Future<Album?> Function(String albumId) _albumLookup;

  final Map<String, DateTime> _unlocked = {};
  String? _equipped;
  final List<String> _celebrations = [];
  _Stats _stats = _Stats();
  bool _loaded = false;
  final Completer<void> _ready = Completer<void>();
  String? _uid;
  Timer? _ticker;

  /// Polled every 30 s: whether rain or storm ambience is playing, and
  /// whether music is playing.
  bool Function()? isRainPlaying;
  bool Function()? isMusicPlaying;

  // Album run: consecutive natural completions within one album.
  String? _runAlbum;
  final Set<String> _runTracks = {};
  String? _lastStartedId;
  String? _lastCompletedId;

  MaskProvider({DateTime Function()? clock, Future<Album?> Function(String)? albumLookup})
      : _clock = clock ?? DateTime.now,
        _albumLookup = albumLookup ?? ((id) => DeezerApiService().getAlbum(id)) {
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => tick(const Duration(seconds: 30)));
  }

  bool get loaded => _loaded;
  Future<void> get ready => _ready.future;
  bool isUnlocked(String id) => _unlocked.containsKey(id);
  DateTime? unlockedAt(String id) => _unlocked[id];
  int get unlockedCount => _unlocked.length;
  int get totalCount => MaskCatalog.all.length;
  OniMask? get equipped => MaskCatalog.byId(_equipped);
  String? get pendingCelebration => _celebrations.isEmpty ? null : _celebrations.first;

  /// (current, goal) for masks with a counted goal.
  (int, int)? progress(String id) {
    final mask = MaskCatalog.byId(id);
    if (mask?.goal == null) return null;
    final goal = mask!.goal!;
    final now = _clock();
    final current = switch (id) {
      'hyaku' || 'sen' => _stats.plays,
      'oshi' => _stats.artistPlays.values.fold<int>(0, (a, b) => b > a ? b : a),
      'tabibito' => _stats.newArtistsSince(now.subtract(const Duration(days: 7))),
      'ame' => _stats.rainSeconds ~/ 3600,
      'yoru' => _stats.nightPlays,
      'ren' => _stats.guessStreak,
      _ => 0,
    };
    return (current.clamp(0, goal), goal);
  }

  // ── Weekly challenges ──

  /// This week's three challenges.
  List<WeeklyChallenge> get weeklyChallenges =>
      WeeklyChallenge.forWeek(WeeklyChallenge.weekOf(_clock()));

  /// How far [c] is this week (capped at its target).
  int weeklyProgress(WeeklyChallenge c) {
    _ensureWeek(_clock());
    final w = _stats;
    final value = switch (c.kind) {
      ChallengeKind.newArtists =>
        w.newArtistsSince(WeeklyChallenge.mondayOf(w.week)),
      ChallengeKind.minutes => (w.wk['sec'] ?? 0) ~/ 60,
      ChallengeKind.plays => w.wk['plays'] ?? 0,
      ChallengeKind.days => w.wkDays.length,
      ChallengeKind.night => w.wk['night'] ?? 0,
      ChallengeKind.morning => w.wk['morning'] ?? 0,
      ChallengeKind.rain => (w.wk['rain'] ?? 0) ~/ 60,
      ChallengeKind.album => w.wkAlbums.length,
      ChallengeKind.guess => w.wk['guess'] ?? 0,
      ChallengeKind.oneArtist =>
        w.wkArtists.values.fold<int>(0, (a, b) => b > a ? b : a),
    };
    return value.clamp(0, c.target);
  }

  bool weeklyDone(WeeklyChallenge c) => weeklyProgress(c) >= c.target;

  int get weeklyDoneCount => weeklyChallenges.where(weeklyDone).length;

  /// The mask this week's challenges give: the one already won this week,
  /// or the next weekly mask not collected yet. Null when all are.
  OniMask? get weeklyReward {
    _ensureWeek(_clock());
    final won = MaskCatalog.byId(_stats.wkRewardId);
    if (won != null) return won;
    final masks = MaskCatalog.weekly;
    if (masks.isEmpty) return null;
    final start = _stats.week % masks.length;
    for (var i = 0; i < masks.length; i++) {
      final m = masks[(start + i) % masks.length];
      if (!isUnlocked(m.id)) return m;
    }
    return null;
  }

  /// Whether this week's reward has been won.
  bool get weeklyRewardWon {
    _ensureWeek(_clock());
    return _stats.wkRewardId != null;
  }

  /// Time until the challenges change (next Monday, local midnight).
  Duration get weekTimeLeft {
    final now = _clock();
    final monday = WeeklyChallenge.mondayOf(WeeklyChallenge.weekOf(now) + 1);
    return DateTime(monday.year, monday.month, monday.day).difference(now);
  }

  /// A new week starts the counters over.
  void _ensureWeek(DateTime now) {
    final week = WeeklyChallenge.weekOf(now);
    if (_stats.week == week) return;
    _stats.week = week;
    _stats.wk = {};
    _stats.wkDays = {};
    _stats.wkArtists = {};
    _stats.wkAlbums = {};
    _stats.wkRewardId = null;
  }

  void _countWeekly(String key, [int by = 1]) {
    _ensureWeek(_clock());
    _stats.wk[key] = (_stats.wk[key] ?? 0) + by;
  }

  /// Hands out the week's mask once its three challenges are done.
  void _checkWeekly() {
    if (_stats.wkRewardId != null) return;
    if (!weeklyChallenges.every(weeklyDone)) return;
    final reward = weeklyReward;
    if (reward == null) return;
    _stats.wkRewardId = reward.id;
    unlock(reward.id);
  }

  /// Fraction 0..1 for the rain goal, which counts seconds.
  double get rainFraction => (_stats.rainSeconds / rainGoalSeconds).clamp(0.0, 1.0);

  // ── Persistence ──

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_unlockedKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((id, ms) {
          if (MaskCatalog.byId(id) != null) {
            _unlocked[id] = DateTime.fromMillisecondsSinceEpoch(ms as int);
          }
        });
      }
      _equipped = prefs.getString(_equippedKey);
      _stats = _Stats.decode(prefs.getString(_statsKey));
    } catch (e) {
      debugPrint('[Masks] load error: $e');
    }
    _loaded = true;
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
    if (_uid != null) unawaited(_syncFromCloud());
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unlockedKey,
          jsonEncode(_unlocked.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch))));
      if (_equipped != null) {
        await prefs.setString(_equippedKey, _equipped!);
      } else {
        await prefs.remove(_equippedKey);
      }
      await prefs.setString(_statsKey, _stats.encode());
    } catch (e) {
      debugPrint('[Masks] save error: $e');
    }
  }

  DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _uid;
    final firebase = FirebaseService();
    if (uid == null || uid.startsWith('guest_') || !firebase.isInitialized || !firebase.isSignedIn) {
      return null;
    }
    return firebase.db.collection('users').doc(uid);
  }

  /// Called when the signed-in account changes. Merges the cloud collection
  /// with this device's, keeping the earliest unlock date of each mask.
  void setUser(String? uid) {
    if (uid == _uid) return;
    final signedOut = _uid != null && uid == null;
    _uid = uid;
    if (signedOut) {
      // The account's masks live in its cloud doc and come back on its next
      // login. Kept here, the next account to sign in would upload them as
      // its own. Waits for the local load so it can't refill them after.
      unawaited(_ready.future.then((_) async {
        if (_uid != null) return; // signed back in meanwhile
        _unlocked.clear();
        _equipped = null;
        _celebrations.clear();
        notifyListeners();
        await _saveLocal();
      }));
    }
    if (_loaded && uid != null) unawaited(_syncFromCloud());
  }

  Future<void> _syncFromCloud() async {
    final doc = _userDoc();
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final masks = snap.data()?['masks'];
      var changed = false;
      if (masks is Map) {
        final cloud = masks['unlocked'];
        if (cloud is Map) {
          cloud.forEach((id, ms) {
            if (MaskCatalog.byId(id as String) == null || ms is! int) return;
            final t = DateTime.fromMillisecondsSinceEpoch(ms);
            final local = _unlocked[id];
            if (local == null || t.isBefore(local)) {
              _unlocked[id] = t;
              changed = true;
            }
          });
        }
        final eq = masks['equipped'];
        if (eq is String && MaskCatalog.byId(eq) != null && eq != _equipped) {
          _equipped = eq;
          changed = true;
        }
      }
      final cloudIds = masks is Map && masks['unlocked'] is Map
          ? (masks['unlocked'] as Map).keys.toSet()
          : <dynamic>{};
      final missing = _unlocked.keys.where((id) => !cloudIds.contains(id)).toList();
      if (missing.isNotEmpty || (_equipped != null && masks is! Map)) {
        await doc.set({
          'masks': {
            'unlocked': {for (final id in missing) id: _unlocked[id]!.millisecondsSinceEpoch},
            if (_equipped != null) 'equipped': _equipped,
          },
        }, SetOptions(merge: true));
      }
      if (changed) {
        await _saveLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Masks] cloud sync error: $e');
    }
  }

  Future<void> _writeCloud(Map<String, dynamic> masks) async {
    final doc = _userDoc();
    if (doc == null) return;
    try {
      await doc.set({'masks': masks}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Masks] cloud write error: $e');
    }
  }

  // ── Unlocking ──

  void unlock(String id) {
    if (_unlocked.containsKey(id) || MaskCatalog.byId(id) == null) return;
    final at = _clock();
    final newly = [id];
    // The legendary one asks for the achievement masks, not the weekly ones.
    final allOthers = MaskCatalog.all.where((m) => m.id != 'oni' && !m.weekly);
    _unlocked[id] = at;
    if (id != 'oni' &&
        !MaskCatalog.byId(id)!.weekly &&
        !_unlocked.containsKey('oni') &&
        allOthers.every((m) => _unlocked.containsKey(m.id))) {
      _unlocked['oni'] = at;
      newly.add('oni');
    }
    _celebrations.addAll(newly);
    _equipped ??= id;
    notifyListeners();
    unawaited(_saveLocal());
    unawaited(_writeCloud({
      'unlocked': {for (final m in newly) m: at.millisecondsSinceEpoch},
      'equipped': _equipped,
    }));
  }

  void equip(String id) {
    if (!_unlocked.containsKey(id) || _equipped == id) return;
    _equipped = id;
    notifyListeners();
    unawaited(_saveLocal());
    unawaited(_writeCloud({'equipped': id}));
  }

  void unequip() {
    if (_equipped == null) return;
    _equipped = null;
    notifyListeners();
    unawaited(_saveLocal());
    unawaited(_writeCloud({'equipped': null}));
  }

  void dismissCelebration() {
    if (_celebrations.isEmpty) return;
    _celebrations.removeAt(0);
    notifyListeners();
  }

  // ── Signals from the app ──

  /// A play that really counted (30 s or half the track).
  void onPlayCounted(Track track) {
    final now = _clock();
    _stats.plays++;
    if (now.hour < 5) _stats.nightPlays++;
    final artist = _artistKey(track);
    if (artist.isNotEmpty) {
      _stats.artistPlays[artist] = (_stats.artistPlays[artist] ?? 0) + 1;
      _stats.artistFirst.putIfAbsent(artist, () => _epochDay(now));
    }
    final today = _dayKey(now);
    if (_stats.dayKey != today) {
      _stats.dayKey = today;
      _stats.dayCounts.clear();
    }
    final todayCount = (_stats.dayCounts[track.id] ?? 0) + 1;
    _stats.dayCounts[track.id] = todayCount;
    _stats.trimMaps();

    _countWeekly('plays');
    _stats.wkDays.add(_epochDay(now));
    if (now.hour < 5) _countWeekly('night');
    if (now.hour >= 5 && now.hour < 9) _countWeekly('morning');
    if (artist.isNotEmpty) {
      _stats.wkArtists[artist] = (_stats.wkArtists[artist] ?? 0) + 1;
    }

    unlock('hajime');
    if (_stats.plays >= 250) unlock('hyaku');
    if (_stats.plays >= 2500) unlock('sen');
    if (_stats.nightPlays >= 50) unlock('yoru');
    if ((_stats.artistPlays[artist] ?? 0) >= 100) unlock('oshi');
    if (_stats.newArtistsSince(now.subtract(const Duration(days: 7))) >= 20) unlock('tabibito');
    if (todayCount >= 15) unlock('shuchaku');
    if (MoonCalculator.snapshot(now).isFullMoonWindow) unlock('mangetsu');
    _checkMoments(now);
    _checkWeekly();
    notifyListeners();
    unawaited(_saveLocal());
  }

  void onTrackStarted(Track track) {
    final continued = _lastStartedId != null &&
        _lastCompletedId == _lastStartedId &&
        track.albumId.isNotEmpty &&
        track.albumId == _runAlbum;
    if (!continued) {
      _runAlbum = track.albumId;
      _runTracks.clear();
    }
    _lastStartedId = track.id;
    _lastCompletedId = null;
    _checkMoments(_clock());
  }

  /// The track played to its end (or crossfaded into the next), not skipped.
  void onTrackCompleted(Track track) {
    if (track.id != _lastStartedId) return;
    _lastCompletedId = track.id;
    if (track.albumId.isEmpty || track.albumId != _runAlbum) return;
    _runTracks.add(track.id);
    if (_runTracks.length == 5) {
      _ensureWeek(_clock());
      if (_stats.wkAlbums.add(track.albumId)) {
        _checkWeekly();
        notifyListeners();
        unawaited(_saveLocal());
      }
    }
    if (_runTracks.length >= 5 && !isUnlocked('kanpeki')) {
      unawaited(_checkAlbumRun(track.albumId, _runTracks.length));
    }
  }

  Future<void> _checkAlbumRun(String albumId, int completed) async {
    try {
      final album = await _albumLookup(albumId);
      if (album == null || album.recordType != 'album' || album.tracksCount < 5) return;
      if (completed >= album.tracksCount) unlock('kanpeki');
    } catch (_) {}
  }

  void onDailyGuessFinished({required bool won, required int attempts, required int streak}) {
    _stats.guessStreak = streak;
    if (won && attempts == 1) unlock('mimi');
    if (streak >= 14) unlock('ren');
    if (won) _countWeekly('guess');
    _checkWeekly();
    notifyListeners();
    unawaited(_saveLocal());
  }

  void onEclipseSeen() => unlock('chizuki');

  /// Driven by a 30 s timer: rain time and time-of-day secrets.
  @visibleForTesting
  void tick(Duration elapsed) {
    if (!_loaded) return;
    final rain = isRainPlaying?.call() ?? false;
    final music = isMusicPlaying?.call() ?? false;
    if (rain) {
      _stats.rainSeconds += elapsed.inSeconds;
      if (_stats.rainSeconds >= rainGoalSeconds) unlock('ame');
      _countWeekly('rain', elapsed.inSeconds);
    }
    if (music) {
      _checkMoments(_clock());
      _countWeekly('sec', elapsed.inSeconds);
    }
    if (rain || music) {
      _checkWeekly();
      unawaited(_saveLocal());
    }
  }

  void _checkMoments(DateTime now) {
    if (now.hour == 3 && now.minute == 33) unlock('sanji');
    final halloween = (now.month == 10 && now.day == 31 && now.hour >= 18) ||
        (now.month == 11 && now.day == 1 && now.hour < 5);
    if (halloween) unlock('hannya');
  }

  /// Seeds known artists so the "new artists" goal only counts real
  /// discoveries, not every artist the user already listened to before.
  void seedKnownArtists(Iterable<String> artistNames) {
    if (!_loaded || _stats.seeded) return;
    for (final name in artistNames) {
      final key = ArtistNames.primary(name).toLowerCase();
      if (key.isEmpty) continue;
      _stats.artistFirst.putIfAbsent(key, () => 0);
    }
    _stats.seeded = true;
    unawaited(_saveLocal());
  }

  bool get artistsSeeded => !_loaded || _stats.seeded;

  static String _artistKey(Track t) => ArtistNames.primary(t.artistName).toLowerCase();
  static int _epochDay(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;
  static String _dayKey(DateTime t) => '${t.year}-${t.month}-${t.day}';

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class _Stats {
  int plays = 0;
  int nightPlays = 0;
  int rainSeconds = 0;
  int guessStreak = 0;
  bool seeded = false;
  Map<String, int> artistPlays = {};
  /// Artist → epoch day first heard (0 = known before tracking started).
  Map<String, int> artistFirst = {};
  String dayKey = '';
  Map<String, int> dayCounts = {};

  // This week's challenge counters (reset each Monday).
  int week = -1;
  Map<String, int> wk = {};
  Set<int> wkDays = {};
  Map<String, int> wkArtists = {};
  Set<String> wkAlbums = {};
  String? wkRewardId;

  int newArtistsSince(DateTime from) {
    final day = DateTime.utc(from.year, from.month, from.day).millisecondsSinceEpoch ~/ 86400000;
    return artistFirst.values.where((d) => d > 0 && d >= day).length;
  }

  void trimMaps() {
    if (artistPlays.length > 3000) {
      final keep = (artistPlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(2000);
      artistPlays = Map.fromEntries(keep);
    }
  }

  String encode() => jsonEncode({
        'plays': plays,
        'night': nightPlays,
        'rain': rainSeconds,
        'streak': guessStreak,
        'seeded': seeded,
        'artistPlays': artistPlays,
        'artistFirst': artistFirst,
        'dayKey': dayKey,
        'dayCounts': dayCounts,
        'week': week,
        'wk': wk,
        'wkDays': wkDays.toList(),
        'wkArtists': wkArtists,
        'wkAlbums': wkAlbums.toList(),
        'wkReward': wkRewardId,
      });

  static _Stats decode(String? raw) {
    final s = _Stats();
    if (raw == null) return s;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      s.plays = m['plays'] ?? 0;
      s.nightPlays = m['night'] ?? 0;
      s.rainSeconds = m['rain'] ?? 0;
      s.guessStreak = m['streak'] ?? 0;
      s.seeded = m['seeded'] == true;
      s.artistPlays = Map<String, int>.from(m['artistPlays'] ?? {});
      s.artistFirst = Map<String, int>.from(m['artistFirst'] ?? {});
      s.dayKey = m['dayKey'] ?? '';
      s.dayCounts = Map<String, int>.from(m['dayCounts'] ?? {});
      s.week = m['week'] ?? -1;
      s.wk = Map<String, int>.from(m['wk'] ?? {});
      s.wkDays = {for (final d in (m['wkDays'] as List? ?? const [])) d as int};
      s.wkArtists = Map<String, int>.from(m['wkArtists'] ?? {});
      s.wkAlbums = {for (final a in (m['wkAlbums'] as List? ?? const [])) '$a'};
      s.wkRewardId = m['wkReward'] as String?;
    } catch (_) {}
    return s;
  }
}
