import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/play_history.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/ambient_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/library_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/playlist_provider.dart';

import 'helpers/fake_firebase_service.dart';

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AudioProvider player;
  late LibraryProvider library;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'), (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    player = AudioProvider();
    library = LibraryProvider(firebase: FakeFirebaseService(FakeFirebaseFirestore()));
    await library.connectToFirestore('u1');
    await pumpEventQueue();
    // The whole graph without a single widget: only the pieces that would
    // reach plugins or Firebase are replaced.
    container = ProviderContainer(overrides: [
      audioProvider.overrideWith((ref) => player),
      libraryProvider.overrideWith((ref) => library),
      playlistProvider.overrideWith((ref) => PlaylistProvider()),
      ambientProvider.overrideWith((ref) => AmbientProvider()),
      playHistoryProvider.overrideWith((ref) => PlayHistory()),
      maskProvider.overrideWith((ref) => MaskProvider()),
    ]);
    addTearDown(() async {
      await pumpEventQueue();
      container.dispose();
    });
  });

  test('the player reports to the library once the app wires it', () async {
    expect(player.onTrackStarted, isNull);
    container.read(playbackWiringProvider);

    final song = _track('t1');
    expect(container.read(isTrackListenedProvider('t1')), isFalse);

    player.onTrackStarted!(song);
    expect(library.recentTracks.map((t) => t.id), contains('t1'));

    player.onListenedThreshold!(song);
    await pumpEventQueue();
    expect(library.isTrackListened('t1'), isTrue);
    expect(container.read(isTrackListenedProvider('t1')), isTrue);
  });

  test('a derived provider only notifies for its own song', () async {
    final changes = <bool>[];
    container.listen<bool>(isTrackListenedProvider('t2'), (_, v) => changes.add(v));

    await library.markTrack(_track('t1'));
    await library.markTrack(_track('t2'));
    await pumpEventQueue();

    expect(changes, [true]);
  });
}
