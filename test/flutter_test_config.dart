import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';

/// Runs around every test file: each test starts with a fresh get_it (and
/// an empty in-memory database), so its lazy singletons (library,
/// playlists, player) never leak from one test into the next. A test can
/// register a fake on top before using it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests open a fresh in-memory database each (never two on one file), so
  // drift's warning about several AppDatabase instances doesn't apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(() async {
    await getIt.reset();
    configureDependencies();
    // The phone's database file needs path_provider; tests get an
    // in-memory one each, closed when get_it resets.
    getIt
      ..unregister<AppDatabase>()
      ..registerLazySingleton<AppDatabase>(
        () => AppDatabase(NativeDatabase.memory()),
        dispose: (db) => db.close(),
      );
  });
  await testMain();
}
