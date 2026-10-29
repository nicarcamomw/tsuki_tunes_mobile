import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceAction { play, search }

class VoiceCommand {
  final VoiceAction action;
  final String query;
  const VoiceCommand(this.action, this.query);
}

/// Why listening stopped without a usable result.
enum VoiceError {
  /// Microphone permission denied.
  permission,

  /// No speech recognizer on this phone (e.g. no Google app).
  unavailable,

  /// Heard nothing, or nothing it could recognize.
  noMatch,

  /// The recognizer needs the network and couldn't reach it.
  network,

  /// The chosen language isn't supported by the recognizer.
  language,

  /// A previous session was still closing.
  busy,

  other,
}

class VoiceSearchService {
  static final VoiceSearchService _instance = VoiceSearchService._();
  factory VoiceSearchService() => _instance;
  VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  final Map<String, String?> _localeCache = {};

  // The plugin takes its listeners once, at initialize; route them to
  // whoever is listening now.
  void Function(String status)? _onStatus;
  void Function(VoiceError error)? _onError;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  /// Asks for the microphone the first time and sets up the recognizer.
  /// Tries again on every call until it works, so granting the permission
  /// later (or installing a recognizer) is picked up without a restart.
  Future<bool> initialize() async {
    if (_available) return true;
    try {
      _available = await _speech.initialize(
        onError: _handleError,
        onStatus: (status) => _onStatus?.call(status),
      );
    } catch (e) {
      debugPrint('[Voice] Init failed: $e');
      _available = false;
    }
    return _available;
  }

  /// Why [initialize] failed.
  Future<VoiceError> initFailure() async {
    try {
      if (!await _speech.hasPermission) return VoiceError.permission;
    } catch (_) {}
    return VoiceError.unavailable;
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('[Voice] ${error.errorMsg} (permanent: ${error.permanent})');
    _onError?.call(errorFromCode(error.errorMsg));
  }

  @visibleForTesting
  static VoiceError errorFromCode(String code) => switch (code) {
        'error_no_match' || 'error_speech_timeout' => VoiceError.noMatch,
        'error_network' ||
        'error_network_timeout' ||
        'error_server' ||
        'error_server_disconnected' ||
        'error_too_many_requests' =>
          VoiceError.network,
        'error_permission' || 'error_insufficient_permissions' =>
          VoiceError.permission,
        'error_language_not_supported' ||
        'error_language_unavailable' =>
          VoiceError.language,
        'error_busy' || 'error_recognizer_busy' => VoiceError.busy,
        _ => VoiceError.other,
      };

