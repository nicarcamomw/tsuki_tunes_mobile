import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crossfade Settings & Storage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default crossfade seconds is 3', () async {
      final storage = StorageService();
      final seconds = await storage.getCrossfadeSeconds();
      expect(seconds, equals(3));
    });

    test('Saving and retrieving crossfade seconds works', () async {
      final storage = StorageService();
      await storage.saveCrossfadeSeconds(6);
      final retrieved = await storage.getCrossfadeSeconds();
      expect(retrieved, equals(6));
    });

    test('Disabled crossfade (0 seconds) persists cleanly', () async {
      final storage = StorageService();
      await storage.saveCrossfadeSeconds(0);
      final retrieved = await storage.getCrossfadeSeconds();
      expect(retrieved, equals(0));
    });

    test('Max crossfade (12 seconds) persists cleanly', () async {
      final storage = StorageService();
      await storage.saveCrossfadeSeconds(12);
      final retrieved = await storage.getCrossfadeSeconds();
      expect(retrieved, equals(12));
    });
  });

}
