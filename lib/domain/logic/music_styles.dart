/// Families of music styles, as the masks and weekly challenges count them.
///
/// The first twelve are the main families (the rainbow mask asks for all of
/// them); the rest are narrower scenes some masks are about.
enum MusicStyle {
  metal,
  rock,
  punk,
  electronic,
  hiphop,
  pop,
  latin,
  jpop,
  kpop,
  lofi,
  jazz,
  classical,
  // Narrower scenes.
  synthwave,
  vocaloid,
  folk,
  indie,
}

/// What a set of genre tags (Last.fm's for an artist, or Deezer's for an
/// album) says about the music: its style families and the countries the
/// tags name.
class StyleInfo {
  final Set<MusicStyle> styles;

  /// ISO 3166 codes ('JP', 'CL'...).
  final Set<String> countries;

  const StyleInfo({this.styles = const {}, this.countries = const {}});

  static const empty = StyleInfo();

  bool get isEmpty => styles.isEmpty && countries.isEmpty;
}

class MusicStyles {
  /// The twelve main families.
  static const main = [
    MusicStyle.metal,
    MusicStyle.rock,
    MusicStyle.punk,
    MusicStyle.electronic,
    MusicStyle.hiphop,
    MusicStyle.pop,
    MusicStyle.latin,
    MusicStyle.jpop,
    MusicStyle.kpop,
    MusicStyle.lofi,
    MusicStyle.jazz,
    MusicStyle.classical,
  ];

