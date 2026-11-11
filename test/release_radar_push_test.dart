import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/release_radar_service.dart';

// The server pushes new releases (functions/src/radar.ts) and the phone's
// own daily check keeps running as the fallback: whichever finds a release
// first tells about it, and the other one stays quiet.

String _daysAgo(int days) =>
    DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);

Map<String, dynamic> _release(String albumId, {String artistId = '27', int daysAgo = 1}) => {
      'albumId': albumId,
      'title': 'Album $albumId',
      'artistId': artistId,
      'artistName': 'Daft Punk',
      'coverUrl': '',
      'releaseDate': _daysAgo(daysAgo),
      'recordType': 'album',
    };

Map<String, dynamic> _push(List<Map<String, dynamic>> releases) => {
      'type': 'release_radar',
      'count': '${releases.length}',
      'releases': jsonEncode(releases),
    };

Map<String, dynamic> _deezerAlbum(String id, int daysAgo) => {
      'id': int.parse(id),
      'title': 'Album $id',
      'release_date': _daysAgo(daysAgo),
      'record_type': 'album',
      'cover_medium': '',
    };

/// Deezer's /artist/{id}/albums answering [albums]; [during] runs while
/// the request is in flight.
MockClient _deezer(List<Map<String, dynamic>> albums, {Future<void> Function()? during}) =>
    MockClient((req) async {
      await during?.call();
      return http.Response(jsonEncode({'data': albums}), 200);
    });

Future<SharedPreferences> _prefs({bool watched = true, List<String>? knownIds}) async {
  SharedPreferences.setMockInitialValues({
    if (watched)
      'tsuki_radar_watched': jsonEncode([
        {'id': '27', 'name': 'Daft Punk'},
      ]),
    if (knownIds != null)
      'tsuki_radar_state': jsonEncode({
        '27': {'ids': knownIds, 'checkedAt': DateTime.now().millisecondsSinceEpoch},
      }),
  });
  return SharedPreferences.getInstance();
}

List<Map<String, dynamic>> _timeline(SharedPreferences prefs) => [
      for (final e in jsonDecode(prefs.getString('tsuki_radar_releases') ?? '[]') as List)
        Map<String, dynamic>.from(e as Map),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final radar = ReleaseRadarService();

  test('a push adds its releases to the radar as new and unread', () async {
    final prefs = await _prefs(knownIds: ['100']);

    final added = await radar.handlePush(_push([_release('200'), _release('201', daysAgo: 3)]));

    expect(added, 2);
    final timeline = _timeline(prefs);
    expect(timeline.map((r) => r['albumId']), ['200', '201']);
    expect(timeline.every((r) => r['isNew'] == true && r['read'] == false), isTrue);
    expect(radar.releases.value.where((r) => r.isUnread), hasLength(2));
  });

  test('the same push twice is told once', () async {
    await _prefs(knownIds: ['100']);
    expect(await radar.handlePush(_push([_release('200')])), 1);
    expect(await radar.handlePush(_push([_release('200')])), 0);
  });

  test("a release the phone's own check already found is not told again", () async {
    final prefs = await _prefs(knownIds: ['100']);
    final found = await http.runWithClient(
      () => radar.runCheck(budget: const Duration(seconds: 5)),
      () => _deezer([_deezerAlbum('100', 300), _deezerAlbum('200', 1)]),
    );
    expect(found, 1);

    expect(await radar.handlePush(_push([_release('200')])), 0);
    expect(_timeline(prefs).where((r) => r['albumId'] == '200'), hasLength(1));
  });

  test('after a push, the check finds nothing new for that release', () async {
    final prefs = await _prefs(knownIds: ['100']);
    await radar.handlePush(_push([_release('200')]));

    final found = await http.runWithClient(
      () => radar.runCheck(budget: const Duration(seconds: 5)),
      () => _deezer([_deezerAlbum('100', 300), _deezerAlbum('200', 1)]),
    );

    expect(found, 0);
    final release = _timeline(prefs).singleWhere((r) => r['albumId'] == '200');
    expect(release['read'], isFalse, reason: 'still waiting in the radar');
  });

  test('a push arriving while the check runs is kept, and told only once', () async {
    final prefs = await _prefs(knownIds: ['100']);
    var pushed = 0;

    final found = await http.runWithClient(
      () => radar.runCheck(budget: const Duration(seconds: 5)),
      () => _deezer(
            [_deezerAlbum('100', 300), _deezerAlbum('200', 1)],
            during: () async => pushed = await radar.handlePush(_push([_release('200')])),
          ),
    );

    expect(pushed, 1);
    expect(found, 0, reason: 'the push already told about it');
    expect(_timeline(prefs).where((r) => r['albumId'] == '200'), hasLength(1));
  });

  test("a push for an artist the check hasn't started watching doesn't make it take old albums for new", () async {
    final prefs = await _prefs();
    await radar.handlePush(_push([_release('200')]));
    expect(jsonDecode(prefs.getString('tsuki_radar_state') ?? '{}'), isNot(contains('27')));

    // First check of the artist: everything is noted, nothing is news.
    final found = await http.runWithClient(
      () => radar.runCheck(budget: const Duration(seconds: 5)),
      () => _deezer([_deezerAlbum('200', 1), _deezerAlbum('150', 10)]),
    );

    expect(found, 0);
    final timeline = _timeline(prefs);
    expect(timeline.singleWhere((r) => r['albumId'] == '200')['isNew'], isTrue);
    expect(timeline.singleWhere((r) => r['albumId'] == '150')['isNew'], isFalse);
  });

  test('other messages and unreadable pushes are ignored', () async {
    final prefs = await _prefs(knownIds: ['100']);
    expect(await radar.handlePush({'type': 'something_else'}), 0);
    expect(await radar.handlePush({'type': 'release_radar', 'releases': 'not json'}), 0);
    expect(await radar.handlePush({'type': 'release_radar', 'releases': '[]'}), 0);
    expect(prefs.getString('tsuki_radar_releases'), isNull);
  });
}
