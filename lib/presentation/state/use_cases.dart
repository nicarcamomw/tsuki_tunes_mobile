import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/playback_controller.dart';
import '../../domain/usecases/library/mark_track_listened.dart';
import '../../domain/usecases/library/toggle_album_listened.dart';
import '../../domain/usecases/library/toggle_follow_artist.dart';
import '../../domain/usecases/library/toggle_track_listened.dart';
import '../../domain/usecases/library/unmark_track_listened.dart';
import '../../domain/usecases/playback/add_to_queue.dart';
import '../../domain/usecases/playback/play_next.dart';
import '../../domain/usecases/playback/play_track.dart';
import '../../domain/usecases/playback/play_tracks.dart';
import '../../domain/usecases/playback/start_radio.dart';
import 'app_providers.dart';

// The use cases, built on the repositories the app owns. Screens call
// these (ref.read(xProvider)(args)) instead of the repositories, and tests
// can override the repository underneath with a fake.
//
// `.notifier` hands over the repository without rebuilding the use case
// every time the repository notifies.

final libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) => ref.watch(libraryProvider.notifier));

final markTrackListenedProvider =
    Provider((ref) => MarkTrackListened(ref.watch(libraryRepositoryProvider)));

final unmarkTrackListenedProvider =
    Provider((ref) => UnmarkTrackListened(ref.watch(libraryRepositoryProvider)));

final toggleTrackListenedProvider =
    Provider((ref) => ToggleTrackListened(ref.watch(libraryRepositoryProvider)));

final toggleAlbumListenedProvider =
    Provider((ref) => ToggleAlbumListened(ref.watch(libraryRepositoryProvider)));

final toggleFollowArtistProvider =
    Provider((ref) => ToggleFollowArtist(ref.watch(libraryRepositoryProvider)));

// --- Playback

final playbackControllerProvider =
    Provider<PlaybackController>((ref) => ref.watch(audioProvider.notifier));

final playTrackProvider = Provider((ref) => PlayTrack(ref.watch(playbackControllerProvider)));

final playTracksProvider = Provider((ref) => PlayTracks(ref.watch(playbackControllerProvider)));

final playNextProvider = Provider((ref) => PlayNext(ref.watch(playbackControllerProvider)));

final addToQueueProvider = Provider((ref) => AddToQueue(ref.watch(playbackControllerProvider)));

final startRadioProvider = Provider((ref) => StartRadio(ref.watch(playbackControllerProvider)));
