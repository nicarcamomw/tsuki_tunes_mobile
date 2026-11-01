/// Artist names joined with commas, split back without breaking the names
/// that hold a comma.
abstract final class ArtistNames {
  /// The artists in a joined name ("A, B", as Track joins its
  /// contributors). Some names hold a comma themselves ("Tyler, The
  /// Creator", "Earth, Wind & Fire"): those are kept whole.
  static List<String> split(String joined) {
    final parts = [
      for (final part in joined.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    final out = <String>[];
    var i = 0;
    while (i < parts.length) {
      final kept = _commaNameAt(parts, i);
      if (kept > 1) {
        out.add(parts.sublist(i, i + kept).join(', '));
        i += kept;
        continue;
      }
      // "Tyler, The Creator": a part starting with "The" finishes the name
      // before it, it is never an artist of its own after a comma.
      if (out.isNotEmpty && parts[i].toLowerCase().startsWith('the ')) {
        out[out.length - 1] = '${out.last}, ${parts[i]}';
      } else {
        out.add(parts[i]);
      }
      i++;
    }
    return out;
  }

  /// Well-known artist names with commas, lowercased and split like above.
  static const List<List<String>> _commaNames = [
    ['earth', 'wind & fire'],
    ['crosby', 'stills', 'nash & young'],
    ['crosby', 'stills & nash'],
    ['emerson', 'lake & palmer'],
    ['peter', 'bjorn and john'],
    ['blood', 'sweat & tears'],
    ['now', 'now'],
    ['me', 'myself and i'],
  ];

  /// How many parts from [i] form one known comma name (1 when none).
  static int _commaNameAt(List<String> parts, int i) {
    for (final name in _commaNames) {
      if (i + name.length > parts.length) continue;
      var match = true;
      for (var j = 0; j < name.length && match; j++) {
        match = parts[i + j].toLowerCase() == name[j];
      }
      if (match) return name.length;
    }
    return 1;
  }

  /// The first (main) artist of a joined name.
  static String primary(String joined) {
    final all = split(joined);
    return all.isEmpty ? joined.trim() : all.first;
  }
}
