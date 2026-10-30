import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_language.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  static const String _cachePrefix = 'tsuki_translated_lyrics_';
  // Keys of the saved translations, oldest first.
  static const String _indexKey = 'tsuki_translated_lyrics_index';

  /// Translations kept on disk. They live in SharedPreferences, which is
  /// read whole at launch, so it must not grow with every song translated.
  static const int _maxSaved = 60;
  static const int _maxInMemory = 30;

  final Map<String, OnDeviceTranslator> _translators = {};
  // Insertion-ordered: the first key is the least recently used.
  final Map<String, List<String>> _memCache = {};

  void _rememberInMemory(String key, List<String> lines) {
    _memCache.remove(key);
    _memCache[key] = lines;
    while (_memCache.length > _maxInMemory) {
      _memCache.remove(_memCache.keys.first);
    }
  }

  TranslateLanguage _appLangToMlKit(AppLanguage lang) {
    return switch (lang) {
      AppLanguage.es => TranslateLanguage.spanish,
      AppLanguage.en => TranslateLanguage.english,
      AppLanguage.ja => TranslateLanguage.japanese,
    };
  }

  TranslateLanguage _bcp47ToMlKit(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('ja')) return TranslateLanguage.japanese;
    if (lower.startsWith('ko')) return TranslateLanguage.korean;
    if (lower.startsWith('zh')) return TranslateLanguage.chinese;
    if (lower.startsWith('es')) return TranslateLanguage.spanish;
    if (lower.startsWith('fr')) return TranslateLanguage.french;
    if (lower.startsWith('de')) return TranslateLanguage.german;
    if (lower.startsWith('pt')) return TranslateLanguage.portuguese;
    if (lower.startsWith('it')) return TranslateLanguage.italian;
    if (lower.startsWith('ru')) return TranslateLanguage.russian;
    return TranslateLanguage.english;
  }

  String _cacheKey(String trackId, AppLanguage target) =>
      '$trackId::${target.code}';

  Future<bool> isModelDownloaded(TranslateLanguage language) async {
    final manager = OnDeviceTranslatorModelManager();
    return manager.isModelDownloaded(language.bcpCode);
  }

  Future<void> downloadModel(
    TranslateLanguage language, {
    VoidCallback? onComplete,
  }) async {
    final manager = OnDeviceTranslatorModelManager();
    final downloaded = await manager.isModelDownloaded(language.bcpCode);
    if (!downloaded) {
      await manager.downloadModel(language.bcpCode);
    }
    onComplete?.call();
  }

  Future<List<String>> translateLines({
    required List<String> lines,
    required String trackId,
    required AppLanguage targetLang,
    String? sourceLanguageCode,
  }) async {
    final key = _cacheKey(trackId, targetLang);

    final inMemory = _memCache[key];
    if (inMemory != null) {
      _rememberInMemory(key, inMemory);
      return inMemory;
    }

    final diskResult = await _loadFromDisk(key);
    if (diskResult != null && diskResult.length == lines.length) {
      _rememberInMemory(key, diskResult);
      return diskResult;
    }

    final sourceLang = sourceLanguageCode != null
        ? _bcp47ToMlKit(sourceLanguageCode)
        : TranslateLanguage.english;
    final targetMlKit = _appLangToMlKit(targetLang);

    if (sourceLang == targetMlKit) {
      return lines;
    }

    final translatorKey = '${sourceLang.bcpCode}_${targetMlKit.bcpCode}';
    final translator = _translators.putIfAbsent(
      translatorKey,
      () => OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetMlKit,
      ),
    );

    final translated = <String>[];
    var failed = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        translated.add('');
        continue;
      }
      try {
        final result = await translator.translateText(line);
        translated.add(result);
      } catch (e) {
        debugPrint('[TranslationService] Error translating line: $e');
        translated.add('');
        failed = true;
      }
    }

    // A failed line (model still downloading, say) must not be saved as an
    // empty translation for good: the next try translates it again.
    if (!failed) {
      _rememberInMemory(key, translated);
      unawaited(_saveToDisk(key, translated));
    }
    return translated;
  }

  Future<List<String>?> _loadFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (e) {
      debugPrint('[TranslationService] Cache read error: $e');
    }
    return null;
  }

  Future<void> _saveToDisk(String key, List<String> lines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', json.encode(lines));
      // Most recent last; drop the oldest beyond the cap. Entries saved
      // before the index existed are adopted (oldest first) and pruned too.
      final index = prefs.getStringList(_indexKey) ??
          prefs
              .getKeys()
              .where((k) => k.startsWith(_cachePrefix) && k != _indexKey)
              .map((k) => k.substring(_cachePrefix.length))
              .toList();
      index
        ..remove(key)
        ..add(key);
      while (index.length > _maxSaved) {
        await prefs.remove('$_cachePrefix${index.removeAt(0)}');
      }
      await prefs.setStringList(_indexKey, index);
    } catch (e) {
      debugPrint('[TranslationService] Cache write error: $e');
    }
  }

  Future<List<TranslateLanguage>> requiredModels({
    String? sourceLanguageCode,
    required AppLanguage targetLang,
  }) async {
    final sourceLang = sourceLanguageCode != null
        ? _bcp47ToMlKit(sourceLanguageCode)
        : TranslateLanguage.english;
    final targetMlKit = _appLangToMlKit(targetLang);

    if (sourceLang == targetMlKit) return [];

    final needed = <TranslateLanguage>[];
    final manager = OnDeviceTranslatorModelManager();

    if (!await manager.isModelDownloaded(sourceLang.bcpCode)) {
      needed.add(sourceLang);
    }
    if (!await manager.isModelDownloaded(targetMlKit.bcpCode)) {
      needed.add(targetMlKit);
    }
    return needed;
  }

  Future<void> downloadRequiredModels({
    String? sourceLanguageCode,
    required AppLanguage targetLang,
    ValueChanged<String>? onProgress,
  }) async {
    final needed = await requiredModels(
      sourceLanguageCode: sourceLanguageCode,
      targetLang: targetLang,
    );

    for (final lang in needed) {
      onProgress?.call(lang.bcpCode);
      await downloadModel(lang);
    }
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }

  void clearCache() {
    _memCache.clear();
  }
}
