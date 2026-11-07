import 'package:injectable/injectable.dart';

import '../data/datasources/deezer_api_service.dart';
import '../data/datasources/feature_flags.dart';
import '../data/datasources/firebase_service.dart';
import '../data/datasources/storage_service.dart';
import '../data/local/library_store.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/party_repository_impl.dart';
import '../data/repositories/playlist_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../data/repositories/shared_playlist_repository_impl.dart';
import '../data/repositories/social_repository_impl.dart';
import '../data/sync/outbox.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/party_repository.dart';
import '../domain/repositories/playback_controller.dart';
import '../domain/repositories/playlist_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/shared_playlist_repository.dart';
import '../domain/repositories/social_repository.dart';
import '../presentation/state/audio_provider.dart';

/// The repositories and the player, each registered once under its own
/// class (the screens read its state) and under the domain interface the
/// use cases depend on, both pointing at the same instance.
@module
abstract class RepositoryModule {
  @lazySingleton
  LibraryRepositoryImpl library(
    FirebaseService firebase,
    StorageService storage,
    LibraryStore store,
    Outbox outbox,
    DeezerApiService deezer,
  ) =>
      LibraryRepositoryImpl(
        firebase: firebase,
        storage: storage,
        store: store,
        outbox: outbox,
        // Old songs learn their artist lists from the catalog.
        lookupTrack: deezer.getTrack,
      );

  @lazySingleton
  LibraryRepository libraryRepository(LibraryRepositoryImpl library) => library;

  @lazySingleton
  PlaylistRepositoryImpl playlists(
    FirebaseService firebase,
    StorageService storage,
    LibraryStore store,
    Outbox outbox,
  ) =>
      PlaylistRepositoryImpl(firebase: firebase, storage: storage, store: store, outbox: outbox);

  @lazySingleton
  PlaylistRepository playlistRepository(PlaylistRepositoryImpl playlists) => playlists;

  /// The one player. It has to exist before any widget: Android Auto can
  /// start the app with no screen.
  @lazySingleton
  AudioProvider player(StorageService storage, FeatureFlags flags) =>
      AudioProvider(storage: storage, flags: flags);

  @lazySingleton
  PlaybackController playback(AudioProvider player) => player;

  @lazySingleton
  ProfileRepository profiles(FirebaseService firebase) => ProfileRepositoryImpl(firebase);

  @lazySingleton
  SocialRepository social(FirebaseService firebase) => SocialRepositoryImpl(firebase);

  @lazySingleton
  SharedPlaylistRepository sharedPlaylists(FirebaseService firebase) => SharedPlaylistRepositoryImpl(firebase);

  @lazySingleton
  PartyRepository parties(FirebaseService firebase) => PartyRepositoryImpl(firebase);
}
