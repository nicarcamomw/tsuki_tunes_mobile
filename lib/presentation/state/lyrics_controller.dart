import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../data/datasources/lyrics_service.dart';
import '../../data/datasources/translation_service.dart';
import '../../domain/entities/synced_lyrics.dart';
import '../../domain/entities/track.dart';

final _log = Log.named('Lyrics');

/// How asking for a translation ended.
enum TranslationOutcome {
  shown,
  /// The user didn't want to download the language models.
  cancelled,
  /// The lyrics are already in the language asked for.
  sameLanguage,
  /// The song's language couldn't be recognized (or can't be translated).
  unknownLanguage,
  failed,
}

/// Lyrics of the playing track, shared by the card under the player and the
/// full-screen view, so they load once and a translation carries over.
class LyricsController extends ChangeNotifier {
  String? _trackId;
  SyncedLyrics? _lyrics;
  bool _loading = false;
  List<String>? _translated;
  bool _showTranslation = false;
  bool _translating = false;
  bool _disposed = false;

  String? get trackId => _trackId;
  SyncedLyrics? get lyrics => _lyrics;
  bool get loading => _loading;
  bool get translating => _translating;

  /// Translated lines, when the translation is switched on.
  List<String>? get translation => _showTranslation ? _translated : null;

  bool get hasText =>
      _lyrics != null &&
      !_lyrics!.isInstrumental &&
      _lyrics!.plainLyrics.trim().isNotEmpty;

  /// One entry per displayed line, in order.
  List<String> get lineTexts => _lyrics == null
      ? const []
      : _lyrics!.isSynced
          ? [for (final l in _lyrics!.lines) l.text]
          : _lyrics!.plainLyrics.split('\n');

  /// Loads [track]'s lyrics unless they are the ones already loaded.
  void ensureFor(Track track) {
    if (_trackId != track.id) _load(track);
  }

  void retry(Track track) => _load(track);

  /// Waits before each automatic retry when lrclib couldn't be reached.
  @visibleForTesting
  static List<Duration> retryDelays = const [Duration(seconds: 2), Duration(seconds: 5)];

  Future<void> _load(Track track) async {
    _trackId = track.id;
    _lyrics = null;
    _loading = true;
    _translated = null;
    _translatedTo = null;
    _showTranslation = false;
    _translating = false;
    _notify();
    SyncedLyrics? result;
    for (var attempt = 0;; attempt++) {
      try {
        result = await LyricsService().getLyrics(track.title, track.artistName,
            durationSeconds: track.durationSeconds);
        break;
      } catch (e) {
        _log.severe('load failed (attempt ${attempt + 1}): $e');
        // A network hiccup, not "no lyrics": try again on our own instead
        // of making the user tap retry.
        if (attempt >= retryDelays.length) break;
        await Future<void>.delayed(retryDelays[attempt]);
        if (_disposed || _trackId != track.id) return;
      }
    }
    if (_disposed || _trackId != track.id) return;
    _lyrics = result;
    _loading = false;
    _notify();
  }

  /// Languages lyrics can be translated into: code → name in itself.
  static Map<String, String> get translationTargets => TranslationService.targets;

  static const _lastTargetKey = 'lyrics_translate_to';

  /// The language last chosen to translate into, if any.
  static Future<String?> lastTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_lastTargetKey);
      return TranslationService.targets.containsKey(code) ? code : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> rememberTarget(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastTargetKey, code);
    } catch (_) {}
  }

  /// The language shown under each line, while a translation is on.
  String? get translatedTo => _showTranslation ? _translatedTo : null;
  String? _translatedTo;

  /// Hides the translation (the original lines stay).
  void hideTranslation() {
    if (!_showTranslation) return;
    _showTranslation = false;
    _notify();
  }

  /// Shows the lyrics translated into [target] (a code from
  /// TranslationService.targets) under each line. The song's language is
  /// recognized first: nothing to do when it's already [target]. Models
  /// still missing are downloaded after [confirmDownload] says yes.
  Future<TranslationOutcome> translateTo(
    String target, {
    required Future<bool> Function(int models) confirmDownload,
  }) async {
    final trackId = _trackId;
    if (trackId == null || !hasText) return TranslationOutcome.failed;
    if (_translatedTo == target && _translated != null) {
      _showTranslation = true;
      _notify();
      return TranslationOutcome.shown;
    }
    final service = TranslationService();
    _translating = true;
    _notify();
    try {
      final lines = lineTexts;
      final saved = await service.savedTranslation(trackId, target, lines.length);
      if (saved != null) {
        if (_disposed || _trackId != trackId) return TranslationOutcome.failed;
        _show(saved, target);
        return TranslationOutcome.shown;
      }
      final source = await service.detectLanguage(lines.join('\n'));
      if (_disposed || _trackId != trackId) return TranslationOutcome.failed;
      if (source == null) return TranslationOutcome.unknownLanguage;
      if (source == target) return TranslationOutcome.sameLanguage;
      final needed = await service.requiredModels(sourceCode: source, targetCode: target);
      if (needed.isNotEmpty) {
        if (!await confirmDownload(needed.length)) return TranslationOutcome.cancelled;
        await service.downloadRequiredModels(sourceCode: source, targetCode: target);
      }
      final translated = await service.translateLines(
        lines: lines,
        trackId: trackId,
        sourceCode: source,
        targetCode: target,
      );
      if (_disposed || _trackId != trackId) return TranslationOutcome.failed;
      _show(translated, target);
      return TranslationOutcome.shown;
    } catch (e) {
      _log.severe('translation failed: $e');
      return TranslationOutcome.failed;
    } finally {
      if (!_disposed && _trackId == trackId) {
        _translating = false;
        _notify();
      }
    }
  }

  void _show(List<String> lines, String target) {
    _translated = lines;
    _translatedTo = target;
    _showTranslation = true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