  /// Starts listening. [onStatus] gets the plugin's status ('listening',
  /// 'notListening', 'done'); [onError] why it stopped early. A null
  /// [localeId] lets the recognizer use the phone's language.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function(VoiceError error) onError,
    void Function(double level)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_available) {
      onError(VoiceError.unavailable);
      return;
    }
    _onStatus = onStatus;
    _onError = onError;
    try {
      if (_speech.isListening) await _speech.cancel();
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.search,
          cancelOnError: true,
          partialResults: true,
          // The on-device recognizer needs an offline language pack most
          // phones don't have, and fails silently without one; the regular
          // one also knows far more band and song names.
          onDevice: false,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 20),
        ),
      );
    } catch (e) {
      debugPrint('[Voice] listen failed: $e');
      onError(VoiceError.other);
    }
  }

  /// Stops listening; the recognizer still delivers what it heard.
  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// Stops listening and drops the result.
  Future<void> cancel() async {
    _onStatus = null;
    _onError = null;
    if (_speech.isListening) await _speech.cancel();
  }

  /// The recognizer rejected the locale picked for [langCode]: let it
  /// choose from now on.
  void forgetLocale(String langCode) => _localeCache[langCode] = null;

  /// The recognizer locale for [langCode]: the phone's own variant when it
  /// speaks that language (es_CL on a Chilean phone), else an installed
  /// variant, else null to let the recognizer choose.
  Future<String?> localeFor(String langCode) async {
    if (_localeCache.containsKey(langCode)) return _localeCache[langCode];
    String? chosen;
    try {
      final system = await _speech.systemLocale();
      final ids = (await _speech.locales()).map((l) => l.localeId).toList();
      chosen = pickLocale(langCode, system?.localeId, ids);
    } catch (e) {
      debugPrint('[Voice] locale lookup failed: $e');
    }
    return _localeCache[langCode] = chosen;
  }

  @visibleForTesting
  static String? pickLocale(
      String langCode, String? systemLocale, List<String> available) {
    String norm(String id) => id.replaceAll('-', '_').toLowerCase();
    bool speaks(String id) => norm(id).split('_').first == langCode;

    if (systemLocale != null && speaks(systemLocale)) return systemLocale;
    final preferred = switch (langCode) {
      'es' => ['es_419', 'es_us', 'es_mx', 'es_es'],
      'en' => ['en_us', 'en_gb'],
      'ja' => ['ja_jp'],
      _ => <String>[],
    };
    for (final p in preferred) {
      for (final id in available) {
        if (norm(id) == p) return id;
      }
    }
    for (final id in available) {
      if (speaks(id)) return id;
    }
    return null;
  }

  // Longest first, so "pon la canción" wins over "pon". Matched without
  // accents, since recognizers spell "búscame" either way.
  static const _playPrefixes = [
    'quiero escuchar ', 'quiero oir ', 'ponme la cancion ', 'ponme el tema ',
    'pon la cancion ', 'pon el tema ', 'reproduce la cancion ',
    'reproducir la cancion ', 'ponme musica de ', 'ponme algo de ',
    'pon musica de ', 'pon algo de ', 'ponme a ', 'pon a ', 'ponme ',
    'reproduce ', 'reproducir ', 'escuchar ', 'tocar ', 'toca ', 'pon ',
    'i want to listen to ', 'play the song ', 'play music by ', 'play some ',
    'listen to ', 'put on ', 'play ',
  ];
  static const _searchPrefixes = [
    'encuentrame ', 'encuentra ', 'buscame ', 'buscar ', 'busca ',
    'search for ', 'look for ', 'look up ', 'search ', 'find ',
  ];
  static const _fillerStarts = [
    'oye ', 'hey ', 'ok ', 'okay ', 'por favor ', 'please ',
  ];
  static const _fillerEnds = [' por favor', ' please'];

  /// Lowercase without Spanish accents; keeps the length, so indices match
  /// the original text.
  static String _fold(String s) {
    const from = 'áéíóúüÁÉÍÓÚÜ';
    const to = 'aeiouuAEIOUU';
    final out = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      out.write(i == -1 ? ch : to[i]);
    }
    return out.toString().toLowerCase();
  }

  /// Parses spoken text into a structured command.
  /// Supports prefix-based commands (ES/EN) and suffix-based (JA).
  static VoiceCommand parseCommand(String text) {
    var trimmed = text.trim().replaceAll(RegExp(r'[.!?¡¿]+$'), '').trim();
    if (trimmed.isEmpty) return const VoiceCommand(VoiceAction.search, '');

    // Drop wake words and politeness around the command.
    var changed = true;
    while (changed) {
      changed = false;
      final folded = _fold(trimmed);
      for (final f in _fillerStarts) {
        if (folded.startsWith(f)) {
          trimmed = trimmed.substring(f.length).trim();
          changed = true;
          break;
        }
      }
      for (final f in _fillerEnds) {
        if (_fold(trimmed).endsWith(f)) {
          trimmed = trimmed.substring(0, trimmed.length - f.length).trim();
          changed = true;
          break;
        }
      }
    }
    if (trimmed.isEmpty) return const VoiceCommand(VoiceAction.search, '');
    final lower = _fold(trimmed);

    // --- Prefix-based: play ---
    for (final p in _playPrefixes) {
      if (lower.startsWith(p)) {
        final q = trimmed.substring(p.length).trim();
        if (q.isNotEmpty) return VoiceCommand(VoiceAction.play, q);
      }
    }

    // --- Prefix-based: search ---
    for (final p in _searchPrefixes) {
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

  /// "Jefe de La Combo Tortuga" -> "Jefe La Combo Tortuga": a second try
  /// for "song by artist" requests when the literal text finds nothing.
  /// Null when there's no "de"/"by" to drop.
  static String? withoutArtistJoiner(String query) {
    final match = RegExp(r'^(.*\S)\s+(?:de|by)\s+(\S.*)$', caseSensitive: false)
        .firstMatch(query);
    if (match == null) return null;
    return '${match.group(1)} ${match.group(2)}';
  }
}
