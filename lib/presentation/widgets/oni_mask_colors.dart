import 'package:flutter/painting.dart';

import '../../domain/entities/oni_mask.dart';

/// The color of each rarity, for frames, glows and progress bars.
extension OniMaskColors on OniMask {
  Color get rarityColor => switch (rarity) {
        _ when chosen => const Color(0xFFFF1E3C),
        _ when divine => const Color(0xFFFFE9A8),
        MaskRarity.r => const Color(0xFF4FA8FF),
        MaskRarity.sr => const Color(0xFFB026FF),
        MaskRarity.ssr => const Color(0xFFFFC94A),
        MaskRarity.ul => const Color(0xFFFF2A4A),
        MaskRarity.dios => const Color(0xFFFFFFFF),
      };
}

/// The colour an equipped UL or DS mask gives the player, picked from its
/// art (its most vivid colour, tuned so masks look apart).
const _aura = <String, Color>{
  // The Chosen: crimson, the colour of her kind.
  'kitsune': Color(0xFFFF1E3C),
  'ou': Color(0xFFE0A84A),
  'niji': Color(0xFFA06CFF),
  'ryuuou': Color(0xFFD8A25F),
  'yougan_ni': Color(0xFFFF6A1F),
  'kitsunebi': Color(0xFFFF4A3A),
  'kitsune_ou': Color(0xFFE2563F),
  'hari': Color(0xFF3FB8E8),
  'hibiboshi': Color(0xFF61C2FF),
  'uchuu': Color(0xFFE040A0),
  'tenshi': Color(0xFFFFD27A),
  'nichigetsu': Color(0xFFE8483A),
  'seiza': Color(0xFF4FA0FF),
  'enbu': Color(0xFFFF5A2E),
  'chirune': Color(0xFFFF2E4A),
  'uchuu_shin': Color(0xFFFFC94A),
  'ochigami': Color(0xFFFF8A3D),
  // The Bearer's own mask: moonlight.
  'portador': Color(0xFFE8F0FF),
};

extension OniMaskAura on OniMask {
  /// The player's accent while this mask is equipped: only UL and DS masks
  /// have one.
  Color? get playerAura =>
      rarity == MaskRarity.ul || rarity == MaskRarity.dios ? _aura[id] : null;
}
