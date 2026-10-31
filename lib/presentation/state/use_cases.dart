import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/injection.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/repositories/playback_controller.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/usecases/catalog/get_album.dart';
import '../../domain/usecases/catalog/get_artist.dart';
import '../../domain/usecases/catalog/get_track.dart';
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
import '../../domain/usecases/playlists/add_track_to_playlist.dart';
import '../../domain/usecases/playlists/create_playlist.dart';
import '../../domain/usecases/playlists/delete_playlist.dart';
import '../../domain/usecases/playlists/remove_track_from_playlist.dart';
import '../../domain/usecases/playlists/rename_playlist.dart';
import '../../domain/usecases/playlists/reorder_playlist.dart';
import 'app_providers.dart';

// The use cases for the screens, which call them (ref.read(xProvider)(args))
// instead of the repositories. They are built on the repositories in the
// Riverpod scope: in the app those are get_it's own instances, so these are
// the same use cases get_it hands out (code outside widgets, like Android
// Auto, takes them from get_it); in a test, the fakes it overrides.
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

// --- Playlists

final playlistRepositoryProvider =
    Provider<PlaylistRepository>((ref) => ref.watch(playlistProvider.notifier));

final createPlaylistProvider =
    Provider((ref) => CreatePlaylist(ref.watch(playlistRepositoryProvider)));

final addTrackToPlaylistProvider =
    Provider((ref) => AddTrackToPlaylist(ref.watch(playlistRepositoryProvider)));

final removeTrackFromPlaylistProvider =
    Provider((ref) => RemoveTrackFromPlaylist(ref.watch(playlistRepositoryProvider)));

final renamePlaylistProvider =
    Provider((ref) => RenamePlaylist(ref.watch(playlistRepositoryProvider)));

final deletePlaylistProvider =
    Provider((ref) => DeletePlaylist(ref.watch(playlistRepositoryProvider)));

final reorderPlaylistProvider =
    Provider((ref) => ReorderPlaylist(ref.watch(playlistRepositoryProvider)));

// --- Catalog

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => getIt<CatalogRepository>());

final getAlbumProvider = Provider((ref) => GetAlbum(ref.watch(catalogRepositoryProvider)));

final getArtistProvider = Provider((ref) => GetArtist(ref.watch(catalogRepositoryProvider)));

final getTrackProvider = Provider((ref) => GetTrack(ref.watch(catalogRepositoryProvider)));
