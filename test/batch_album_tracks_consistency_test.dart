import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

List<Track> generateTracks(int count, {String albumId = 'album_1'}) => List.generate(
      count,
      (i) => Track(
        id: 'track_${albumId}_$i',
        title: 'Track $i',
        artistId: 'artist_1',
        artistName: 'Artist 1',
        albumId: albumId,
        albumTitle: 'Album 1',
        coverUrl: 'https://example.com/cover.jpg',
        previewUrl: 'https://example.com/audio_$i.mp3',
        durationSeconds: 180,
      ),
    );

ListenedTrackData _listened(Track t) => ListenedTrackData(
      trackId: t.id,
      title: t.title,
      artistName: t.fullArtistName,
      albumTitle: t.albumTitle,
      albumId: t.albumId,
      coverUrl: t.coverUrl,
      previewUrl: t.previewUrl,
      duration: t.durationSeconds,
      listenedAt: DateTime.now(),
    );

// Offline-first: a change shows at once and is saved on the phone; the
// outbox sends it in batches. A failure that may pass (network) keeps the
// change and retries it; only a refusal for good undoes it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'user_test_123';

  late AppDatabase phone;
  late LibraryRepositoryImpl library;

  LibraryRepositoryImpl open() {
    final lib = LibraryRepositoryImpl(store: LibraryStore(phone), outbox: Outbox(phone))
      ..bypassAuthForTesting = true
      ..setUidForTesting(uid)
      ..setListenedTracksLoadedForTesting(true);
    return lib;
  }

  Future<Map<int, int>> syncStates() async {
    final rows = await phone.select(phone.listenedTracks).get();
    final out = <int, int>{};
    for (final r in rows) {
      out[r.syncState] = (out[r.syncState] ?? 0) + 1;
    }
    return out;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    phone = AppDatabase(NativeDatabase.memory());
    library = open();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    library.disconnectFirestore(); // stops the retry timers
    await phone.close();
  });

  test('marking an album shows at once and is sent in batches of 450', () async {
    final chunks = <int>[];
    library.markAlbumChunkHandlerForTesting = (chunk, _) async => chunks.add(chunk.length);

    await library.markAlbumTracks(generateTracks(900), albumId: 'album_1', totalTracks: 900);
    expect(library.totalTracksCount, 900, reason: 'shown before the server answers');

    await library.pendingWritesSentForTesting();
    expect(chunks, [450, 450]);
    expect(await syncStates(), {SyncState.synced: 900});
  });

  test('a failure that may pass keeps the songs, and the retry sends them', () async {
    var calls = 0;
    library.markAlbumChunkHandlerForTesting = (chunk, _) async {
      if (++calls == 2) throw Exception('network timeout');
    };

    await library.markAlbumTracks(generateTracks(900), albumId: 'album_1', totalTracks: 900);
    await library.pendingWritesSentForTesting();

    expect(library.totalTracksCount, 900, reason: 'nothing is undone');
    expect(library.lastSyncError, isNull);
    expect(await syncStates(), {SyncState.synced: 450, SyncState.pendingUpsert: 450});

    // Back online.
    library.retryPendingSync();
    await Future<void>.delayed(Duration.zero);
    await library.pendingWritesSentForTesting();
    expect(calls, 3);
    expect(await syncStates(), {SyncState.synced: 900});
  });

  test('a refusal for good undoes only its batch and says so', () async {
    var calls = 0;
    library.markAlbumChunkHandlerForTesting = (chunk, _) async {
      if (++calls == 2) throw const PermanentSyncError('permission-denied');
    };

    await library.markAlbumTracks(generateTracks(900), albumId: 'album_1', totalTracks: 900);
    await library.pendingWritesSentForTesting();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(library.totalTracksCount, 450);
    expect(library.isTrackListened('track_album_1_0'), isTrue);
    expect(library.isTrackListened('track_album_1_899'), isFalse);
    expect(library.lastSyncError, 'mark_failed');
    expect(await syncStates(), {SyncState.synced: 450});
  });

  test('unmarking hides at once; the songs only leave once the server agrees', () async {
    final tracks = generateTracks(900);
    await library.setListenedTracksForTesting(tracks.map(_listened).toList());
    var calls = 0;
    library.unmarkAlbumChunkHandlerForTesting = (ids, _) async {
      if (++calls == 2) throw Exception('network timeout');
    };

    await library.unmarkAlbumTracks([for (final t in tracks) t.id]);
    await library.pendingWritesSentForTesting();

    expect(library.totalTracksCount, 0, reason: 'unmarked here at once');
    // The first batch of 240 is confirmed; the other 660 wait as hidden
    // tombstones (the failed batch blocks the ones behind it).
    expect(await syncStates(), {SyncState.pendingDelete: 660});
  });

  test('a refused unmark brings its songs back', () async {
    final tracks = generateTracks(480);
    await library.setListenedTracksForTesting(tracks.map(_listened).toList());
    var calls = 0;
    library.unmarkAlbumChunkHandlerForTesting = (ids, _) async {
      if (++calls == 1) throw const PermanentSyncError('permission-denied');
    };

    await library.unmarkAlbumTracks([for (final t in tracks) t.id]);
    await library.pendingWritesSentForTesting();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(library.totalTracksCount, 240, reason: 'the first batch of 240 comes back');
    expect(library.lastSyncError, 'unmark_failed');
    expect(await syncStates(), {SyncState.synced: 240});
  });

  test('songs marked offline survive closing the app and go up on reopening', () async {
    library.markAlbumChunkHandlerForTesting = (_, __) async => throw Exception('offline');
    await library.markAlbumTracks(generateTracks(3), albumId: 'album_1', totalTracks: 3);
    await library.pendingWritesSentForTesting();
    library.disconnectFirestore();

    // The app opens again: same phone database, new everything else.
    final sent = <String>[];
    library = open();
    library.markAlbumChunkHandlerForTesting = (chunk, _) async => sent.addAll(chunk.map((t) => t.trackId));
    library.retryPendingSync();
    await Future<void>.delayed(Duration.zero);
    await library.pendingWritesSentForTesting();

    expect(sent, hasLength(3));
    expect(await syncStates(), {SyncState.synced: 3});
  });
}
