import 'package:injectable/injectable.dart';

import '../data/contracts/music_api_contract.dart';
import '../data/contracts/storage_contract.dart';
import '../data/datasources/audio_precache_service.dart';
import '../data/datasources/deezer_api_service.dart';
import '../data/datasources/firebase_service.dart';
import '../data/datasources/home_widget_service.dart';
import '../data/datasources/lyrics_service.dart';
import '../data/datasources/rain_mix_service.dart';
import '../data/datasources/release_radar_service.dart';
import '../data/datasources/storage_service.dart';
import '../data/datasources/translation_service.dart';

/// The data sources. Most are process-wide singletons already (their
/// factory constructor returns one instance), so this hands that same
/// instance to whoever asks get_it, and a test can register a fake instead.
@module
abstract class DataModule {
  @lazySingleton
  FirebaseService get firebase => FirebaseService();

  @lazySingleton
  StorageService get storage => StorageService();

  @lazySingleton
  StorageContract storageContract(StorageService storage) => storage;

  @lazySingleton
  DeezerApiService get deezer => DeezerApiService();

  @lazySingleton
  MusicApiContract musicApi(DeezerApiService deezer) => deezer;

  @lazySingleton
  LyricsService get lyrics => LyricsService();

  @lazySingleton
  TranslationService get translation => TranslationService();

  @lazySingleton
  AudioPrecacheService get precache => AudioPrecacheService();

  @lazySingleton
  RainMixService get rainMix => RainMixService();

  @lazySingleton
  ReleaseRadarService get releaseRadar => ReleaseRadarService();

  @lazySingleton
  HomeWidgetService get homeWidget => HomeWidgetService();
}
