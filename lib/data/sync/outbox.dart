import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../local/app_database.dart';
import '../../core/logger.dart';


final _log = Log.named('Outbox');

/// A write waiting to reach the server.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.uid,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.attempts,
  });

  final int id;
  final String uid;
  final String kind;
  final String entityId;
  final Map<String, dynamic> payload;
  final int attempts;
}

/// Thrown by a handler when retrying can't help (the server refused the
/// write for good). The entry leaves the outbox and [Outbox.onPermanentFailure]
/// runs, so the change can be undone locally.
class PermanentSyncError implements Exception {
  const PermanentSyncError(this.reason);
  final String reason;

  @override
  String toString() => 'PermanentSyncError: $reason';
}

/// Sends one kind of entry to the server. Must be idempotent: an entry can
/// be sent again after an app restart or a timeout, and the server may
/// already have it.
typedef OutboxHandler = Future<void> Function(OutboxEntry entry);

/// The outbox: writes saved in the database next to the change they carry
/// (same transaction), sent in order, retried with a growing wait until
/// they land. They survive restarts, so a change made offline reaches the
/// server whenever the app is next online.
///
/// Order is strict: the first entry that fails stops the run, so an
/// unmark never lands before the mark it undoes.
class Outbox {
  Outbox(
    this._db, {
    Map<String, OutboxHandler> handlers = const {},
    this.onPermanentFailure,
    Duration Function(int attempts)? backoff,
    DateTime Function()? clock,
    this.attemptTimeout = const Duration(seconds: 30),
  })  : _handlers = {...handlers},
        _backoff = backoff ?? defaultBackoff,
        _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final Map<String, OutboxHandler> _handlers;
  final Duration Function(int attempts) _backoff;
  final DateTime Function() _now;

  /// How long one send may take before it counts as failed (offline, a
  /// Firestore commit waits for the server indefinitely).
  final Duration attemptTimeout;

  /// The server refused [entry] for good.
  void Function(OutboxEntry entry, Object error)? onPermanentFailure;

  final _refused = <String, void Function(OutboxEntry entry, Object error)>{};

  /// Sends entries of [kind] through [handler]; [onRefused] undoes the
  /// local change when the server refuses one for good.
  void register(
    String kind,
    OutboxHandler handler, {
    void Function(OutboxEntry entry, Object error)? onRefused,
  }) {
    _handlers[kind] = handler;
    if (onRefused != null) _refused[kind] = onRefused;
  }

  final _running = <String, Future<void>>{};
  final _timers = <String, Timer>{};
  final _again = <String>{};

  /// 2 s, 4 s, 8 s... capped at 15 minutes, with a little jitter so several
  /// devices don't retry in lockstep.
  static Duration defaultBackoff(int attempts) {
    final seconds = min<int>(900, 2 * pow(2, max(0, attempts - 1)).toInt());
    return Duration(milliseconds: seconds * 1000 + Random().nextInt(500));
  }

  /// Saves a write for [uid]. Call it inside the transaction that changes
  /// the local rows, so both are kept or neither. [kick] then sends it.
  Future<void> enqueue(String uid, String kind, String entityId, [Map<String, dynamic> payload = const {}]) {
    assert(_handlers.containsKey(kind), 'no outbox handler for $kind');
    final now = _now();
    return _db.into(_db.outboxRows).insert(OutboxRowsCompanion.insert(
          uid: uid,
          kind: kind,
          entityId: entityId,
          payload: Value(jsonEncode(payload)),
          nextAttemptAt: now,
          createdAt: now,
        ));
  }

  /// Sends what's due for [uid] now (or right after the run in progress).
  void kick(String uid) {
    if (_running.containsKey(uid)) {
      _again.add(uid);
      return;
    }
    _timers.remove(uid)?.cancel();
    _running[uid] = drain(uid).whenComplete(() {
      _running.remove(uid);
      if (_again.remove(uid)) kick(uid);
    });
  }

  /// Sends the due entries of [uid] in order, stopping at the first one
  /// that fails; then schedules the next attempt.
  @visibleForTesting
  Future<void> drain(String uid) async {
    while (true) {
      final row = await (_db.select(_db.outboxRows)
            ..where((o) => o.uid.equals(uid))
            ..orderBy([(o) => OrderingTerm(expression: o.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row == null) return;
      if (row.nextAttemptAt.isAfter(_now())) {
        _schedule(uid, row.nextAttemptAt);
        return;
      }
      final entry = OutboxEntry(
        id: row.id,
        uid: row.uid,
        kind: row.kind,
        entityId: row.entityId,
        payload: Map<String, dynamic>.from(jsonDecode(row.payload) as Map),
        attempts: row.attempts,
      );
      final handler = _handlers[row.kind];
      try {
        if (handler == null) throw PermanentSyncError('no handler for ${row.kind}');
        await handler(entry).timeout(attemptTimeout);
        await (_db.delete(_db.outboxRows)..where((o) => o.id.equals(row.id))).go();
      } on PermanentSyncError catch (e) {
        await (_db.delete(_db.outboxRows)..where((o) => o.id.equals(row.id))).go();
        _log.warning('${row.kind} ${row.entityId} refused for good: ${e.reason}');
        _refused[row.kind]?.call(entry, e);
        onPermanentFailure?.call(entry, e);
      } catch (e) {
        final attempts = row.attempts + 1;
        final next = _now().add(_backoff(attempts));
        await (_db.update(_db.outboxRows)..where((o) => o.id.equals(row.id))).write(OutboxRowsCompanion(
          attempts: Value(attempts),
          nextAttemptAt: Value(next),
          lastError: Value(e.toString()),
        ));
        _schedule(uid, next);
        return;
      }
    }
  }

  void _schedule(String uid, DateTime at) {
    _timers.remove(uid)?.cancel();
    final wait = at.difference(_now());
    _timers[uid] = Timer(wait.isNegative ? Duration.zero : wait, () => kick(uid));
  }

  /// Completes when [uid]'s run in progress (and any it queued) is over.
  Future<void> idle(String uid) async {
    while (true) {
      final running = _running[uid];
      if (running == null) return;
      await running;
    }
  }

  /// Sends [uid]'s writes now, skipping the wait (back online).
  Future<void> retryNow(String uid) async {
    await (_db.update(_db.outboxRows)..where((o) => o.uid.equals(uid)))
        .write(OutboxRowsCompanion(nextAttemptAt: Value(_now())));
    kick(uid);
  }

  /// How many writes of [uid] haven't reached the server, as it changes.
  Stream<int> watchPending(String uid) {
    final count = _db.outboxRows.id.count();
    final query = _db.selectOnly(_db.outboxRows)
      ..addColumns([count])
      ..where(_db.outboxRows.uid.equals(uid));
    return query.map((r) => r.read(count) ?? 0).watchSingle();
  }

  /// The writes of [uid] still waiting, oldest first.
  Future<List<OutboxEntry>> pending(String uid) async {
    final rows = await (_db.select(_db.outboxRows)
          ..where((o) => o.uid.equals(uid))
          ..orderBy([(o) => OrderingTerm(expression: o.id)]))
        .get();
    return [
      for (final r in rows)
        OutboxEntry(
          id: r.id,
          uid: r.uid,
          kind: r.kind,
          entityId: r.entityId,
          payload: Map<String, dynamic>.from(jsonDecode(r.payload) as Map),
          attempts: r.attempts,
        ),
    ];
  }

  /// Stops the retry timers (sign-out, tests). Entries stay for next time.
  void stop() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
