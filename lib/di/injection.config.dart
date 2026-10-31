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
import 'package:tsuki_tunes_mobile/domain/repositories/library_repository.dart'
    as _i409;
import 'package:tsuki_tunes_mobile/domain/repositories/playback_controller.dart'
    as _i802;
import 'package:tsuki_tunes_mobile/domain/repositories/playlist_repository.dart'
    as _i128;
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
    gh.lazySingleton<_i409.LibraryRepository>(
      () =>
          repositoryModule.libraryRepository(gh<_i424.LibraryRepositoryImpl>()),
    );
    gh.lazySingleton<_i802.PlaybackController>(
      () => repositoryModule.playback(gh<_i1052.AudioProvider>()),
    );
    return this;
  }
}

class _$DataModule extends _i520.DataModule {}

class _$RepositoryModule extends _i53.RepositoryModule {}
