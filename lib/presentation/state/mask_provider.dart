import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/firebase_service.dart';
import '../../data/datasources/weather_service.dart';
import '../../data/datasources/wrapped_service.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/play_day.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/weekly_challenge.dart';
import '../../domain/logic/artist_names.dart';
import '../../domain/logic/moon_calculator.dart';
import '../../domain/logic/music_styles.dart';

export '../../domain/entities/oni_mask.dart';
export '../../domain/entities/weekly_challenge.dart';

final _log = Log.named('Masks');

/// Achievement engine for the Oni mask collection.
///
/// Unlocked masks and the equipped one live in the user's Firestore document
/// (one small write per unlock or equip). Progress counters change on every
/// play, so they're kept on the device and backed up to the account at most
/// every [progressUploadEvery] (masks.progress); another phone takes the
/// higher of each. Plays made before the masks existed, or on a phone that
/// never backed up, are caught up once from the play log
/// ([catchUpFromHistory]).
class MaskProvider extends ChangeNotifier {
  static const _unlockedKey = 'masks_unlocked_v1';
  static const _equippedKey = 'masks_equipped_v1';
  static const _statsKey = 'masks_stats_v1';
  static const int rainGoalSeconds = 10 * 3600;

  /// How often the progress counters are backed up, at most.
  static const progressUploadEvery = Duration(hours: 6);

  /// Artists kept in the backup (the "devotion" goal needs only the top).
  static const int backedUpArtists = 30;

  /// Secret masks show a riddle once this many masks are unlocked.
  static const int secretHintsAfter = 5;

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

  /// The ambient sounds playing now, by name ('fire', 'waves'...).
  Set<String> Function()? ambientOn;

  /// A song's music style (looked up once per artist), its tempo when
  /// known, and the weather where the user is (null when it's off).
  Future<StyleInfo> Function(Track track)? styleOf;
  double? Function(String trackId)? bpmOf;
  WeatherNow? Function()? weatherNow;

  /// Songs this fast count as "fast" (Llama de Cobre).
  static const double fastBpm = 150;

  /// Deezer's rank (0 to about 1,000,000): hits above, hidden gems below.
  static const int hitRank = 750000;
  static const int hiddenRank = 150000;

  /// Plays of each of the 12 main styles the rainbow mask asks for.
  static const int perStyleForRainbow = 10;

  /// The account's play log for the last year. Set by the app's wiring.
  Future<List<PlayDay>> Function()? historyLoader;
  String? _historyTriedFor;
  DateTime? _historyTriedAt;

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

