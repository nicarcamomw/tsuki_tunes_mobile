import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/sync/firestore_sync.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late List<String> sent;
  late Map<String, Object> failNext; // entityId -> error to throw once
  late List<(OutboxEntry, Object)> refused;

  Outbox outbox() => Outbox(
        db,
        handlers: {
          'mark': (e) async {
            final error = failNext.remove(e.entityId);
            if (error != null) throw error;
            sent.add('mark ${e.entityId} ${e.payload['n'] ?? ''}'.trim());
          },
          'unmark': (e) async => sent.add('unmark ${e.entityId}'),
        },
        onPermanentFailure: (e, error) => refused.add((e, error)),
        backoff: (attempts) => Duration(seconds: 10 * attempts),
        clock: () => now,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 31, 12);
    sent = [];
    failNext = {};
    refused = [];
  });
  tearDown(() => db.close());

  test('entries are sent in order and leave the outbox', () async {
    final box = outbox();
    await box.enqueue('u1', 'mark', 't1', {'n': 1});
    await box.enqueue('u1', 'unmark', 't1');
    await box.enqueue('u1', 'mark', 't2');

    await box.drain('u1');
    expect(sent, ['mark t1 1', 'unmark t1', 'mark t2']);
    expect(await box.pending('u1'), isEmpty);
    box.stop();
  });

  test('a failure stops the run and is retried after a growing wait', () async {
    final box = outbox();
    await box.enqueue('u1', 'mark', 't1');
    await box.enqueue('u1', 'unmark', 't1');
    failNext['t1'] = Exception('offline');

    await box.drain('u1');
    expect(sent, isEmpty, reason: 'the unmark waits for its mark');
    final waiting = await box.pending('u1');
    expect(waiting.map((e) => e.kind), ['mark', 'unmark']);
    expect(waiting.first.attempts, 1);

    // Not due yet: nothing happens.
    now = now.add(const Duration(seconds: 5));
    await box.drain('u1');
    expect(sent, isEmpty);

    now = now.add(const Duration(seconds: 6));
    await box.drain('u1');
    expect(sent, ['mark t1', 'unmark t1']);
    box.stop();
  });

  test('writes saved offline are still there after a restart', () async {
    final before = outbox();
    await before.enqueue('u1', 'mark', 't1');
    failNext['t1'] = Exception('offline');
    await before.drain('u1');
    before.stop();

    now = now.add(const Duration(minutes: 1));
    final after = outbox(); // the app opened again
    await after.drain('u1');
    expect(sent, ['mark t1']);
    after.stop();
  });

  test('a refusal for good leaves the outbox and is reported, the rest goes on', () async {
    final box = outbox();
    await box.enqueue('u1', 'mark', 't1');
    await box.enqueue('u1', 'mark', 't2');
    failNext['t1'] = const PermanentSyncError('permission-denied');

    await box.drain('u1');
    expect(refused.single.$1.entityId, 't1');
    expect(sent, ['mark t2']);
    expect(await box.pending('u1'), isEmpty);
    box.stop();
  });

  test('a send that hangs (offline commit) counts as failed', () async {
    final box = Outbox(
      db,
      handlers: {'mark': (_) => Completer<void>().future},
      backoff: (_) => const Duration(seconds: 1),
      clock: () => now,
      attemptTimeout: const Duration(milliseconds: 10),
    );
    await box.enqueue('u1', 'mark', 't1');
    await box.drain('u1');
    expect((await box.pending('u1')).single.attempts, 1);
    box.stop();
  });

  test('accounts have their own queue', () async {
    final box = outbox();
    await box.enqueue('u1', 'mark', 't1');
    await box.enqueue('u2', 'mark', 't2');
    failNext['t1'] = Exception('offline');

    await box.drain('u2');
    expect(sent, ['mark t2']);
    expect((await box.pending('u1')).length, 1);
    box.stop();
  });

  test('the pending count follows the outbox', () async {
    final box = outbox();
    final counts = <int>[];
    final sub = box.watchPending('u1').listen(counts.add);
    await pumpEventQueue();
    await box.enqueue('u1', 'mark', 't1');
    await pumpEventQueue();
    await box.drain('u1');
    await pumpEventQueue();
    await sub.cancel();
    expect(counts, [0, 1, 0]);
    box.stop();
  });

  group('Firestore errors', () {
    test('refusals are for good, the rest is retried', () async {
      Future<Object?> outcome(String code) async {
        try {
          await sendToFirestore(() async => throw FirebaseException(plugin: 'cloud_firestore', code: code));
        } catch (e) {
          return e;
        }
        return null;
      }

      expect(await outcome('permission-denied'), isA<PermanentSyncError>());
      expect(await outcome('invalid-argument'), isA<PermanentSyncError>());
      expect(await outcome('unavailable'), isA<FirebaseException>());
      expect(await outcome('resource-exhausted'), isA<FirebaseException>());
    });
  });
}
