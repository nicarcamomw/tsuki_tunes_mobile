import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/repositories/profile_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/public_profile.dart';

import 'helpers/fake_firebase_service.dart';

void main() {
  late FakeFirebaseFirestore server;
  late ProfileRepositoryImpl repo;

  setUp(() {
    server = FakeFirebaseFirestore();
    repo = ProfileRepositoryImpl(FakeFirebaseService(server));
  });

  test('a profile goes up with exactly the fields the rules accept and comes back', () async {
    await repo.saveMyProfile(const PublicProfile(
      uid: 'u1',
      displayName: 'Nico',
      photoUrl: 'https://x/n.jpg',
      maskId: 'hannya',
      isPublic: true,
      stats: ProfileStats(tracks: 120, albums: 4, artists: 30),
      topArtists: [TopArtist(name: 'SOAD', count: 40)],
    ));

    final raw = (await server.collection('profiles').doc('u1').get()).data()!;
    expect(raw.keys.toSet(), {'displayName', 'photoUrl', 'maskId', 'public', 'stats', 'topArtists', 'updatedAt'});

    final back = await repo.getProfile('u1');
    expect(back!.displayName, 'Nico');
    expect(back.isPublic, isTrue);
    expect(back.stats, const ProfileStats(tracks: 120, albums: 4, artists: 30));
    expect(back.topArtists.single, const TopArtist(name: 'SOAD', count: 40));
  });

  test('at most five artists go up, and a long name is cut to fit', () async {
    await repo.saveMyProfile(PublicProfile(
      uid: 'u1',
      displayName: 'x' * 80,
      topArtists: [for (var i = 0; i < 8; i++) TopArtist(name: 'A$i', count: 8 - i)],
    ));
    final back = await repo.getProfile('u1');
    expect(back!.topArtists.map((a) => a.name), ['A0', 'A1', 'A2', 'A3', 'A4']);
    expect(back.displayName.length, PublicProfile.maxNameLength);
  });

  test('a profile that is not there reads as null', () async {
    expect(await repo.getProfile('nobody'), isNull);
  });

  test('sameContentAs ignores only the time', () {
    const a = PublicProfile(uid: 'u', displayName: 'N', stats: ProfileStats(tracks: 1));
    expect(a.sameContentAs(a.copyWith()), isTrue);
    expect(a.sameContentAs(a.copyWith(stats: const ProfileStats(tracks: 2))), isFalse);
    expect(a.sameContentAs(a.copyWith(isPublic: true)), isFalse);
  });
}
