import 'package:flutter/painting.dart';

import '../../domain/entities/oni_mask.dart';

/// The color of each rarity, for frames, glows and progress bars.
extension OniMaskColors on OniMask {
  Color get rarityColor => switch (rarity) {
        MaskRarity.common => const Color(0xFFB8C0D0),
        MaskRarity.rare => const Color(0xFF00E5FF),
        MaskRarity.epic => const Color(0xFFB026FF),
        MaskRarity.secret => const Color(0xFFFF2A4A),
        MaskRarity.legendary => const Color(0xFFFFC94A),
      };
}
