import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/public_profile.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/profile/build_my_profile.dart';

void main() {
  const build = BuildMyProfile();

  test('counts songs, distinct artists and ranks the top five', () {
    final p = build(
      uid: 'u',
      displayName: ' Nico ',
      isPublic: true,
      albumsCompleted: 2,
      listenedTrackArtists: [
        for (final a in ['SOAD', 'soad', 'SOAD', 'Korn', 'Korn', 'Deftones', 'Tool', 'Tool', 'Tool', 'Tool', 'Muse', 'Placebo', '']) [a],
      ],
      knownArtists: const [Artist(id: '27', name: 'System of a Down', pictureUrl: 'x'), Artist(id: '9', name: 'tool', pictureUrl: 'https://t')],
    );
    expect(p.displayName, 'Nico');
    expect(p.stats, const ProfileStats(tracks: 13, albums: 2, artists: 6));
    expect(p.topArtists.map((a) => '${a.name}:${a.count}'), ['Tool:4', 'SOAD:3', 'Korn:2', 'Deftones:1', 'Muse:1']);
    expect(p.topArtists.first.pictureUrl, 'https://t', reason: 'a followed artist lends their picture');
    expect(p.topArtists[1].pictureUrl, isNull);
  });

  test('an empty library publishes zeros and no artists', () {
    final p = build(uid: 'u', displayName: '', isPublic: false, albumsCompleted: 0, listenedTrackArtists: const []);
    expect(p.displayName, 'Tsuki');
    expect(p.stats, const ProfileStats());
    expect(p.topArtists, isEmpty);
  });

  test('a collaboration counts for each of its artists, not as a new one', () {
    final p = build(
      uid: 'u',
      displayName: 'N',
      isPublic: false,
      albumsCompleted: 0,
      listenedTrackArtists: const [
        ['Bad Bunny', 'J Balvin'],
        ['Bad Bunny'],
        ['Tyler, The Creator'],
        ['J Balvin', 'j balvin'],
      ],
    );
    expect(p.stats.tracks, 4);
    expect(p.stats.artists, 3);
    expect(p.topArtists.map((a) => '${a.name}:${a.count}'), ['Bad Bunny:2', 'J Balvin:2', 'Tyler, The Creator:1']);
  });
}
