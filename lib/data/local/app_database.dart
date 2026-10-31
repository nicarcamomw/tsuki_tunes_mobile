import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// The library on the phone: SQLite through Drift. Each account's songs,
// playlists and followed artists are rows keyed by its uid, so marking a
// song writes one row instead of the whole list, and stats can query.
//
// Changing a table: bump schemaVersion and add the step to [migration],
// then dart run build_runner build -d.

/// The songs marked as listened, per account.
@TableIndex(name: 'listened_by_album', columns: {#uid, #albumId})
@TableIndex(name: 'listened_by_date', columns: {#uid, #listenedAt})
class ListenedTracks extends Table {
  TextColumn get uid => text()();
  TextColumn get trackId => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text()();
  TextColumn get albumTitle => text()();
  TextColumn get albumId => text()();
  TextColumn get coverUrl => text()();
  TextColumn get previewUrl => text().withDefault(const Constant(''))();
  IntColumn get duration => integer()();
  DateTimeColumn get listenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {uid, trackId};
}

/// The account's playlists, in the order the app shows them. The songs stay
/// one JSON list per playlist: they are always read and written whole.
class Playlists extends Table {
  TextColumn get uid => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {uid, id};
}

/// The artists the account follows (for the release radar), in order.
class FollowedArtists extends Table {
  TextColumn get uid => text()();
  TextColumn get artistId => text()();
  IntColumn get position => integer()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {uid, artistId};
}

@DriftDatabase(tables: [ListenedTracks, Playlists, FollowedArtists])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The app's database file, in the app's private storage.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'tsuki_library'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Future versions: if (from < 2) { await m.addColumn(...); }
        onUpgrade: (m, from, to) async {},
      );
}
