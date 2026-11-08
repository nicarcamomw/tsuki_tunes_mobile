import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/cyber_orb.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/motion.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/tap_scale.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _frame(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('contrast (WCAG AA, 4.5:1 for text)', () {
    const backgrounds = {
      'bgDeep': AppColors.bgDeep,
      'bgMid': AppColors.bgMid,
      'bgCard': AppColors.bgCard,
      'bgHover': AppColors.bgHover,
    };
    final textColours = {
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
      'textMuted': AppColors.textMuted,
      'textBright': AppColors.textBright,
      'accent as text': AppColors.forText(AppColors.accent),
      'neonPurple as text': AppColors.forText(AppColors.neonPurple),
      'error as text': AppColors.forText(AppColors.error),
      'neonCyan': AppColors.neonCyan,
      'neonGreen': AppColors.neonGreen,
      'sakura': AppColors.sakura,
      'success': AppColors.success,
      'warning': AppColors.warning,
    };

    test('every text colour reads on every background', () {
      final failing = [
        for (final t in textColours.entries)
          for (final b in backgrounds.entries)
            if (_contrast(t.value, b.value) < 4.5)
              '${t.key} on ${b.key}: ${_contrast(t.value, b.value).toStringAsFixed(2)}',
      ];
      expect(failing, isEmpty);
    });

    test('white text on a crimson button reads', () {
      expect(_contrast(AppColors.textBright, AppColors.accentFill), greaterThanOrEqualTo(4.5));
    });

    testWidgets('text styles swap the brand colours for their readable versions', (tester) async {
      final locale = LocaleProvider();
      expect(locale.getTextStyle(color: AppColors.accent).color, AppColors.accentText);
      expect(locale.getTextStyle(color: AppColors.neonPurple).color, AppColors.neonPurpleText);
      expect(locale.getTextStyle(color: AppColors.textMuted).color, AppColors.textMuted);
    });
  });

  group('touch targets (48 dp)', () {
    testWidgets('a small icon in TapScale is 48 dp to touch, and looks the same', (tester) async {
      await tester.pumpWidget(_frame(TapScale(
        semanticLabel: 'Close',
        onTap: () {},
        child: const Icon(Icons.close, size: 20),
      )));
      expect(tester.getSize(find.byType(TapScale)), const Size(48, 48));
      expect(tester.getSize(find.byIcon(Icons.close)), const Size(20, 20));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('a big child keeps its size', (tester) async {
      await tester.pumpWidget(_frame(TapScale(
        onTap: () {},
        child: const SizedBox(width: 160, height: 90),
      )));
      expect(tester.getSize(find.byType(TapScale)), const Size(160, 90));
    });

    test('every icon button tells screen readers what it does', () {
      // IconButton without a tooltip (or its icon's semanticLabel) reads as
      // just "button" to TalkBack.
      final call = RegExp(r'\bIconButton(\.filled|\.outlined|\.filledTonal)?\(');
      final missing = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final s = f.readAsStringSync();
        for (final m in call.allMatches(s)) {
          var depth = 0, j = m.end - 1;
          for (; j < s.length; j++) {
            if (s[j] == '(') depth++;
            if (s[j] == ')' && --depth == 0) break;
          }
          final body = s.substring(m.end, j);
          final labelledAbove = RegExp(r'Semantics\([^)]*label:')
              .hasMatch(s.substring((m.start - 250).clamp(0, s.length), m.start));
          if (!body.contains('tooltip:') && !body.contains('semanticLabel:') && !labelledAbove) {
            missing.add('${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}');
          }
        }
      }
      expect(missing, isEmpty, reason: 'give them a tooltip');
    });
  });

  group('reduce motion', () {
    testWidgets('a decorative loop stays still', (tester) async {
      await tester.pumpWidget(_frame(const CyberOrb(), reduceMotion: true));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(_frame(const CyberOrb()));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('an entrance shows its end at once', (tester) async {
      Widget entrance({required bool still}) => _frame(
            Builder(builder: (context) => const Text('hi').animateCalm(context).fadeIn(duration: 500.ms)),
            reduceMotion: still,
          );
      await tester.pumpWidget(entrance(still: true));
      expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, 1.0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(reduceMotion(tester.element(find.text('hi'))), isTrue);
      await tester.pump(const Duration(milliseconds: 1)); // flutter_animate's zero-delay start, a no-op here
    });
  });
}
