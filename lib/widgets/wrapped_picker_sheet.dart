import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../providers/app_providers.dart';
import '../screens/wrapped_screen.dart';
import '../services/wrapped_service.dart';
import 'swipeable_sheet.dart';

/// Picks which Wrapped to open: the whole year or one of the last months,
/// each with how much was listened.
Future<void> showWrappedPicker(BuildContext context) {
  return SwipeableSheet.show(
    context,
    initialChildSize: 0.72,
    maxChildSize: 0.92,
    builder: (_, controller) => _WrappedPicker(controller: controller),
  );
}

class _WrappedPicker extends ConsumerStatefulWidget {
  final ScrollController controller;
  const _WrappedPicker({required this.controller});

  @override
  ConsumerState<_WrappedPicker> createState() => _WrappedPickerState();
}

class _WrappedPickerState extends ConsumerState<_WrappedPicker> {
  // Minutes per month ("yyyy-mm"), from the play log.
  Map<String, int>? _minutes;
  late final DateTime _now = DateTime.now();

  List<DateTime> get _months => [
        for (var i = 0; i < 12; i++) DateTime(_now.year, _now.month - i, 1),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library = ref.read(libraryProvider);
    final from = _months.last;
    final days = await library.loadPlayDays(from, _now);
    if (!mounted) return;
    final service = WrappedService();
    setState(() {
      _minutes = {
        for (final m in _months) _key(m): service.minutesIn(days, m.year, month: m.month),
      };
    });
  }

  static String _key(DateTime m) => '${m.year}-${m.month}';

  void _open({required int year, int? month}) {
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    nav.pop();
    WrappedScreen.open(nav.context, year: year, month: month);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final minutes = _minutes;
    final maxMinutes = minutes == null || minutes.isEmpty
        ? 1
        : minutes.values.fold<int>(1, (a, b) => a > b ? a : b);

    TextStyle t(double size, {FontWeight w = FontWeight.w700, Color c = AppColors.textBright, double? spacing}) =>
        locale.getTextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: spacing);

    return SafeArea(
      child: ListView(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('月', style: GoogleFonts.notoSansJp(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.accent)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TSUKI WRAPPED', style: t(16, w: FontWeight.w900, spacing: 2)),
                    Text(strings.wrappedPickerSubtitle, style: t(11, w: FontWeight.w500, c: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // The whole year, up top.
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _open(year: _now.year),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent, width: 1.2),
                gradient: LinearGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.22),
                  AppColors.accent.withValues(alpha: 0.04),
                ]),
                boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 16)],
              ),
              child: Row(
                children: [
                  Text('${_now.year}', style: t(30, w: FontWeight.w900, c: AppColors.accent, spacing: 2)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.wrappedYearlyLabel, style: t(10, w: FontWeight.w800, c: AppColors.textMuted, spacing: 2)),
                        Text(strings.wrappedWholeYear(_now.year), style: t(14, w: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 30),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.wrappedMonthlyLabel, style: t(10, w: FontWeight.w800, c: AppColors.textMuted, spacing: 2)),
          const SizedBox(height: 8),
          for (final m in _months)
            _MonthRow(
              label: strings.wrappedPeriod(m.year, m.month),
              current: m.year == _now.year && m.month == _now.month,
              currentLabel: strings.wrappedThisMonth,
              minutes: minutes?[_key(m)],
              minutesLabel: (v) => strings.wrappedMinutes(v),
              fraction: minutes == null ? 0 : (minutes[_key(m)] ?? 0) / maxMinutes,
              style: t,
              onTap: () => _open(year: m.year, month: m.month),
            ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _open(year: _now.year - 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(strings.wrappedWholeYear(_now.year - 1), style: t(13))),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final String label;
  final bool current;
  final String currentLabel;
  final int? minutes;
  final String Function(int) minutesLabel;
  final double fraction;
  final TextStyle Function(double size, {FontWeight w, Color c, double? spacing}) style;
  final VoidCallback onTap;

  const _MonthRow({
    required this.label,
    required this.current,
    required this.currentLabel,
    required this.minutes,
    required this.minutesLabel,
    required this.fraction,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: current ? AppColors.accent.withValues(alpha: 0.08) : AppColors.bgMid.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: current ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(13, w: FontWeight.w800))),
                      if (current) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(currentLabel, style: style(9, w: FontWeight.w800, c: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  minutes == null ? '…' : (minutes == 0 ? '—' : minutesLabel(minutes!)),
                  style: style(11, w: FontWeight.w600, c: AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.06)),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(color: AppColors.accent.withValues(alpha: current ? 1 : 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
