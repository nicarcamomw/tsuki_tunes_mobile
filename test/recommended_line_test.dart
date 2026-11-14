import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/recommended_line.dart';

import 'helpers/test_scope.dart';

const _song = Track(
  id: 'r1',
  title: 'Instant Crush',
  artistId: 'df',
  artistName: 'Daft Punk',
  albumId: 'b',
  albumTitle: 'RAM',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 337,
);

/// A player playing a song smart shuffle recommended.
class _RecoAudio extends AudioProvider {
  bool kept = false;
  @override
  bool isRecommended(String trackId) => !kept && trackId == _song.id;
  @override
  RadioReason? recommendationReasonFor(String trackId) =>
      isRecommended(trackId) ? const RadioReason(RadioSource.deezer, '', 'Justice') : null;
  @override
  void keepRecommendation(String trackId) {
    kept = true;
    notifyListeners();
  }
}

/// Already in the library, so keeping it only stops it being a
/// recommendation (marking it needs an account).
class _Library extends LibraryRepositoryImpl {
  @override
  bool isTrackListened(String trackId) => true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.${(call.arguments as Map)['id']}'), (_) async => {});
      }
      return {};
    });
  });

  testWidgets('a recommended song says so and why, and keeps with one tap', (tester) async {
    final audio = _RecoAudio();
    await tester.pumpWidget(TestScope(
      overrides: [
        audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
        libraryProvider.overrideWith((ref) => _Library()),
      ],
      child: const MaterialApp(home: Scaffold(body: RecommendedLine(track: _song))),
    ));
    await tester.pump();
    expect(find.textContaining('RECOMENDADA'), findsOneWidget);
    expect(find.textContaining('Justice'), findsOneWidget, reason: 'why it is here');

    await tester.tap(find.text('GUARDAR'));
    await tester.pump();
    expect(audio.kept, isTrue);
    expect(find.textContaining('RECOMENDADA'), findsNothing, reason: 'one of the user\'s now');

    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });

  testWidgets('any other song shows nothing', (tester) async {
    final audio = _RecoAudio()..kept = true;
    await tester.pumpWidget(TestScope(
      overrides: [audioProvider.overrideWith((ref) => audio, disposeNotifier: false)],
      child: const MaterialApp(home: Scaffold(body: RecommendedLine(track: _song))),
    ));
    await tester.pump();
    expect(find.byType(TextButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });
}
