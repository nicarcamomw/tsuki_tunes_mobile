import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/core/theme/cyber_theme.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/swipeable_sheet.dart';

void main() {
  test('D-14: three surfaces, lighter as they come closer', () {
    final levels = [AppColors.surface, AppColors.surfaceCard, AppColors.surfaceRaised];
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].computeLuminance(), greaterThan(levels[i - 1].computeLuminance()));
    }
  });

  testWidgets('dialogs, menus and sheets rise over the screen; cards sit on it', (tester) async {
    final theme = CyberTheme.darkTheme;
    expect(theme.dialogTheme.backgroundColor, AppColors.surfaceRaised);
    expect(theme.popupMenuTheme.color, AppColors.surfaceRaised);
    expect(theme.cardTheme.color, AppColors.surfaceCard);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => SwipeableSheet.show<void>(context, builder: (_, __) => const Text('hoja')),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final sheet = tester.widgetList<Material>(
      find.ancestor(of: find.text('hoja'), matching: find.byType(Material)),
    );
    expect(sheet.map((m) => m.color), contains(AppColors.surfaceRaised));
  });

  test('D-12: a missing picture is drawn in a neutral, not the red', () {
    final found = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // A cover that failed or is loading, or a song with none.
        if (!RegExp(r'errorWidget:|placeholder:|color: AppColors\.(bgMid|bgCard),').hasMatch(lines[i])) continue;
        final window = lines.skip(i).take(4).join('\n');
        if (RegExp(r'Icon\(Icons\.(person|album|music_note)(_rounded)?,\s*color: AppColors\.accent\b').hasMatch(window)) {
          found.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(found, isEmpty);
  });
}
