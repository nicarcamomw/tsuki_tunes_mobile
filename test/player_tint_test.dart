import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/domain/entities/oni_mask.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/oni_mask_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';

void main() {
  test('every UL and DS mask has an aura; the others none', () {
    for (final m in MaskCatalog.all) {
      final top = m.rarity == MaskRarity.ul || m.rarity == MaskRarity.dios;
      expect(m.playerAura != null, top, reason: m.id);
    }
  });

  testWidgets('the player reads its tint, the app red by default', (tester) async {
    late Color inside, outside;
    await tester.pumpWidget(Column(children: [
      Builder(builder: (c) {
        outside = PlayerTint.of(c);
        return const SizedBox();
      }),
      PlayerTint(
        color: MaskCatalog.byId('uchuu_shin')!.playerAura!,
        child: Builder(builder: (c) {
          inside = PlayerTint.of(c);
          return const SizedBox();
        }),
      ),
    ]));
    expect(outside, AppColors.accent);
    expect(inside, const Color(0xFFFFC94A));
  });
}
