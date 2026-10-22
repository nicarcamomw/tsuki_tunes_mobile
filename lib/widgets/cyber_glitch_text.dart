import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// CyberGlitchText: Ultra-realistic Cyberpunk glitch & distortion text widget.
/// Calm for random intervals, then triggers violent, crisp digital glitch bursts
/// with multi-layer RGB Chromatic Aberration, slice displacements, and cyber glyph corruption.
class CyberGlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final List<String>? corruptions;

  const CyberGlitchText({
    super.key,
    required this.text,
    this.style,
    this.corruptions,
  });

  @override
  State<CyberGlitchText> createState() => _CyberGlitchTextState();
}

class _CyberGlitchTextState extends State<CyberGlitchText> {
  Timer? _scheduleTimer;
  Timer? _burstTicker;
  final Random _rng = Random();

  bool _isGlitching = false;
  int _burstFrame = 0;
  String _corruptedText = '';

  // Glitch frame offsets & slice params
  double _jitterX = 0.0;
  double _jitterY = 0.0;
  double _cyanDx = 0.0;
  double _cyanDy = 0.0;
  double _magentaDx = 0.0;
  double _magentaDy = 0.0;
  double _slice1Y = 0.3;
  double _slice1Shift = 0.0;
  double _slice2Y = 0.7;
  double _slice2Shift = 0.0;
  bool _whiteFlash = false;

  @override
  void initState() {
    super.initState();
    _corruptedText = widget.text;
    _scheduleNextGlitch();
  }

