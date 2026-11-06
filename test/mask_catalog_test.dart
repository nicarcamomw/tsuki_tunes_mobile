import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/oni_mask.dart';

void main() {
  test('every mask\'s image is in the app', () {
    for (final m in MaskCatalog.all) {
      expect(File(m.asset()).existsSync(), isTrue, reason: '${m.id}: ${m.asset()}');
    }
  });

  test('new masks live in their rarity\'s folder', () {
    for (final m in MaskCatalog.all.where((m) => m.image != null)) {
      expect(m.image, startsWith('assets/images/masks/${m.rarity.name}/'), reason: m.id);
    }
  });

  test('ids are unique', () {
    final ids = MaskCatalog.all.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('rarity pyramid: more R than SR than SSR, one UL at least', () {
    int count(MaskRarity r) => MaskCatalog.all.where((m) => m.rarity == r).length;
    expect(count(MaskRarity.r), greaterThan(count(MaskRarity.sr)));
    expect(count(MaskRarity.sr), greaterThan(count(MaskRarity.ssr)));
    expect(count(MaskRarity.ul), greaterThanOrEqualTo(1));
  });

  test('7 divine masks, all UL; 2 supreme gods above them', () {
    final divine = MaskCatalog.all.where((m) => m.divine).toList();
    expect(divine.length, 7);
    expect(divine.every((m) => m.rarity == MaskRarity.ul), isTrue);
    expect(MaskCatalog.all.where((m) => m.rarity == MaskRarity.dios).map((m) => m.id),
        unorderedEquals(['uchuu_shin', 'ochigami']));
    // The Fallen God asks for every non-divine UL.
    final ultra = MaskCatalog.all.where((m) => m.rarity == MaskRarity.ul && !m.divine).length;
    expect(MaskCatalog.byId('ochigami')!.goal, ultra);
  });
}
