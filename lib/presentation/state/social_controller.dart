import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/entities/social.dart';
import '../../domain/logic/sintonia.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/social_repository.dart';

final _log = Log.named('Social');

/// What this Bearer's Echo did lately (Resonances), kept on the phone per
/// account and published with the profile, newest first.
class MilestoneLog extends ChangeNotifier {
  MilestoneLog({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  String? _uid;
  List<Milestone> _items = const [];

  List<Milestone> get items => _items;

  static String _key(String uid) => 'tsuki_milestones_$uid';

  /// The signed-in account (null: no one, or an Observer: nothing is kept).
  Future<void> setUser(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    _items = const [];
    notifyListeners();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid));
      if (raw == null || _uid != uid) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _items = [
        for (final m in list)
          if (Milestone.fromMap(m) case final ms?) ms,
      ];
      notifyListeners();
    } catch (e) {
      _log.warning('reading milestones failed: $e');
    }
  }

  /// Notes [m]; the same thing twice in a day counts once.
  void add(Milestone m) {
    final uid = _uid;
    if (uid == null) return;
    final day = DateTime(m.at.year, m.at.month, m.at.day);
    final dup = _items.any((o) =>
        o.kind == m.kind && o.a == m.a && o.b == m.b && DateTime(o.at.year, o.at.month, o.at.day) == day);
    if (dup) return;
    _items = [m, ..._items].take(Milestone.kept).toList();
    notifyListeners();
    unawaited(_save(uid));
  }

  void album(String title, String artist) =>
      add(Milestone(kind: MilestoneKind.album, a: title, b: artist, at: _now()));

  Future<void> _save(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(uid), jsonEncode([for (final m in _items) m.toMap()]));
    } catch (_) {}
  }
}

/// Bonds (Lazos): finding Bearers, the requests and the Bonds, live, their
/// Resonances and the Sintonía with each. Only for a signed-in Bearer:
/// Observers keep nothing.
class SocialController extends ChangeNotifier {
  SocialController({
    required SocialRepository repository,
    required ProfileRepository profiles,
    required Listenable changes,
    required String? Function() uid,
    required SocialPerson? Function() myCard,
    required List<String> Function() myTops,
  })  : _repo = repository,
        _profiles = profiles,
        _changes = changes,
        _uid = uid,
        _myCard = myCard,
        _myTops = myTops {
    _changes.addListener(_onChange);
    _onChange();
  }

  final SocialRepository _repo;
  final ProfileRepository _profiles;
  final Listenable _changes;
  final String? Function() _uid;
  final SocialPerson? Function() _myCard;
  final List<String> Function() _myTops;

  String? _me;
  final List<StreamSubscription> _subs = [];
  List<SocialPerson> _bonds = const [];
  List<SocialPerson> _received = const [];
  List<SocialPerson> _sent = const [];
  final Set<String> _busy = {};

  bool get available => _me != null;
  String? get me => _me;
  List<SocialPerson> get bonds => _bonds;
  List<SocialPerson> get received => _received;
  List<SocialPerson> get sent => _sent;

  /// Requests waiting for my answer: the badge.
  int get pending => _received.length;

  /// Whether an action on [uid] is on its way.
  bool isBusy(String uid) => _busy.contains(uid);

  BondState stateWith(String uid) {
    if (_bonds.any((p) => p.uid == uid)) return BondState.bonded;
    if (_received.any((p) => p.uid == uid)) return BondState.received;
    if (_sent.any((p) => p.uid == uid)) return BondState.sent;
    return BondState.none;
  }

