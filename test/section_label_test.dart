import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/section_title.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(backgroundColor: AppColors.bgDeep, body: Center(child: child))),
      );

  testWidgets('a group label reads in capitals, with its count, as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    final locale = LocaleProvider();
    await pump(tester, SectionLabel(locale: locale, text: 'Tus lazos', count: 3));

    expect(find.text('TUS LAZOS · 3'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('TUS LAZOS · 3')),
      matchesSemantics(label: 'TUS LAZOS · 3', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('a marker and a trailing piece go around it; long text ends in …', (tester) async {
    final locale = LocaleProvider();
    await pump(
      tester,
      SizedBox(
        width: 120,
        child: SectionLabel(
          locale: locale,
          text: 'Una etiqueta de grupo muy larga para su sitio',
          marker: AppColors.neonCyan,
          trailing: const Icon(Icons.shuffle_rounded, size: 11),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    final bar = tester.widget<Container>(find.byType(Container).first);
    expect(bar.color, AppColors.neonCyan);
    expect(tester.widget<Text>(find.byType(Text)).overflow, TextOverflow.ellipsis);
  });

  testWidgets('a content section title is a heading too', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, SectionTitle(locale: LocaleProvider(), text: 'Música nueva'));
    expect(tester.getSemantics(find.text('Música nueva')), matchesSemantics(label: 'Música nueva', isHeader: true));
    handle.dispose();
  });
}
