import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_on_device_translator');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final translation = TranslationService();
  var failing = false;

  setUp(() {
    translation.clearCache();
    failing = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'nlp#startLanguageTranslator') return null;
      if (failing) throw PlatformException(code: 'model-missing');
      return 'ES:${(call.arguments as Map)['text']}';
    });
  });

  Future<List<String>> translate(String trackId) => translation.translateLines(
        lines: ['hello', '', 'world'],
        trackId: trackId,
        targetLang: AppLanguage.es,
        sourceLanguageCode: 'en',
      );

  test('a failed line is not saved, so the next try translates again', () async {
    SharedPreferences.setMockInitialValues({});
    failing = true;
    expect(await translate('t1'), ['', '', '']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.contains('t1')), isEmpty);

    failing = false;
    expect(await translate('t1'), ['ES:hello', '', 'ES:world']);
  });

  test('saved translations are capped, oldest dropped first', () async {
    SharedPreferences.setMockInitialValues({
      // Saved before the index existed: adopted and pruned too.
      'tsuki_translated_lyrics_legacy::es': '["x","","y"]',
    });
    for (var i = 0; i < 65; i++) {
      await translate('song$i');
    }
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs
        .getKeys()
        .where((k) => k.startsWith('tsuki_translated_lyrics_') && k != 'tsuki_translated_lyrics_index');
    expect(saved.length, 60);
    expect(prefs.containsKey('tsuki_translated_lyrics_legacy::es'), isFalse);
    expect(prefs.containsKey('tsuki_translated_lyrics_song0::es'), isFalse);
    expect(prefs.containsKey('tsuki_translated_lyrics_song64::es'), isTrue);
  });
}
