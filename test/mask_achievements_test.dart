import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/weather_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/play_day.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/moon_calculator.dart';
import 'package:tsuki_tunes_mobile/domain/logic/music_styles.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';

Track _t(String id, {String artist = 'Artist', int? rank, bool explicit = false, String albumId = ''}) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: artist,
      albumId: albumId,
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
      rank: rank,
      isExplicit: explicit,
    );

WeatherNow _weather(Sky sky, double temp) => WeatherNow(
      sky: sky,
      temperature: temp,
      isDay: true,
      precipitation: 0,
      localTime: DateTime(2026, 7, 1),
      fetchedAt: DateTime(2026, 7, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late MaskProvider masks;
  Album? album;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 12, 15); // an ordinary afternoon, no full moon
    album = null;
    masks = MaskProvider(clock: () => now, albumLookup: (_) async => album);
    await masks.ready;
  });

  tearDown(() => masks.dispose());

  void play(int n, {String prefix = 'p', String artist = 'Artist'}) {
    for (var i = 0; i < n; i++) {
      masks.onPlayCounted(_t('$prefix$i', artist: artist));
    }
  }

  group('music styles', () {
    test('50 metal songs: Oni de Acero, with progress on the way', () {
      for (var i = 0; i < 49; i++) {
        masks.onStyle(const StyleInfo(styles: {MusicStyle.metal}));
      }
      expect(masks.progress('tetsu'), (49, 50));
      expect(masks.isUnlocked('tetsu'), isFalse);
      masks.onStyle(const StyleInfo(styles: {MusicStyle.metal}));
      expect(masks.isUnlocked('tetsu'), isTrue);
    });

    test('a song counts for every family it belongs to', () {
      for (var i = 0; i < 50; i++) {
        masks.onStyle(const StyleInfo(styles: {MusicStyle.rock, MusicStyle.indie}));
      }
      expect(masks.isUnlocked('sabi'), isTrue);
      expect(masks.isUnlocked('kumo'), isTrue);
    });

    test('the rainbow needs 10 songs of each of the 12 main styles', () {
      for (final s in MusicStyles.main.take(11)) {
        for (var i = 0; i < 10; i++) {
          masks.onStyle(StyleInfo(styles: {s}));
        }
      }
      expect(masks.progress('niji'), (11, 12));
      for (var i = 0; i < 9; i++) {
        masks.onStyle(StyleInfo(styles: {MusicStyles.main.last}));
      }
      expect(masks.isUnlocked('niji'), isFalse);
      masks.onStyle(StyleInfo(styles: {MusicStyles.main.last}));
      expect(masks.isUnlocked('niji'), isTrue);
    });

    test('10 different countries: Jade; the same one twice counts once', () {
      for (final c in ['JP', 'JP', 'KR', 'CL', 'AR', 'MX', 'US', 'GB', 'SE', 'FR']) {
        masks.onStyle(StyleInfo(countries: {c}));
      }
      expect(masks.progress('hisui'), (9, 10));
      masks.onStyle(const StyleInfo(countries: {'BR'}));
      expect(masks.isUnlocked('hisui'), isTrue);
    });

    test('each counted song asks for its style', () async {
      final asked = <String>[];
      masks.styleOf = (t) async {
        asked.add(t.id);
        return const StyleInfo(styles: {MusicStyle.punk});
      };
      play(30, artist: 'Ramones');
      await Future<void>.delayed(Duration.zero);
      expect(asked.length, 30);
      expect(masks.isUnlocked('kuchi'), isTrue);
    });
  });

  group('what the song is', () {
    test('fast, hits, hidden gems and explicit songs', () {
      masks.bpmOf = (id) => id.startsWith('fast') ? 172 : 98;
      for (var i = 0; i < 50; i++) {
        masks.onPlayCounted(_t('fast$i'));
        masks.onPlayCounted(_t('hit$i', rank: 900000));
        masks.onPlayCounted(_t('exp$i', explicit: true));
      }
      for (var i = 0; i < 30; i++) {
        masks.onPlayCounted(_t('gem$i', rank: 42000));
      }
      expect(masks.isUnlocked('homura'), isTrue);
      expect(masks.isUnlocked('kin_oni'), isTrue);
      expect(masks.isUnlocked('doku'), isTrue);
      expect(masks.isUnlocked('meisai'), isTrue);
    });

    test('unknown rank or tempo counts for nothing', () {
      play(60);
      expect(masks.progress('homura'), (0, 50));
      expect(masks.progress('kin_oni'), (0, 50));
      expect(masks.progress('meisai'), (0, 30));
    });
  });

  group('habits', () {
    test('30 days in a row: Bushi; a missed day starts the run over', () {
      for (var d = 0; d < 20; d++) {
        now = DateTime(2026, 1, 1 + d, 20);
        play(1, prefix: 'd$d-');
      }
      now = DateTime(2026, 1, 23, 20); // skipped the 21st and 22nd
      play(1, prefix: 'gap');
      expect(masks.progress('bushi'), (20, 30), reason: 'the best run is kept');
      for (var d = 0; d < 30; d++) {
        now = DateTime(2026, 1, 24 + d, 20);
        play(1, prefix: 'e$d-');
      }
      expect(masks.isUnlocked('bushi'), isTrue);
      expect(masks.progress('ryuuou'), (31, 100));
    });

    test('back after 14 days away: Porcelana', () {
      now = DateTime(2026, 3, 1, 12);
      play(1);
      now = DateTime(2026, 3, 10, 12);
      play(1, prefix: 'q');
      expect(masks.isUnlocked('jiki'), isFalse);
      now = DateTime(2026, 3, 25, 12);
      play(1, prefix: 'r');
      expect(masks.isUnlocked('jiki'), isTrue);
    });

    test('coming back 3 times: Kitsune de Porcelana', () {
      // The first time is not a comeback: four visits, three returns.
      for (var i = 0; i < 4; i++) {
        now = DateTime(2026, 1 + i * 2, 1, 12);
        play(1, prefix: 'c$i-');
        if (i == 2) expect(masks.progress('kitsune_jiki'), (2, 3));
      }
      expect(masks.isUnlocked('kitsune_jiki'), isTrue);
    });

    test('50 songs after midnight under the full moon: Kitsunebi (UL)', () {
      // Late nights without a full moon don't count.
      now = DateTime(2026, 11, 12, 2);
      play(60);
      expect(masks.progress('kitsunebi'), (0, 50));
      var day = DateTime(2026, 1, 1, 2);
      while (!MoonCalculator.snapshot(day).isFullMoonWindow) {
        day = day.add(const Duration(days: 1));
      }
      now = day;
      play(49, prefix: 'f');
      expect(masks.isUnlocked('kitsunebi'), isFalse);
      play(1, prefix: 'g');
      expect(masks.isUnlocked('kitsunebi'), isTrue);
      expect(MaskCatalog.byId('kitsunebi')!.rarity, MaskRarity.ul);
    });

    test('9 different full moons: Kitsune', () {
      var moons = 0;
      var day = DateTime(2025, 1, 1, 22);
      int? last;
      while (moons < 9) {
        if (MoonCalculator.snapshot(day).isFullMoonWindow && MaskProvider.lunationOf(day) != last) {
          last = MaskProvider.lunationOf(day);
          now = day;
          play(2, prefix: 'm$moons-');
          moons++;
          if (moons == 8) expect(masks.isUnlocked('kitsune'), isFalse);
        }
        day = day.add(const Duration(days: 1));
      }
      expect(masks.isUnlocked('kitsune'), isTrue);
    });

    test('the sleep timer, 10 nights (twice a night counts once): Oni de Sombra', () {
      for (var d = 0; d < 10; d++) {
        now = DateTime(2026, 2, 1 + d, 23);
        masks.onSleepTimerFinished();
        masks.onSleepTimerFinished();
        if (d == 8) expect(masks.progress('yami'), (9, 10));
      }
      expect(masks.isUnlocked('yami'), isTrue);
    });

    test('a 3-hour marathon; a long pause ends the session', () {
      var playing = true;
      masks.isMusicPlaying = () => playing;
      for (var m = 0; m < 120; m++) {
        masks.tick(const Duration(minutes: 1));
      }
      playing = false;
      for (var m = 0; m < 11; m++) {
        masks.tick(const Duration(minutes: 1));
      }
      playing = true;
      for (var m = 0; m < 120; m++) {
        masks.tick(const Duration(minutes: 1));
      }
      expect(masks.isUnlocked('hinome'), isFalse, reason: 'two sessions of 2 h');
      expect(masks.progress('hinome'), (120, 180));
      for (var m = 0; m < 3; m++) {
        playing = false;
        masks.tick(const Duration(minutes: 5)); // short breaks are fine
        playing = true;
        masks.tick(const Duration(minutes: 20));
      }
      expect(masks.isUnlocked('hinome'), isTrue);
    });
  });

  group('the app\'s sounds and the weather', () {
    test('hours with campfire, waves and wind', () {
      masks.ambientOn = () => {'fire', 'waves', 'wind'};
      for (var h = 0; h < 10; h++) {
        masks.tick(const Duration(hours: 1));
        if (h == 4) {
          expect(masks.isUnlocked('yougan'), isTrue);
          expect(masks.isUnlocked('fubuki'), isTrue);
          expect(masks.isUnlocked('umi'), isFalse);
        }
      }
      expect(masks.isUnlocked('umi'), isTrue);
    });

    test('a real storm or 3 h of storm sound: Rayo; 5 °C or less: Escarcha', () {
      masks.weatherNow = () => _weather(Sky.rain, 12);
      play(3);
      expect(masks.isUnlocked('inazuma'), isFalse);
      expect(masks.isUnlocked('tsurara'), isFalse);
      masks.weatherNow = () => _weather(Sky.storm, 4);
      play(1, prefix: 's');
      expect(masks.isUnlocked('inazuma'), isTrue);
      expect(masks.isUnlocked('tsurara'), isTrue);
    });

    test('weather off: nothing from it', () {
      masks.weatherNow = () => null;
      play(5);
      expect(masks.isUnlocked('tsurara'), isFalse);
    });
  });

  group('the app\'s features', () {
    test('synced lyrics of 50 different songs: Geisha', () {
      for (var i = 0; i < 49; i++) {
        masks.onLyricsShown('song$i');
        masks.onLyricsShown('song$i');
      }
      expect(masks.progress('geisha'), (49, 50));
      masks.onLyricsShown('song49');
      expect(masks.isUnlocked('geisha'), isTrue);
    });

    test('10 running sessions of 5 minutes or more: Kabuto', () {
      masks.onRunFinished(const Duration(minutes: 2));
      expect(masks.progress('kabuto'), (0, 10));
      for (var i = 0; i < 10; i++) {
        masks.onRunFinished(const Duration(minutes: 25));
      }
      expect(masks.isUnlocked('kabuto'), isTrue);
    });

    test('10 whole albums: Rey de Hierro', () async {
      album = const Album(id: 'x', title: 'A', coverUrl: '', artistId: '', artistName: '', tracksCount: 5);
      for (var a = 0; a < 10; a++) {
        for (var i = 0; i < 5; i++) {
          final t = _t('al$a-$i', albumId: 'album$a');
          masks.onTrackStarted(t);
          masks.onTrackCompleted(t);
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(masks.isUnlocked('kanpeki'), isTrue);
      expect(masks.isUnlocked('kanmuri'), isTrue);
    });

    test('500 songs of one artist: Akagane', () {
      play(499, artist: 'Ghost');
      expect(masks.isUnlocked('akagane'), isFalse);
      play(1, prefix: 'x', artist: 'Ghost');
      expect(masks.isUnlocked('akagane'), isTrue);
    });

    test('the 50th mask brings the Oni King', () {
      final ids = [for (final m in MaskCatalog.all) if (m.id != 'ou' && m.id != 'oni') m.id];
      for (final id in ids.take(48)) {
        masks.unlock(id);
      }
      expect(masks.isUnlocked('ou'), isFalse);
      masks.unlock(ids[48]);
      expect(masks.isUnlocked('ou'), isTrue);
    });

    test('the 75th mask brings the Kitsune King', () {
      final ids = [
        for (final m in MaskCatalog.all)
          if (m.counter != 'masks' && m.id != 'oni') m.id,
      ];
      for (final id in ids.take(72)) {
        masks.unlock(id);
      }
      // 72 + the Oni King = 73.
      expect(masks.isUnlocked('ou'), isTrue);
      expect(masks.isUnlocked('kitsune_ou'), isFalse);
      masks.unlock(ids[72]);
      expect(masks.isUnlocked('kitsune_ou'), isTrue, reason: '74 + itself');
    });

    test('El Oni still asks for the original achievements only', () {
      for (final m in MaskCatalog.oniSet) {
        masks.unlock(m.id);
      }
      expect(masks.isUnlocked('oni'), isTrue);
      expect(MaskCatalog.oniSet.any((m) => m.image != null), isFalse);
    });
  });

  group('backup', () {
    test('styles and counters travel with the account', () {
      for (var i = 0; i < 12; i++) {
        masks.onStyle(const StyleInfo(styles: {MusicStyle.jazz}));
      }
      masks.onLyricsShown('a');
      final snap = masks.progressSnapshot();
      expect((snap['styles'] as Map)['jazz'], 12);
      expect((snap['c'] as Map)['lyrics'], 1);

      // Another phone with more: the higher of each, and what it unlocks.
      expect(
          masks.applyProgress({
            'styles': {'jazz': 40},
            'c': {'lyrics': 60, 'streak': 3},
          }),
          isTrue);
      expect(masks.isUnlocked('jouki'), isTrue);
      expect(masks.isUnlocked('geisha'), isTrue);
    });

    test('the play log brings the best streak and the one going on', () {
      PlayDay day(String date) => PlayDay(
            date: date,
            plays: const {'a': 1},
            tracks: const {'a': PlayDayTrack(id: 'a', title: 'A', artistName: 'X')},
          );
      masks.applyHistory([
        for (var d = 1; d <= 31; d++) day('2026-10-${d.toString().padLeft(2, '0')}'),
        day('2026-11-10'),
        day('2026-11-11'),
      ]);
      expect(masks.isUnlocked('bushi'), isTrue, reason: '31 days in October');
      // The 10th and 11th, then today (the 12th): a run of 3.
      play(1);
      expect(masks.progress('ryuuou'), (31, 100));
      now = DateTime(2026, 11, 13, 15);
      play(1, prefix: 'n');
      now = DateTime(2026, 11, 20, 15);
      play(1, prefix: 'o');
      expect(masks.progress('ryuuou'), (31, 100), reason: 'the best stays');
    });

    test('every mask with a counter has a goal the progress can show', () {
      for (final m in MaskCatalog.all.where((m) => m.counter != null)) {
        if (m.goal == null) continue; // one-off moments (cold, coming back)
        expect(masks.progress(m.id), isNotNull, reason: m.id);
      }
    });
  });
}