  void _onChange() {
    final uid = _uid();
    if (uid == _me) return;
    _me = uid;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _bonds = _received = _sent = const [];
    _feed = null;
    notifyListeners();
    if (uid == null) return;
    void listen(Stream<List<SocialPerson>> s, void Function(List<SocialPerson>) set) {
      _subs.add(s.listen((v) {
        if (_me != uid) return;
        set(v);
        notifyListeners();
      }, onError: (Object e) => _log.warning('social listener: $e')));
    }

    listen(_repo.watchBonds(uid), (v) {
      final before = _bonds.map((p) => p.uid).toSet();
      _bonds = v;
      // A new Bond: the feed has someone new to hear.
      if (!setEquals(before, v.map((p) => p.uid).toSet())) _feed = null;
    });
    listen(_repo.watchReceived(uid), (v) => _received = v);
    listen(_repo.watchSent(uid), (v) => _sent = v);
  }

  // ── Search ──

  /// Public Bearers by name, without me.
  Future<List<PublicProfile>> search(String query) async {
    final me = _me;
    if (me == null || query.trim().length < 2) return const [];
    try {
      final found = await _repo.search(query);
      return [for (final p in found) if (p.uid != me) p];
    } catch (e) {
      _log.warning('search failed: $e');
      rethrow;
    }
  }

  // ── Requests and Bonds ──

  Future<bool> _run(String uid, Future<void> Function(String me) action) async {
    final me = _me;
    if (me == null || _busy.contains(uid)) return false;
    _busy.add(uid);
    notifyListeners();
    try {
      await action(me);
      return true;
    } catch (e) {
      _log.warning('social action failed: $e');
      return false;
    } finally {
      _busy.remove(uid);
      notifyListeners();
    }
  }

  /// Asks [to] for a Bond. If they had already asked me, it's a Bond now.
  Future<bool> request(SocialPerson to) {
    if (stateWith(to.uid) == BondState.received) return accept(to.uid);
    return _run(to.uid, (me) async {
      final card = _myCard();
      if (card == null) throw StateError('no card');
      await _repo.sendRequest(me: card, to: to);
    });
  }

  Future<bool> cancel(String to) => _run(to, (me) => _repo.cancelRequest(me: me, to: to));
  Future<bool> accept(String from) => _run(from, (me) async {
        final card = _myCard();
        if (card == null) throw StateError('no card');
        await _repo.accept(me: card, from: from);
      });
  Future<bool> decline(String from) => _run(from, (me) => _repo.decline(me: me, from: from));
  Future<bool> unbond(String other) => _run(other, (me) => _repo.unbond(me: me, other: other));

  // ── Resonances ──

  List<Resonance>? _feed;
  DateTime? _feedAt;
  Future<List<Resonance>>? _loading;
  static const _feedFresh = Duration(minutes: 5);

  /// What my Bonds' Echo did lately, newest first: one profile read per
  /// Bond, kept for a few minutes.
  Future<List<Resonance>> resonances({bool refresh = false}) {
    final kept = _feed;
    final at = _feedAt;
    if (!refresh && kept != null && at != null && DateTime.now().difference(at) < _feedFresh) {
      return Future.value(kept);
    }
    return _loading ??= _loadFeed().whenComplete(() => _loading = null);
  }

  Future<List<Resonance>> _loadFeed() async {
    final me = _me;
    final bonds = _bonds;
    final profiles = await Future.wait([
      for (final b in bonds)
        _profiles.getProfile(b.uid).catchError((Object _) => null),
    ]);
    if (_me != me) return const [];
    final feed = <Resonance>[];
    for (var i = 0; i < bonds.length; i++) {
      final p = profiles[i];
      if (p == null) continue;
      final person = SocialPerson(
        uid: p.uid,
        name: p.displayName,
        photoUrl: p.photoUrl ?? bonds[i].photoUrl,
        maskId: p.maskId ?? bonds[i].maskId,
      );
      for (final m in p.milestones) {
        feed.add(Resonance(person: person, milestone: m));
      }
    }
    feed.sort((a, b) => b.milestone.at.compareTo(a.milestone.at));
    _feed = feed;
    _feedAt = DateTime.now();
    return feed;
  }

  // ── Sintonía ──

  Sintonia sintoniaWith(PublicProfile other) => Sintonia.of(_myTops(), other.tops);

  @override
  void dispose() {
    _changes.removeListener(_onChange);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
