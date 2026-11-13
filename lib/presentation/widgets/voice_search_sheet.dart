import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/voice_error.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'motion.dart';
import 'swipeable_sheet.dart';

enum _SheetState { initializing, listening, done, failed }

class VoiceSearchSheet extends StatefulWidget {
  final String langCode;

  const VoiceSearchSheet({super.key, required this.langCode});

  static Future<String?> show(
    BuildContext context, {
    required String langCode,
  }) {
    return showAppSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceSearchSheet(langCode: langCode),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late final _voice = context.readState(voiceSearchProvider);
  late final AnimationController _pulseController;

  _SheetState _state = _SheetState.initializing;
  VoiceError? _error;
  String _recognizedText = '';
  double _soundLevel = 0;
  String? _localeId;
  bool _localeResolved = false;
  bool _finished = false;
  bool _retriedLocale = false;
  bool _retriedBusy = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _start();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voice.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _retriedBusy = false;
    setState(() {
      _state = _SheetState.initializing;
      _error = null;
      _recognizedText = '';
      _soundLevel = 0;
    });
    final available = await _voice.initialize();
    if (!mounted) return;
    if (!available) {
      _fail(await _voice.initFailure());
      return;
    }
    if (!_localeResolved) {
      _localeId = await _voice.localeFor(widget.langCode);
      _localeResolved = true;
      if (!mounted) return;
    }
    await _listen();
  }

