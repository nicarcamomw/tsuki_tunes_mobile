import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/services/sub_write_queue.dart';

void main() {
  final queue = SubWriteQueue.instance;
  setUp(() => queue.gap = const Duration(milliseconds: 150));
  tearDown(() => queue.gap = const Duration(milliseconds: 1100));

  test('writes run one at a time, spaced by the gap', () async {
    final starts = <DateTime>[];
    final ends = <DateTime>[];
    Future<int> write(int v) async {
      starts.add(DateTime.now());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      ends.add(DateTime.now());
      return v;
    }

    final results = await Future.wait([
      queue.run(() => write(1)),
      queue.run(() => write(2)),
      queue.run(() => write(3)),
    ]);
    expect(results, [1, 2, 3]);
    for (var i = 1; i < 3; i++) {
      expect(starts[i].difference(ends[i - 1]).inMilliseconds, greaterThanOrEqualTo(140));
    }
  });

  test('a failed write passes its error on and does not block the next', () async {
    final failing = queue.run<void>(() async => throw StateError('rejected'));
    final next = queue.run(() async => 'ok');
    await expectLater(failing, throwsStateError);
    expect(await next, 'ok');
  });
}
