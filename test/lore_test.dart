import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/domain/lore/tsuki_lore.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/lore_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/lore_text.dart';

import 'helpers/test_scope.dart';

/// Every text the lore tells, in both languages.
Iterable<String> _allTexts() sync* {
  for (final c in TsukiLore.chapters) {
    yield c.body.es;
    yield c.body.en;
  }
  for (final f in TsukiLore.factions) {
    yield* [f.secret.es, f.secret.en, f.motto.es, f.motto.en];
  }
  for (final b in TsukiLore.bonds) {
    yield* [b.title.es, b.title.en, b.text.es, b.text.en];
  }
  for (final f in TsukiLore.faces) {
    yield* [f.title.es, f.title.en, f.text.es, f.text.en];
  }
}

void main() {
  group('the world', () {
    test('every being outside the 9 Faces, the Five and the clan masks belongs to exactly one clan', () {
      for (final m in MaskCatalog.all) {
        final clans = TsukiLore.factions.where((f) => f.members.contains(m.id)).length;
        final outside = m.divine ||
            m.rarity == MaskRarity.dios ||
            m.counter == 'ethereal' ||
            TsukiLore.crossed.contains(m.id) ||
            (m.counter?.startsWith('clan:') ?? false);
        expect(clans, outside ? 0 : 1, reason: m.id);
      }
    });

    test('the Five who crossed are real beings, and the eight Ultras are the non-divine ULs', () {
      expect(TsukiLore.crossed.length, 5);
      for (final id in TsukiLore.crossed) {
        expect(MaskCatalog.byId(id), isNotNull, reason: id);
      }
      expect(TsukiLore.ultras.toSet(), {
        for (final m in MaskCatalog.all)
          if (m.rarity == MaskRarity.ul && !m.divine && m.counter != 'ethereal') m.id,
      });
    });

    test('leaders belong to their clan; rivals are each other\'s', () {
      for (final f in TsukiLore.factions) {
        expect(f.members, contains(f.leader), reason: f.id);
        if (f.rival != null) expect(TsukiLore.faction(f.rival)!.rival, f.id, reason: f.id);
      }
    });

    test('the 9 Faces of the Universe are the 7 divine beings and the 2 gods', () {
      final faces = TsukiLore.faces.map((f) => f.mask).toSet();
      expect(faces.length, 9);
      expect(faces, {
        for (final m in MaskCatalog.all)
          if (m.divine || m.rarity == MaskRarity.dios) m.id,
      });
    });

    test('ethereal beings have no family: no parents, children or siblings anywhere', () {
      final family = RegExp(
        r'\b(herman[oa]s?|hij[oa]s?|padres?|consortes?|espos[oa]s?|siblings?|sisters?|brothers?|'
        r'consorts?|father|parents?|wife|husband)\b',
        caseSensitive: false,
      );
      for (final t in _allTexts()) {
        // "no parents and no children" is the rule itself, not a family.
        final clean = t
            .replaceAll(RegExp('No tienen padres ni hijos', caseSensitive: false), '')
            .replaceAll(RegExp('no parents and no children', caseSensitive: false), '')
            .replaceAll('no existe la palabra hermano', '')
            .replaceAll('the word brother does not exist', '');
        expect(family.hasMatch(clean), isFalse, reason: t);
      }
    });

    test('every name in red is a real being\'s name, in its language', () {
      final mark = RegExp(r'\[\[([^\]]+)\]\]');
      final es = {for (final m in MaskCatalog.all) m.name(AppLanguage.es)};
      final en = {for (final m in MaskCatalog.all) m.name(AppLanguage.en)};
      var marks = 0;
      for (final c in TsukiLore.chapters) {
        for (final m in mark.allMatches(c.body.es)) {
          expect(es, contains(m.group(1)), reason: '${c.id} (es)');
          marks++;
        }
        for (final m in mark.allMatches(c.body.en)) {
          expect(en, contains(m.group(1)), reason: '${c.id} (en)');
        }
        // Both languages name the same beings.
        expect(mark.allMatches(c.body.es).length, mark.allMatches(c.body.en).length, reason: c.id);
      }
      expect(marks, greaterThan(150));
    });

    test('chapters: each with its volume, its level and its text', () {
      final ids = <String>{};
      for (final c in TsukiLore.chapters) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate ${c.id}');
        expect(TsukiLore.tomos.any((t) => t.number == c.tomo), isTrue, reason: c.id);
        if (c.factionId != null) expect(TsukiLore.faction(c.factionId), isNotNull, reason: c.id);
        expect(c.level, inInclusiveRange(1, EcoLevels.maxLevel), reason: c.id);
        expect(c.body.es.trim(), isNotEmpty);
        expect(c.body.en.trim(), isNotEmpty);
        expect(c.body.es.split('\n\n').length, c.body.en.split('\n\n').length, reason: '${c.id}: same paragraphs');
      }
      // Within a volume the chapters open in order.
      for (final t in TsukiLore.tomos) {
        final levels = TsukiLore.chaptersOf(t.number).map((c) => c.level).toList();
        expect(levels, [...levels]..sort(), reason: 'volume ${t.number}');
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
    test('Eco is knowledge: each chapter opens at its level', () {
      expect({for (final c in TsukiLore.chapters) if (TsukiLore.isOpen(c, 1)) c.id}, {'prologo'});
      expect(TsukiLore.isOpen(TsukiLore.chapters.firstWhere((c) => c.id == 'portadores'), 6), isFalse);
      expect(TsukiLore.isOpen(TsukiLore.chapters.firstWhere((c) => c.id == 'portadores'), 7), isTrue);
      expect(TsukiLore.openCount(EcoLevels.maxLevel), TsukiLore.chapters.length);
    });

    test('a volume opens with its first chapter', () {
      expect(TsukiLore.tomoLevel(1), 1);
      expect(TsukiLore.tomoLevel(2), 10);
      expect(TsukiLore.tomoOpen(5, 59), isFalse);
      expect(TsukiLore.tomoOpen(5, 60), isTrue);
    });

    test('every chapter after the prologue is a level\'s reward', () {
      for (final c in TsukiLore.chapters.where((c) => c.level > 1)) {
        expect(EcoLevels.rewardsAt(c.level).any((r) => r.chapter == c), isTrue, reason: c.id);
      }
    });

    test('a clan\'s secret needs the whole clan', () {
      final zorro = TsukiLore.faction('zorro')!;
      final owned = zorro.members.take(zorro.members.length - 1).toSet();
      expect(TsukiLore.complete(zorro, owned), isFalse);
      expect(TsukiLore.complete(zorro, {...owned, zorro.members.last}), isTrue);
    });
  });

  test('names read in red capitals; the plain text keeps them', () {
    expect(LoreText.plain('Lo gobierna [[Rey Dragón]], el más viejo.'), 'Lo gobierna REY DRAGÓN, el más viejo.');
  });

  testWidgets('the lore opens from its button and reads a chapter', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    // Level 5: the Ancients' chapter.
    masks.applyProgress({'plays': 100});
    expect(masks.level, 5);

    await tester.pumpWidget(TestScope(
      overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
      child: const MaterialApp(home: LoreScreen()),
    ));
    await tester.pump();
    expect(find.text('TSUKI LORE'), findsOneWidget);
    expect(find.text('La Luna Madre'), findsOneWidget);
    expect(find.text('4 de ${TsukiLore.chapters.length} capítulos abiertos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Se abre en el nivel 10'), 300);
    expect(find.text('Se abre en el nivel 10'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Los Antiguos'), -300);

    await tester.tap(find.text('Los Antiguos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Antes de los clanes'), findsOneWidget);
    // The four first faces, by name, in red.
    expect(find.text('PRIMER ECO'), findsWidgets);
    final name = tester.widget<Text>(find.text('PRIMER ECO').first);
    expect(name.style?.color, loreNameColor);
    await tester.scrollUntilVisible(find.text('MIEMBROS DEL CLAN'), 300);
    expect(find.text('MIEMBROS DEL CLAN'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SECRETO DEL CLAN'), 300);
    expect(find.textContaining('para conocer su secreto'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });
}