  /// Whether locked secret masks show their riddle.
  bool get secretHintsShown => _unlocked.length >= secretHintsAfter;

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
      _ => mask.counter == null ? 0 : counterValue(mask.counter!),
    };
    return (current.clamp(0, goal), goal);
  }

  /// What a mask's [OniMask.counter] has reached, in its goal's units.
  int counterValue(String key) {
    final c = _stats.c;
    if (key.startsWith('style:')) return _stats.styles[key.substring(6)] ?? 0;
    // Ambient time is kept in seconds, goals are in hours.
    if (key.startsWith('amb:')) return (c[key] ?? 0) ~/ 3600;
    return switch (key) {
      'styles12' => MusicStyles.main
          .where((s) => (_stats.styles[s.name] ?? 0) >= perStyleForRainbow)
          .length,
      'artistMax' => _stats.artistPlays.values.fold<int>(0, (a, b) => b > a ? b : a),
      'masks' => _unlocked.length,
      // The gods: the divine masks, and the ultra ones that are not.
      'divine' => MaskCatalog.all.where((m) => m.divine && _unlocked.containsKey(m.id)).length,
      'ultra' => MaskCatalog.all
          .where((m) => m.rarity == MaskRarity.ul && !m.divine && _unlocked.containsKey(m.id))
          .length,
      'night' => _stats.nightPlays,
      _ => c[key] ?? 0,
    };
  }

  /// Unlocks the masks whose counted goals the counters reach.
  void _checkCounterMasks() {
    for (final m in MaskCatalog.all) {
      final key = m.counter;
      final goal = m.goal;
      if (key == null || goal == null || _unlocked.containsKey(m.id)) continue;
      if (counterValue(key) >= goal) unlock(m.id);
    }
  }

  void _bump(String key, [int by = 1]) {
    _stats.c[key] = (_stats.c[key] ?? 0) + by;
    _stats.progressDirty = true;
  }

  /// Counts [id] under [key] once ever (distinct songs, nights, albums...).
  void _bumpDistinct(String key, String id) {
    final seen = _stats.seen.putIfAbsent(key, () => <String>{});
    if (!seen.add(id)) return;
    // Only recent ids are kept: enough to not count one twice in a row.
    if (seen.length > 120) seen.remove(seen.first);
    _bump(key);
  }

  // ── Weekly challenges ──

  /// This week's three challenges. The last one follows the week's theme:
  /// songs of the style the SR prize is about.
  List<WeeklyChallenge> get weeklyChallenges {
    final base = WeeklyChallenge.forWeek(WeeklyChallenge.weekOf(_clock()));
    final theme = weeklyTheme;
    if (theme == null) return base;
    return [...base.take(2), WeeklyChallenge.ofStyle(theme)];
  }

  /// The style this week is about, from its prizes (null when none has one).
  MusicStyle? get weeklyTheme {
    for (final prize in [weeklyRewardFor(MaskRarity.sr), weeklyRewardFor(MaskRarity.r)]) {
      final theme = MaskCatalog.weeklyThemes[prize?.id];
      if (theme != null) return theme;
    }
    return null;
  }

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
      ChallengeKind.style => w.wk['style:${c.style?.name}'] ?? 0,
    };
    return value.clamp(0, c.target);
  }

  bool weeklyDone(WeeklyChallenge c) => weeklyProgress(c) >= c.target;

  int get weeklyDoneCount => weeklyChallenges.where(weeklyDone).length;

  /// Two challenges done give an R, all three an SR: the week's prize of
  /// each, the one already won this week or the next weekly mask of that
  /// rarity not collected yet. Null when all are.
  OniMask? weeklyRewardFor(MaskRarity rarity) {
    _ensureWeek(_clock());
    final won = MaskCatalog.byId(_stats.wkRewards[rarity.name]);
    if (won != null) return won;
    final masks = [for (final m in MaskCatalog.weekly) if (m.rarity == rarity) m];
    if (masks.isEmpty) return null;
    final start = _stats.week % masks.length;
    for (var i = 0; i < masks.length; i++) {
      final m = masks[(start + i) % masks.length];
      if (!isUnlocked(m.id)) return m;
    }
    return null;
  }

  /// Whether this week's prize of [rarity] has been won.
  bool weeklyRewardWonFor(MaskRarity rarity) {
    _ensureWeek(_clock());
    return _stats.wkRewards.containsKey(rarity.name);
  }

  /// Challenges done this week that each prize needs.
  static const weeklyNeeds = {MaskRarity.r: 2, MaskRarity.sr: 3};

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
    _stats.wkRewards = {};
  }

  void _countWeekly(String key, [int by = 1]) {
    _ensureWeek(_clock());
    _stats.wk[key] = (_stats.wk[key] ?? 0) + by;
  }

  /// Hands out the week's prizes as their challenges get done.
  void _checkWeekly() {
    final done = weeklyDoneCount;
    for (final entry in weeklyNeeds.entries) {
      if (done < entry.value || weeklyRewardWonFor(entry.key)) continue;
      final reward = weeklyRewardFor(entry.key);
      if (reward == null) continue;
      _stats.wkRewards[entry.key.name] = reward.id;
      unlock(reward.id);
    }
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
      _log.severe('load error: $e');
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
      _log.severe('save error: $e');
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
        // Progress is the account's too (it's backed up to it): the next
        // account must not start from this one's counts.
        _stats = _Stats();
        _historyTriedFor = null;
        _historyTriedAt = null;
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
      if (masks is Map && masks['progress'] is Map) {
        if (applyProgress(Map<String, dynamic>.from(masks['progress'] as Map))) changed = true;
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
      unawaited(_maybeUploadProgress());
    } catch (e) {
      _log.severe('cloud sync error: $e');
    }
  }

  // ── Progress backup ──

  /// The counters as backed up to the account.
  @visibleForTesting
  Map<String, dynamic> progressSnapshot() {
    final top = (_stats.artistPlays.entries
            .where((e) => e.key.isNotEmpty && !e.key.startsWith('__'))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(backedUpArtists);
    return {
      'plays': _stats.plays,
      'night': _stats.nightPlays,
      'rain': _stats.rainSeconds,
      'artists': {
        for (final e in top) (e.key.length > 100 ? e.key.substring(0, 100) : e.key): e.value,
      },
      'styles': Map<String, int>.of(_stats.styles),
      'c': Map<String, int>.of(_stats.c),
    };
  }

  /// Takes the higher of each counter from a backup ([progressSnapshot]
  /// format) and unlocks what the counts now reach. Whether anything rose.
  @visibleForTesting
  bool applyProgress(Map<String, dynamic> cloud) {
    int read(String k) => cloud[k] is num ? (cloud[k] as num).toInt() : 0;
    var rose = false;
    int higher(int local, int other) {
      if (other > local) {
        rose = true;
        return other;
      }
      return local;
    }

    _stats.plays = higher(_stats.plays, read('plays'));
    _stats.nightPlays = higher(_stats.nightPlays, read('night'));
    _stats.rainSeconds = higher(_stats.rainSeconds, read('rain'));
    void mergeInto(Map<String, int> local, Object? other) {
      if (other is! Map) return;
      other.forEach((k, v) {
        if (v is! num) return;
        final key = '$k';
        local[key] = higher(local[key] ?? 0, v.toInt());
      });
    }

    mergeInto(_stats.artistPlays, cloud['artists']);
    mergeInto(_stats.styles, cloud['styles']);
    mergeInto(_stats.c, cloud['c']);
    // This phone had more: the backup is behind.
    if (_stats.plays > read('plays') || _stats.nightPlays > read('night') || _stats.rainSeconds > read('rain')) {
      _stats.progressDirty = true;
    }
    if (rose) {
      _checkCounters();
      _checkCounterMasks();
    }
    return rose;
  }

  /// Counts plays, late-night plays and plays per artist in [days] (the
  /// play log) and takes the higher of each, like [applyProgress].
  @visibleForTesting
  bool applyHistory(List<PlayDay> days) {
    var plays = 0, night = 0;
    final artists = <String, int>{};
    for (final d in days) {
      plays += d.totalPlays;
      for (var h = 0; h < 5; h++) {
        night += d.hours[h] ?? 0;
      }
      d.plays.forEach((id, n) {
        final name = d.tracks[id]?.artistName ?? '';
        final key = ArtistNames.primary(name).toLowerCase();
        if (key.isNotEmpty) artists[key] = (artists[key] ?? 0) + n;
      });
    }
    final dates = [for (final d in days) if (d.totalPlays > 0) d.date];
    final (best, _) = WrappedService.longestStreak(dates);
    final rose = applyProgress({
      'plays': plays,
      'night': night,
      'artists': artists,
      'c': {'streak': best},
    });
    // The streak goes on from the last day in the log.
    final days0 = [for (final d in dates) if (DateTime.tryParse(d) case final t?) _epochDay(t)]..sort();
    if (days0.isNotEmpty && days0.last > _stats.lastDay) {
      var run = 1;
      for (var i = days0.length - 1; i > 0 && days0[i] - days0[i - 1] == 1; i--) {
        run++;
      }
      _stats.lastDay = days0.last;
      _stats.streak = run;
    }
    if (rose) _stats.progressDirty = true;
    return rose;
  }

  /// Once per account on this phone: counts what the play log holds that
  /// this phone's counters don't (plays from before the masks existed, or
  /// from another phone). An empty log (a new account, or one not ready
  /// yet right after signing in) is read again after 10 minutes at most,
  /// not on every song.
  Future<void> catchUpFromHistory() async {
    final uid = _uid;
    final load = historyLoader;
    if (!_loaded || uid == null || load == null || _stats.historyApplied) return;
    final now = _clock();
    final last = _historyTriedAt;
    if (_historyTriedFor == uid && last != null && now.difference(last) < const Duration(minutes: 10)) return;
    _historyTriedFor = uid;
    _historyTriedAt = now;
    try {
      final days = await load();
      if (_uid != uid || days.isEmpty) return;
      applyHistory(days);
      _stats.historyApplied = true;
      notifyListeners();
      await _saveLocal();
      unawaited(_maybeUploadProgress());
    } catch (e) {
      _log.warning('history catch-up failed: $e');
    }
  }

  Future<void> _maybeUploadProgress() async {
    if (!_stats.progressDirty) return;
    final now = _clock().millisecondsSinceEpoch;
    if (now - _stats.progressUploadedAt < progressUploadEvery.inMilliseconds) return;
    final doc = _userDoc();
    if (doc == null) return;
    _stats.progressUploadedAt = now;
    _stats.progressDirty = false;
    try {
      // Replaces the whole progress map: merging would keep artists that
      // fell out of the top.
      await doc.set({
        'masks': {'progress': progressSnapshot()},
      }, SetOptions(mergeFields: [FieldPath(const ['masks', 'progress'])]));
    } catch (e) {
      _stats.progressDirty = true;
      _log.severe('progress backup error: $e');
    }
    unawaited(_saveLocal());
  }

  /// Unlocks the masks whose counted goals the counters reach.
  void _checkCounters() {
    if (_stats.plays >= 1) unlock('hajime');
    if (_stats.plays >= 250) unlock('hyaku');
    if (_stats.plays >= 2500) unlock('sen');
    if (_stats.nightPlays >= 50) unlock('yoru');
    if (_stats.rainSeconds >= rainGoalSeconds) unlock('ame');
    if (_stats.artistPlays.values.any((n) => n >= 100)) unlock('oshi');
  }

  Future<void> _writeCloud(Map<String, dynamic> masks) async {
    final doc = _userDoc();
    if (doc == null) return;
    try {
      await doc.set({'masks': masks}, SetOptions(merge: true));
    } catch (e) {
      _log.severe('cloud write error: $e');
    }
  }

  // ── Unlocking ──

  void unlock(String id) {
    if (_unlocked.containsKey(id) || MaskCatalog.byId(id) == null) return;
    final at = _clock();
    final newly = [id];
    _unlocked[id] = at;
    // El Oni asks for the original achievement masks.
    if (id != 'oni' &&
        !_unlocked.containsKey('oni') &&
        MaskCatalog.oniSet.every((m) => _unlocked.containsKey(m.id))) {
      _unlocked['oni'] = at;
      newly.add('oni');
    }
    // The collectors' masks (Rey Oni at 50, Rey Kitsune at 75, the gods)
    // come with the mask that completes their set.
    for (var changed = true; changed;) {
      changed = false;
      for (final m in MaskCatalog.all) {
        if (!_collectors.contains(m.counter) || _unlocked.containsKey(m.id)) continue;
        if (counterValue(m.counter!) >= m.goal!) {
          _unlocked[m.id] = at;
          newly.add(m.id);
          changed = true;
        }
      }
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
    if (MoonCalculator.snapshot(now).isFullMoonWindow) {
      unlock('mangetsu');
      _bumpDistinct('moons', '${lunationOf(now)}');
      // Kitsunebi: late night under the full moon.
      if (now.hour < 5) _bump('moonNight');
    }
    _countDay(now);
    _countSong(track);
    _checkWeather();
    _checkMoments(now);
    _checkCounterMasks();
    _checkWeekly();
    _stats.progressDirty = true;
    notifyListeners();
    unawaited(_saveLocal());
    unawaited(_maybeUploadProgress());
    _lookUpStyle(track);
  }

  /// Days in a row with music, and coming back after a long time away.
  void _countDay(DateTime now) {
    final day = _epochDay(now);
    final last = _stats.lastDay;
    if (day == last) return;
    if (last > 0 && day - last >= comebackDays) {
      _bump('comebacks');
      unlock('jiki');
    }
    _stats.streak = last > 0 && day - last == 1 ? _stats.streak + 1 : 1;
    _stats.lastDay = day;
    if (_stats.streak > (_stats.c['streak'] ?? 0)) _stats.c['streak'] = _stats.streak;
  }

  /// Counters that are collections of masks: checked on every unlock.
  static const _collectors = {'masks', 'divine', 'ultra'};

  /// Away this many days, then back: Porcelana.
  static const int comebackDays = 14;

  /// What the song itself is: fast, a hit or a hidden gem, explicit.
  void _countSong(Track track) {
    final bpm = bpmOf?.call(track.id);
    if (bpm != null && bpm >= fastBpm) _bump('fast');
    final rank = track.rank;
    if (rank != null && rank > 0) {
      if (rank >= hitRank) _bump('hits');
      if (rank <= hiddenRank) _bump('hidden');
    }
    if (track.isExplicit) _bump('explicit');
  }

  void _checkWeather() {
    final w = weatherNow?.call();
    if (w == null) return;
    if (w.temperature <= 5) unlock('tsurara');
    if (w.sky == Sky.storm) unlock('inazuma');
  }

  /// The style arrives later (looked up once per artist), and counts then.
  void _lookUpStyle(Track track) {
    final lookup = styleOf;
    if (lookup == null) return;
    unawaited(lookup(track).then(onStyle).catchError((Object e) {
      _log.fine('style lookup failed: $e');
    }));
  }

  /// A counted song's style, once known.
  @visibleForTesting
  void onStyle(StyleInfo info) {
    if (info.isEmpty) return;
    for (final s in info.styles) {
      _stats.styles[s.name] = (_stats.styles[s.name] ?? 0) + 1;
      _countWeekly('style:${s.name}');
    }
    for (final country in info.countries) {
      _bumpDistinct('countries', country);
    }
    _stats.progressDirty = true;
    _checkCounterMasks();
    _checkWeekly();
    notifyListeners();
    unawaited(_saveLocal());
  }

  /// Full moons are told apart by lunation: synodic months since a known
  /// new moon (6 January 2000, 18:14 UTC).
  static int lunationOf(DateTime t) {
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    return (t.toUtc().difference(ref).inMinutes / (29.530588 * 24 * 60)).floor();
  }

  /// The full-screen lyrics showed [trackId]'s synced lyrics.
  void onLyricsShown(String trackId) {
    _bumpDistinct('lyrics', trackId);
    _checkCounterMasks();
    notifyListeners();
    unawaited(_saveLocal());
  }

  /// A running session ended after [elapsed]. Short tries don't count.
  void onRunFinished(Duration elapsed) {
    if (elapsed < const Duration(minutes: 5)) return;
    _bump('runs');
    _checkCounterMasks();
    notifyListeners();
    unawaited(_saveLocal());
  }

  /// The sleep timer stopped the music: one night (counted once a day).
  void onSleepTimerFinished() {
    _bumpDistinct('sleep', '${_epochDay(_clock())}');
    _checkCounterMasks();
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
    if (_runTracks.length >= 5) {
      unawaited(_checkAlbumRun(track.albumId, _runTracks.length));
    }
  }

  Future<void> _checkAlbumRun(String albumId, int completed) async {
    try {
      final album = await _albumLookup(albumId);
      if (album == null || album.recordType != 'album' || album.tracksCount < 5) return;
      if (completed >= album.tracksCount) {
        unlock('kanpeki');
        _bumpDistinct('albums', albumId);
        _checkCounterMasks();
        notifyListeners();
        unawaited(_saveLocal());
      }
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
      _stats.progressDirty = true;
      if (_stats.rainSeconds >= rainGoalSeconds) unlock('ame');
      _countWeekly('rain', elapsed.inSeconds);
    }
    if (music) {
      _checkMoments(_clock());
      _countWeekly('sec', elapsed.inSeconds);
    }
    final sounds = ambientOn?.call() ?? const <String>{};
    for (final sound in sounds) {
      _bump('amb:$sound', elapsed.inSeconds);
    }
    _countMarathon(music, elapsed);
    if (sounds.isNotEmpty || music) _checkCounterMasks();
    if (rain || music || sounds.isNotEmpty) {
      _checkWeekly();
      unawaited(_saveLocal());
      unawaited(_maybeUploadProgress());
    }
  }

  /// Music in a row: pauses up to [marathonBreak] don't end the session.
  void _countMarathon(bool music, Duration elapsed) {
    if (music) {
      _stats.sessionSec += elapsed.inSeconds;
      _stats.idleSec = 0;
      final minutes = _stats.sessionSec ~/ 60;
      if (minutes > (_stats.c['marathon'] ?? 0)) _stats.c['marathon'] = minutes;
    } else if (_stats.sessionSec > 0) {
      _stats.idleSec += elapsed.inSeconds;
      if (_stats.idleSec >= marathonBreak.inSeconds) {
        _stats.sessionSec = 0;
        _stats.idleSec = 0;
      }
    }
  }

  static const marathonBreak = Duration(minutes: 10);

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
  /// This week's prizes won, by rarity name ('r', 'sr').
  Map<String, String> wkRewards = {};

  /// Plays per music style family (MusicStyle.name).
  Map<String, int> styles = {};

  /// Counters behind the masks with their own achievements (OniMask.counter).
  Map<String, int> c = {};

  /// Recent ids already counted under a counter (lyrics, albums, nights...).
  Map<String, Set<String>> seen = {};

  /// Days in a row: the last day with music (epoch day) and the run so far.
  int lastDay = 0;
  int streak = 0;

  /// The music session going on now (marathon), and the pause in it.
  int sessionSec = 0;
  int idleSec = 0;

  // Progress backup (see MaskProvider.progressSnapshot).
  bool historyApplied = false;
  int progressUploadedAt = 0;
  bool progressDirty = false;

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
        'wkRewards': wkRewards,
        'styles': styles,
        'c': c,
        'seen': {for (final e in seen.entries) e.key: e.value.toList()},
        'lastDay': lastDay,
        'dayStreak': streak,
        'session': sessionSec,
        'idle': idleSec,
        'history': historyApplied,
        'uploadedAt': progressUploadedAt,
        'dirty': progressDirty,
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
      s.wkRewards = Map<String, String>.from(m['wkRewards'] ?? {});
      // Before two prizes a week, the one prize was the full-week one.
      if (m['wkReward'] is String && s.wkRewards.isEmpty) {
        final old = MaskCatalog.byId(m['wkReward'] as String);
        if (old != null) s.wkRewards[old.rarity.name] = old.id;
      }
      s.styles = Map<String, int>.from(m['styles'] ?? {});
      s.c = Map<String, int>.from(m['c'] ?? {});
      s.seen = {
        for (final e in (m['seen'] as Map? ?? const {}).entries)
          '${e.key}': {for (final v in (e.value as List? ?? const [])) '$v'},
      };
      s.lastDay = m['lastDay'] ?? 0;
      s.streak = m['dayStreak'] ?? 0;
      s.sessionSec = m['session'] ?? 0;
      s.idleSec = m['idle'] ?? 0;
      s.historyApplied = m['history'] == true;
      s.progressUploadedAt = m['uploadedAt'] is int ? m['uploadedAt'] as int : 0;
      s.progressDirty = m['dirty'] == true;
    } catch (_) {}
    return s;
  }
}
