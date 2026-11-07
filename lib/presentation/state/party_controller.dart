import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../domain/entities/party.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/party_repository.dart';

final _log = Log.named('Party');

/// What the party needs from the player.
abstract interface class PartyPlayer implements Listenable {
  Track? get current;
  bool get playing;
  Duration get position;
  Future<void> play(Track track);
  Future<void> setPlaying(bool playing);
  Future<void> seek(Duration position);
}

/// Listening together. As host, what my player does is published (on a
/// new song, a pause or a jump, never every second); as a guest, my player
/// follows the host's: the same song, at the same point, playing or not.
class PartyController extends ChangeNotifier {
  PartyController({
    required PartyRepository repository,
    required Listenable changes,
    required String? Function() uid,
    required String Function() myName,
    required PartyPlayer player,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 2),
    this.tolerance = const Duration(seconds: 3),
  })  : _repo = repository,
        _changes = changes,
        _uid = uid,
        _myName = myName,
        _player = player,
        _now = clock ?? DateTime.now {
    _changes.addListener(_onAccount);
    _onAccount();
  }

  final PartyRepository _repo;
  final Listenable _changes;
  final String? Function() _uid;
  final String Function() _myName;
  final PartyPlayer _player;
  final DateTime Function() _now;

  /// How often the host compares the player with what was published.
  final Duration tick;

  /// How far apart a guest may drift before jumping to the host.
  final Duration tolerance;

  String? _me;
  StreamSubscription? _invitesSub;
  StreamSubscription? _partySub;
  Timer? _hostTimer;
  List<Party> _invitations = const [];
  Party? _party;
  String? _joinedHost;
  bool _ended = false;

  // What the host published last, to tell a jump from time passing.
  String? _sentTrack;
  bool _sentPlaying = false;
  Duration _sentPosition = Duration.zero;
  DateTime? _sentAt;

  bool get available => _me != null;
  String? get me => _me;
  List<Party> get invitations => _invitations;

  /// The party I'm in (hosting or as a guest), live.
  Party? get party => _party;
  bool get hosting => _party != null && _party!.host == _me;
  bool get inParty => _party != null;

  /// The party I was in ended (the host closed it).
  bool get ended => _ended;

  void _onAccount() {
    final uid = _uid();
    if (uid == _me) return;
    unawaited(_stop());
    _me = uid;
    unawaited(_invitesSub?.cancel());
    _invitations = const [];
    notifyListeners();
    if (uid == null) return;
    _invitesSub = _repo.watchInvitations(uid).listen((v) {
      _invitations = v;
      notifyListeners();
    }, onError: (Object e) => _log.warning('party invitations: $e'));
  }

  // ── Hosting ──

  /// Opens my party with what I'm playing.
  Future<bool> host() async {
    final me = _me;
    if (me == null) return false;
    try {
      await _stop();
      final t = _player.current;
      await _repo.open(
        me: me,
        myName: _myName(),
        track: t,
        positionMs: _player.position.inMilliseconds,
        playing: _player.playing,
      );
      _remember();
      _follow(me);
      _hostTimer = Timer.periodic(tick, (_) => unawaited(_hostTick()));
      return true;
    } catch (e) {
      _log.warning('opening the party failed: $e');
      return false;
    }
  }

  void _remember() {
    _sentTrack = _player.current?.id;
    _sentPlaying = _player.playing;
    _sentPosition = _player.position;
    _sentAt = _now();
  }

  /// Publishes when the song changed, it paused or resumed, or it jumped.
  Future<void> _hostTick() async {
    final me = _me;
    if (me == null || !hosting) return;
    final t = _player.current;
    final playing = _player.playing;
    final pos = _player.position;
    final since = _sentAt == null ? Duration.zero : _now().difference(_sentAt!);
    final expected = _sentPlaying ? _sentPosition + since : _sentPosition;
    final jumped = (pos - expected).abs() > tolerance;
    if (t?.id == _sentTrack && playing == _sentPlaying && !jumped) return;
    _remember();
    try {
      await _repo.publish(me: me, track: t, positionMs: pos.inMilliseconds, playing: playing);
    } catch (e) {
      _log.warning('publishing the party failed: $e');
    }
  }

  @visibleForTesting
  Future<void> hostTickForTesting() => _hostTick();

  Future<bool> invite(String bond) async {
    final me = _me;
    if (me == null || !hosting) return false;
    try {
      await _repo.invite(me: me, bond: bond);
      return true;
    } catch (e) {
      _log.warning('inviting failed: $e');
      return false;
    }
  }

  // ── As a guest ──

  Future<bool> join(String host) async {
    final me = _me;
    if (me == null) return false;
    try {
      await _stop();
      await _repo.join(host: host, me: me, myName: _myName());
      _joinedHost = host;
      _follow(host);
      return true;
    } catch (e) {
      _log.warning('joining failed: $e');
      return false;
    }
  }

  Future<void> decline(String host) async {
    final me = _me;
    if (me == null) return;
    try {
      await _repo.decline(host: host, me: me);
    } catch (e) {
      _log.warning('declining failed: $e');
    }
  }

  void _follow(String host) {
    _ended = false;
    unawaited(_partySub?.cancel());
    _partySub = _repo.watch(host).listen((p) {
      final wasIn = _party != null;
      _party = p;
      if (p == null && wasIn) {
        _ended = true;
        unawaited(_stop());
      } else if (p != null && p.host != _me) {
        unawaited(_sync(p));
      }
      notifyListeners();
    }, onError: (Object e) => _log.warning('party: $e'));
  }

  /// Brings my player to where the host's is.
  Future<void> _sync(Party p) async {
    final t = p.track;
    if (t == null) return;
    try {
      if (_player.current?.id != t.id) {
        await _player.play(t);
        final target = p.positionAt(_now());
        if (target > tolerance) await _player.seek(target);
      } else {
        final target = p.positionAt(_now());
        if ((_player.position - target).abs() > tolerance) await _player.seek(target);
      }
      if (_player.playing != p.playing) await _player.setPlaying(p.playing);
    } catch (e) {
      _log.warning('following the host failed: $e');
    }
  }

  @visibleForTesting
  Future<void> syncForTesting() async {
    final p = _party;
    if (p != null) await _sync(p);
  }

  // ── Leaving ──

  /// Leaves (as a guest) or ends it (as the host).
  Future<void> leave() async {
    final me = _me;
    final p = _party;
    if (me == null || p == null) return;
    try {
      if (p.host == me) {
        await _repo.close(me);
      } else {
        await _repo.leave(host: p.host, me: me);
      }
    } catch (e) {
      _log.warning('leaving failed: $e');
    }
    await _stop();
    notifyListeners();
  }

  Future<void> _stop() async {
    _hostTimer?.cancel();
    _hostTimer = null;
    await _partySub?.cancel();
    _partySub = null;
    _party = null;
    _joinedHost = null;
  }

  String? get joinedHost => _joinedHost;

  @override
  void dispose() {
    _changes.removeListener(_onAccount);
    _hostTimer?.cancel();
    unawaited(_partySub?.cancel());
    unawaited(_invitesSub?.cancel());
    super.dispose();
  }
}
