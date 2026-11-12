import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/auto_media_library.dart';
import 'package:tsuki_tunes_mobile/data/datasources/media_session_handler.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: 'https://e-cdns-images.dzcdn.net/images/cover/$id/250x250.jpg',
      previewUrl: 'https://e/$id.mp3',
      durationSeconds: 200,
    );

class _Player extends AudioPlayerService {
  final played = <String>[];

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async =>
      played.add(track.id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AutoArtwork.authority = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'), (call) async => {});
      }
      return {};
    });
  });

  tearDown(() => AutoArtwork.authority = null);

  group('album art in the car', () {
    test('covers go through the app\'s artwork provider', () {
      AutoArtwork.authority = 'com.tsuki.tsuki_tunes_mobile.artwork';
      const cover = 'https://e-cdns-images.dzcdn.net/images/cover/x/250x250.jpg';
      final uri = AutoArtwork.uri(cover)!;
      expect(uri.scheme, 'content');
      expect(uri.host, 'com.tsuki.tsuki_tunes_mobile.artwork');
      expect(uri.queryParameters['u'], cover);
    });

    test('off Android the link is used as it is, and no cover is no art', () {
      expect(AutoArtwork.uri('https://x/y.jpg').toString(), 'https://x/y.jpg');
      expect(AutoArtwork.uri(''), isNull);
    });

    test('the lists Auto browses carry provider URIs', () async {
      AutoArtwork.authority = 'app.artwork';
      final storage = StorageService();
      await storage.saveFavoriteTracks([_t('1')]);
      final library = AutoMediaLibrary(
        play: (_, __) async {},
        storage: storage,
        currentUid: () async => null,
      );
      final items = await library.children(AutoMediaLibrary.favoritesId);
      expect(items.single.artUri?.scheme, 'content');
    });
  });

  group('the queue in the car', () {
    test('Auto gets the song playing and the next ones, and can jump to one', () async {
      final player = _Player();
      final handler = TsukiAudioHandler();
      final audio = AudioProvider(service: player, storage: StorageService(), mediaHandler: handler);
      final tracks = [_t('a'), _t('b'), _t('c'), _t('d')];
      await audio.playTrack(tracks[1], newQueue: tracks);
      await Future<void>.delayed(Duration.zero);

      final queue = handler.queue.value;
      expect(queue.map((m) => m.title), ['Song b', 'Song c', 'Song d']);
      expect(handler.playbackState.value.queueIndex, 0);

      await handler.skipToQueueItem(2);
      expect(player.played.last, 'd');
      expect(audio.currentTrack?.id, 'd');
      await Future<void>.delayed(Duration.zero);
      expect(handler.queue.value.map((m) => m.title), ['Song d']);
    });

    test('a queue edit reaches the car', () async {
      final handler = TsukiAudioHandler();
      final audio = AudioProvider(service: _Player(), storage: StorageService(), mediaHandler: handler);
      await audio.playTrack(_t('a'), newQueue: [_t('a'), _t('b')]);
      await Future<void>.delayed(Duration.zero);
      audio.addToQueue(_t('z'));
      await Future<void>.delayed(Duration.zero);
      // Queued songs play right after the current one: the car shows that order.
      expect(handler.queue.value.map((m) => m.title), ['Song a', 'Song z', 'Song b']);
    });
  });
}
