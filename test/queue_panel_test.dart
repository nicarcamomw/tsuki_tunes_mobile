import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/queue_panel.dart';

import 'helpers/test_scope.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: 'Artist',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

List<String> _upcoming(AudioProvider a) =>
    [for (final i in a.upcomingOrder()) a.queue[i].id];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  Future<AudioProvider> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final audio = AudioProvider();
    final queue = [for (final id in 'abcde'.split('')) _t(id)];
    await tester.runAsync(() async {
      try {
        await audio.playTrack(queue.first, newQueue: queue);
      } catch (_) {}
    });
    await tester.pumpWidget(TestScope(
        overrides: [
          audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
        ],
        child: const MaterialApp(home: Scaffold(body: QueuePanel()))));
    await tester.pump();
    return audio;
  }

  testWidgets('shows what plays now and next, with the time left',
      (tester) async {
    await pumpPanel(tester);
    expect(find.text('SONANDO AHORA'), findsOneWidget);
    expect(find.text('A CONTINUACIÓN'), findsOneWidget);
    expect(find.text('Song a'), findsOneWidget);
    expect(find.text('Song e'), findsOneWidget);
    // 4 songs of 200 s still to come.
    expect(find.text('4 canciones · 13 min'), findsOneWidget);
  });

  testWidgets('swipe left removes a song, and undo brings it back',
      (tester) async {
    final audio = await pumpPanel(tester);
    await tester.drag(find.text('Song c'), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(_upcoming(audio), ['b', 'd', 'e']);

    await tester.tap(find.text('DESHACER'));
    await tester.pumpAndSettle();
    expect(_upcoming(audio), ['b', 'c', 'd', 'e']);
  });

  testWidgets('swipe right makes a song play next', (tester) async {
    final audio = await pumpPanel(tester);
    await tester.drag(find.text('Song d'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(_upcoming(audio), ['d', 'b', 'c', 'e']);
    expect(audio.isUserQueued('d'), isTrue);
    expect(find.text('Song d'), findsOneWidget);
    // Let the undo snackbar time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
