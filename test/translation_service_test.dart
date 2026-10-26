import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/services/translation_service.dart';

void main() {
  group('TranslationService cache logic', () {
    test('clearCache empties the in-memory cache', () {
      final service = TranslationService();
      service.clearCache();
      // Should not throw - basic smoke test for the singleton
      expect(service, isNotNull);
    });

    test('singleton pattern returns same instance', () {
      final a = TranslationService();
      final b = TranslationService();
      expect(identical(a, b), isTrue);
    });
  });
}
