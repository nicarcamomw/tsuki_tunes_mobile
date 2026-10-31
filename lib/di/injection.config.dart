// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:tsuki_tunes_mobile/data/contracts/music_api_contract.dart'
    as _i372;
import 'package:tsuki_tunes_mobile/data/contracts/storage_contract.dart'
    as _i298;
import 'package:tsuki_tunes_mobile/data/datasources/audio_precache_service.dart'
    as _i316;
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart'
    as _i814;
import 'package:tsuki_tunes_mobile/data/datasources/firebase_service.dart'
    as _i186;
import 'package:tsuki_tunes_mobile/data/datasources/home_widget_service.dart'
    as _i887;
import 'package:tsuki_tunes_mobile/data/datasources/lyrics_service.dart'
    as _i416;
import 'package:tsuki_tunes_mobile/data/datasources/rain_mix_service.dart'
    as _i957;
import 'package:tsuki_tunes_mobile/data/datasources/release_radar_service.dart'
    as _i642;
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart'
    as _i905;
import 'package:tsuki_tunes_mobile/data/datasources/translation_service.dart'
    as _i1031;
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart'
    as _i424;
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart'
    as _i553;
import 'package:tsuki_tunes_mobile/di/data_module.dart' as _i520;
import 'package:tsuki_tunes_mobile/di/repository_module.dart' as _i53;
import 'package:tsuki_tunes_mobile/domain/repositories/catalog_repository.dart'
    as _i1049;
import 'package:tsuki_tunes_mobile/domain/repositories/library_repository.dart'
    as _i409;
import 'package:tsuki_tunes_mobile/domain/repositories/playback_controller.dart'
    as _i802;
import 'package:tsuki_tunes_mobile/domain/repositories/playlist_repository.dart'
    as _i128;
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_album.dart'
    as _i741;
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_artist.dart'
    as _i190;
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_track.dart'
    as _i9;
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_album.dart'
    as _i401;
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_track_listened.dart'
    as _i135;
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_album_listened.dart'
    as _i83;
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_follow_artist.dart'
    as _i6;
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_track_listened.dart'
    as _i42;
import 'package:tsuki_tunes_mobile/domain/usecases/library/unmark_album.dart'
    as _i522;
import 'package:tsuki_tunes_mobile/domain/usecases/library/unmark_track_listened.dart'
    as _i102;
import 'package:tsuki_tunes_mobile/domain/usecases/playback/add_to_queue.dart'
    as _i317;
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_next.dart'
    as _i740;
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_track.dart'
    as _i373;
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_tracks.dart'
    as _i639;
import 'package:tsuki_tunes_mobile/domain/usecases/playback/start_radio.dart'
    as _i1002;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/add_track_to_playlist.dart'
    as _i883;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/create_playlist.dart'
    as _i79;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/delete_playlist.dart'
    as _i371;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/remove_track_from_playlist.dart'
    as _i161;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/rename_playlist.dart'
    as _i758;
