import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../../domain/logic/bpm_flow.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';

/// Reads the tempo of the upcoming tracks, shows how many Deezer knows, and
/// reorders the queue in the chosen flow.
class FlowSheet extends ConsumerStatefulWidget {
  const FlowSheet({super.key});

  static Future<void> show(BuildContext context) => SwipeableSheet.show(
        context,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, controller) => const FlowSheet(),
      );

  @override
  ConsumerState<FlowSheet> createState() => _FlowSheetState();
}

class _FlowSheetState extends ConsumerState<FlowSheet> {
  static const _color = AppColors.neonCyan;

  late final _service = ref.read(bpmProvider);
  bool _loading = true;
  int _done = 0;
  int _toLookUp = 0;
  Map<String, double> _bpms = {};
  int _total = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final upcoming = ref.read(audioProvider).upcomingTracks;
    _total = upcoming.length;
    final bpms = await _service.lookup(
      upcoming,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _done = done;
            _toLookUp = total;
          });
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _bpms = bpms;
      _loading = false;
      _failed = bpms.isEmpty && _service.lastFailures > 0;
    });
  }

  void _apply(FlowMode mode) {
    final audio = ref.read(audioProvider);
    final strings = ref.read(stringsProvider);
    // The queue may have moved on while the sheet was open: arrange what is
    // upcoming right now.
    final result = BpmFlow.arrange(audio.upcomingTracks, _bpms, mode);
    Haptics.confirm();
    audio.setUpcomingOrder(result.order);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final from = result.fromBpm?.round() ?? 0;
    final to = result.toBpm?.round() ?? 0;
    messenger.showSnackBar(SnackBar(
      content: Text(mode == FlowMode.wave
          ? strings.flowAppliedWave(from, result.peakBpm?.round() ?? 0, to)
          : strings.flowApplied(from, to)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgCard,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final known = _bpms.length;
    final coverage = _total == 0 ? 0.0 : known / _total;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderGlow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.show_chart_rounded, color: _color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    strings.flowTitle,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.bodyLg,
                      fontWeight: FontWeight.w800,
                      color: _color,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.flowSubtitle,
              style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            if (_loading) ...[
              Text(
                strings.flowAnalyzing(_done, _toLookUp),
                style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _toLookUp == 0 ? null : _done / _toLookUp,
                  minHeight: 5,
                  backgroundColor: AppColors.bgMid,
                  color: _color,
                ),
              ),
            ] else if (_failed)
              Text(strings.flowError,
                  style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textPrimary))
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.flowCoverage(known, _total),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                  Text(
                    '${(coverage * 100).round()}%',
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w800,
                      color: coverage >= BpmFlow.minUsefulCoverage ? _color : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: coverage,
                  minHeight: 5,
                  backgroundColor: AppColors.bgMid,
                  color: coverage >= BpmFlow.minUsefulCoverage ? _color : AppColors.warning,
                ),
              ),
              const SizedBox(height: 12),
              if (known < 3)
                Text(strings.flowNotEnough,
                    style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textPrimary))
              else ...[
                if (coverage < BpmFlow.minUsefulCoverage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      strings.flowLowCoverage,
                      style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.warning),
                    ),
                  ),
                for (final mode in FlowMode.values)
                  _ModeTile(
                    mode: mode,
                    preview: BpmFlow.arrange(
                        ref.read(audioProvider).upcomingTracks, _bpms, mode),
                    bpms: _bpms,
                    onTap: () => _apply(mode),
                  ),
                const SizedBox(height: 6),
                Text(
                  strings.flowHalfTimeNote,
                  style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends ConsumerWidget {
  final FlowMode mode;
  final FlowResult preview;
  final Map<String, double> bpms;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.preview,
    required this.bpms,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final curve = [
      for (final t in preview.order)
        if (bpms[t.id] != null) BpmFlow.feel(bpms[t.id]!),
    ];
    final icon = switch (mode) {
      FlowMode.rise => Icons.trending_up_rounded,
      FlowMode.calm => Icons.trending_down_rounded,
      FlowMode.wave => Icons.waves_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.neonCyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.flowModeName(mode),
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.bodyLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBright,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.flowModeDescription(mode),
                        style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  height: 30,
                  child: CustomPaint(painter: _CurvePainter(curve)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sparkline of the tempo along the new queue order.
class _CurvePainter extends CustomPainter {
  final List<double> values;

  _CurvePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / span * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.neonCyan,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.values != values;
}
