import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../data/contracts/music_api_contract.dart';
import '../data/contracts/storage_contract.dart';
import '../data/datasources/audio_precache_service.dart';
import '../data/datasources/deezer_api_service.dart';
import '../data/datasources/feature_flags.dart';
import '../data/datasources/firebase_service.dart';
import '../data/datasources/home_widget_service.dart';
import '../data/datasources/lyrics_service.dart';
import '../data/datasources/product_analytics.dart';
import '../data/datasources/rain_mix_service.dart';
import '../data/datasources/release_radar_service.dart';
import '../data/datasources/storage_service.dart';
import '../data/datasources/translation_service.dart';
import '../data/local/app_database.dart';
import '../data/local/library_store.dart';
import '../data/sync/outbox.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/product_events.dart';

/// The data sources. Most are process-wide singletons already (their
/// factory constructor returns one instance), so this hands that same
/// instance to whoever asks get_it, and a test can register a fake instead.
@module
abstract class DataModule {
  @lazySingleton
  FirebaseService get firebase => FirebaseService();

  /// Remote switches (Remote Config); started in main() once Firebase is.
  @lazySingleton
  FeatureFlags get featureFlags => FeatureFlags();

  /// Product analytics (Firebase Analytics), attached in main() once
  /// Firebase is up; the use cases report what people do through it.
  @lazySingleton
  ProductEvents get productEvents => ProductAnalytics.instance;

  @lazySingleton
  AppDatabase get database => AppDatabase.open();

  @lazySingleton
  LibraryStore libraryStore(AppDatabase database) => LibraryStore(database);

  /// Writes waiting to reach the server; each repository registers the
  /// handlers that send its kinds.
  @lazySingleton
  Outbox outbox(AppDatabase database) => Outbox(database);

  /// On the web the library stays in SharedPreferences: SQLite there needs
  /// extra wasm files the app doesn't ship.
  @lazySingleton
  StorageService storage(LibraryStore libraryStore) =>
      StorageService(localStore: kIsWeb ? null : libraryStore);

  @lazySingleton
  StorageContract storageContract(StorageService storage) => storage;

  @lazySingleton
  DeezerApiService get deezer => DeezerApiService();

  @lazySingleton
  MusicApiContract musicApi(DeezerApiService deezer) => deezer;

  @lazySingleton
  CatalogRepository catalog(DeezerApiService deezer) => deezer;

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
