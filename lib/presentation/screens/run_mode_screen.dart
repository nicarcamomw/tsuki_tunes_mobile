import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/logic/cadence_detector.dart';
import '../../domain/logic/pace_matcher.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/run_provider.dart';
import '../widgets/haptics.dart';

class RunModeScreen extends ConsumerWidget {
  const RunModeScreen({super.key});

  static Future<void> open(BuildContext context) => const RunModeRoute().push(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final run = ref.watch(runProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.runTitle,
          style: locale.getTextStyle(
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  Center(child: _CadenceGauge(run: run)),
                  const SizedBox(height: 10),
                  _StatusLine(run: run),
                  const SizedBox(height: 16),
                  if (run.active || !run.sensorAvailable) ...[
                    _MusicPanel(run: run),
                    const SizedBox(height: 12),
                  ],
                  _SyncRow(run: run),
                  if (run.active) ...[
                    const SizedBox(height: 12),
                    _SessionStats(run: run),
                  ],
                  const SizedBox(height: 16),
                  _Hint(icon: Icons.lock_clock_rounded, text: strings.runBackgroundHint),
                  const SizedBox(height: 8),
                  _Hint(icon: Icons.speed_rounded, text: strings.runHalfTimeNote),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: run.active ? AppColors.bgCard : AppColors.accentFill,
                    foregroundColor: AppColors.textBright,
                    side: run.active ? const BorderSide(color: AppColors.accent) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Haptics.confirm();
                    run.active ? run.stop() : run.start();
                  },
                  child: Text(
                    run.active ? strings.runStop : strings.runStart,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.heading,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _stateColor(MotionState state) => switch (state) {
      MotionState.still => AppColors.textMuted,
      MotionState.walking => AppColors.neonCyan,
      MotionState.running => AppColors.accent,
    };

/// Cadence dial: 60–200 steps/min around a ring, with a pulse on every step
/// and a marker at the tempo the music follows.
class _CadenceGauge extends ConsumerWidget {
  final RunProvider run;
  const _CadenceGauge({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final reading = run.reading;
    final spm = run.active ? reading.spm : null;
    final color = _stateColor(spm == null ? MotionState.still : reading.state);
    final label = spm == null ? '- - -' : '${spm.round()}';

    return Semantics(
      label: '${strings.runSpmUnit}: $label, ${strings.runState(reading.state)}',
      child: SizedBox(
        width: 240,
        height: 240,
        child: RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _StepPulse(spm: spm, color: color),
              CustomPaint(
                size: const Size.square(240),
                painter: _GaugePainter(
                  spm: spm,
                  target: run.active ? run.target : null,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: locale.getTextStyle(
                      fontSize: spm == null ? AppFontSize.hero : AppFontSize.giant,
                      fontWeight: FontWeight.w900,
                      color: spm == null ? AppColors.borderGlow : AppColors.textBright,
                      height: 1,
                      shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 18)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.runSpmUnit,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      strings.runState(spm == null ? MotionState.still : reading.state),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  static const double minSpm = 60, maxSpm = 200;
  static const double start = pi * 0.75, sweep = pi * 1.5;

  final double? spm;
  final double? target;
  final Color color;

  _GaugePainter({required this.spm, required this.target, required this.color});

  double _angle(double v) => start + sweep * ((v - minSpm) / (maxSpm - minSpm)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 22;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = AppColors.bgCard);

    // Ticks every 20 steps/min.
    final tick = Paint()
      ..color = AppColors.borderGlow
      ..strokeWidth = 1.5;
    for (var v = minSpm; v <= maxSpm; v += 20) {
      final a = _angle(v);
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(c + dir * (r + 10), c + dir * (r + 15), tick);
    }

    final v = spm;
    if (v != null) {
      final end = _angle(v);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        // Rotated to start at the dial's start; the dial covers 3/4 of the
        // turn and the last quarter fades back to cyan, so the round cap at
        // the start doesn't pick up the end colour.
        ..shader = const SweepGradient(
          colors: [AppColors.neonCyan, AppColors.neonPurple, AppColors.accent, AppColors.neonCyan],
          stops: [0, 0.375, 0.75, 1],
          transform: GradientRotation(start),
        ).createShader(rect);
      canvas.drawArc(rect, start, end - start, false, arc);
      final tip = c + Offset(cos(end), sin(end)) * r;
      canvas.drawCircle(tip, 7, Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(tip, 4, Paint()..color = AppColors.textBright);
    }

    final t = target;
    if (t != null) {
      // Marker outside the ring where the music sits.
      final a = _angle(t);
      final dir = Offset(cos(a), sin(a));
      final normal = Offset(-dir.dy, dir.dx);
      final p = c + dir * (r + 12);
      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo((p + dir * 9 + normal * 5).dx, (p + dir * 9 + normal * 5).dy)
        ..lineTo((p + dir * 9 - normal * 5).dx, (p + dir * 9 - normal * 5).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.warning);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.spm != spm || old.target != target || old.color != color;
}

/// A ring that flashes once per step.
class _StepPulse extends StatefulWidget {
  final double? spm;
  final Color color;
  const _StepPulse({required this.spm, required this.color});

  @override
  State<_StepPulse> createState() => _StepPulseState();
}

class _StepPulseState extends State<_StepPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StepPulse old) {
    super.didUpdateWidget(old);
    // Only re-time on a real change, so the pulse doesn't stutter.
    final a = old.spm, b = widget.spm;
    if ((a == null) != (b == null) || (a != null && b != null && (a - b).abs() >= 1)) _sync();
  }

  void _sync() {
    final spm = widget.spm;
    if (spm == null || spm <= 0 || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _c.stop();
      _c.value = 0;
      return;
    }
    _c.duration = Duration(microseconds: (60e6 / spm).round());
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        if (widget.spm == null) return const SizedBox.shrink();
        final scale = 0.78 + 0.16 * Curves.easeOut.transform(t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends ConsumerWidget {
  final RunProvider run;
  const _StatusLine({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final String text;
    var color = AppColors.textMuted;
    if (!run.active) {
      text = strings.runIntro;
    } else if (!run.sensorAvailable) {
      text = strings.runNoSensor;
      color = AppColors.warning;
    } else if (run.isLocked) {
      text = strings.runLockedHint;
    } else {
      switch (run.phase) {
        case RunPhase.waiting:
          text = strings.runWaiting;
        case RunPhase.searching:
          text = strings.runSearching;
        case RunPhase.noMatches:
          text = strings.runNoMatches;
          color = AppColors.warning;
        case RunPhase.playing:
          final t = run.target;
          text = t == null ? strings.runWaiting : strings.runMusicAt(t.round());
          color = AppColors.textPrimary;
      }
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: locale.getTextStyle(fontSize: AppFontSize.body, color: color, height: 1.4),
    );
  }
}

class _MusicPanel extends ConsumerWidget {
  final RunProvider run;
  const _MusicPanel({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final track = ref.watch(currentTrackProvider);
    final target = run.target;
    final bpm = run.currentBpm;
    final rate = run.currentRate;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target == null ? '—' : strings.runMusicAt(target.round()),
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.bodyLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                  ),
                ),
              ),
              if (run.isLocked) ...[
                _RoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: '−2',
                  onTap: () { Haptics.selection(); run.nudgeLock(-2); },
                ),
                const SizedBox(width: 6),
                _RoundButton(
                  icon: Icons.add_rounded,
                  tooltip: '+2',
                  onTap: () { Haptics.selection(); run.nudgeLock(2); },
                ),
              ],
            ],
          ),
          if (run.sensorAvailable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: target == null
                    ? null
                    : () {
                        Haptics.selection();
                        run.isLocked ? run.unlock() : run.lock();
                      },
                icon: Icon(run.isLocked ? Icons.directions_walk_rounded : Icons.lock_rounded, size: 16),
                label: Text(
                  run.isLocked ? strings.runUnlock : strings.runLock,
                  style: locale.getTextStyle(fontSize: AppFontSize.label, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neonCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          if (track != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: track.coverUrl.isEmpty
                      ? Container(width: 44, height: 44, color: AppColors.bgHover)
                      : CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          memCacheWidth: imageCacheSize(context, 44),
                          errorWidget: (_, __, ___) =>
                              Container(width: 44, height: 44, color: AppColors.bgHover),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                        ),
                      ),
                      Text(
                        track.fullArtistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TempoChip(bpm: bpm, rate: rate, target: target),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TempoChip extends ConsumerWidget {
  final double? bpm;
  final double rate;
  final double? target;
  const _TempoChip({required this.bpm, required this.rate, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final b = bpm;
    final t = target;
    final Color color;
    if (b == null || t == null) {
      color = AppColors.textMuted;
    } else {
      final dev = PaceMatcher.match(b * rate, t).deviation;
      color = dev <= 0.02
          ? AppColors.neonGreen
          : dev <= PaceMatcher.tolerance
              ? AppColors.warning
              : AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        b == null ? locale.strings.runUnknownTempo : locale.strings.runSongTempo(b.round(), rate),
        style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        radius: 20,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderGlow),
          ),
          child: Icon(icon, size: 18, color: AppColors.textBright),
        ),
      ),
    );
  }
}

class _SyncRow extends ConsumerWidget {
  final RunProvider run;
  const _SyncRow({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final canSync = ref.watch(audioProvider.select((a) => a.canChangeTempo));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: AppColors.neonCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.runSyncTitle,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canSync ? strings.runSyncSubtitle : strings.runSyncSpotify,
                  style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
          Switch(
            value: run.syncTempo && canSync,
            activeThumbColor: AppColors.neonCyan,
            onChanged: canSync
                ? (v) {
                    Haptics.selection();
                    run.setSyncTempo(v);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Session numbers and the cadence over time. Ticks every second for the
/// clock without rebuilding the rest of the screen.
class _SessionStats extends ConsumerStatefulWidget {
  final RunProvider run;
  const _SessionStats({required this.run});

  @override
  ConsumerState<_SessionStats> createState() => _SessionStatsState();
}

class _SessionStatsState extends ConsumerState<_SessionStats> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  static String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final run = widget.run;
    final avg = run.averageCadence;
    final history = run.history;

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.heading,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBright,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              stat(strings.runStatTime, _time(run.elapsed)),
              stat(strings.runStatSteps, '${run.steps}'),
              stat(strings.runStatAverage, avg == null ? '—' : '${avg.round()}'),
              stat(strings.runStatSongs, '${run.songs}'),
            ],
          ),
          if (history.length >= 2) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: CustomPaint(painter: _HistoryPainter(history)),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  final List<double> values;
  _HistoryPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final moving = values.where((v) => v > 0);
    if (moving.isEmpty) return;
    final lo = min(60.0, moving.reduce(min) - 5);
    final hi = max(140.0, moving.reduce(max) + 5);
    final dx = size.width / (values.length - 1);
    Offset at(int i) => Offset(
        i * dx, size.height - size.height * ((max(values[i], lo) - lo) / (hi - lo)).clamp(0.0, 1.0));

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.neonCyan.withValues(alpha: 0.25), AppColors.neonCyan.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.neonCyan,
    );
  }

  @override
  bool shouldRepaint(_HistoryPainter old) =>
      old.values.length != values.length || old.values.last != values.last;
}

class _Hint extends ConsumerWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}
