import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tsuki_storage_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  List<Map<String, dynamic>> tracks(int n) =>
      [for (var i = 0; i < n; i++) {'trackId': '$i', 'title': 'Song $i'}];

  test('the library moves out of SharedPreferences into its own file', () async {
    SharedPreferences.setMockInitialValues({
      'tsuki_cached_tracks_u1': jsonEncode(tracks(3)),
    });
    final storage = StorageService();

    final loaded = await storage.getCachedListenedTracks('u1');
    expect(loaded.map((t) => t['trackId']), ['0', '1', '2']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('tsuki_cached_tracks_u1'), isFalse);
    expect(File('${dir.path}/listened_tracks_u1.json').existsSync(), isTrue);
    expect((await storage.getCachedListenedTracks('u1')).length, 3);
  });

  test('big libraries round-trip, and the last save wins', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    // Fired back to back: they must land in order.
    final first = storage.saveCachedListenedTracks('u2', tracks(1000));
    final second = storage.saveCachedListenedTracks('u2', tracks(1200));
    await Future.wait([first, second]);

    final loaded = await storage.getCachedListenedTracks('u2');
    expect(loaded.length, 1200);
    expect(loaded.last['title'], 'Song 1199');
    expect(File('${dir.path}/listened_tracks_u2.json.tmp').existsSync(), isFalse);
  });
}
