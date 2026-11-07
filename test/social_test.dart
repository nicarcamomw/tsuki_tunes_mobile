import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/profile_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/social_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/public_profile.dart';
import 'package:tsuki_tunes_mobile/domain/entities/social.dart';
import 'package:tsuki_tunes_mobile/domain/logic/sintonia.dart';
import 'package:tsuki_tunes_mobile/presentation/state/social_controller.dart';

import 'helpers/fake_firebase_service.dart';

SocialPerson _p(String uid) => SocialPerson(uid: uid, name: 'Name $uid', maskId: 'hannya');

void main() {
  group('Sintonía', () {
    test('the same artists in the same order tune in fully; none at all, zero', () {
      expect(Sintonia.of(['A', 'B', 'C'], ['a', 'b', 'c']).percent, 100);
      expect(Sintonia.of(['A', 'B'], ['X', 'Y']).percent, 0);
      expect(Sintonia.of(const [], ['A']).percent, 0);
    });

    test('sharing the favourites weighs more than sharing the tail', () {
      final mine = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
      final top = Sintonia.of(mine, ['A', 'B', 'X', 'Y', 'Z', 'W', 'V', 'U']);
      final tail = Sintonia.of(mine, ['X', 'Y', 'Z', 'W', 'V', 'U', 'G', 'H']);
      expect(top.percent, greaterThan(tail.percent));
      expect(top.shared, ['A', 'B']);
    });
  });

  test('a milestone survives the trip through the profile document', () {
    final m = Milestone(kind: MilestoneKind.album, a: 'Toxicity', b: 'SOAD', at: DateTime(2026, 11, 7, 10));
    expect(Milestone.fromMap(m.toMap()), m);
    expect(Milestone.fromMap({'k': 'nope', 'a': 'x', 't': 1}), isNull);
  });

  group('Milestone log', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('newest first, the same thing once a day, at most ten, and none for no one', () async {
      var now = DateTime(2026, 11, 7, 10);
      final log = MilestoneLog(clock: () => now);
      log.album('A', 'X');
      expect(log.items, isEmpty, reason: 'no account (an Observer)');
      await log.setUser('me');
      log.album('A', 'X');
      log.album('A', 'X');
      expect(log.items, hasLength(1));
      for (var i = 0; i < 12; i++) {
        now = now.add(const Duration(hours: 1));
        log.album('B$i', 'Y');
      }
      expect(log.items, hasLength(Milestone.kept));
      expect(log.items.first.a, 'B11');
      // Kept per account.
      final again = MilestoneLog();
      await again.setUser('me');
      expect(again.items.first.a, 'B11');
    });
  });

  group('Bonds through Firestore', () {
    late FakeFirebaseFirestore db;
    late SocialRepositoryImpl repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = SocialRepositoryImpl(FakeFirebaseService(db));
    });

    test('a request, then accepting it, makes the Bond on both sides and clears the request', () async {
      await repo.sendRequest(me: _p('alice'), to: _p('bob'));
      expect((await db.doc('users/bob/friendRequests/alice').get()).data()!['name'], 'Name alice');
      expect((await db.doc('users/alice/sentRequests/bob').get()).exists, isTrue);

      await repo.accept(me: _p('bob'), from: 'alice');
      expect((await db.doc('users/bob/friends/alice').get()).data()!['name'], 'Name alice');
      expect((await db.doc('users/alice/friends/bob').get()).exists, isTrue);
      expect((await db.doc('users/bob/friendRequests/alice').get()).exists, isFalse);
      expect((await db.doc('users/alice/sentRequests/bob').get()).exists, isFalse);

      await repo.unbond(me: 'alice', other: 'bob');
      expect((await db.doc('users/bob/friends/alice').get()).exists, isFalse);
      expect((await db.doc('users/alice/friends/bob').get()).exists, isFalse);
    });

    test('declining and cancelling clear both sides', () async {
      await repo.sendRequest(me: _p('alice'), to: _p('bob'));
      await repo.decline(me: 'bob', from: 'alice');
      expect((await db.doc('users/alice/sentRequests/bob').get()).exists, isFalse);
      await repo.sendRequest(me: _p('alice'), to: _p('bob'));
      await repo.cancelRequest(me: 'alice', to: 'bob');
      expect((await db.doc('users/bob/friendRequests/alice').get()).exists, isFalse);
    });

    test('search finds public profiles by the start of the name, any case or accent', () async {
      final profiles = ProfileRepositoryImpl(FakeFirebaseService(db));
      Future<void> save(String uid, String name, {bool public = true}) => profiles.saveMyProfile(
          PublicProfile(uid: uid, displayName: name, isPublic: public));
      await save('a', 'Álvaro');
      await save('b', 'Alma', public: false);
      await save('c', 'Bruno');
      final found = await repo.search('alv');
      expect(found.map((p) => p.uid), ['a']);
      expect(await repo.search(' '), isEmpty);
    });
  });

  group('the controller', () {
    late FakeFirebaseFirestore db;
    late SocialController bob;
    final account = ValueNotifier<String?>('bob');

    setUp(() async {
      db = FakeFirebaseFirestore();
      final repo = SocialRepositoryImpl(FakeFirebaseService(db));
      bob = SocialController(
        repository: repo,
        profiles: ProfileRepositoryImpl(FakeFirebaseService(db)),
        changes: account,
        uid: () => account.value,
        myCard: () => account.value == null ? null : _p(account.value!),
        myTops: () => const ['A'],
      );
    });

    tearDown(() => bob.dispose());

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('follows the requests live; asking someone who asked me makes the Bond', () async {
      expect(bob.stateWith('alice'), BondState.none);
      await SocialRepositoryImpl(FakeFirebaseService(db)).sendRequest(me: _p('alice'), to: _p('bob'));
      await settle();
      expect(bob.pending, 1);
      expect(bob.stateWith('alice'), BondState.received);

      expect(await bob.request(_p('alice')), isTrue);
      await settle();
      expect(bob.stateWith('alice'), BondState.bonded);
      expect(bob.pending, 0);
    });

    test('a request out shows as sent, and can be taken back', () async {
      expect(await bob.request(_p('carol')), isTrue);
      await settle();
      expect(bob.stateWith('carol'), BondState.sent);
      expect(await bob.cancel('carol'), isTrue);
      await settle();
      expect(bob.stateWith('carol'), BondState.none);
    });

    test("the Resonances come from the Bonds' profiles, newest first", () async {
      final profiles = ProfileRepositoryImpl(FakeFirebaseService(db));
      await profiles.saveMyProfile(PublicProfile(uid: 'alice', displayName: 'Alice', milestones: [
        Milestone(kind: MilestoneKind.rank, a: '20', at: DateTime(2026, 11, 1)),
        Milestone(kind: MilestoneKind.album, a: 'Toxicity', b: 'SOAD', at: DateTime(2026, 11, 5)),
      ]));
      await db.doc('users/bob/friends/alice').set({'name': 'Alice', 'at': DateTime(2026)});
      await settle();
      final feed = await bob.resonances(refresh: true);
      expect(feed.map((r) => r.milestone.a), ['Toxicity', '20']);
      expect(feed.first.person.name, 'Alice');
    });

    test('signed out (or an Observer): nothing', () async {
      account.value = null;
      await settle();
      expect(bob.available, isFalse);
      expect(await bob.request(_p('alice')), isFalse);
      account.value = 'bob';
    });
  });
}
