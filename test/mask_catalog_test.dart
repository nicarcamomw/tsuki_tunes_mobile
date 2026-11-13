import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/domain/entities/oni_mask.dart';
import 'package:tsuki_tunes_mobile/domain/lore/tsuki_lore.dart';

void main() {
  test('every mask\'s image is in the app', () {
    // A folder in pubspec.yaml's assets bundles its own files only, not its
    // subfolders': the image's own folder has to be listed.
    final declared = RegExp(r'^\s+- (assets/\S+/)\s*$', multiLine: true)
        .allMatches(File('pubspec.yaml').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    for (final m in MaskCatalog.all) {
      final path = m.asset();
      expect(File(path).existsSync(), isTrue, reason: '${m.id}: $path');
      expect(declared, contains(path.substring(0, path.lastIndexOf('/') + 1)),
          reason: '${m.id}: its folder is not in pubspec.yaml, so $path is not bundled');
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
    // The Fallen God asks for every non-divine UL (not the Bearer's own).
    final ultra =
        MaskCatalog.all.where((m) => m.rarity == MaskRarity.ul && !m.divine && m.counter != 'ethereal').length;
    expect(MaskCatalog.byId('ochigami')!.goal, ultra);
  });

  test('the Chosen is one alone: Kitsune, a UL of her own kind', () {
    final chosen = MaskCatalog.all.where((m) => m.chosen).toList();
    expect(chosen.map((m) => m.id), ['kitsune']);
    expect(chosen.single.rarity, MaskRarity.ul);
    expect(chosen.single.divine, isFalse);
    const es = AppStrings(AppLanguage.es);
    expect(es.maskTierName(chosen.single), 'LA ELEGIDA');
    expect(es.maskTierName(MaskCatalog.byId('tenshi')!), 'DIVINA');
    // Still one of the eight Ultras.
    expect(TsukiLore.ultras, contains('kitsune'));
  });
}
