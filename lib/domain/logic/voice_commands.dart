/// What a spoken request asks for: play something, or just search it.
enum VoiceAction { play, search }

class VoiceCommand {
  final VoiceAction action;
  final String query;
  const VoiceCommand(this.action, this.query);
}

/// Reads spoken requests ("pon Chop Suey", "busca Deftones", "米津玄師を再生して")
/// into a [VoiceCommand]. Pure logic, shared by the voice search screen and
/// tests.
class VoiceCommands {
  VoiceCommands._();

  // Longest first, so "pon la canción" wins over "pon". Matched without
  // accents, since recognizers spell "búscame" either way.
  static const _playPrefixes = [
    'quiero escuchar ', 'quiero oir ', 'ponme la cancion ', 'ponme el tema ',
    'pon la cancion ', 'pon el tema ', 'reproduce la cancion ',
    'reproducir la cancion ', 'ponme musica de ', 'ponme algo de ',
    'pon musica de ', 'pon algo de ', 'ponme a ', 'pon a ', 'ponme ',
    'reproduce ', 'reproducir ', 'escuchar ', 'tocar ', 'toca ', 'pon ',
    'i want to listen to ', 'play the song ', 'play music by ', 'play some ',
    'listen to ', 'put on ', 'play ',
  ];
  static const _searchPrefixes = [
    'encuentrame ', 'encuentra ', 'buscame ', 'buscar ', 'busca ',
    'search for ', 'look for ', 'look up ', 'search ', 'find ',
  ];
  static const _fillerStarts = [
    'oye ', 'hey ', 'ok ', 'okay ', 'por favor ', 'please ',
  ];
  static const _fillerEnds = [' por favor', ' please'];

  /// Lowercase without Spanish accents; keeps the length, so indices match
  /// the original text.
  static String _fold(String s) {
    const from = 'áéíóúüÁÉÍÓÚÜ';
    const to = 'aeiouuAEIOUU';
    final out = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      out.write(i == -1 ? ch : to[i]);
    }
    return out.toString().toLowerCase();
  }

  /// Parses spoken text into a structured command.
  /// Supports prefix-based commands (ES/EN) and suffix-based (JA).
  static VoiceCommand parse(String text) {
    var trimmed = text.trim().replaceAll(RegExp(r'[.!?¡¿]+$'), '').trim();
    if (trimmed.isEmpty) return const VoiceCommand(VoiceAction.search, '');

    // Drop wake words and politeness around the command.
    var changed = true;
    while (changed) {
      changed = false;
      final folded = _fold(trimmed);
      for (final f in _fillerStarts) {
        if (folded.startsWith(f)) {
          trimmed = trimmed.substring(f.length).trim();
          changed = true;
          break;
        }
      }
      for (final f in _fillerEnds) {
        if (_fold(trimmed).endsWith(f)) {
          trimmed = trimmed.substring(0, trimmed.length - f.length).trim();
          changed = true;
          break;
        }
      }
    }
    if (trimmed.isEmpty) return const VoiceCommand(VoiceAction.search, '');
    final lower = _fold(trimmed);

    // --- Prefix-based: play ---
    for (final p in _playPrefixes) {
      if (lower.startsWith(p)) {
        final q = trimmed.substring(p.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
      }
    }

    // --- Prefix-based: search ---
    for (final p in _searchPrefixes) {
      if (lower.startsWith(p)) {
        final q = trimmed.substring(p.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.search, q);
      }
    }

    // --- Suffix-based (Japanese verb-final): play ---
    const playSuffixes = [
      'を再生して', '再生して', 'をかけて', 'かけて', 'を流して', '流して',
      'を再生', 'をプレイ',
    ];
    for (final s in playSuffixes) {
      if (lower.endsWith(s)) {
        final q = trimmed.substring(0, trimmed.length - s.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
      }
    }

    // --- Suffix-based (Japanese): search ---
    const searchSuffixes = ['を探して', '探して', 'を検索', '検索'];
    for (final s in searchSuffixes) {
      if (lower.endsWith(s)) {
        final q = trimmed.substring(0, trimmed.length - s.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.search, q);
      }
    }

    // --- Japanese prefix-based ---
    if (lower.startsWith('かけて ')) {
      final q = trimmed.substring(4).trim();
      if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
    }
    if (lower.startsWith('再生 ')) {
      final q = trimmed.substring(3).trim();
      if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
    }

    return VoiceCommand(VoiceAction.search, trimmed);
  }

  /// "Jefe de La Combo Tortuga" -> "Jefe La Combo Tortuga": a second try
  /// for "song by artist" requests when the literal text finds nothing.
  /// Null when there's no "de"/"by" to drop.
  static String? withoutArtistJoiner(String query) {
    final match = RegExp(r'^(.*\S)\s+(?:de|by)\s+(\S.*)$', caseSensitive: false)
        .firstMatch(query);
    if (match == null) return null;
    return '${match.group(1)} ${match.group(2)}';
  }
}
