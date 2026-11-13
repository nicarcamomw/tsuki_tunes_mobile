import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/empty_state.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/error_state.dart';

import 'helpers/test_scope.dart';

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

Widget _app(Widget child) => TestScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('D-06: what is missing, why, and a 48 dp action TalkBack can name', (tester) async {
    await http.runWithClient(() async {
      final handle = tester.ensureSemantics();
      var tapped = 0;
      await tester.pumpWidget(_app(EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Nada por aquí',
        message: 'Busca algo para empezar',
        actionLabel: 'Ir a buscar',
        actionSemanticLabel: 'Ir a la pestaña Buscar',
        onAction: () => tapped++,
      )));
      expect(find.text('NADA POR AQUÍ'), findsOneWidget);
      expect(find.text('Busca algo para empezar'), findsOneWidget);
      expect(find.bySemanticsLabel('Ir a la pestaña Buscar'), findsOneWidget);
      await tester.tap(find.text('IR A BUSCAR'));
      expect(tapped, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    }, () => _noNetwork);
  });

  testWidgets('without an action there is no button; compact keeps the title as written', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const EmptyState(title: 'Nada después', compact: true)));
      expect(find.text('Nada después'), findsOneWidget);
      expect(find.byType(StateAction), findsNothing);
    }, () => _noNetwork);
  });

  testWidgets('ErrorState retries through the same button', (tester) async {
    await http.runWithClient(() async {
      var retried = false;
      await tester.pumpWidget(_app(ErrorState(message: 'Falló', onRetry: () => retried = true)));
      await tester.tap(find.byType(StateAction));
      expect(retried, isTrue);
    }, () => _noNetwork);
  });
}
