@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/glass_card.dart';

void main() {
  group('GlassCard golden', () {
    testWidgets('purple card after bloom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Center(
              child: SizedBox(
                width: 300,
                child: GlassCard(
                  color: Colors.purple,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Tsuki Tunes',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(GlassCard.bloomDuration);
      await tester.pump(GlassCard.bloomDuration);

      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_purple.png'),
      );
    });

    testWidgets('cyan card after bloom', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Center(
              child: SizedBox(
                width: 300,
                child: GlassCard(
                  color: Colors.cyan,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Now Playing',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(GlassCard.bloomDuration);
      await tester.pump(GlassCard.bloomDuration);

      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_cyan.png'),
      );
    });
  });
}