  static MusicStyle? byName(String name) {
    for (final s in MusicStyle.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  // Whole tags (after normalizing) and words inside tags, per family.
  static const _exact = <MusicStyle, Set<String>>{
    MusicStyle.metal: {'djent', 'deathcore', 'grindcore', 'thrash', 'doom'},
    MusicStyle.rock: {'grunge', 'britpop'},
    MusicStyle.punk: {'hardcore', 'emo', 'screamo', 'oi'},
    MusicStyle.electronic: {
      'edm', 'techno', 'house', 'trance', 'dubstep', 'dnb', 'idm', 'dance',
      'breakbeat', 'garage', 'hardstyle', 'chiptune', 'electro', 'electronica',
    },
    MusicStyle.hiphop: {'rap', 'trap', 'grime', 'drill', 'boom bap', 'hip hop', 'hiphop'},
    MusicStyle.pop: {'pop'},
    MusicStyle.latin: {
      'reggaeton', 'latin', 'latino', 'urbano', 'urbano latino', 'dembow',
      'bachata', 'salsa', 'cumbia', 'corridos', 'perreo', 'merengue', 'latin music',
    },
    MusicStyle.jpop: {
      'jpop', 'jrock', 'anime', 'japanese', 'city pop', 'visual kei', 'enka',
      'anisong', 'jrap', 'japan',
    },
    MusicStyle.kpop: {'kpop', 'korean', 'krap', 'kindie', 'krnb', 'korea'},
    MusicStyle.lofi: {
      'lofi', 'chillhop', 'chill', 'chillout', 'ambient', 'downtempo',
      'trip hop', 'sleep', 'study', 'lo fi',
    },
    MusicStyle.jazz: {
      'jazz', 'soul', 'blues', 'funk', 'swing', 'bossa nova', 'neo soul',
      'rnb', 'r and b', 'motown', 'gospel',
    },
    MusicStyle.classical: {
      'classical', 'instrumental', 'soundtrack', 'score', 'orchestral',
      'piano', 'opera', 'baroque', 'neoclassical', 'ost', 'video game music',
      'films games', 'film score',
    },
    MusicStyle.synthwave: {
      'synthwave', 'retrowave', 'outrun', 'darksynth', 'vaporwave', '80s',
      'new wave', 'chillwave', 'synth pop', 'synthpop',
    },
    MusicStyle.vocaloid: {'vocaloid', 'hyperpop', 'glitchcore', 'digicore', 'utaite', 'nightcore'},
    MusicStyle.folk: {
      'folk', 'acoustic', 'singer songwriter', 'americana', 'country',
      'bluegrass', 'cantautor', 'trova', 'andean', 'folklore', 'cueca',
    },
    MusicStyle.indie: {
      'indie', 'alternative', 'dream pop', 'shoegaze', 'bedroom pop',
      'post punk', 'math rock', 'indie pop', 'indie rock',
    },
  };

  // Words that put a tag in a family wherever they appear in it.
  static const _words = <MusicStyle, Set<String>>{
    MusicStyle.metal: {'metal', 'metalcore'},
    MusicStyle.rock: {'rock'},
    MusicStyle.punk: {'punk'},
    MusicStyle.electronic: {'electronic', 'house', 'techno', 'trance', 'dubstep', 'electro'},
    MusicStyle.hiphop: {'rap', 'trap', 'hip'},
    MusicStyle.latin: {'reggaeton', 'latin', 'latino', 'cumbia'},
    MusicStyle.jpop: {'japanese', 'anime', 'jpop', 'jrock'},
    MusicStyle.kpop: {'kpop', 'korean'},
    MusicStyle.lofi: {'lofi', 'chill', 'ambient'},
    MusicStyle.jazz: {'jazz', 'soul', 'blues', 'funk'},
    MusicStyle.classical: {'classical', 'orchestral', 'soundtrack'},
    MusicStyle.synthwave: {'synthwave', 'retrowave', 'vaporwave'},
    MusicStyle.folk: {'folk', 'acoustic'},
    MusicStyle.indie: {'indie', 'alternative', 'shoegaze'},
  };

  // "pop" inside these is its own scene, not the pop family.
  static const _notPop = {'kpop', 'jpop', 'city pop', 'hyperpop', 'dream pop', 'bedroom pop', 'synth pop'};

  // Nationalities and countries named in tags. Languages ("spanish",
  // "english") are left out: they don't say where the music is from.
  static const _countries = <String, String>{
    'japanese': 'JP', 'japan': 'JP', 'jpop': 'JP', 'jrock': 'JP', 'anime': 'JP',
    'korean': 'KR', 'korea': 'KR', 'kpop': 'KR',
    'chilean': 'CL', 'chile': 'CL',
    'argentine': 'AR', 'argentinian': 'AR', 'argentina': 'AR',
    'mexican': 'MX', 'mexico': 'MX',
    'colombian': 'CO', 'colombia': 'CO',
    'peruvian': 'PE', 'peru': 'PE',
    'venezuelan': 'VE', 'cuban': 'CU', 'uruguayan': 'UY',
    'puerto rican': 'PR', 'puerto rico': 'PR',
    'brazilian': 'BR', 'brazil': 'BR', 'mpb': 'BR',
    'spain': 'ES', 'british': 'GB', 'uk': 'GB', 'scottish': 'GB',
    'american': 'US', 'usa': 'US', 'canadian': 'CA', 'canada': 'CA',
    'australian': 'AU', 'french': 'FR', 'france': 'FR', 'german': 'DE',
    'germany': 'DE', 'swedish': 'SE', 'norwegian': 'NO', 'finnish': 'FI',
    'danish': 'DK', 'icelandic': 'IS', 'dutch': 'NL', 'belgian': 'BE',
    'italian': 'IT', 'irish': 'IE', 'polish': 'PL', 'portuguese': 'PT',
    'russian': 'RU', 'turkish': 'TR', 'chinese': 'CN', 'cpop': 'CN',
    'taiwanese': 'TW', 'filipino': 'PH', 'indian': 'IN', 'nigerian': 'NG',
    'jamaican': 'JM', 'south african': 'ZA',
  };

  /// "J-Pop", "hip-hop", "R&B", "Rap/Hip Hop" → "jpop", "hip hop", "r and b",
  /// "rap hip hop".
  static String normalize(String tag) {
    var t = tag.toLowerCase().trim().replaceAll('&', ' and ');
    // j-pop / k-pop / c-pop and lo-fi glue together; other dashes split.
    t = t.replaceAllMapped(RegExp(r'\b([jkc])-(pop|rock|rap|indie|r and b)\b'), (m) => '${m[1]}${m[2]}');
    t = t.replaceAll('lo-fi', 'lofi').replaceAll('k rnb', 'krnb');
    t = t.replaceAll(RegExp(r'[-/_.,]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// The families and countries [tags] name. Only the first [limit] tags
  /// count: Last.fm sorts them by how many people used them, and the tail
  /// is often noise ("seen live", "favorites").
  static StyleInfo fromTags(Iterable<String> tags, {int limit = 6}) {
    final styles = <MusicStyle>{};
    final countries = <String>{};
    for (final raw in tags.take(limit)) {
      final tag = normalize(raw);
      if (tag.isEmpty) continue;
      final words = tag.split(' ').toSet();
      for (final entry in _exact.entries) {
        if (entry.value.contains(tag)) styles.add(entry.key);
      }
      for (final entry in _words.entries) {
        if (entry.value.any(words.contains)) styles.add(entry.key);
      }
      if (words.contains('pop') && !_notPop.contains(tag)) styles.add(MusicStyle.pop);
      if (tag == 'r and b' || tag == 'rnb') styles.add(MusicStyle.jazz);
      if (tag.contains('hip hop')) styles.add(MusicStyle.hiphop);
      final country = _countries[tag] ?? _countries[words.first];
      if (country != null) countries.add(country);
    }
    return StyleInfo(styles: styles, countries: countries);
  }
}
