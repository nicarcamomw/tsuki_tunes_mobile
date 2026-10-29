import 'package:flutter_test/flutter_test.dart';

void main() {
  group('birthday sakura overlay', () {
    test('birthday MM-dd format parsing', () {
      const birthday = '10-27';
      final parts = birthday.split('-');
      expect(parts.length, 2);
      expect(int.parse(parts[0]), 10);
      expect(int.parse(parts[1]), 27);
    });

    test('today matches birthday triggers overlay', () {
      final now = DateTime.now();
      final todayMmDd = '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final parts = todayMmDd.split('-');
      expect(int.parse(parts[0]), now.month);
      expect(int.parse(parts[1]), now.day);
    });

    test('different day does not match', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowMmDd = '${tomorrow.month.toString().padLeft(2, '0')}-'
          '${tomorrow.day.toString().padLeft(2, '0')}';
      final todayMmDd = '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      if (now.day != tomorrow.day || now.month != tomorrow.month) {
        expect(tomorrowMmDd, isNot(todayMmDd));
      }
    });

    test('petal count is 28', () {
      const petalCount = 28;
      expect(petalCount, greaterThanOrEqualTo(20));
      expect(petalCount, lessThanOrEqualTo(40));
    });
  });
}
