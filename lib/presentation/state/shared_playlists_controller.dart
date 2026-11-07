import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../domain/entities/shared_playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/shared_playlist_repository.dart';

final _log = Log.named('SharedPlaylists');

/// The collaborative playlists I'm in and the ones I'm invited to, live,
/// and what I can do with them. Only for a signed-in Bearer.
class SharedPlaylistsController extends ChangeNotifier {
  SharedPlaylistsController({
    required SharedPlaylistRepository repository,
    required Listenable changes,
    required String? Function() uid,
    required String Function() myName,
  })  : _repo = repository,
        _changes = changes,
        _uid = uid,
        _myName = myName {
    _changes.addListener(_onChange);
    _onChange();
  }

  final SharedPlaylistRepository _repo;
  final Listenable _changes;
  final String? Function() _uid;
  final String Function() _myName;

  String? _me;
  final List<StreamSubscription> _subs = [];
  List<SharedPlaylist> _mine = const [];
  List<SharedPlaylist> _invitations = const [];

  bool get available => _me != null;
  String? get me => _me;
  List<SharedPlaylist> get mine => _mine;
  List<SharedPlaylist> get invitations => _invitations;
  SharedPlaylistRepository get repository => _repo;

  void _onChange() {
    final uid = _uid();
    if (uid == _me) return;
    _me = uid;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _mine = _invitations = const [];
    notifyListeners();
    if (uid == null) return;
    _subs
      ..add(_repo.watchMine(uid).listen((v) {
        _mine = v;
        notifyListeners();
      }, onError: (Object e) => _log.warning('shared playlists: $e')))
      ..add(_repo.watchInvitations(uid).listen((v) {
        _invitations = v;
        notifyListeners();
      }, onError: (Object e) => _log.warning('invitations: $e')));
  }

  Future<bool> _run(Future<void> Function(String me) action) async {
    final me = _me;
    if (me == null) return false;
    try {
      await action(me);
      return true;
    } catch (e) {
      _log.warning('shared playlist action failed: $e');
      return false;
    }
  }

  /// A new collaborative playlist; its id, or null.
  Future<String?> create(String name, {List<Track> tracks = const []}) async {
    final me = _me;
    if (me == null) return null;
    try {
      return await _repo.create(me: me, myName: _myName(), name: name, tracks: tracks);
    } catch (e) {
      _log.warning('creating a shared playlist failed: $e');
      return null;
    }
  }

  Future<bool> addTrack(String id, Track track) => _run((me) => _repo.addTrack(id: id, me: me, track: track));
  Future<bool> removeTrack(String id, String trackId) =>
      _run((me) => _repo.removeTrack(id: id, me: me, trackId: trackId));
  Future<bool> invite(String id, String bond) => _run((me) => _repo.invite(id: id, me: me, bond: bond));
  Future<bool> removePerson(String id, String uid) => _run((me) => _repo.removePerson(id: id, me: me, uid: uid));
  Future<bool> join(String id) => _run((me) => _repo.join(id: id, me: me, myName: _myName()));
  Future<bool> decline(String id) => _run((me) => _repo.decline(id: id, me: me));
  Future<bool> leave(String id) => _run((me) => _repo.leave(id: id, me: me));
  Future<bool> rename(String id, String name) => _run((me) => _repo.rename(id: id, me: me, name: name));
  Future<bool> delete(String id) => _run((_) => _repo.delete(id));

  @override
  void dispose() {
    _changes.removeListener(_onChange);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
