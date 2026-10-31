import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/contracts/music_api_contract.dart';
import 'package:tsuki_tunes_mobile/data/contracts/storage_contract.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/library_repository.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/playback_controller.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/playlist_repository.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // flutter_test_config.dart configures a fresh get_it before each test.

  test('the data sources are registered once, interfaces included', () {
    expect(getIt<DeezerApiService>(), same(DeezerApiService()));
    expect(getIt<MusicApiContract>(), same(getIt<DeezerApiService>()));
    expect(getIt<StorageContract>(), same(getIt<StorageService>()));
    expect(getIt<StorageService>(), same(getIt<StorageService>()));
  });

  test('repositories and the player: one instance behind each interface', () {
    expect(getIt<LibraryRepository>(), same(getIt<LibraryRepositoryImpl>()));
    expect(getIt<PlaylistRepository>(), same(getIt<PlaylistRepositoryImpl>()));
    expect(getIt<PlaybackController>(), same(getIt<AudioProvider>()));
  });

  test('Riverpod hands the screens the instances get_it owns', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(libraryProvider), same(getIt<LibraryRepositoryImpl>()));
    expect(container.read(playlistProvider), same(getIt<PlaylistRepositoryImpl>()));
    expect(container.read(audioProvider), same(getIt<AudioProvider>()));
  });
}
