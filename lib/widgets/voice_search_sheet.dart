import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../services/voice_search_service.dart';

enum _SheetState { initializing, listening, done, error }

class VoiceSearchSheet extends StatefulWidget {
  final String localeId;
  final String langCode;

  const VoiceSearchSheet({
    super.key,
    required this.localeId,
    required this.langCode,
  });

  static Future<String?> show(
    BuildContext context, {
    required String localeId,
    required String langCode,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceSearchSheet(
        localeId: localeId,
        langCode: langCode,
      ),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final _voice = VoiceSearchService();
  late final AnimationController _pulseController;

  _SheetState _state = _SheetState.initializing;
  String _recognizedText = '';
  double _soundLevel = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _initAndListen();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voice.cancel();
    super.dispose();
  }

  Future<void> _initAndListen() async {
    final available = await _voice.initialize();
    if (!mounted) return;

    if (!available) {
      setState(() => _state = _SheetState.error);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _state = _SheetState.listening);
    _pulseController.repeat();
    HapticFeedback.lightImpact();

    await _voice.listen(
      localeId: widget.localeId,
      onSoundLevel: (level) {
        if (mounted) setState(() => _soundLevel = ((level + 2) / 12).clamp(0.0, 1.0));
      },
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _recognizedText = text);
        if (isFinal && text.isNotEmpty) _onFinalResult(text);
      },
    );
  }

  void _onFinalResult(String text) async {
    HapticFeedback.mediumImpact();
    setState(() => _state = _SheetState.done);
    _pulseController.stop();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.pop(context, text);
  }

  void _onStop() async {
    await _voice.stop();
    if (_recognizedText.isNotEmpty && mounted) {
      _onFinalResult(_recognizedText);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  void _onCancel() {
    _voice.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF0141720), Color(0xF00D0F18)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Telemetry header
          Text(
            '◈ VOICE.SCAN // ACTIVE',
            style: GoogleFonts.notoSansJp(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.accent.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          // Mic with pulse rings
          SizedBox(
            width: 160,
            height: 160,
            child: _buildMicArea(),
          ),
          const SizedBox(height: 20),
          // Recognized text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _recognizedText.isEmpty ? _hintText : _recognizedText,
                key: ValueKey(_recognizedText.isEmpty ? 'hint' : 'text'),
                style: TextStyle(
                  fontSize: _recognizedText.isEmpty ? 13 : 18,
                  fontWeight:
                      _recognizedText.isEmpty ? FontWeight.w400 : FontWeight.w600,
                  color: _recognizedText.isEmpty
                      ? AppColors.textMuted
                      : AppColors.textBright,
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
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _state == _SheetState.error
                  ? AppColors.accent
                  : AppColors.textSecondary,
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
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMicArea() {
    if (_state == _SheetState.error) {
      return Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.mic_off, color: AppColors.accent, size: 36),
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
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: outlined
                ? AppColors.border
                : AppColors.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
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
        _SheetState.initializing => 'INITIALIZING...',
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
        _SheetState.error => switch (widget.langCode) {
            'es' => 'VOZ NO DISPONIBLE',
            'ja' => '音声認識が利用できません',
            _ => 'VOICE NOT AVAILABLE',
          },
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
}
