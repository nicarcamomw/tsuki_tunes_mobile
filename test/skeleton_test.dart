import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/skeleton_loader.dart';

import 'helpers/test_scope.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => TestScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  testWidgets('a whole skeleton shimmers on one ticker', (tester) async {
    await tester.pumpWidget(_app(const SkeletonTrackList(count: 8)));
    // 8 rows of 5 bones each, and only the scope's animation runs.
    expect(find.byType(SkeletonLoader), findsNWidgets(40));
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('the shimmer repaints the bones without rebuilding them', (tester) async {
    await tester.pumpWidget(_app(const SkeletonTrackList(count: 3)));
    final bone = find.descendant(of: find.byType(SkeletonLoader), matching: find.byType(CustomPaint)).first;
    final before = tester.widget(bone);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // The same widget: frames only repaint it.
    expect(identical(tester.widget(bone), before), isTrue);
  });

  testWidgets('a bone on its own still shimmers', (tester) async {
    await tester.pumpWidget(_app(const SkeletonLoader(width: 40, height: 10)));
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('reduced motion: the skeleton holds still', (tester) async {
    await tester.pumpWidget(_app(const SkeletonTrackList(count: 3), reduceMotion: true));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('screen readers hear "loading", not the bones', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const SkeletonRowList(count: 3)));
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);

    await tester.pumpWidget(_app(const SkeletonLyrics(label: '// SINCRONIZANDO LETRAS...')));
    expect(find.bySemanticsLabel('// SINCRONIZANDO LETRAS...'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('lines vary in width like real titles', (tester) async {
    await tester.pumpWidget(_app(const SkeletonTrackList(count: 3)));
    final widths = {
      for (final e in find.byType(SkeletonLine).evaluate()) (e.widget as SkeletonLine).factor,
    };
    expect(widths.length, greaterThan(3));
  });

  testWidgets('the skeleton fades into the content', (tester) async {
    Widget at(bool loading) => _app(SkeletonSwitcher(
          loading: loading,
          skeleton: const SkeletonTrackList(count: 2),
          child: const Text('songs'),
        ));
    await tester.pumpWidget(at(true));
    expect(find.text('songs'), findsNothing);

    await tester.pumpWidget(at(false));
    await tester.pump(SkeletonSwitcher.duration ~/ 2);
    // Halfway: both, crossing.
    expect(find.text('songs'), findsOneWidget);
    expect(find.byType(SkeletonTrackList), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SkeletonTrackList), findsNothing);
  });

  test('content loads show a skeleton: no page-sized spinner left', () {
    // A centred spinner standing in for a page or a list. Spinners stay for
    // actions in place (a button, buffering, a field's search).
    final pageSpinner = RegExp(r'Center\(\s*child:\s*CircularProgressIndicator');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && pageSpinner.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty, reason: 'use a skeleton from widgets/skeleton_loader.dart');
  });
}
