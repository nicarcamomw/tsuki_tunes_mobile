import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceAction { play, search }

class VoiceCommand {
  final VoiceAction action;
  final String query;
  const VoiceCommand(this.action, this.query);
}

class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _initDone = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_initDone) return _available;
    _initDone = true;
    try {
      _available = await _speech.initialize(
        onError: (error) => debugPrint('[Voice] ${error.errorMsg}'),
      );
    } catch (e) {
      debugPrint('[Voice] Init failed: $e');
      _available = false;
    }
    return _available;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.search,
        cancelOnError: true,
        partialResults: true,
        onDevice: true,
        localeId: localeId,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 15),
      ),
    );
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }

  /// Parses spoken text into a structured command.
  /// Supports prefix-based commands (ES/EN) and suffix-based (JA).
  static VoiceCommand parseCommand(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const VoiceCommand(VoiceAction.search, '');
    final lower = trimmed.toLowerCase();

    // --- Prefix-based: play ---
    const playPrefixes = [
      'ponme a ', 'pon a ', 'ponme ', 'reproduce ', 'reproducir ',
      'toca ', 'tocar ', 'pon ',
      'put on ', 'play ',
    ];
    for (final p in playPrefixes) {
      if (lower.startsWith(p)) {
        final q = trimmed.substring(p.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
      }
    }

    // --- Prefix-based: search ---
    const searchPrefixes = [
      'búscame ', 'buscar ', 'busca ',
      'search for ', 'look for ', 'search ', 'find ',
    ];
    for (final p in searchPrefixes) {
      if (lower.startsWith(p)) {
        final q = trimmed.substring(p.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.search, q);
      }
    }

    // --- Suffix-based (Japanese verb-final): play ---
    const playSuffixes = [
      'を再生して', '再生して', 'をかけて', 'かけて', 'を流して', '流して',
      'を再生', 'をプレイ',
    ];
    for (final s in playSuffixes) {
      if (lower.endsWith(s)) {
        final q = trimmed.substring(0, trimmed.length - s.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
      }
    }

    // --- Suffix-based (Japanese): search ---
    const searchSuffixes = ['を探して', '探して', 'を検索', '検索'];
    for (final s in searchSuffixes) {
      if (lower.endsWith(s)) {
        final q = trimmed.substring(0, trimmed.length - s.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.search, q);
      }
    }

    // --- Japanese prefix-based ---
    if (lower.startsWith('かけて ')) {
      final q = trimmed.substring(4).trim();
      if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
    }
    if (lower.startsWith('再生 ')) {
      final q = trimmed.substring(3).trim();
      if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
    }

    return VoiceCommand(VoiceAction.search, trimmed);
  }

  String localeForLanguage(String langCode) => switch (langCode) {
        'es' => 'es_MX',
        'ja' => 'ja_JP',
        _ => 'en_US',
      };
}
