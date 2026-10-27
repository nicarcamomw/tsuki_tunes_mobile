import 'package:flutter_test/flutter_test.dart';

void main() {
  group('witching hour time check', () {
    test('3:33 AM is the witching minute', () {
      final dt = DateTime(2026, 10, 27, 3, 33, 0);
      expect(dt.hour == 3 && dt.minute == 33, isTrue);
    });

    test('3:34 AM is not the witching minute', () {
      final dt = DateTime(2026, 10, 27, 3, 34, 0);
      expect(dt.hour == 3 && dt.minute == 33, isFalse);
    });

    test('15:33 (3:33 PM) is not the witching minute', () {
      final dt = DateTime(2026, 10, 27, 15, 33, 0);
      expect(dt.hour == 3 && dt.minute == 33, isFalse);
    });

    test('kanji pool has expected entries', () {
      const kanji = ['鬼', '魂', '闇', '呪', '死', '影', '夢', '幽'];
      expect(kanji, hasLength(8));
      expect(kanji, contains('鬼'));
    });
  });
}
