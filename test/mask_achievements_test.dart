import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/weather_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/play_day.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/moon_calculator.dart';
import 'package:tsuki_tunes_mobile/domain/logic/music_styles.dart';
import 'package:tsuki_tunes_mobile/domain/lore/tsuki_lore.dart';
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

  /// Goals come from the catalog: rarities (and so goals) get tuned.
  int goal(String id) => MaskCatalog.byId(id)!.goal!;

  void play(int n, {String prefix = 'p', String artist = 'Artist'}) {
    for (var i = 0; i < n; i++) {
      masks.onPlayCounted(_t('$prefix$i', artist: artist));
    }
  }

  group('music styles', () {
    test('metal songs: Oni de Acero, with progress on the way', () {
      final n = goal('tetsu');
      for (var i = 0; i < n - 1; i++) {
        masks.onStyle(const StyleInfo(styles: {MusicStyle.metal}));
      }
      expect(masks.progress('tetsu'), (n - 1, n));
      expect(masks.isUnlocked('tetsu'), isFalse);
      masks.onStyle(const StyleInfo(styles: {MusicStyle.metal}));
      expect(masks.isUnlocked('tetsu'), isTrue);
    });

    test('a song counts for every family it belongs to', () {
      for (var i = 0; i < goal('kumo'); i++) {
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

    test('different countries: Jade; the same one twice counts once', () {
      final n = goal('hisui');
      const all = ['JP', 'KR', 'CL', 'AR', 'MX', 'US', 'GB', 'SE', 'FR', 'BR', 'DE', 'IT'];
      masks.onStyle(const StyleInfo(countries: {'JP'}));
      for (final c in all.take(n - 1)) {
        masks.onStyle(StyleInfo(countries: {c}));
      }
      expect(masks.progress('hisui'), (n - 1, n));
      masks.onStyle(StyleInfo(countries: {all[n - 1]}));
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
      for (var i = 0; i < goal('homura'); i++) {
        masks.onPlayCounted(_t('fast$i'));
      }
      for (var i = 0; i < goal('kin_oni'); i++) {
        masks.onPlayCounted(_t('hit$i', rank: 900000));
      }
      for (var i = 0; i < goal('doku'); i++) {
        masks.onPlayCounted(_t('exp$i', explicit: true));
      }
      for (var i = 0; i < goal('meisai'); i++) {
        masks.onPlayCounted(_t('gem$i', rank: 42000));
      }
      expect(masks.isUnlocked('homura'), isTrue);
      expect(masks.isUnlocked('kin_oni'), isTrue);
      expect(masks.isUnlocked('doku'), isTrue);
      expect(masks.isUnlocked('meisai'), isTrue);
    });

    test('unknown rank or tempo counts for nothing', () {
      play(60);
      for (final id in ['homura', 'kin_oni', 'meisai']) {
        expect(masks.progress(id), (0, goal(id)));
      }
    });
  });

  group('habits', () {
    test('30 days in a row: Bushi; days missed beyond the moon shields start over', () {
      for (var d = 0; d < 20; d++) {
        now = DateTime(2026, 1, 1 + d, 20);
        play(1, prefix: 'd$d-');
      }
      // 20 days earned the two shields; three days missed is one too many.
      now = DateTime(2026, 1, 24, 20);
      play(1, prefix: 'gap');
      expect(masks.progress('bushi'), (20, 30), reason: 'the best run is kept');
      for (var d = 0; d < 30; d++) {
        now = DateTime(2026, 1, 25 + d, 20);
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

    test('sleep-timer nights (twice a night counts once): Oni de Sombra', () {
      final n = goal('yami');
      for (var d = 0; d < n; d++) {
        now = DateTime(2026, 2, 1 + d, 23);
        masks.onSleepTimerFinished();
        masks.onSleepTimerFinished();
        if (d == n - 2) expect(masks.progress('yami'), (n - 1, n));
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
      final fire = goal('yougan');
      for (var h = 0; h < goal('umi'); h++) {
        masks.tick(const Duration(hours: 1));
        if (h == fire - 1) {
          expect(masks.isUnlocked('yougan'), isTrue);
          expect(masks.isUnlocked('fubuki'), goal('fubuki') <= fire);
          expect(masks.isUnlocked('umi'), isFalse);
        }
      }
      expect(masks.isUnlocked('umi'), isTrue);
      expect(masks.isUnlocked('fubuki'), isTrue);
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

    test('running sessions of 5 minutes or more: Kabuto', () {
      masks.onRunFinished(const Duration(minutes: 2));
      expect(masks.progress('kabuto'), (0, goal('kabuto')));
      for (var i = 0; i < goal('kabuto'); i++) {
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

    // Unlocking masks can complete clans, whose masks come too: what
    // matters is that each collector arrives exactly with its count.
    for (final (king, count) in [('ou', 50), ('kitsune_ou', 75)]) {
      test('the ${count}th mask brings $king', () {
        final ids = [
          for (final m in MaskCatalog.all)
            if (m.counter != 'masks' && m.id != 'oni') m.id,
        ];
        for (final id in ids) {
          if (masks.isUnlocked(king)) break;
          masks.unlock(id);
          expect(masks.isUnlocked(king), masks.unlockedCount >= count,
              reason: '${masks.unlockedCount} masks');
        }
        expect(masks.isUnlocked(king), isTrue);
      });
    }

    test('the 7 divine masks bring the God of the Universe; the ultra ones the Fallen God', () {
      final divine = [for (final m in MaskCatalog.all) if (m.divine) m.id];
      for (final id in divine.take(6)) {
        masks.unlock(id);
      }
      expect(masks.progress('uchuu_shin'), (6, 7));
      expect(masks.isUnlocked('uchuu_shin'), isFalse);
      masks.unlock(divine.last);
      expect(masks.isUnlocked('uchuu_shin'), isTrue);

      final ultra = [
        for (final m in MaskCatalog.all)
          if (m.rarity == MaskRarity.ul && !m.divine && m.counter != 'ethereal') m.id,
      ];
      for (final id in ultra.take(ultra.length - 1)) {
        masks.unlock(id);
      }
      expect(masks.isUnlocked('ochigami'), isFalse);
      masks.unlock(ultra.last);
      expect(masks.isUnlocked('ochigami'), isTrue);
    });

    test('a whole clan awakens its clan mask', () {
      final zorro = TsukiLore.faction('zorro')!;
      for (final id in zorro.members.take(zorro.members.length - 1)) {
        masks.unlock(id);
      }
      expect(masks.isUnlocked('kyuubi'), isFalse);
      expect(masks.progress('kyuubi'), (zorro.members.length - 1, zorro.members.length));
      masks.unlock(zorro.members.last);
      expect(masks.isUnlocked('kyuubi'), isTrue);
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
