/// Sintonía: how close two Bearers' music is, from their most listened
/// artists (best first). Each shared artist weighs more the higher it sits
/// in both lists, so two people who love the same few artists tune in more
/// than two who share many they barely play.
class Sintonia {
  const Sintonia({required this.percent, required this.shared});

  /// 0..100.
  final int percent;

  /// The artists both listen to, by how much they weigh together.
  final List<String> shared;

  /// How many top artists each profile publishes for it.
  static const artistsCompared = 30;

  static String _key(String name) => name.trim().toLowerCase();

  static Sintonia of(List<String> mine, List<String> theirs) {
    final a = mine.take(artistsCompared).toList();
    final b = theirs.take(artistsCompared).toList();
    if (a.isEmpty || b.isEmpty) return const Sintonia(percent: 0, shared: []);
    double weight(int rank, int length) => 1 / (1 + rank * 0.15);
    final wb = <String, double>{};
    final shown = <String, String>{};
    for (var i = 0; i < b.length; i++) {
      wb.putIfAbsent(_key(b[i]), () => weight(i, b.length));
    }
    var common = 0.0;
    final scored = <String, double>{};
    for (var i = 0; i < a.length; i++) {
      final k = _key(a[i]);
      final other = wb[k];
      if (other == null || scored.containsKey(k)) continue;
      final w = weight(i, a.length);
      // The smaller of the two weights: both have to care.
      final s = w < other ? w : other;
      scored[k] = s;
      shown[k] = a[i].trim();
      common += s;
    }
    double total(List<String> l) {
      var t = 0.0;
      for (var i = 0; i < l.length; i++) {
        t += weight(i, l.length);
      }
      return t;
    }

    // Against the shorter list: a short list fully shared is a full match.
    final ta = total(a), tb = total(b);
    final best = ta < tb ? ta : tb;
    final pct = best == 0 ? 0 : (common / best * 100).round().clamp(0, 100);
    final shared = scored.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    return Sintonia(percent: pct, shared: [for (final e in shared) shown[e.key]!]);
  }
}
