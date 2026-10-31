import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/album.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/mask_provider.dart';

Track _t(String id, {String artist = 'Artist', String albumId = ''}) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: artist,
      albumId: albumId,
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
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

  test('first play unlocks and equips the first mask, with a celebration', () {
    masks.onPlayCounted(_t('1'));
    expect(masks.isUnlocked('hajime'), isTrue);
    expect(masks.equipped?.id, 'hajime');
    expect(masks.pendingCelebration, 'hajime');
    masks.dismissCelebration();
    expect(masks.pendingCelebration, isNull);
  });

  test('play count goals show progress and unlock at 250', () {
    for (var i = 0; i < 249; i++) {
      masks.onPlayCounted(_t('$i', artist: 'A$i'));
    }
    expect(masks.isUnlocked('hyaku'), isFalse);
    expect(masks.progress('hyaku'), (249, 250));
    masks.onPlayCounted(_t('x'));
    expect(masks.isUnlocked('hyaku'), isTrue);
  });

  test('night creature needs 50 plays after midnight', () {
    now = DateTime(2026, 11, 12, 1, 10);
    for (var i = 0; i < 50; i++) {
      masks.onPlayCounted(_t('$i'));
    }
    expect(masks.isUnlocked('yoru'), isTrue);
  });

  test('secret: listening at 3:33 AM', () {
    now = DateTime(2026, 11, 12, 3, 32);
    masks.onPlayCounted(_t('1'));
    expect(masks.isUnlocked('sanji'), isFalse);
    now = DateTime(2026, 11, 12, 3, 33, 40);
    masks.onTrackStarted(_t('2'));
    expect(masks.isUnlocked('sanji'), isTrue);
  });

  test('secret: Halloween night, also while a song just keeps playing', () {
    now = DateTime(2026, 10, 31, 21);
    masks.isMusicPlaying = () => true;
    masks.tick(const Duration(seconds: 30));
    expect(masks.isUnlocked('hannya'), isTrue);
  });

  test('secret: the same song 15 times in one day', () {
    for (var i = 0; i < 14; i++) {
      masks.onPlayCounted(_t('loop'));
    }
    expect(masks.isUnlocked('shuchaku'), isFalse);
    now = now.add(const Duration(days: 1));
    masks.onPlayCounted(_t('loop'));
    expect(masks.isUnlocked('shuchaku'), isFalse, reason: 'a new day starts over');
    for (var i = 0; i < 14; i++) {
      masks.onPlayCounted(_t('loop'));
    }
    expect(masks.isUnlocked('shuchaku'), isTrue);
  });

  test('wanderer counts only artists that are new, not ones heard before', () {
    masks.seedKnownArtists(['Known 0', 'Known 1']);
    masks.onPlayCounted(_t('k0', artist: 'Known 0'));
    masks.onPlayCounted(_t('k1', artist: 'Known 1'));
    for (var i = 0; i < 19; i++) {
      masks.onPlayCounted(_t('n$i', artist: 'New $i'));
    }
    expect(masks.isUnlocked('tabibito'), isFalse);
    expect(masks.progress('tabibito'), (19, 20));
    masks.onPlayCounted(_t('n19', artist: 'New 19'));
    expect(masks.isUnlocked('tabibito'), isTrue);
  });

  test('devotion: 100 plays of one artist', () {
    for (var i = 0; i < 100; i++) {
      now = now.add(const Duration(hours: 3));
      masks.onPlayCounted(_t('$i', artist: 'Chop Suey Fans, feat. X'));
    }
    expect(masks.isUnlocked('oshi'), isTrue);
  });

  test('full moon mask on the full moon night only', () {
    masks.onPlayCounted(_t('1'));
    expect(masks.isUnlocked('mangetsu'), isFalse);
    now = DateTime(2026, 10, 26, 1);
    masks.onPlayCounted(_t('2'));
    expect(masks.isUnlocked('mangetsu'), isTrue);
  });

  group('perfect album', () {
    final tracks = [for (var i = 0; i < 5; i++) _t('t$i', albumId: 'al')];

    setUp(() {
      album = const Album(
        id: 'al',
        title: 'Album',
        coverUrl: '',
        artistId: '',
        artistName: '',
        recordType: 'album',
        tracksCount: 5,
      );
    });

    test('every track played to the end unlocks it', () async {
      for (final t in tracks) {
        masks.onTrackStarted(t);
        masks.onTrackCompleted(t);
      }
      await Future<void>.delayed(Duration.zero);
      expect(masks.isUnlocked('kanpeki'), isTrue);
    });

    test('a single skip breaks the run', () async {
      for (final t in tracks) {
        masks.onTrackStarted(t);
        if (t.id != 't2') masks.onTrackCompleted(t);
      }
      await Future<void>.delayed(Duration.zero);
      expect(masks.isUnlocked('kanpeki'), isFalse);
    });

    test('singles and EPs do not count', () async {
      album = const Album(
        id: 'al', title: 'EP', coverUrl: '', artistId: '', artistName: '',
        recordType: 'ep', tracksCount: 5,
      );
      for (final t in tracks) {
        masks.onTrackStarted(t);
        masks.onTrackCompleted(t);
      }
      await Future<void>.delayed(Duration.zero);
      expect(masks.isUnlocked('kanpeki'), isFalse);
    });
  });

  test('rain spirit after ten hours of rain ambience', () {
    var raining = true;
    masks.isRainPlaying = () => raining;
    masks.tick(const Duration(hours: 9));
    raining = false;
    masks.tick(const Duration(hours: 2));
    expect(masks.isUnlocked('ame'), isFalse);
    expect(masks.progress('ame'), (9, 10));
    raining = true;
    masks.tick(const Duration(hours: 1));
    expect(masks.isUnlocked('ame'), isTrue);
  });

  test('guess game masks', () {
    masks.onDailyGuessFinished(won: true, attempts: 2, streak: 13);
    expect(masks.isUnlocked('mimi'), isFalse);
    expect(masks.isUnlocked('ren'), isFalse);
    masks.onDailyGuessFinished(won: true, attempts: 1, streak: 14);
    expect(masks.isUnlocked('mimi'), isTrue);
    expect(masks.isUnlocked('ren'), isTrue);
  });

  test('eclipse mask', () {
    masks.onEclipseSeen();
    expect(masks.isUnlocked('chizuki'), isTrue);
  });

  test('collecting every mask awards the legendary Oni', () {
    for (final m in MaskCatalog.all.where((m) => m.id != 'oni')) {
      masks.unlock(m.id);
    }
    expect(masks.isUnlocked('oni'), isTrue);
    expect(masks.unlockedCount, MaskCatalog.all.length);
  });

  test('only unlocked masks can be equipped, and everything persists', () async {
    masks.equip('sen');
    expect(masks.equipped, isNull);
    masks.unlock('hyaku');
    masks.unlock('sen');
    masks.equip('sen');
    expect(masks.equipped?.id, 'sen');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final reloaded = MaskProvider(clock: () => now);
    await reloaded.ready;
    expect(reloaded.isUnlocked('hyaku'), isTrue);
    expect(reloaded.equipped?.id, 'sen');
    reloaded.dispose();
  });

  test('catalog is consistent', () {
    final ids = MaskCatalog.all.map((m) => m.id).toSet();
    expect(ids.length, MaskCatalog.all.length);
    expect(MaskCatalog.all.where((m) => m.secret).length, greaterThanOrEqualTo(4));
    for (final m in MaskCatalog.all) {
      expect(m.dye == null || m.dye!.length == 20, isTrue, reason: m.id);
    }
  });

  test('signing out forgets the account\'s masks, a guest keeps theirs', () async {
    masks.setUser('account-1');
    masks.onPlayCounted(_t('1'));
    expect(masks.isUnlocked('hajime'), isTrue);

    masks.setUser(null);
    await Future<void>.delayed(Duration.zero);
    expect(masks.isUnlocked('hajime'), isFalse);
    expect(masks.equipped, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('masks_unlocked_v1'), '{}');

    // Guests (never signed in) keep what they unlock.
    masks.onPlayCounted(_t('2'));
    masks.setUser(null);
    await Future<void>.delayed(Duration.zero);
    expect(masks.isUnlocked('hajime'), isTrue);
  });
}
