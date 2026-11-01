import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/artist_features.dart';

Track _t(String id, {String artistId = '', required String artistName, List<String> contributors = const []}) => Track(
      id: id,
      title: id,
      artistId: artistId,
      artistName: artistName,
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 1,
      contributors: [for (final c in contributors) Contributor(id: c, name: c)],
    );

void main() {
  test('own songs and features are told apart by the main artist', () {
    final top = [
      _t('see you again', artistId: '1', artistName: 'Tyler, The Creator, Kali Uchis',
          contributors: ['Tyler, The Creator', 'Kali Uchis']),
      _t('feat on kali', artistId: '2', artistName: 'Kali Uchis, Tyler, The Creator',
          contributors: ['Kali Uchis', 'Tyler, The Creator']),
      _t('earfquake', artistId: '1', artistName: 'Tyler, The Creator'),
    ];
    final split = ArtistFeatures.split(top, artistId: '1', artistName: 'Tyler, The Creator');
    expect(split.own.map((t) => t.id), ['see you again', 'earfquake']);
    expect(split.features.map((t) => t.id), ['feat on kali']);
  });

  test('without ids the main artist name decides, commas and all', () {
    final top = [
      _t('a', artistName: 'Tyler, The Creator, Kali Uchis'),
      _t('b', artistName: 'Kali Uchis, Tyler, The Creator'),
    ];
    final split = ArtistFeatures.split(top, artistId: '', artistName: 'tyler, the creator');
    expect(split.own.map((t) => t.id), ['a']);
    expect(split.features.map((t) => t.id), ['b']);
  });
}
