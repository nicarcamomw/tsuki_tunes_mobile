import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.steps.dart';

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

  /// Whether the server has this row yet ([SyncState]; 0 is synced, a
  /// literal so the saved schema snapshots can hold it).
  IntColumn get syncState => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {uid, trackId};
}

/// How far a local row is from the server.
abstract final class SyncState {
  static const synced = 0;

  /// Written here, waiting in the outbox to reach the server.
  static const pendingUpsert = 1;

  /// Removed here (kept as a tombstone, hidden from the app) until the
  /// server confirms the delete, so a remote copy can't bring it back.
  static const pendingDelete = 2;
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

/// Writes waiting to reach the server, oldest first. Each one is retried
/// with a growing wait until it lands or fails for good; it survives app
/// restarts because it lives here.
@TableIndex(name: 'outbox_due', columns: {#uid, #nextAttemptAt})
@DataClassName('OutboxRow')
class OutboxRows extends Table {
  @override
  String get tableName => 'outbox';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text()();

  /// What to do (see OutboxKind), on which entity, with what data.
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text().withDefault(const Constant('{}'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [ListenedTracks, Playlists, FollowedArtists, OutboxRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The app's database file, in the app's private storage.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'tsuki_library'));

  @override
  int get schemaVersion => 2;

  // Each step is checked against the saved schema of its version
  // (drift_schemas/, test/drift/): dart run drift_dev make-migrations
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: stepByStep(
          from1To2: (m, schema) async {
            await m.addColumn(schema.listenedTracks, schema.listenedTracks.syncState);
            await m.createTable(schema.outbox);
            await m.createIndex(schema.outboxDue);
          },
        ),
      );
}
