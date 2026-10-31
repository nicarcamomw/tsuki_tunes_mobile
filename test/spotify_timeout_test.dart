import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/spotify_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A connection that never answers.
  final stalled = MockClient((_) => Completer<http.Response>().future);

  testWidgets('a stalled Spotify request gives up instead of hanging', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'spotify_access_token': 'token',
      'spotify_refresh_token': 'refresh',
      'spotify_token_expiry':
          '${DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch}',
    });
    final spotify = SpotifyService();

    await http.runWithClient(() async {
      await tester.runAsync(spotify.loadSavedState);

      bool? paused;
      List<Map<String, dynamic>>? devices;
      unawaited(spotify.pause().then((v) => paused = v));
      unawaited(spotify.getDevices().then((v) => devices = v));

      await tester.pump(const Duration(seconds: 9));
      expect(paused, isNull, reason: 'still within the timeout');

      await tester.pump(const Duration(seconds: 2));
      expect(paused, isFalse);
      expect(devices, isEmpty);
    }, () => stalled);
  });
}
