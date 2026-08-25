class ArtistFontConfig {
  final double sizeMultiplier;
  final double strokeWidth;
  final double letterSpacing;
  final bool forceUppercase;
  final double leftOffset;
  final double topOffset;

  const ArtistFontConfig({
    this.sizeMultiplier = 1.0,
    this.strokeWidth = 1.5,
    this.letterSpacing = 1.5,
    this.forceUppercase = true,
    this.leftOffset = 0.0,
    this.topOffset = 0.0,
  });
}

class ArtistFonts {
  static const Map<String, String> idToFont = {
    '119': 'Metallica',
    '458': 'SystemOfADown',
    '927': 'HelveticaBlackOblique',
    '117': 'Sickness',
    '12246': 'Satisfaction',
    '115': 'Squealer',
    '415': 'Optionyx',
    '10803980': 'Blackpink',
    '399': 'EuroSwh',
    '409': 'Resurrec',
    '1': 'Bootle',
    '1785': 'InstantZen',
    '847': 'Densmore',
    '27': 'DaftFont',
    '113': 'Trixie',
    '9222': 'CenturyGothicItalic',
    '464': 'Rammstein',
    '848': 'Kashmir',
    '6408': 'FrizQuadrata',
    '525643': 'ScaryGlyphs',
    '698': 'LaBamba',
    '315': 'LasVegas',
    '7': 'Jamiroquai',
    '142381': 'HelveticaBlackRegular',
    '11565': 'Americana',
    '88684': 'Exo',
  };

  static const Map<String, String> nameToFont = {
    'metallica': 'Metallica',
    'system of a down': 'SystemOfADown',
    'systemofadown': 'SystemOfADown',
    'soad': 'SystemOfADown',
    'oasis': 'HelveticaBlackOblique',
    'slipknot': 'Sickness',
    'taylor swift': 'Satisfaction',
    'ac/dc': 'Squealer',
    'acdc': 'Squealer',
    'blackpink': 'Blackpink',
    'queen': 'EuroSwh',
    'avenged sevenfold': 'Resurrec',
    'a7x': 'Resurrec',
    'the beatles': 'Bootle',
    'beatles': 'Bootle',
    'coldplay': 'InstantZen',
    'the doors': 'Densmore',
    'doors': 'Densmore',
    'daft punk': 'DaftFont',
    'nirvana': 'Optionyx',
    'twenty one pilots': 'CenturyGothicItalic',
    'twenty-one pilots': 'CenturyGothicItalic',
    '21 pilots': 'CenturyGothicItalic',
    'rammstein': 'Rammstein',
    'led zeppelin': 'Kashmir',
    'bad religion': 'FrizQuadrata',
    'skrillex': 'ScaryGlyphs',
    'los lobos': 'LaBamba',
    'the killers': 'LasVegas',
    'killers': 'LasVegas',
    'jamiroquai': 'Jamiroquai',
    'arctic monkeys': 'HelveticaBlackRegular',
    'lana del rey': 'Americana',
    'exo': 'Exo',
  };

  // Artist-specific fine-tuned metrics
  static const Map<String, ArtistFontConfig> fontConfigs = {
    'ScaryGlyphs': ArtistFontConfig(
      sizeMultiplier: 1.5,
      strokeWidth: 1.5,
      letterSpacing: 2.0,
      forceUppercase: true,
    ),
    'SystemOfADown': ArtistFontConfig(
      sizeMultiplier: 1.25,
      strokeWidth: 1.8,
      letterSpacing: 2.0,
      forceUppercase: true,
    ),
    'Metallica': ArtistFontConfig(
      sizeMultiplier: 2.8,
      strokeWidth: 1.6,
      letterSpacing: 0.5,
      forceUppercase: false,
      leftOffset: 16.0,
      topOffset: 40.0, // Specifically moves Metallica down slightly
    ),
    'Satisfaction': ArtistFontConfig(
      sizeMultiplier: 1.3,
      strokeWidth: 1.3,
      letterSpacing: 1.0,
      forceUppercase: false,
    ),
    'Bootle': ArtistFontConfig(
      sizeMultiplier: 1.2,
      strokeWidth: 1.5,
      letterSpacing: 1.0,
      forceUppercase: false,
    ),
    'Densmore': ArtistFontConfig(
      sizeMultiplier: 1.15,
      strokeWidth: 1.5,
      letterSpacing: 1.5,
      forceUppercase: false,
    ),
    'DaftFont': ArtistFontConfig(
      sizeMultiplier: 1.15,
      strokeWidth: 1.5,
      letterSpacing: 1.5,
      forceUppercase: true,
    ),
    'Sickness': ArtistFontConfig(
      sizeMultiplier: 2.55,
      strokeWidth: 1.6,
      letterSpacing: 1.5,
      forceUppercase: false,
    ),
    'Squealer': ArtistFontConfig(
      sizeMultiplier: 2.9,
      strokeWidth: 1.6,
      letterSpacing: 2.0,
      forceUppercase: true,
      topOffset: 0.0,
    ),
    'Blackpink': ArtistFontConfig(
      sizeMultiplier: 1.15,
      strokeWidth: 1.4,
      letterSpacing: 1.5,
      forceUppercase: true,
    ),
    'Rammstein': ArtistFontConfig(
      sizeMultiplier: 1.15,
      strokeWidth: 1.6,
      letterSpacing: 1.5,
      forceUppercase: true,
    ),
    'Kashmir': ArtistFontConfig(
      sizeMultiplier: 1.15,
      strokeWidth: 1.5,
      letterSpacing: 1.5,
      forceUppercase: true,
    ),
    'Resurrec': ArtistFontConfig(
      sizeMultiplier: 0.78, // Compact so "AVENGED SEVENFOLD" fits on a single line
      strokeWidth: 1.5,
      letterSpacing: 0.0, // Normal spacing without extra gaps
      forceUppercase: true,
    ),
    'Optionyx': ArtistFontConfig(
      sizeMultiplier: 2.3, // Large and prominent logo for Nirvana
      strokeWidth: 1.5,
      letterSpacing: 2.5,
      forceUppercase: true,
      topOffset: 20.0, // Moves Nirvana down slightly
    ),
    'Trixie': ArtistFontConfig(
      sizeMultiplier: 1.5,
      strokeWidth: 1.5,
      letterSpacing: 1.5,
      forceUppercase: true,
    ),
  };

  static String? getFontFamily(String artistId, String artistName) {
    if (idToFont.containsKey(artistId)) {
      return idToFont[artistId];
    }
    final normalized = artistName.trim().toLowerCase();
    if (nameToFont.containsKey(normalized)) {
      return nameToFont[normalized];
    }
    return null;
  }

  static ArtistFontConfig getConfig(String fontFamily) {
    return fontConfigs[fontFamily] ?? const ArtistFontConfig();
  }

  static bool hasCustomFont(String artistId, String artistName) {
    return getFontFamily(artistId, artistName) != null;
  }
}

