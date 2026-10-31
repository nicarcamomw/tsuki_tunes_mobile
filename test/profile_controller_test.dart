import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/public_profile.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/profile_repository.dart';
import 'package:tsuki_tunes_mobile/presentation/state/profile_controller.dart';

class _Repo implements ProfileRepository {
  final saved = <PublicProfile>[];
  PublicProfile? existing;

  @override
  Future<PublicProfile?> getProfile(String uid) async => existing;

  @override
  Stream<PublicProfile?> watchProfile(String uid) => const Stream.empty();

  @override
  Future<void> saveMyProfile(PublicProfile profile) async => saved.add(profile);
}

void main() {
  late _Repo repo;
  late ChangeNotifier changes;
  late List<String> artists;
  String? uid;
  bool loaded = true;
  late DateTime now;

  ProfileController make() => ProfileController(
        repository: repo,
        changes: changes,
        uid: () => uid,
        displayName: () => 'Nico',
        photoUrl: () => null,
        maskId: () => 'hannya',
        libraryLoaded: () => loaded,
        listenedArtistNames: () => artists,
        albumsCompleted: () => 0,
        knownArtists: () => const [],
        debounce: const Duration(seconds: 20),
        minInterval: const Duration(minutes: 10),
        clock: () => now,
      );

  setUp(() {
    repo = _Repo();
    changes = ChangeNotifier();
    artists = ['SOAD'];
    uid = 'u1';
    loaded = true;
    now = DateTime(2026, 11, 1, 12);
  });

  void elapse(FakeAsync async, Duration d) {
    now = now.add(d);
    async.elapse(d);
  }

  test('publishes once after a quiet moment, then only when something changed', () {
    fakeAsync((async) {
      final c = make();
      async.flushMicrotasks();
      expect(c.available, isTrue);
      expect(c.isPublic, isFalse, reason: 'private until chosen');

      elapse(async, const Duration(seconds: 21));
      expect(repo.saved.single.stats.tracks, 1);

      // Nothing new: no write.
      changes.notifyListeners();
      elapse(async, const Duration(minutes: 11));
      expect(repo.saved, hasLength(1));
      c.dispose();
    });
  });

  test('changes inside ten minutes wait, and go out together', () {
    fakeAsync((async) {
      final c = make();
      async.flushMicrotasks();
      elapse(async, const Duration(seconds: 21));

      for (final a in ['Korn', 'Tool', 'Muse']) {
        artists = [...artists, a];
        changes.notifyListeners();
        elapse(async, const Duration(minutes: 1));
      }
      expect(repo.saved, hasLength(1));
      elapse(async, const Duration(minutes: 10));
      expect(repo.saved, hasLength(2));
      expect(repo.saved.last.stats.tracks, 4);
      c.dispose();
    });
  });

  test('going public is published right away (after the server\'s 10 seconds)', () {
    fakeAsync((async) {
      final c = make();
      async.flushMicrotasks();
      elapse(async, const Duration(seconds: 21));

      unawaited(c.setPublic(true));
      async.flushMicrotasks();
      expect(repo.saved, hasLength(1), reason: 'the last write was under 10 s ago');
      elapse(async, const Duration(seconds: 11));
      expect(repo.saved.last.isPublic, isTrue);
      c.dispose();
    });
  });

  test('keeps the visibility already published, and never publishes before the library loads', () {
    fakeAsync((async) {
      repo.existing = const PublicProfile(uid: 'u1', displayName: 'Nico', isPublic: true);
      loaded = false;
      final c = make();
      async.flushMicrotasks();
      expect(c.isPublic, isTrue);

      elapse(async, const Duration(minutes: 1));
      expect(repo.saved, isEmpty);
      loaded = true;
      changes.notifyListeners();
      elapse(async, const Duration(seconds: 21));
      expect(repo.saved.single.isPublic, isTrue);
      c.dispose();
    });
  });

  test('guests have no profile', () {
    fakeAsync((async) {
      uid = null;
      final c = make();
      elapse(async, const Duration(minutes: 1));
      expect(c.available, isFalse);
      expect(c.shareLink, isNull);
      expect(repo.saved, isEmpty);
      c.dispose();
    });
  });
}
