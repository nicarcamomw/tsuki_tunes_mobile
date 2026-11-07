import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/spotify_service.dart';

class _TestableSpotifyService extends SpotifyService {
  List<Map<String, dynamic>> devicesToReturn = [];
  final List<String> transferredTo = [];

  @override
  Future<List<Map<String, dynamic>>> getDevices() async => devicesToReturn;

  @override
  Future<bool> transferPlayback(String deviceId) async {
    transferredTo.add(deviceId);
    return true;
  }
}

void main() {
  late _TestableSpotifyService svc;

  setUp(() => svc = _TestableSpotifyService());

  test('returns null when no devices at all', () async {
    svc.devicesToReturn = [];
    expect(await svc.ensureActiveDevice(), isNull);
  });

  test('returns active smartphone directly', () async {
    svc.devicesToReturn = [
      {'id': 'phone1', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': true},
      {'id': 'tv1', 'type': 'TV', 'name': 'Samsung TV', 'is_active': false},
    ];
    expect(await svc.ensureActiveDevice(), 'phone1');
    expect(svc.transferredTo, isEmpty);
  });

  test('transfers to inactive smartphone when no active phone', () async {
    svc.devicesToReturn = [
      {'id': 'phone1', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': false},
    ];
    expect(await svc.ensureActiveDevice(), 'phone1');
    expect(svc.transferredTo, ['phone1']);
  });

  test('ignores non-phone devices (TV, speaker) even if active', () async {
    svc.devicesToReturn = [
      {'id': 'tv1', 'type': 'TV', 'name': 'Samsung TV', 'is_active': true},
      {'id': 'spk1', 'type': 'Speaker', 'name': 'Echo', 'is_active': false},
    ];
    expect(await svc.ensureActiveDevice(), isNull);
    expect(svc.transferredTo, isEmpty);
  });

  test('prefers active phone over inactive phone', () async {
    svc.devicesToReturn = [
      {'id': 'phone1', 'type': 'Smartphone', 'name': 'Old Phone', 'is_active': false},
      {'id': 'phone2', 'type': 'Smartphone', 'name': 'New Phone', 'is_active': true},
    ];
    expect(await svc.ensureActiveDevice(), 'phone2');
    expect(svc.transferredTo, isEmpty);
  });

  test('phone plus TV: picks the phone, ignores the TV', () async {
    svc.devicesToReturn = [
      {'id': 'tv1', 'type': 'TV', 'name': 'Samsung TV', 'is_active': true},
      {'id': 'phone1', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': false},
    ];
    expect(await svc.ensureActiveDevice(), 'phone1');
    expect(svc.transferredTo, ['phone1']);
  });

  group('listening on another device (Spotify Connect)', () {
    final devices = [
      {'id': 'phone1', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': true},
      {'id': 'pc1', 'type': 'Computer', 'name': 'PC', 'is_active': false},
    ];

    Future<bool> listenOn(String id, String name, {bool isPhone = false}) {
      final client = MockClient((r) async {
        expect(r.method, 'PUT');
        expect(r.url.path, '/v1/me/player');
        expect(r.body, contains('"play":true'));
        return http.Response('', 204);
      });
      return http.runWithClient(() => svc.listenOn(id, name: name, isPhone: isPhone), () => client);
    }

    test('the chosen device stays the target while it is around', () async {
      svc.accessTokenForTesting = 'token';
      svc.devicesToReturn = devices;
      expect(await listenOn('pc1', 'PC'), isTrue);
      expect(svc.listeningOnName, 'PC');
      expect(await svc.ensureActiveDevice(), 'pc1');
      expect(svc.transferredTo, ['pc1'], reason: 'it was not the active one');
    });

    test('once it is gone, playback comes back to the phone', () async {
      svc.accessTokenForTesting = 'token';
      svc.devicesToReturn = devices;
      await listenOn('pc1', 'PC');
      svc.devicesToReturn = [devices.first];
      expect(await svc.ensureActiveDevice(), 'phone1');
      expect(svc.listeningOnName, isNull);
    });

    test('choosing a phone means this phone again', () async {
      svc.accessTokenForTesting = 'token';
      svc.devicesToReturn = devices;
      await listenOn('pc1', 'PC');
      await listenOn('phone1', 'Pixel', isPhone: true);
      expect(svc.listeningOnName, isNull);
      expect(await svc.ensureActiveDevice(), 'phone1');
    });
  });
}
