import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/domain/entities/play_day.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/mask_collection_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';

import 'helpers/test_scope.dart';

Track _t(String id, {String artist = 'Artist'}) => Track(
  id: id,
  title: 'Song $id',
  artistId: '',
  artistName: artist,
  albumId: '',
  albumTitle: '',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 200,
);

PlayDay _day(
  String date,
  Map<String, int> plays, {
  Map<int, int> hours = const {},
  String artist = 'Ghost',
}) => PlayDay(
  date: date,
  plays: plays,
  tracks: {
    for (final id in plays.keys)
      id: PlayDayTrack(id: id, title: id, artistName: artist),
  },
  hours: hours,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MaskProvider masks;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await masks.ready;
  });

  tearDown(() => masks.dispose());

  group('progress backup', () {
    test('the snapshot holds the counters and only the top artists', () {
      for (var a = 0; a < MaskProvider.backedUpArtists + 10; a++) {
        for (var i = 0; i <= a; i++) {
          masks.onPlayCounted(_t('$a-$i', artist: 'Artist $a'));
        }
      }
      final snap = masks.progressSnapshot();
      final artists = snap['artists'] as Map;
      expect(artists.length, MaskProvider.backedUpArtists);
      expect(
        artists.containsKey('artist 39'),
        isTrue,
        reason: 'most played kept',
      );
      expect(
        artists.containsKey('artist 0'),
        isFalse,
        reason: 'least played dropped',
      );
      // 1 + 2 + … + 40 plays.
      expect(snap['plays'], 820);
    });

    test(
      'another phone\'s higher counts are taken, and unlock what they reach',
      () {
        masks.onPlayCounted(_t('1'));
        final rose = masks.applyProgress({
          'plays': 300,
          'night': 10,
          'rain': 0,
          'artists': {'ghost': 120},
        });
        expect(rose, isTrue);
        expect(masks.progress('hyaku'), (250, 250));
        expect(masks.isUnlocked('hyaku'), isTrue);
        expect(
          masks.isUnlocked('oshi'),
          isTrue,
          reason: '120 plays of one artist',
        );
        expect(masks.progress('yoru'), (10, 50));
      },
    );

    test('lower counts from the backup change nothing', () {
      for (var i = 0; i < 20; i++) {
        masks.onPlayCounted(_t('$i'));
      }
      expect(masks.applyProgress({'plays': 5, 'night': 0, 'rain': 0}), isFalse);
      expect(masks.progress('hyaku'), (20, 250));
    });

    test('a bad backup is ignored', () {
      expect(masks.applyProgress({'plays': 'many', 'artists': 'x'}), isFalse);
      expect(masks.progress('hyaku'), (0, 250));
    });
  });

  group('catching up from the play log', () {
    final log = [
      _day('2026-10-01', {'a': 200, 'b': 40}, hours: {1: 30, 3: 25, 15: 185}),
      _day('2026-10-02', {'a': 20}, hours: {14: 20}),
    ];

    test('plays, late-night plays and plays per artist count', () {
      masks.applyHistory(log);
      expect(masks.progress('hyaku'), (250, 250));
      expect(masks.isUnlocked('hyaku'), isTrue);
      expect(masks.progress('yoru'), (
        50,
        50,
      ), reason: '30 at 1 AM + 25 at 3 AM');
      expect(masks.isUnlocked('yoru'), isTrue);
      expect(masks.isUnlocked('oshi'), isTrue, reason: '260 plays of Ghost');
    });

    test('not counted twice: the higher of log and phone', () {
      for (var i = 0; i < 100; i++) {
        masks.onPlayCounted(_t('$i', artist: 'Ghost'));
      }
      masks.applyHistory([
        _day('2026-10-01', {'a': 60}),
      ]);
      expect(masks.progress('hyaku'), (100, 250));
    });

    test('once per account, only when signed in', () async {
      var loads = 0;
      masks.historyLoader = () async {
        loads++;
        return log;
      };
      await masks.catchUpFromHistory();
      expect(loads, 0, reason: 'signed out: nothing to read');

      masks.setUser('alice');
      await masks.catchUpFromHistory();
      await masks.catchUpFromHistory();
      expect(loads, 1);
      expect(masks.isUnlocked('hyaku'), isTrue);
    });

    test('an empty log is tried again later, not on every song', () async {
      var now = DateTime(2026, 11, 12, 15);
      masks.dispose();
      masks = MaskProvider(clock: () => now);
      await masks.ready;
      var loads = 0;
      var days = <PlayDay>[];
      masks.historyLoader = () async {
        loads++;
        return days;
      };
      masks.setUser('alice');
      await masks.catchUpFromHistory();
      await masks.catchUpFromHistory();
      expect(loads, 1);

      days = log;
      now = now.add(const Duration(minutes: 11));
      await masks.catchUpFromHistory();
      expect(loads, 2);
      expect(masks.isUnlocked('hyaku'), isTrue);
    });
  });

  test(
    'signing out starts the counters over: they belong to the account',
    () async {
      masks.setUser('alice');
      for (var i = 0; i < 30; i++) {
        masks.onPlayCounted(_t('$i'));
      }
      masks.setUser(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(masks.progress('hyaku'), (0, 250));
      expect(masks.isUnlocked('hajime'), isFalse);
    },
  );

  group('secret mask riddles', () {
    test('every secret mask has one', () {
      for (final m in MaskCatalog.all.where((m) => m.secret)) {
        expect(m.hint(AppLanguage.es), isNotNull, reason: m.id);
        expect(m.hint(AppLanguage.en), isNotNull, reason: m.id);
        expect(m.hint(AppLanguage.ja), isNotNull, reason: m.id);
      }
    });

    testWidgets('shown once enough masks are collected', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Future<void> openSecret() async {
        await tester.pumpWidget(
          TestScope(
            overrides: [
              maskProvider.overrideWith((ref) => masks, disposeNotifier: false),
            ],
            child: const MaterialApp(home: MaskCollectionScreen()),
          ),
        );
        await tester.pump();
        // A locked secret mask: a "???" tile.
        await tester.tap(find.text('???').first);
        await tester.pumpAndSettle();
      }

      masks.unlock('hajime');
      await openSecret();
      expect(
        find.text(
          'Despierta ${MaskProvider.secretHintsAfter} seres etéreos para ver una pista.',
        ),
        findsOneWidget,
      );
      expect(find.text('PISTA'), findsNothing);

      for (final id in ['hyaku', 'oshi', 'tabibito', 'mimi']) {
        masks.unlock(id);
      }
      await tester.pumpWidget(const SizedBox());
      await openSecret();
      expect(find.text('PISTA'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
