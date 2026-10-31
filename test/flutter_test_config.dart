import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';

/// Runs around every test file: each test starts with a fresh get_it, so
/// its lazy singletons (library, playlists, player) never leak from one
/// test into the next. A test can register a fake on top before using it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() async {
    await getIt.reset();
    configureDependencies();
  });
  await testMain();
}