  Future<void> _listen() async {
    setState(() {
      _state = _SheetState.listening;
      _error = null;
    });
    // The ring pulses while listening; still with less motion asked for
    // (the "listening" text says it all the same).
    if (!reduceMotion(context)) _pulseController.repeat();
    Haptics.tap();

    await _voice.listen(
      localeId: _localeId,
      onSoundLevel: (level) {
        if (mounted) {
          setState(() => _soundLevel = ((level + 2) / 12).clamp(0.0, 1.0));
        }
      },
      onResult: (text, isFinal) {
        if (!mounted || _finished) return;
        setState(() => _recognizedText = text);
        if (isFinal && text.trim().isNotEmpty) _finish(text);
      },
      onStatus: (status) {
        if (status != 'done' && status != 'notListening') return;
        // The final result can trail the status by a moment.
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted || _finished || _state != _SheetState.listening) return;
          if (_recognizedText.trim().isNotEmpty) {
            _finish(_recognizedText);
          } else {
            _fail(VoiceError.noMatch);
          }
        });
      },
      onError: (error) {
        if (!mounted || _finished || _state != _SheetState.listening) return;
        _onError(error);
      },
    );
  }

  void _onError(VoiceError error) {
    // Recoverable hiccups get one silent retry.
    if (error == VoiceError.language && !_retriedLocale && _localeId != null) {
      _retriedLocale = true;
      _localeId = null;
      _voice.forgetLocale(widget.langCode);
      _listen();
      return;
    }
    if (error == VoiceError.busy && !_retriedBusy) {
      _retriedBusy = true;
      _voice.cancel().then((_) {
        if (mounted && !_finished) _listen();
      });
      return;
    }
    // Whatever was heard before the hiccup is still worth searching.
    if (_recognizedText.trim().isNotEmpty &&
        error != VoiceError.permission &&
        error != VoiceError.unavailable) {
      _finish(_recognizedText);
      return;
    }
    _fail(error);
  }

  void _fail(VoiceError error) {
    _pulseController.stop();
    Haptics.error();
    setState(() {
      _state = _SheetState.failed;
      _error = error;
      _soundLevel = 0;
    });
  }

  void _finish(String text) async {
    if (_finished) return;
    _finished = true;
    Haptics.confirm();
    setState(() => _state = _SheetState.done);
    _pulseController.stop();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.pop(context, text.trim());
  }

  void _onStop() async {
    final text = _recognizedText;
    await _voice.stop();
    if (!mounted || _finished) return;
    if (text.trim().isNotEmpty) {
      _finish(text);
    } else {
      Navigator.pop(context);
    }
  }

  void _onRetry() {
    if (_error == VoiceError.permission) {
      Geolocator.openAppSettings();
      return;
    }
    _start();
  }

  void _onCancel() {
    _voice.cancel();
    Navigator.pop(context);
  }

  bool get _canRetry => _error != VoiceError.unavailable;

  @override
  Widget build(BuildContext context) {
    final failed = _state == _SheetState.failed;
    final showHint = _recognizedText.isEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF0141720), Color(0xF00D0F18)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border(
          top: BorderSide(color: Color(0x33FF1919), width: 1),
          left: BorderSide(color: Color(0x33FF1919), width: 1),
          right: BorderSide(color: Color(0x33FF1919), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          const SheetHandle(),
          const SizedBox(height: 16),
          // Telemetry header
          // Flavour, not information: screen readers skip it.
          ExcludeSemantics(child: Text(
            '◈ VOICE.SCAN // ACTIVE',
            style: GoogleFonts.notoSansJp(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.accentText,
              letterSpacing: 1.2,
            ),
          )),
          const SizedBox(height: 28),
          // Mic with pulse rings; tapping it after a failure listens again
          // (also picks up a permission just granted in Settings).
          GestureDetector(
            onTap: failed && _canRetry ? _start : null,
            child: SizedBox(
              width: 160,
              height: 160,
              child: _buildMicArea(),
            ),
          ),
          const SizedBox(height: 20),
          // Recognized text, the hint, or why it failed
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                failed && showHint
                    ? _errorDetail
                    : (showHint ? _hintText : _recognizedText),
                key: ValueKey(failed ? 'error' : (showHint ? 'hint' : 'text')),
                style: TextStyle(
                  fontSize: showHint ? AppFontSize.bodyLg : AppFontSize.titleLg,
                  fontWeight: showHint ? FontWeight.w400 : FontWeight.w600,
                  color: showHint ? AppColors.textMuted : AppColors.textBright,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Status
          Text(
            _statusText,
            style: TextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w800,
              color: failed ? AppColors.accent : AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                label: _cancelLabel,
                onTap: _onCancel,
                outlined: true,
              ),
              if (_state == _SheetState.listening &&
                  _recognizedText.isNotEmpty) ...[
                const SizedBox(width: 16),
                _buildActionButton(
                  label: _doneLabel,
                  onTap: _onStop,
                  outlined: false,
                ),
              ],
              if (failed && _canRetry) ...[
                const SizedBox(width: 16),
                _buildActionButton(
                  label: _error == VoiceError.permission
                      ? _settingsLabel
                      : _retryLabel,
                  onTap: _onRetry,
                  outlined: false,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMicArea() {
    if (_state == _SheetState.failed) {
      return Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 2),
          ),
          child: Icon(
            _canRetry ? Icons.refresh : Icons.mic_off,
            color: AppColors.accent,
            size: 36,
          ),
        ),
      );
    }

    if (_state == _SheetState.done) {
      return Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.2),
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: const Icon(Icons.check, color: AppColors.accent, size: 36),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 3; i++) _buildRing(i / 3.0),
            // Inner glow responds to sound level
            Container(
              width: 72 + 8 * _soundLevel,
              height: 72 + 8 * _soundLevel,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08 + 0.12 * _soundLevel),
              ),
            ),
            // Mic icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: const Icon(Icons.mic, color: AppColors.accent, size: 36),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRing(double phaseOffset) {
    final raw = (_pulseController.value + phaseOffset) % 1.0;
    final progress = Curves.easeOut.transform(raw);
    final size = 72.0 + 80.0 * progress;
    final opacity = (1.0 - progress) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: math.max(0, opacity)),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required bool outlined,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: outlined
                ? AppColors.border
                : AppColors.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w800,
            color: outlined ? AppColors.textSecondary : AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  String get _hintText => switch (widget.langCode) {
        'es' => '"pon Chop Suey" o "busca Deftones"',
        'ja' => '"Chop Sueyをかけて" や "Deftones探して"',
        _ => '"play Chop Suey" or "search Deftones"',
      };

  String get _statusText => switch (_state) {
        _SheetState.initializing => switch (widget.langCode) {
            'es' => 'PREPARANDO MICRÓFONO...',
            'ja' => 'マイクを準備中...',
            _ => 'STARTING MIC...',
          },
        _SheetState.listening => switch (widget.langCode) {
            'es' => 'ESCUCHANDO...',
            'ja' => '聞いています...',
            _ => 'LISTENING...',
          },
        _SheetState.done => switch (widget.langCode) {
            'es' => 'PROCESANDO...',
            'ja' => '処理中...',
            _ => 'PROCESSING...',
          },
        _SheetState.failed => _errorTitle,
      };

  String get _errorTitle => switch ((_error, widget.langCode)) {
        (VoiceError.permission, 'es') => 'MICRÓFONO SIN PERMISO',
        (VoiceError.permission, 'ja') => 'マイクの許可がありません',
        (VoiceError.permission, _) => 'NO MICROPHONE PERMISSION',
        (VoiceError.unavailable, 'es') => 'VOZ NO DISPONIBLE',
        (VoiceError.unavailable, 'ja') => '音声認識が利用できません',
        (VoiceError.unavailable, _) => 'VOICE NOT AVAILABLE',
        (VoiceError.noMatch, 'es') => 'NO TE ESCUCHÉ',
        (VoiceError.noMatch, 'ja') => '聞き取れませんでした',
        (VoiceError.noMatch, _) => "DIDN'T CATCH THAT",
        (VoiceError.network, 'es') => 'SIN CONEXIÓN',
        (VoiceError.network, 'ja') => '接続エラー',
        (VoiceError.network, _) => 'NO CONNECTION',
        (VoiceError.language, 'es') => 'IDIOMA NO DISPONIBLE',
        (VoiceError.language, 'ja') => '言語が利用できません',
        (VoiceError.language, _) => 'LANGUAGE NOT AVAILABLE',
        (_, 'es') => 'ALGO FALLÓ',
        (_, 'ja') => 'エラーが発生しました',
        _ => 'SOMETHING WENT WRONG',
      };

  String get _errorDetail => switch ((_error, widget.langCode)) {
        (VoiceError.permission, 'es') =>
          'Permite el micrófono en Ajustes para buscar por voz',
        (VoiceError.permission, 'ja') => '設定でマイクを許可してください',
        (VoiceError.permission, _) =>
          'Allow the microphone in Settings to search by voice',
        (VoiceError.unavailable, 'es') =>
          'Este teléfono no tiene reconocimiento de voz (usa la app de Google)',
        (VoiceError.unavailable, 'ja') => 'この端末では音声認識が使えません',
        (VoiceError.unavailable, _) =>
          "This phone has no speech recognizer (it uses the Google app)",
        (VoiceError.noMatch, 'es') =>
          'Habla cerca del teléfono y toca para intentarlo de nuevo',
        (VoiceError.noMatch, 'ja') => 'もう一度タップして話してください',
        (VoiceError.noMatch, _) => 'Speak close to the phone and tap to retry',
        (VoiceError.network, 'es') =>
          'La búsqueda por voz necesita internet',
        (VoiceError.network, 'ja') => '音声検索にはインターネットが必要です',
        (VoiceError.network, _) => 'Voice search needs the internet',
        (VoiceError.language, 'es') =>
          'Tu reconocedor de voz no tiene este idioma',
        (VoiceError.language, 'ja') => 'この言語は利用できません',
        (VoiceError.language, _) => "Your speech recognizer lacks this language",
        (_, 'es') => 'Toca para intentarlo de nuevo',
        (_, 'ja') => 'タップして再試行',
        _ => 'Tap to try again',
      };

  String get _cancelLabel => switch (widget.langCode) {
        'es' => 'CANCELAR',
        'ja' => 'キャンセル',
        _ => 'CANCEL',
      };

  String get _doneLabel => switch (widget.langCode) {
        'es' => 'LISTO',
        'ja' => '完了',
        _ => 'DONE',
      };

  String get _retryLabel => switch (widget.langCode) {
        'es' => 'REINTENTAR',
        'ja' => '再試行',
        _ => 'RETRY',
      };

  String get _settingsLabel => switch (widget.langCode) {
        'es' => 'AJUSTES',
        'ja' => '設定',
        _ => 'SETTINGS',
      };
}
