import 'dart:async';
import 'dart:convert';

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';

final _log = Log.named('TranslationService');

/// Translates lyrics on the phone (Google ML Kit): the song's language is
/// recognized from its words, and lines go one by one so each translation
/// sits under its own line. Each language needs its model downloaded once
/// (about 30 MB); after that it works offline.
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  /// Languages offered to translate into, by code, each named in itself.
  static const targets = <String, String>{
    'es': 'Español',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'pt': 'Português',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'ru': 'Русский',
    'uk': 'Українська',
    'pl': 'Polski',
    'nl': 'Nederlands',
    'sv': 'Svenska',
    'tr': 'Türkçe',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'vi': 'Tiếng Việt',
    'th': 'ไทย',
  };

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

  /// The ML Kit language for a code ('es', 'ja'...), or null when it can't
  /// translate that language.
  static TranslateLanguage? languageFor(String code) {
    for (final l in TranslateLanguage.values) {
      if (l.bcpCode == code) return l;
    }
    return null;
  }

  /// The language the lyrics are written in, as a code the translator
  /// knows, or null when it can't tell (or can't translate from it).
  /// Romanized text ('ja-Latn': Japanese in Latin letters) counts as
  /// unknown: the translator expects the language's own script.
  Future<String?> detectLanguage(String text) async {
    final sample = text.length > 2000 ? text.substring(0, 2000) : text;
    if (sample.trim().isEmpty) return null;
    final identifier = LanguageIdentifier(confidenceThreshold: 0.5);
    try {
      final tag = await identifier.identifyLanguage(sample);
      if (tag == 'und' || tag.contains('-')) return null;
      return languageFor(tag) == null ? null : tag;
    } catch (e) {
      _log.warning('language not identified: $e');
      return null;
    } finally {
      unawaited(identifier.close().catchError((Object _) {}));
    }
  }

  String _cacheKey(String trackId, String target) => '$trackId::$target';

  /// Whether [trackId]'s lyrics were already translated into [target]
  /// (no model or language detection needed to show them again).
  Future<List<String>?> savedTranslation(String trackId, String target, int lineCount) async {
    final key = _cacheKey(trackId, target);
    final inMemory = _memCache[key];
    if (inMemory != null && inMemory.length == lineCount) {
      _rememberInMemory(key, inMemory);
      return inMemory;
    }
    final saved = await _loadFromDisk(key);
    if (saved != null && saved.length == lineCount) {
      _rememberInMemory(key, saved);
      return saved;
    }
    return null;
  }

  Future<List<String>> translateLines({
    required List<String> lines,
    required String trackId,
    required String sourceCode,
    required String targetCode,
  }) async {
    final saved = await savedTranslation(trackId, targetCode, lines.length);
    if (saved != null) return saved;

    final source = languageFor(sourceCode);
    final target = languageFor(targetCode);
    if (source == null || target == null) {
      throw ArgumentError('cannot translate $sourceCode → $targetCode');
    }
    if (source == target) return lines;

    final translator = _translators.putIfAbsent(
      '${source.bcpCode}_${target.bcpCode}',
      () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
    );

    final translated = <String>[];
    var failed = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        translated.add('');
        continue;
      }
      try {
        translated.add(await translator.translateText(line));
      } catch (e) {
        _log.severe('Error translating line: $e');
        translated.add('');
        failed = true;
      }
    }

    // A failed line (model still downloading, say) must not be saved as an
    // empty translation for good: the next try translates it again.
    if (!failed) {
      final key = _cacheKey(trackId, targetCode);
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
      _log.severe('Cache read error: $e');
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
      _log.severe('Cache write error: $e');
    }
  }

  /// The models still to download to translate [sourceCode] → [targetCode].
  Future<List<TranslateLanguage>> requiredModels({
    required String sourceCode,
    required String targetCode,
  }) async {
    final needed = <TranslateLanguage>[];
    final manager = OnDeviceTranslatorModelManager();
    for (final code in {sourceCode, targetCode}) {
      final language = languageFor(code);
      if (language == null) continue;
      if (!await manager.isModelDownloaded(language.bcpCode)) needed.add(language);
    }
    return needed;
  }

  Future<void> downloadRequiredModels({
    required String sourceCode,
    required String targetCode,
  }) async {
    final manager = OnDeviceTranslatorModelManager();
    for (final language in await requiredModels(sourceCode: sourceCode, targetCode: targetCode)) {
      await manager.downloadModel(language.bcpCode);
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
