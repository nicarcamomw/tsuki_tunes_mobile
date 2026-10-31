import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/contracts/music_api_contract.dart';
import 'package:tsuki_tunes_mobile/data/contracts/storage_contract.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';

void main() {
  setUp(configureDependencies);
  tearDown(getIt.reset);

  test('the data sources are registered once, interfaces included', () {
    expect(getIt<DeezerApiService>(), same(DeezerApiService()));
    expect(getIt<MusicApiContract>(), same(getIt<DeezerApiService>()));
    expect(getIt<StorageContract>(), same(getIt<StorageService>()));
    expect(getIt<StorageService>(), same(getIt<StorageService>()));
  });
}
