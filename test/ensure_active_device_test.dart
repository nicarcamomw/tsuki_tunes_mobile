import 'package:flutter_test/flutter_test.dart';
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
}
