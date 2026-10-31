import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/providers/app_providers.dart';
import 'package:tsuki_tunes_mobile/providers/locale_provider.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the texts follow the language and only notify when it changes', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [localeProvider.overrideWith((ref) => LocaleProvider())],
    );
    addTearDown(container.dispose);

    final seen = <AppLanguage>[];
    container.listen<AppStrings>(stringsProvider, (_, next) => seen.add(next.language));
    expect(container.read(stringsProvider).language, AppLanguage.es);

    final locale = container.read(localeProvider);
    final storage = StorageService();
    await locale.setLanguage(AppLanguage.en, storage);
    expect(container.read(appLanguageProvider), AppLanguage.en);
    expect(container.read(stringsProvider).language, AppLanguage.en);

    // Notifying without a new language (e.g. the saved choice loading)
    // doesn't reach the texts' listeners.
    locale.notifyListeners();
    container.read(stringsProvider);
    await locale.setLanguage(AppLanguage.ja, storage);
    container.read(stringsProvider);

    expect(seen, [AppLanguage.en, AppLanguage.ja]);
  });
}
