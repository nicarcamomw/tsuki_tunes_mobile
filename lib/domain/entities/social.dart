// The social side of Tsuki: Bonds (Lazos) between Bearers, the requests
// that make them, and the milestones each one's Echo leaves (Resonances).

/// Someone in a request or a Bond: what the request carried, so lists show
/// without reading every profile.
class SocialPerson {
  const SocialPerson({required this.uid, required this.name, this.photoUrl, this.maskId, this.at});

  final String uid;
  final String name;
  final String? photoUrl;
  final String? maskId;

  /// When the request was sent or the Bond made.
  final DateTime? at;
}

/// Where two people stand.
enum BondState {
  /// Nothing between them.
  none,

  /// I asked them; waiting.
  sent,

  /// They asked me; mine to answer.
  received,

  /// A Bond.
  bonded,
}

/// What a Bearer did that their Bonds hear about.
enum MilestoneKind {
  /// An album heard whole: [Milestone.a] the album, [Milestone.b] the artist.
  album,

  /// An ethereal being awakened: [Milestone.a] the mask id.
  mask,

  /// A new rank: [Milestone.a] the level.
  rank,

  /// Days in a row: [Milestone.a] how many.
  streak,
}

class Milestone {
  const Milestone({required this.kind, required this.a, this.b, required this.at});

  final MilestoneKind kind;
  final String a;
  final String? b;
  final DateTime at;

  /// The most a profile shows, newest first.
  static const kept = 10;

  Map<String, Object> toMap() => {
        'k': kind.name,
        'a': a.length > 120 ? a.substring(0, 120) : a,
        if (b != null) 'b': b!.length > 120 ? b!.substring(0, 120) : b!,
        't': at.millisecondsSinceEpoch,
      };

  static Milestone? fromMap(Object? m) {
    if (m is! Map) return null;
    final kind = MilestoneKind.values.where((k) => k.name == m['k']).firstOrNull;
    final a = m['a'];
    final t = m['t'];
    if (kind == null || a is! String || t is! num) return null;
    return Milestone(
      kind: kind,
      a: a,
      b: m['b'] is String ? m['b'] as String : null,
      at: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Milestone && other.kind == kind && other.a == a && other.b == b && other.at == at;

  @override
  int get hashCode => Object.hash(kind, a, b, at);
}

/// A milestone with whose it is, for the feed.
class Resonance {
  const Resonance({required this.person, required this.milestone});

  final SocialPerson person;
  final Milestone milestone;
}
