import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/account_deletion_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/party_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/party.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/party_controller.dart';

import 'helpers/fake_firebase_service.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistName: 'Artist',
      artistId: 'a',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://p/$id.mp3',
      durationSeconds: 200,
    );

class _Player extends ChangeNotifier implements PartyPlayer {
  @override
  Track? current;
  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  final played = <String>[];
  final seeks = <Duration>[];

  @override
  Future<void> play(Track track) async {
    current = track;
    playing = true;
    position = Duration.zero;
    played.add(track.id);
  }

  @override
  Future<void> setPlaying(bool value) async => playing = value;

  @override
  Future<void> seek(Duration p) async {
    position = p;
    seeks.add(p);
  }
}

void main() {
  test('where the host is: the position moves on only while playing', () {
    final at = DateTime(2026, 11, 7, 20);
    final p = Party(host: 'h', hostName: 'H', members: const [], invited: const [], names: const {},
        positionMs: 10000, playing: true, at: at);
    expect(p.positionAt(at.add(const Duration(seconds: 5))), const Duration(seconds: 15));
    final paused = Party(host: 'h', hostName: 'H', members: const [], invited: const [], names: const {},
        positionMs: 10000, at: at);
    expect(paused.positionAt(at.add(const Duration(seconds: 5))), const Duration(seconds: 10));
  });

  group('a party', () {
    late FakeFirebaseFirestore db;
    late PartyRepositoryImpl repo;
    late _Player hostPlayer;
    late _Player guestPlayer;
    late PartyController host;
    late PartyController guest;
    final now = DateTime(2026, 11, 7, 20);

    PartyController make(String uid, _Player player) => PartyController(
          repository: repo,
          changes: ChangeNotifier(),
          uid: () => uid,
          myName: () => 'Name $uid',
          player: player,
          clock: () => now,
          tick: const Duration(hours: 1),
        );

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = PartyRepositoryImpl(FakeFirebaseService(db));
      hostPlayer = _Player()
        ..current = _t('1')
        ..playing = true;
      guestPlayer = _Player();
      host = make('alice', hostPlayer);
      guest = make('bob', guestPlayer);
    });

    tearDown(() {
      host.dispose();
      guest.dispose();
    });

    test('an invited guest joins and hears the host\'s song; the host publishes only what changes', () async {
      expect(await host.host(), isTrue);
      await settle();
      expect(host.hosting, isTrue);
      expect(await host.invite('bob'), isTrue);
      await settle();
      expect(guest.invitations.single.host, 'alice');

      expect(await guest.join('alice'), isTrue);
      await settle();
      await guest.syncForTesting();
      expect(guestPlayer.played, ['1']);
      expect(guest.party!.members, ['bob']);

      // Nothing changed: nothing is written.
      final before = (await db.doc('parties/alice').get()).data()!['positionMs'];
      await host.hostTickForTesting();
      expect((await db.doc('parties/alice').get()).data()!['positionMs'], before);

      // A new song goes out.
      hostPlayer.current = _t('2');
      await host.hostTickForTesting();
      await settle();
      await guest.syncForTesting();
      expect(guestPlayer.played, ['1', '2']);

      // The host pauses: so does the guest.
      hostPlayer.playing = false;
      await host.hostTickForTesting();
      await settle();
      await guest.syncForTesting();
      expect(guestPlayer.playing, isFalse);
    });

    test('when the host ends it, the guest is told', () async {
      await host.host();
      await host.invite('bob');
      await guest.join('alice');
      await settle();
      await host.leave();
      await settle();
      expect(guest.inParty, isFalse);
      expect(guest.ended, isTrue);
    });

    test('deleting an account closes its party and leaves the others', () async {
      await host.host();
      await host.invite('bob');
      await guest.join('alice');
      final bobParty = make('bob', guestPlayer);
      await settle();
      await AccountDeletionService(db, batchGap: Duration.zero).deleteUserData('bob');
      expect((await db.doc('parties/alice').get()).data()!['members'], isEmpty);
      await AccountDeletionService(db, batchGap: Duration.zero).deleteUserData('alice');
      expect((await db.doc('parties/alice').get()).exists, isFalse);
      bobParty.dispose();
    });
  });
}
