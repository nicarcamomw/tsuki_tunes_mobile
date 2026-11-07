import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/party.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/party_repository.dart';
import '../datasources/firebase_service.dart';

/// `parties/{host}`: the host's name, members, invited, names, the song
/// and where it is (positionMs at `at`, the server's time), playing.
class PartyRepositoryImpl implements PartyRepository {
  PartyRepositoryImpl(this._firebase);

  final FirebaseService _firebase;

  CollectionReference<Map<String, dynamic>> get _col => _firebase.db.collection('parties');

  static Map<String, Object?> _track(Track t) => {
        'id': t.id,
        'title': t.title,
        'artistName': t.artistName,
        'artistId': t.artistId,
        'albumId': t.albumId,
        'albumTitle': t.albumTitle,
        'coverUrl': t.coverUrl,
        'previewUrl': t.previewUrl,
        'durationSeconds': t.durationSeconds,
        if (t.isrc != null) 'isrc': t.isrc,
      };

  static Party _from(String host, Map<String, dynamic> d) {
    List<String> uids(Object? v) => [if (v is List) for (final x in v) if (x is String) x];
    final t = d['track'];
    return Party(
      host: host,
      hostName: d['name'] is String ? d['name'] as String : '',
      members: uids(d['members']),
      invited: uids(d['invited']),
      names: {
        if (d['names'] is Map)
          for (final e in (d['names'] as Map).entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      track: t is Map && t['id'] != null
          ? Track(
              id: '${t['id']}',
              title: '${t['title'] ?? ''}',
              artistName: '${t['artistName'] ?? ''}',
              artistId: '${t['artistId'] ?? ''}',
              albumId: '${t['albumId'] ?? ''}',
              albumTitle: '${t['albumTitle'] ?? ''}',
              coverUrl: '${t['coverUrl'] ?? ''}',
              previewUrl: '${t['previewUrl'] ?? ''}',
              durationSeconds: t['durationSeconds'] is num ? (t['durationSeconds'] as num).toInt() : 0,
              isrc: t['isrc'] is String ? t['isrc'] as String : null,
            )
          : null,
      positionMs: d['positionMs'] is num ? (d['positionMs'] as num).toInt() : 0,
      playing: d['playing'] == true,
      at: d['at'] is Timestamp ? (d['at'] as Timestamp).toDate() : null,
    );
  }

  @override
  Stream<Party?> watch(String host) =>
      _col.doc(host).snapshots().map((s) => s.data() == null ? null : _from(s.id, s.data()!));

  @override
  Stream<List<Party>> watchInvitations(String me) => _col
      .where('invited', arrayContains: me)
      .snapshots()
      .map((s) => [for (final d in s.docs) _from(d.id, d.data())]);

  @override
  Future<void> open({
    required String me,
    required String myName,
    Track? track,
    int positionMs = 0,
    bool playing = false,
  }) =>
      _col.doc(me).set({
        'host': me,
        'name': myName.length > 60 ? myName.substring(0, 60) : myName,
        'members': <String>[],
        'invited': <String>[],
        'names': <String, String>{},
        if (track != null) 'track': _track(track),
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'playing': playing,
        'at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> publish({required String me, Track? track, required int positionMs, required bool playing}) =>
      _col.doc(me).update({
        if (track != null) 'track': _track(track),
        'positionMs': positionMs < 0 ? 0 : positionMs,
        'playing': playing,
        'at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> invite({required String me, required String bond}) => _col.doc(me).update({
        'invited': FieldValue.arrayUnion([bond]),
        'lastInvited': bond,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> join({required String host, required String me, required String myName}) => _col.doc(host).update({
        'invited': FieldValue.arrayRemove([me]),
        'members': FieldValue.arrayUnion([me]),
        'names.$me': myName.length > 60 ? myName.substring(0, 60) : myName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> decline({required String host, required String me}) => _col.doc(host).update({
        'invited': FieldValue.arrayRemove([me]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> leave({required String host, required String me}) => _col.doc(host).update({
        'members': FieldValue.arrayRemove([me]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> close(String me) => _col.doc(me).delete();
}