  @override
  void didUpdateWidget(covariant CyberGlitchText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _corruptedText = widget.text;
    }
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _burstTicker?.cancel();
    super.dispose();
  }

  void _scheduleNextGlitch() {
    _scheduleTimer?.cancel();
    // Random calm pause before next glitch eruption (2.0s to 4.2s)
    final delayMs = 2000 + _rng.nextInt(2200);
    _scheduleTimer = Timer(Duration(milliseconds: delayMs), _triggerGlitchBurst);
  }

  void _triggerGlitchBurst() {
    if (!mounted) return;
    _burstTicker?.cancel();

    setState(() {
      _isGlitching = true;
      _burstFrame = 0;
    });

    // Fast 38ms tick rate for authentic ~280ms digital glitch burst
    _burstTicker = Timer.periodic(const Duration(milliseconds: 38), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _burstFrame++;
      // A burst lasts 6-8 micro-frames (~230ms - ~300ms)
      if (_burstFrame >= 7) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isGlitching = false;
            _corruptedText = widget.text;
            _jitterX = 0.0;
            _jitterY = 0.0;
            _cyanDx = 0.0;
            _cyanDy = 0.0;
            _magentaDx = 0.0;
            _magentaDy = 0.0;
            _whiteFlash = false;
          });
          _scheduleNextGlitch();
        }
        return;
      }

      setState(() {
        // Physical jitter
        _jitterX = (_rng.nextDouble() * 5.0) - 2.5;
        _jitterY = (_rng.nextDouble() * 2.4) - 1.2;

        // Chromatic Aberration offsets
        _cyanDx = -(_rng.nextDouble() * 4.5 + 2.5);
        _cyanDy = (_rng.nextDouble() * 2.0) - 1.0;
        _magentaDx = (_rng.nextDouble() * 4.5 + 2.5);
        _magentaDy = (_rng.nextDouble() * 2.0) - 1.0;

        // Multi-slice parameters
        _slice1Y = _rng.nextDouble() * 0.45;
        _slice1Shift = (_rng.nextDouble() * 9.0) - 4.5;
        _slice2Y = 0.5 + _rng.nextDouble() * 0.45;
        _slice2Shift = (_rng.nextDouble() * 9.0) - 4.5;

        _whiteFlash = _rng.nextDouble() > 0.65;

        // Corrupted matrix text on glitch frames
        if (_burstFrame % 2 == 1) {
          _corruptedText = _generateCorrupted(widget.text);
        } else {
          _corruptedText = widget.text;
        }
      });
    });
  }

  String _generateCorrupted(String original) {
    if (widget.corruptions != null && widget.corruptions!.isNotEmpty) {
      return widget.corruptions![_rng.nextInt(widget.corruptions!.length)];
    }
    // Dynamic glyph corruption
    final chars = original.split('');
    const glitchGlyphs = ['#', '\$', '!', '_', '[]', '¥', '0', '1', '/', '%', '*'];
    for (int i = 0; i < chars.length; i++) {
      if (_rng.nextDouble() < 0.42 && chars[i] != ' ') {
        chars[i] = glitchGlyphs[_rng.nextInt(glitchGlyphs.length)];
      }
    }
    return chars.join();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.4,
          color: AppColors.accent,
        );

    // Calm state: 100% clean, crisp red with deep neon glow
    if (!_isGlitching) {
      return Text(
        widget.text,
        style: baseStyle.copyWith(
          color: baseStyle.color ?? AppColors.accent,
          shadows: [
            const Shadow(
              color: AppColors.accentGlow,
              blurRadius: 10,
            ),
            ...?baseStyle.shadows,
          ],
        ),
      );
    }

    // Glitching state: multi-layer distorted stack
    return Transform.translate(
      offset: Offset(_jitterX, _jitterY),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Dark Crimson Chromatic Aberration Underlayer
          Transform.translate(
            offset: Offset(_cyanDx, _cyanDy),
            child: Text(
              _corruptedText,
              style: baseStyle.copyWith(
                color: const Color(0xFFFF2B40).withValues(alpha: 0.85),
              ),
            ),
          ),

          // 2. Deep Ruby Chromatic Aberration Underlayer
          Transform.translate(
            offset: Offset(_magentaDx, _magentaDy),
            child: Text(
              _corruptedText,
              style: baseStyle.copyWith(
                color: const Color(0xFF9E0B0B).withValues(alpha: 0.85),
              ),
            ),
          ),

          // 3. Main Text (Red with potential white electrical flash)
          Text(
            _corruptedText,
            style: baseStyle.copyWith(
              color: _whiteFlash ? Colors.white : (baseStyle.color ?? AppColors.accent),
              shadows: [
                const Shadow(
                  color: AppColors.accentGlow,
                  blurRadius: 12,
                ),
                const Shadow(
                  color: Color(0xFFFF2B40),
                  blurRadius: 6,
                  offset: Offset(-1.5, 0),
                ),
                ...?baseStyle.shadows,
              ],
            ),
          ),

          // 4. Horizontal Slice Displacements (Band 1)
          ClipRect(
            clipper: _MultiSliceClipper(
              relativeTop: _slice1Y,
              height: 4.0,
            ),
            child: Transform.translate(
              offset: Offset(_slice1Shift, 0),
              child: Text(
                _corruptedText,
                style: baseStyle.copyWith(
                  color: Colors.white,
                  shadows: [
                    const Shadow(color: AppColors.accent, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),

          // 5. Horizontal Slice Displacements (Band 2)
          ClipRect(
            clipper: _MultiSliceClipper(
              relativeTop: _slice2Y,
              height: 3.5,
            ),
            child: Transform.translate(
              offset: Offset(_slice2Shift, 0),
              child: Text(
                _corruptedText,
                style: baseStyle.copyWith(
                  color: Colors.white,
                  shadows: [
                    const Shadow(color: AppColors.accent, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSliceClipper extends CustomClipper<Rect> {
  final double relativeTop;
  final double height;

  _MultiSliceClipper({required this.relativeTop, required this.height});

  @override
  Rect getClip(Size size) {
    final top = size.height * relativeTop;
    return Rect.fromLTWH(-10, top, size.width + 20, height);
  }

  @override
  bool shouldReclip(_MultiSliceClipper oldClipper) =>
      oldClipper.relativeTop != relativeTop || oldClipper.height != height;
}
