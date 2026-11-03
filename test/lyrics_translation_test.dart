import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/lyrics_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/translation_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/lyrics_view.dart';

const _track = Track(
  id: 'k1',
  title: 'Song',
  artistId: 'a',
  artistName: 'Artist',
  albumId: '',
  albumTitle: '',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late String detected;
  late Set<String> downloadedModels;
  late List<String> downloads;
  late List<String> pairs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LyricsService().clearCache();
    TranslationService().clearCache();
    detected = 'ja';
    downloadedModels = {'en'};
    downloads = [];
    pairs = [];
    messenger.setMockMethodCallHandler(const MethodChannel('google_mlkit_language_identifier'),
        (call) async => call.method == 'nlp#startLanguageIdentifier' ? detected : null);
    messenger.setMockMethodCallHandler(const MethodChannel('google_mlkit_on_device_translator'),
        (call) async {
      final args = (call.arguments as Map?) ?? {};
      switch (call.method) {
        case 'nlp#manageLanguageModelModels':
          if (args['task'] == 'check') return downloadedModels.contains(args['model']);
          if (args['task'] == 'download') {
            downloads.add(args['model'] as String);
            downloadedModels.add(args['model'] as String);
            return true;
          }
          return true;
        case 'nlp#startLanguageTranslator':
          pairs.add('${args['source']}>${args['target']}');
          return '[${args['target']}] ${args['text']}';
      }
      return null;
    });
  });

  Future<LyricsController> loaded(String lrc) async {
    final controller = LyricsController();
    final client = MockClient((req) async => req.url.path == '/api/get'
        ? http.Response.bytes(utf8.encode(jsonEncode({'syncedLyrics': lrc})), 200,
            headers: {'content-type': 'application/json'})
        : http.Response('[]', 200));
    await http.runWithClient(() async {
      controller.ensureFor(_track);
      while (controller.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }, () => client);
    return controller;
  }

  test('a Japanese song is translated from Japanese, under each line', () async {
    final c = await loaded('[00:01.00]こんにちは\n[00:02.00]世界');
    var asked = 0;
    final outcome = await c.translateTo('es', confirmDownload: (n) async {
      asked = n;
      return true;
    });

    expect(outcome, TranslationOutcome.shown);
    expect(asked, 2, reason: 'Japanese and Spanish models, after asking');
    expect(downloads, unorderedEquals(['ja', 'es']));
    expect(pairs.toSet(), {'ja>es'}, reason: 'from the song\'s language, not English');
    expect(c.translation, ['[es] こんにちは', '[es] 世界']);
    expect(c.translatedTo, 'es');
    c.dispose();
  });

  test('another language can be picked, and back to the first without redoing it', () async {
    final c = await loaded('[00:01.00]hello');
    detected = 'en';
    downloadedModels.addAll({'pt', 'ko'});
    Future<bool> yes(int _) async => true;

    await c.translateTo('pt', confirmDownload: yes);
    expect(c.translation, ['[pt] hello']);
    await c.translateTo('ko', confirmDownload: yes);
    expect(c.translation, ['[ko] hello']);
    expect(c.translatedTo, 'ko');

    pairs.clear();
    await c.translateTo('pt', confirmDownload: yes);
    expect(c.translation, ['[pt] hello']);
    expect(pairs, isEmpty, reason: 'saved from before');

    c.hideTranslation();
    expect(c.translation, isNull);
    expect(c.translatedTo, isNull);
    c.dispose();
  });

  test('lyrics already in that language: said so, nothing repeated under them', () async {
    final c = await loaded('[00:01.00]hola');
    detected = 'es';
    final outcome = await c.translateTo('es', confirmDownload: (_) async => true);
    expect(outcome, TranslationOutcome.sameLanguage);
    expect(c.translation, isNull);
    expect(pairs, isEmpty);
    c.dispose();
  });

  test('an unrecognized or romanized language is said so', () async {
    final c = await loaded('[00:01.00]konnichiwa sekai');
    detected = 'ja-Latn';
    expect(await c.translateTo('es', confirmDownload: (_) async => true),
        TranslationOutcome.unknownLanguage);
    detected = 'und';
    expect(await c.translateTo('es', confirmDownload: (_) async => true),
        TranslationOutcome.unknownLanguage);
    c.dispose();
  });

  test('declining the download leaves the lyrics as they were', () async {
    final c = await loaded('[00:01.00]こんにちは');
    final outcome = await c.translateTo('es', confirmDownload: (_) async => false);
    expect(outcome, TranslationOutcome.cancelled);
    expect(downloads, isEmpty);
    expect(c.translation, isNull);
    expect(c.translating, isFalse);
    c.dispose();
  });

  test('the language picked last is remembered', () async {
    expect(await LyricsController.lastTarget(), isNull);
    await LyricsController.rememberTarget('ko');
    expect(await LyricsController.lastTarget(), 'ko');
    expect(LyricsController.translationTargets['ko'], '한국어');
  });
}
