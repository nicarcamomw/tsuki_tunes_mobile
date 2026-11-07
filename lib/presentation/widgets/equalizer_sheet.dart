import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/logic/equalizer_presets.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';

/// The equalizer's presets, with each one's curve drawn so the difference
/// shows before it's heard.
Future<void> showEqualizerSheet(BuildContext context) => SwipeableSheet.show(
      context,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (_, controller) => _EqualizerSheet(controller: controller),
    );

class _EqualizerSheet extends ConsumerWidget {
  final ScrollController controller;
  const _EqualizerSheet({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final current = audio.eqPreset;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Text(strings.eqTitle.toUpperCase(),
            style: locale.getTextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 2)),
        const SizedBox(height: 6),
        Text(audio.hasEqualizer ? strings.eqSubtitle : strings.eqUnavailable,
            style: locale.getTextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 14),
        _Curve(preset: current),
        const SizedBox(height: 14),
        for (final p in EqPreset.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PresetTile(
              name: strings.eqPresetName(p),
              hint: strings.eqPresetHint(p),
              selected: p == current,
              enabled: audio.hasEqualizer,
              locale: locale,
              onTap: () {
                Haptics.selection();
                audio.setEqPreset(p);
              },
            ),
          ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String name;
  final String hint;
  final bool selected;
  final bool enabled;
  final LocaleProvider locale;
  final VoidCallback onTap;
  const _PresetTile({
    required this.name,
    required this.hint,
    required this.selected,
    required this.enabled,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name. $hint',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: locale.getTextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textBright)),
                      const SizedBox(height: 2),
                      Text(hint, style: locale.getTextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The preset's gain from 30 Hz to 16 kHz, flat when off.
class _Curve extends StatelessWidget {
  final EqPreset preset;
  const _Curve({required this.preset});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0F15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(preset),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(painter: _CurvePainter(preset, t)),
          ),
        ),
      );
}

class _CurvePainter extends CustomPainter {
  final EqPreset preset;
  final double t;
  _CurvePainter(this.preset, this.t);

  static const _minHz = 30.0, _maxHz = 16000.0, _range = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = AppColors.border);
    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final x = i / steps;
      final hz = _minHz * math.pow(_maxHz / _minHz, x);
      final db = EqCurves.gainAt(preset, hz) * t;
      final y = mid - (db / _range) * (size.height / 2 - 8);
      final px = x * size.width;
      if (i == 0) {
        path.moveTo(px, y);
      } else {
        path.lineTo(px, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.preset != preset || old.t != t;
}
