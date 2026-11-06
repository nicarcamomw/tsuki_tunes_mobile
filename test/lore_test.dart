import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/lore/tsuki_lore.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/lore_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';

import 'helpers/test_scope.dart';

void main() {
  group('the world', () {
    test('every mask outside the 9 Faces belongs to exactly one clan', () {
      for (final m in MaskCatalog.all) {
        final clans = TsukiLore.factions.where((f) => f.members.contains(m.id)).length;
        // The 9 Faces, the clan masks and the Bearer's own belong to none.
        final outside = m.divine ||
            m.rarity == MaskRarity.dios ||
            m.counter == 'level' ||
            (m.counter?.startsWith('clan:') ?? false);
        expect(clans, outside ? 0 : 1, reason: m.id);
      }
    });

    test('leaders belong to their clan; rivals are each other\'s', () {
      for (final f in TsukiLore.factions) {
        expect(f.members, contains(f.leader), reason: f.id);
        if (f.rival != null) expect(TsukiLore.faction(f.rival)!.rival, f.id, reason: f.id);
      }
    });

    test('the 9 Faces of the Universe are the 7 divine masks and the 2 gods', () {
      final faces = TsukiLore.faces.map((f) => f.mask).toSet();
      expect(faces.length, 9);
      expect(faces, {
        for (final m in MaskCatalog.all)
          if (m.divine || m.rarity == MaskRarity.dios) m.id,
      });
    });

    test('bonds and chapters name real masks and clans', () {
      for (final b in TsukiLore.bonds) {
        for (final id in b.masks) {
          expect(MaskCatalog.byId(id), isNotNull, reason: id);
        }
      }
      for (final c in TsukiLore.chapters) {
        if (c.lock == LoreLock.faction) expect(TsukiLore.faction(c.factionId), isNotNull, reason: c.id);
        expect(TsukiLore.tomos.any((t) => t.number == c.tomo), isTrue, reason: c.id);
        expect(c.body.es.trim(), isNotEmpty);
        expect(c.body.en.trim(), isNotEmpty);
      }
    });
  });

  test('a clan mask asks for its whole clan', () {
    for (final f in TsukiLore.factions) {
      final reward = MaskCatalog.byId(f.reward);
      expect(reward, isNotNull, reason: f.id);
      expect(reward!.goal, f.members.length, reason: f.id);
    }
  });

  group('what opens', () {
    test('the prologue and chapter I from the start; II with a first being', () {
      final open = {for (final c in TsukiLore.chapters) if (TsukiLore.isOpen(c, {}, level: 1)) c.id};
      expect(open, {'prologo', 'eco'});
      expect(TsukiLore.isOpen(TsukiLore.chapters.firstWhere((c) => c.id == 'mascaras'), {'hajime'}, level: 1), isTrue);
      expect(TsukiLore.isOpen(TsukiLore.chapters.firstWhere((c) => c.id == 'antiguos'), {'hajime'}, level: 1), isTrue);
    });

    test('the legend of the Bearers opens at level 5', () {
      final c = TsukiLore.chapters.firstWhere((c) => c.id == 'portadores');
      expect(TsukiLore.isOpen(c, {}, level: 4), isFalse);
      expect(TsukiLore.isOpen(c, {}, level: 5), isTrue);
    });

    test('each volume opens at its Eco level, whatever beings there are', () {
      final all = {for (final m in MaskCatalog.all) m.id};
      for (final level in [1, 9, 10, 19, 20, 39, 40, 100]) {
        for (final c in TsukiLore.chapters) {
          final byLevel = c.lock != LoreLock.level || level >= c.need;
          expect(TsukiLore.isOpen(c, all, level: level), level >= EcoLevels.tomoLevels[c.tomo]! && byLevel,
              reason: '${c.id} at $level');
        }
      }
    });

    test('a clan\'s secret needs the whole clan', () {
      final zorro = TsukiLore.faction('zorro')!;
      final owned = zorro.members.take(zorro.members.length - 1).toSet();
      expect(TsukiLore.complete(zorro, owned), isFalse);
      expect(TsukiLore.complete(zorro, {...owned, zorro.members.last}), isTrue);
    });
  });

  testWidgets('the lore opens from its button and reads a chapter', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    masks.unlock('hajime');

    await tester.pumpWidget(TestScope(
      overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
      child: const MaterialApp(home: LoreScreen()),
    ));
    await tester.pump();
    expect(find.text('TSUKI LORE'), findsOneWidget);
    expect(find.text('La Luna Madre'), findsOneWidget);
    // The other volumes open with the Eco levels; the legend of the
    // Bearers at level 5.
    expect(find.text('4 de 5 capítulos abiertos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Se abre en el nivel 10'), 300);
    expect(find.text('Se abre en el nivel 10'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Los Antiguos'), -300);

    await tester.tap(find.text('Los Antiguos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Antes de los clanes'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('MIEMBROS DEL CLAN'), 300);
    expect(find.text('MIEMBROS DEL CLAN'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SECRETO DEL CLAN'), 300);
    expect(find.textContaining('para conocer su secreto'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });
}
