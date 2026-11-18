import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';

import 'helpers/test_scope.dart';

// A progress bar runs the full width and fills from its start. The mini
// player's bar had no width of its own: its Stack shrank to the played part
// and the column centred it, so half a song looked like a short bar in the
// middle of the dock, with no track around it.

const _song = Track(
  id: '1',
  title: 'Misis Guiñi',
  artistId: 'a',
  artistName: 'Tronic',
  albumId: 'b',
  albumTitle: 'Evoluciona',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 146,
);

/// Halfway through the song.
class _Halfway extends AudioProvider {
  @override
  Track? get currentTrack => _song;
  @override
  Duration get duration => const Duration(seconds: 146);
  @override
  Duration get position => const Duration(seconds: 73);
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  testWidgets('the mini player\'s bar fills from the left: half a song is its left half', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          audioProvider.overrideWith((ref) => _Halfway()),
          playerTintColorProvider.overrideWithValue(const Color(0xFFFFC83D)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer()))),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final fill = find.descendant(of: find.byType(MiniPlayer), matching: find.byType(FractionallySizedBox)).first;
      final track = tester.getRect(find.ancestor(of: fill, matching: find.byType(Stack)).first);
      final played = tester.getRect(find.descendant(of: fill, matching: find.byType(DecoratedBox)).first);
      final player = tester.getRect(find.byType(MiniPlayer));
      expect(track.width, greaterThan(player.width * 0.8), reason: 'the track runs the dock\'s width');
      expect(played.left, closeTo(track.left, 0.5), reason: 'it starts where the track starts');
      expect(played.width, closeTo(track.width / 2, 1), reason: 'half the song, half the track');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _noNetwork);
  });

  test('every fill says where it starts', () {
    // Every FractionallySizedBox with a widthFactor under a Stack is a fill;
    // each must say where it starts.
    final offenders = <String>[];
    for (final f in [
      'lib/presentation/widgets/mini_player.dart',
      'lib/presentation/widgets/album_progress_bar.dart',
      'lib/presentation/widgets/wrapped_picker_sheet.dart',
      'lib/presentation/screens/wrapped/wrapped_slides.dart',
    ]) {
      final src = File(f).readAsStringSync();
      final calls = RegExp(r'FractionallySizedBox\((?:(?!\n\s*child:)[\s\S])*?widthFactor').allMatches(src);
      for (final m in calls) {
        if (!m.group(0)!.contains('alignment:')) offenders.add('$f: ${m.group(0)!.split('\n').first.trim()}');
      }
    }
    expect(offenders, isEmpty);
  });
}
