import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/logic/music_styles.dart';

Set<MusicStyle> s(List<String> tags) => MusicStyles.fromTags(tags).styles;

void main() {
  test('Last.fm tags fall into their families', () {
    expect(s(['heavy metal', 'thrash metal']), {MusicStyle.metal});
    expect(s(['Hip-Hop', 'rap']), {MusicStyle.hiphop});
    expect(s(['reggaeton', 'latin']), {MusicStyle.latin});
    expect(s(['J-Pop', 'anime']), {MusicStyle.jpop});
    expect(s(['K-Pop']), {MusicStyle.kpop});
    expect(s(['lo-fi', 'chillhop']), {MusicStyle.lofi});
    expect(s(['soul', 'R&B']), {MusicStyle.jazz});
    expect(s(['soundtrack', 'instrumental']), {MusicStyle.classical});
    expect(s(['vocaloid']), {MusicStyle.vocaloid});
    expect(s(['synthwave', '80s']), {MusicStyle.synthwave});
  });

  test('a tag can name more than one family', () {
    expect(s(['indie rock']), containsAll([MusicStyle.indie, MusicStyle.rock]));
    expect(s(['pop punk']), containsAll([MusicStyle.pop, MusicStyle.punk]));
    expect(s(['trap latino']), containsAll([MusicStyle.hiphop, MusicStyle.latin]));
  });

  test('scenes with "pop" in the name are not the pop family', () {
    expect(s(['K-Pop']), isNot(contains(MusicStyle.pop)));
    expect(s(['hyperpop']), isNot(contains(MusicStyle.pop)));
    expect(s(['dream pop']), {MusicStyle.indie});
  });

  test('Deezer album genres work too', () {
    expect(s(['Rap/Hip Hop']), contains(MusicStyle.hiphop));
    expect(s(['Electro']), {MusicStyle.electronic});
    expect(s(['Films/Games']), {MusicStyle.classical});
    expect(s(['Soul & Funk']), {MusicStyle.jazz});
  });

  test('countries from nationality tags, not languages', () {
    expect(MusicStyles.fromTags(['chilean', 'rock']).countries, {'CL'});
    expect(MusicStyles.fromTags(['japanese']).countries, {'JP'});
    expect(MusicStyles.fromTags(['spanish']).countries, isEmpty);
  });

  test('only the first tags count; noise matches nothing', () {
    expect(s(['seen live', 'favorites', 'awesome']), isEmpty);
    expect(s(['rock', 'a', 'b', 'c', 'd', 'e', 'metal']), {MusicStyle.rock});
  });
}
