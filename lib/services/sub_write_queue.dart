import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs the writes that stamp `users/{uid}.lastSubWrite` one at a time, at
/// least [gap] apart.
///
/// firestore.rules rejects a stamped write that lands less than a second
/// after the previous one. Without this, two quick actions (mark two songs,
/// follow an artist then mark a song, remove two songs from a playlist) sent
/// the second write too soon: rejected, and the change silently rolled back.
/// Here the second simply waits its turn.
class SubWriteQueue {
  SubWriteQueue._();
  static final SubWriteQueue instance = SubWriteQueue._();

  /// Comfortably over the rules' one second, for clock and network jitter.
  @visibleForTesting
  Duration gap = const Duration(milliseconds: 1100);

  Future<void> _tail = Future.value();
  DateTime? _lastDone;

  /// Queues [write]; completes with its result (or error) when it has run.
  Future<T> run<T>(Future<T> Function() write) {
    final result = _tail.then((_) async {
      final last = _lastDone;
      if (last != null) {
        final wait = gap - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      try {
        return await write();
      } finally {
        _lastDone = DateTime.now();
      }
    });
    // The next write waits for this one whether it succeeds or fails.
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}
