import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/shared_playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/shared_playlist_repository.dart';
import '../datasources/firebase_service.dart';

/// `sharedPlaylists/{id}` (firestore.rules says who may change what):
/// name, owner, members, invited, names (uid -> name), tracks (each with
/// addedBy), and the last change's time and author.
class SharedPlaylistRepositoryImpl implements SharedPlaylistRepository {
  SharedPlaylistRepositoryImpl(this._firebase);

  final FirebaseService _firebase;

  CollectionReference<Map<String, dynamic>> get _col => _firebase.db.collection('sharedPlaylists');

  static Map<String, dynamic> _trackMap(Track t, String by) => {
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
        'addedBy': by,
      };

  static SharedPlaylist _from(String id, Map<String, dynamic> d) {
    List<String> uids(Object? v) => [if (v is List) for (final x in v) if (x is String) x];
    return SharedPlaylist(
      id: id,
      name: d['name'] is String ? d['name'] as String : '',
      owner: d['owner'] is String ? d['owner'] as String : '',
      members: uids(d['members']),
      invited: uids(d['invited']),
      names: {
        if (d['names'] is Map)
          for (final e in (d['names'] as Map).entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
      },
      tracks: [
        if (d['tracks'] is List)
          for (final t in d['tracks'] as List)
            if (t is Map && t['id'] != null)
              SharedTrack(
                addedBy: t['addedBy'] is String ? t['addedBy'] as String : '',
                track: Track(
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
                ),
              ),
      ],
      updatedAt: d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, Object> _stamp(String me) => {'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': me};

  @override
  Stream<List<SharedPlaylist>> watchMine(String me) => _col
      .where('members', arrayContains: me)
      .snapshots()
      .map((s) => [for (final d in s.docs) _from(d.id, d.data())]..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Stream<List<SharedPlaylist>> watchInvitations(String me) => _col
      .where('invited', arrayContains: me)
      .snapshots()
      .map((s) => [for (final d in s.docs) _from(d.id, d.data())]);

  @override
  Stream<SharedPlaylist?> watch(String id) =>
      _col.doc(id).snapshots().map((s) => s.data() == null ? null : _from(s.id, s.data()!));

  @override
  Future<String> create({required String me, required String myName, required String name, List<Track> tracks = const []}) async {
    final doc = _col.doc();
    final seen = <String>{};
    await doc.set({
      'name': name.length > 100 ? name.substring(0, 100) : name,
      'owner': me,
      'members': [me],
      'invited': <String>[],
      'names': {me: myName.length > 60 ? myName.substring(0, 60) : myName},
      'tracks': [
        for (final t in tracks)
          if (seen.add(t.id)) _trackMap(t, me),
      ].take(SharedPlaylist.maxTracks).toList(),
      ..._stamp(me),
    });
    return doc.id;
  }

  /// Read, change and write back in one transaction, so two members adding
  /// at once both keep their songs.
  Future<void> _tracks(String id, String me, List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) change) =>
      _firebase.db.runTransaction((tx) async {
        final snap = await tx.get(_col.doc(id));
        final list = [
          for (final t in (snap.data()?['tracks'] as List? ?? const []))
            if (t is Map) Map<String, dynamic>.from(t),
        ];
        tx.update(_col.doc(id), {'tracks': change(list), ..._stamp(me)});
      });

  @override
  Future<void> addTrack({required String id, required String me, required Track track}) => _tracks(id, me, (list) {
        if (list.any((t) => t['id'] == track.id) || list.length >= SharedPlaylist.maxTracks) return list;
        return [...list, _trackMap(track, me)];
      });

  @override
  Future<void> removeTrack({required String id, required String me, required String trackId}) =>
      _tracks(id, me, (list) => [for (final t in list) if (t['id'] != trackId) t]);

  @override
  Future<void> invite({required String id, required String me, required String bond}) => _col.doc(id).update({
        'invited': FieldValue.arrayUnion([bond]),
        'lastInvited': bond,
        ..._stamp(me),
      });

  @override
  Future<void> removePerson({required String id, required String me, required String uid}) => _col.doc(id).update({
        'invited': FieldValue.arrayRemove([uid]),
        'members': FieldValue.arrayRemove([uid]),
        ..._stamp(me),
      });

  @override
  Future<void> join({required String id, required String me, required String myName}) => _col.doc(id).update({
        'invited': FieldValue.arrayRemove([me]),
        'members': FieldValue.arrayUnion([me]),
        'names.$me': myName.length > 60 ? myName.substring(0, 60) : myName,
        ..._stamp(me),
      });

  @override
  Future<void> decline({required String id, required String me}) => _col.doc(id).update({
        'invited': FieldValue.arrayRemove([me]),
        ..._stamp(me),
      });

  @override
  Future<void> leave({required String id, required String me}) => _col.doc(id).update({
        'members': FieldValue.arrayRemove([me]),
        ..._stamp(me),
      });

  @override
  Future<void> rename({required String id, required String me, required String name}) =>
      _col.doc(id).update({'name': name.length > 100 ? name.substring(0, 100) : name, ..._stamp(me)});

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}
