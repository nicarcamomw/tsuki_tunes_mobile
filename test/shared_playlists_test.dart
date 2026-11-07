import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/account_deletion_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/shared_playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

import 'helpers/fake_firebase_service.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistName: 'Artist',
      artistId: 'a',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: 'https://c/$id.jpg',
      previewUrl: 'https://p/$id.mp3',
      durationSeconds: 200,
    );

void main() {
  late FakeFirebaseFirestore db;
  late SharedPlaylistRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = SharedPlaylistRepositoryImpl(FakeFirebaseService(db));
  });

  test('made, shared with a Bond who joins, and built together with who added what', () async {
    final id = await repo.create(me: 'alice', myName: 'Alice', name: 'Noche', tracks: [_t('1'), _t('1')]);
    await repo.invite(id: id, me: 'alice', bond: 'bob');
    expect((await repo.watchInvitations('bob').first).single.name, 'Noche');
    await repo.join(id: id, me: 'bob', myName: 'Bob');
    expect((await repo.watchInvitations('bob').first), isEmpty);

    await repo.addTrack(id: id, me: 'bob', track: _t('2'));
    await repo.addTrack(id: id, me: 'bob', track: _t('2'));
    final p = (await repo.watch(id).first)!;
    expect(p.members, ['alice', 'bob']);
    expect(p.tracks.map((s) => s.track.id), ['1', '2'], reason: 'once each');
    expect(p.tracks.last.addedBy, 'bob');
    expect(p.nameOf('bob'), 'Bob');
    expect(p.tracks.last.track.previewUrl, 'https://p/2.mp3');

    await repo.removeTrack(id: id, me: 'alice', trackId: '1');
    final left = (await db.collection('sharedPlaylists').doc(id).get()).data()!['tracks'] as List;
    expect(left.map((t) => (t as Map)['id']), ['2']);
    expect((await repo.watchMine('bob').first).single.id, id);

    await repo.leave(id: id, me: 'bob');
    expect(await repo.watchMine('bob').first, isEmpty);
  });

  test('deleting an account deletes the playlists it made and leaves the others', () async {
    final mineId = await repo.create(me: 'me', myName: 'Me', name: 'Mía');
    final theirs = await repo.create(me: 'other', myName: 'Other', name: 'Suya');
    await repo.invite(id: theirs, me: 'other', bond: 'me');
    await repo.join(id: theirs, me: 'me', myName: 'Me');
    final invite = await repo.create(me: 'other', myName: 'Other', name: 'Invitación');
    await repo.invite(id: invite, me: 'other', bond: 'me');

    await AccountDeletionService(db, batchGap: Duration.zero).deleteUserData('me');

    expect((await db.collection('sharedPlaylists').doc(mineId).get()).exists, isFalse);
    expect((await repo.watch(theirs).first)!.members, ['other']);
    expect((await repo.watch(invite).first)!.invited, isEmpty);
  });
}
