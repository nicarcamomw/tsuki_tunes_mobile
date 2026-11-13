import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/utils/image_quality.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/presentation/state/image_quality_setting.dart';

// U7: the image quality setting.

const _cover = 'https://e-cdns-images.dzcdn.net/images/cover/abc123/250x250-000000-80-0-0.jpg';
const _xl = 'https://e-cdns-images.dzcdn.net/images/artist/f00/1000x1000-000000-80-0-0.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a Deezer image can be asked at any size; others are left alone', () {
    expect(deezerImageAt(_cover, 1000), contains('/1000x1000-000000'));
    expect(deezerImageAt(_xl, 250), contains('/250x250-000000'));
    expect(deezerImageAt('https://example.com/a/250x250-1.jpg', 1000), 'https://example.com/a/250x250-1.jpg');
    expect(deezerImageAt('', 1000), '');
  });

  test('normal is as always; high and data saver change only large images\' size', () {
    expect(ImageQuality.normal.large(_cover), _cover);
    expect(ImageQuality.normal.large(_xl), _xl);
    expect(ImageQuality.high.large(_cover), contains('/1000x1000-'));
    expect(ImageQuality.dataSaver.large(_xl), contains('/250x250-'));
  });

  test('an unknown or missing choice is normal', () {
    expect(ImageQuality.fromName(null), ImageQuality.normal);
    expect(ImageQuality.fromName('ultra'), ImageQuality.normal);
    expect(ImageQuality.fromName('dataSaver'), ImageQuality.dataSaver);
  });

  test('the choice is kept on the phone', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ImageQualitySetting(StorageService());
    expect(first.quality, ImageQuality.normal);
    await first.set(ImageQuality.dataSaver);
    expect(first.large(_cover), contains('/250x250-'));

    final again = ImageQualitySetting(StorageService());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(again.quality, ImageQuality.dataSaver);
  });
}