import 'package:tsuki_tunes_mobile/domain/usecases/playlists/reorder_playlist.dart'
    as _i670;
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart'
    as _i1052;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final dataModule = _$DataModule();
    final repositoryModule = _$RepositoryModule();
    gh.lazySingleton<_i186.FirebaseService>(() => dataModule.firebase);
    gh.lazySingleton<_i905.StorageService>(() => dataModule.storage);
    gh.lazySingleton<_i814.DeezerApiService>(() => dataModule.deezer);
    gh.lazySingleton<_i416.LyricsService>(() => dataModule.lyrics);
    gh.lazySingleton<_i1031.TranslationService>(() => dataModule.translation);
    gh.lazySingleton<_i316.AudioPrecacheService>(() => dataModule.precache);
    gh.lazySingleton<_i957.RainMixService>(() => dataModule.rainMix);
    gh.lazySingleton<_i642.ReleaseRadarService>(() => dataModule.releaseRadar);
    gh.lazySingleton<_i887.HomeWidgetService>(() => dataModule.homeWidget);
    gh.lazySingleton<_i424.LibraryRepositoryImpl>(
      () => repositoryModule.library(
        gh<_i186.FirebaseService>(),
        gh<_i905.StorageService>(),
      ),
    );
    gh.lazySingleton<_i553.PlaylistRepositoryImpl>(
      () => repositoryModule.playlists(
        gh<_i186.FirebaseService>(),
        gh<_i905.StorageService>(),
      ),
    );
    gh.lazySingleton<_i372.MusicApiContract>(
      () => dataModule.musicApi(gh<_i814.DeezerApiService>()),
    );
    gh.lazySingleton<_i1049.CatalogRepository>(
      () => dataModule.catalog(gh<_i814.DeezerApiService>()),
    );
    gh.lazySingleton<_i128.PlaylistRepository>(
      () => repositoryModule.playlistRepository(
        gh<_i553.PlaylistRepositoryImpl>(),
      ),
    );
    gh.lazySingleton<_i298.StorageContract>(
      () => dataModule.storageContract(gh<_i905.StorageService>()),
    );
    gh.lazySingleton<_i1052.AudioProvider>(
      () => repositoryModule.player(gh<_i905.StorageService>()),
    );
    gh.factory<_i741.GetAlbum>(
      () => _i741.GetAlbum(gh<_i1049.CatalogRepository>()),
    );
    gh.factory<_i190.GetArtist>(
      () => _i190.GetArtist(gh<_i1049.CatalogRepository>()),
    );
    gh.factory<_i9.GetTrack>(
      () => _i9.GetTrack(gh<_i1049.CatalogRepository>()),
    );
    gh.factory<_i883.AddTrackToPlaylist>(
      () => _i883.AddTrackToPlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.factory<_i79.CreatePlaylist>(
      () => _i79.CreatePlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.factory<_i371.DeletePlaylist>(
      () => _i371.DeletePlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.factory<_i161.RemoveTrackFromPlaylist>(
      () => _i161.RemoveTrackFromPlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.factory<_i758.RenamePlaylist>(
      () => _i758.RenamePlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.factory<_i670.ReorderPlaylist>(
      () => _i670.ReorderPlaylist(gh<_i128.PlaylistRepository>()),
    );
    gh.lazySingleton<_i409.LibraryRepository>(
      () =>
          repositoryModule.libraryRepository(gh<_i424.LibraryRepositoryImpl>()),
    );
    gh.lazySingleton<_i802.PlaybackController>(
      () => repositoryModule.playback(gh<_i1052.AudioProvider>()),
    );
    gh.factory<_i317.AddToQueue>(
      () => _i317.AddToQueue(gh<_i802.PlaybackController>()),
    );
    gh.factory<_i740.PlayNext>(
      () => _i740.PlayNext(gh<_i802.PlaybackController>()),
    );
    gh.factory<_i373.PlayTrack>(
      () => _i373.PlayTrack(gh<_i802.PlaybackController>()),
    );
    gh.factory<_i639.PlayTracks>(
      () => _i639.PlayTracks(gh<_i802.PlaybackController>()),
    );
    gh.factory<_i1002.StartRadio>(
      () => _i1002.StartRadio(gh<_i802.PlaybackController>()),
    );
    gh.factory<_i83.ToggleAlbumListened>(
      () => _i83.ToggleAlbumListened(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i401.MarkAlbum>(
      () => _i401.MarkAlbum(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i135.MarkTrackListened>(
      () => _i135.MarkTrackListened(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i6.ToggleFollowArtist>(
      () => _i6.ToggleFollowArtist(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i42.ToggleTrackListened>(
      () => _i42.ToggleTrackListened(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i522.UnmarkAlbum>(
      () => _i522.UnmarkAlbum(gh<_i409.LibraryRepository>()),
    );
    gh.factory<_i102.UnmarkTrackListened>(
      () => _i102.UnmarkTrackListened(gh<_i409.LibraryRepository>()),
    );
    return this;
  }
}

class _$DataModule extends _i520.DataModule {}

class _$RepositoryModule extends _i53.RepositoryModule {}
