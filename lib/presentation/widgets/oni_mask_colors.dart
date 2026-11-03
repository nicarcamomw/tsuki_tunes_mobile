import 'package:flutter/painting.dart';

import '../../domain/entities/oni_mask.dart';

/// The color of each rarity, for frames, glows and progress bars.
extension OniMaskColors on OniMask {
  Color get rarityColor => switch (rarity) {
        MaskRarity.r => const Color(0xFF4FA8FF),
        MaskRarity.sr => const Color(0xFFB026FF),
        MaskRarity.ssr => const Color(0xFFFFC94A),
        MaskRarity.ul => const Color(0xFFFF2A4A),
      };
}
