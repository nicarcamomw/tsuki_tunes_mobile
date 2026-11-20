import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/first_launch.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/session_gate.dart';
import 'package:tsuki_tunes_mobile/presentation/state/auth_provider.dart';

class _SignedOut extends ChangeNotifier implements AuthProvider {
  @override
  bool get loading => false;
  @override
  bool get isLoggedIn => false;
  @override
  bool get isGuest => false;
  @override
  String? get uid => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists implements PlaylistRepositoryImpl {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// The first start after install holds on the loading screen while the
// phone's one-time work passes; every later start goes straight on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(FirstLaunch.debugReset);

  test('the first start is known as such, and only once', () async {
    await FirstLaunch.check();
    expect(FirstLaunch.isFirst, isTrue);
    await FirstLaunch.finish();
    await FirstLaunch.ready;
    await FirstLaunch.check();
    expect(FirstLaunch.isFirst, isFalse, reason: 'the next start');
  });

  test('a first start holds the session on the loading screen until the phone is ready', () async {
    FirstLaunch.debugStartFirst();
    final gate = SessionGate(
      auth: _SignedOut(),
      library: LibraryRepositoryImpl(),
      playlists: _Playlists(),
      storage: StorageService(),
    );
    expect(gate.status, SessionStatus.preparing);
    expect(gate.prepStep.value, PrepStep.settling);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(gate.status, SessionStatus.preparing, reason: 'still getting ready');

    await FirstLaunch.finish();
    await Future<void>.delayed(Duration.zero);
    expect(gate.status, SessionStatus.signedOut);
    expect(gate.prepStep.value, isNull);
    gate.dispose();
  });

  test('a first start never holds for good', () async {
    FirstLaunch.debugStartFirst();
    final previous = SessionGate.firstLaunchPatience;
    SessionGate.firstLaunchPatience = const Duration(milliseconds: 20);
    addTearDown(() => SessionGate.firstLaunchPatience = previous);
    final gate = SessionGate(
      auth: _SignedOut(),
      library: LibraryRepositoryImpl(),
      playlists: _Playlists(),
      storage: StorageService(),
    );
    expect(gate.status, SessionStatus.preparing);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gate.status, SessionStatus.signedOut);
    gate.dispose();
  });

  testWidgets('settling ends, smooth frames or not, within its bounds', (tester) async {
    var done = false;
    unawaited(FirstLaunch.settle(atLeast: const Duration(milliseconds: 100), atMost: const Duration(milliseconds: 300))
        .then((_) => done = true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(done, isFalse, reason: 'not before its minimum');
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isTrue);
  });
}
