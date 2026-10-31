import 'package:injectable/injectable.dart';

import '../data/datasources/firebase_service.dart';
import '../data/datasources/storage_service.dart';
import '../data/local/library_store.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/playlist_repository_impl.dart';
import '../data/sync/outbox.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/playback_controller.dart';
import '../domain/repositories/playlist_repository.dart';
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
  ) =>
      LibraryRepositoryImpl(firebase: firebase, storage: storage, store: store, outbox: outbox);

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
  AudioProvider player(StorageService storage) => AudioProvider(storage: storage);

  @lazySingleton
  PlaybackController playback(AudioProvider player) => player;
}
