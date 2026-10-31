import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/locale_provider.dart';

class ListeningClockScreen extends ConsumerStatefulWidget {
  const ListeningClockScreen({super.key});

  @override
  ConsumerState<ListeningClockScreen> createState() => _ListeningClockScreenState();
}

class _ListeningClockScreenState extends ConsumerState<ListeningClockScreen> {
  Map<int, int> _hourCounts = {};
  Map<int, int> _dayCounts = {};
  int _totalTracks = 0;
  int _peakHour = 0;
  int _peakDayCount = 0;
  int _year = DateTime.now().year;
  int _todayDoy = 0;
  int? _selectedHour;

  @override
  void initState() {
    super.initState();
    _computeData();
  }

  void _computeData() {
    final library = ref.read(libraryProvider);
    final year = DateTime.now().year;
    final yearTracks = library.listenedTracks
        .where((t) => t.listenedAt != null && t.listenedAt!.year == year)
        .toList();

    final hourCounts = <int, int>{};
    final dayCounts = <int, int>{};
    final jan1 = DateTime(year, 1, 1);

    for (final t in yearTracks) {
      final dt = t.listenedAt!;
      hourCounts.update(dt.hour, (v) => v + 1, ifAbsent: () => 1);
      final doy = dt.difference(jan1).inDays + 1;
      dayCounts.update(doy, (v) => v + 1, ifAbsent: () => 1);
    }

    int peakHour = 0;
    int maxH = 0;
    for (final e in hourCounts.entries) {
      if (e.value > maxH) {
        maxH = e.value;
        peakHour = e.key;
      }
    }

    int peakDay = 0;
    for (final v in dayCounts.values) {
      if (v > peakDay) peakDay = v;
    }

    final now = DateTime.now();
    final todayDoy = now.difference(jan1).inDays + 1;

    setState(() {
      _hourCounts = hourCounts;
      _dayCounts = dayCounts;
      _totalTracks = yearTracks.length;
      _peakHour = peakHour;
      _peakDayCount = peakDay;
      _year = year;
      _todayDoy = todayDoy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: _totalTracks == 0
            ? _buildEmptyState(locale, strings)
            : _buildContent(locale, strings),
      ),
    );
  }

  Widget _buildEmptyState(LocaleProvider locale, dynamic strings) {
    return Column(
      children: [
        _buildHeader(locale, strings),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.access_time,
                        color: AppColors.accent, size: 36),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    strings.clockNoData,
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.clockNoDataSubtitle,
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(LocaleProvider locale, dynamic strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back,
                color: AppColors.textBright, size: 22),
            tooltip: strings.a11yBack,
          ),
          const SizedBox(width: 4),
          Text(
            strings.clockTitle,
            style: locale.getTextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            '◈ $_year',
            style: GoogleFonts.notoSansJp(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LocaleProvider locale, dynamic strings) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(locale, strings),
          const SizedBox(height: 20),

          // Section: Radar
          _buildSectionLabel(
            locale,
            strings.clockRadar,
            AppColors.accent,
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 16),

          // Sharingan Radar (interactive)
          Center(
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final radarCenter = const Offset(160, 160);
                final local = details.localPosition;
                final dx = local.dx - radarCenter.dx;
                final dy = local.dy - radarCenter.dy;
                final dist = sqrt(dx * dx + dy * dy);
                if (dist < 40 || dist > 140) {
                  setState(() => _selectedHour = null);
                  return;
                }
                var angle = atan2(dy, dx) + pi / 2;
                if (angle < 0) angle += 2 * pi;
                final hour = ((angle / (2 * pi)) * 24).round() % 24;
                setState(() => _selectedHour = hour);
              },
              child: SizedBox(
                width: 320,
                height: 320,
                child: CustomPaint(
                  painter: _SharinganRadarPainter(
                    hourCounts: _hourCounts,
                    selectedHour: _selectedHour,
                  ),
                  size: const Size(320, 320),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 200.ms)
              .scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack),
          const SizedBox(height: 16),

          // Hour detail badge (selected or peak)
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_selectedHour ?? -1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: (_selectedHour != null
                          ? AppColors.textBright
                          : AppColors.accent)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (_selectedHour != null
                            ? AppColors.textBright
                            : AppColors.accent)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _selectedHour != null
                      ? strings.clockPeakHour(
                          strings.wrappedHourLabel(_selectedHour!),
                          _hourCounts[_selectedHour!] ?? 0,
                        )
                      : strings.clockPeakHour(
                          strings.wrappedHourLabel(_peakHour),
                          _hourCounts[_peakHour] ?? 0,
                        ),
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
          const SizedBox(height: 36),

          // Section: Daily Activity
          _buildSectionLabel(
            locale,
            strings.clockDailyActivity,
            AppColors.neonCyan,
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
          const SizedBox(height: 16),

          // Daily bars
          _DailyActivityBars(
            year: _year,
            dayCounts: _dayCounts,
            peakCount: _peakDayCount,
            todayDoy: _todayDoy,
            locale: locale,
          ).animate().fadeIn(duration: 800.ms, delay: 800.ms),
          const SizedBox(height: 8),

          // Total count
          Center(
            child: Text(
              strings.clockTotalYear(_totalTracks),
              style: GoogleFonts.notoSansJp(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.accent.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
      LocaleProvider locale, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: locale.getTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SHARINGAN RADAR PAINTER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SharinganRadarPainter extends CustomPainter {
  final Map<int, int> hourCounts;
  final int? selectedHour;

  _SharinganRadarPainter({required this.hourCounts, this.selectedHour});

  static const _pi2 = 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24;

    final maxCount = hourCounts.values.fold(0, (a, b) => a > b ? a : b);

    _drawBackground(canvas, center, radius);
    _drawConcentricRings(canvas, center, radius);
    _drawRadialLines(canvas, center, radius);
    if (maxCount > 0) _drawHourBars(canvas, center, radius, maxCount);
    _drawSharinganCenter(canvas, center, radius);
    _drawHourLabels(canvas, center, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.9, bgPaint);
  }

  void _drawConcentricRings(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final rings = [0.35, 0.52, 0.7, 0.88];
    for (int i = 0; i < rings.length; i++) {
      paint.color = AppColors.accent.withValues(alpha: 0.08 + i * 0.03);
      canvas.drawCircle(center, radius * rings[i], paint);
    }

    // Outer boundary ring
    paint
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius * 0.88, paint);
  }

  void _drawRadialLines(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = AppColors.accent.withValues(alpha: 0.06);

    final innerR = radius * 0.28;
    final outerR = radius * 0.88;

    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * _pi2 - pi / 2;
      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle),
            center.dy + innerR * sin(angle)),
        Offset(center.dx + outerR * cos(angle),
            center.dy + outerR * sin(angle)),
        paint,
      );
    }

    // Major cross lines at 0, 6, 12, 18
    paint
      ..strokeWidth = 0.7
      ..color = AppColors.accent.withValues(alpha: 0.12);
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * _pi2 - pi / 2;
      canvas.drawLine(
        Offset(center.dx + radius * 0.22 * cos(angle),
            center.dy + radius * 0.22 * sin(angle)),
        Offset(center.dx + radius * 0.9 * cos(angle),
            center.dy + radius * 0.9 * sin(angle)),
        paint,
      );
    }
  }

  void _drawHourBars(
      Canvas canvas, Offset center, double radius, int maxCount) {
    final segmentAngle = _pi2 / 24;
    final barAngle = segmentAngle * 0.72;
    final innerR = radius * 0.3;
    final maxOuterR = radius * 0.85;

    for (int hour = 0; hour < 24; hour++) {
      final count = hourCounts[hour] ?? 0;
      if (count == 0) continue;

      final ratio = count / maxCount;
      final outerR = innerR + (maxOuterR - innerR) * ratio;
      final centerAngle = (hour / 24) * _pi2 - pi / 2;
      final startAngle = centerAngle - barAngle / 2;

      final isSelected = hour == selectedHour;
      final color = isSelected
          ? AppColors.textBright
          : Color.lerp(
              AppColors.accent.withValues(alpha: 0.35),
              AppColors.accent,
              ratio,
            )!;

      final path = Path();
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerR),
        startAngle,
        barAngle,
        true,
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: outerR),
        startAngle + barAngle,
        -barAngle,
        false,
      );
      path.close();

      canvas.drawPath(path, Paint()..color = color);

      // Glow on peak or selected bars
      if (ratio > 0.9 || isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = (isSelected ? AppColors.textBright : AppColors.accent)
                .withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }
  }

  void _drawSharinganCenter(Canvas canvas, Offset center, double radius) {
    final pupilR = radius * 0.24;

    // Dark pupil fill
    canvas.drawCircle(
      center,
      pupilR,
      Paint()..color = const Color(0xFF080808),
    );

    // Pupil ring
    canvas.drawCircle(
      center,
      pupilR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent.withValues(alpha: 0.6),
    );

    // Inner ring for tomoe orbit
    final tomoeOrbitR = pupilR * 0.55;
    canvas.drawCircle(
      center,
      tomoeOrbitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = AppColors.accent.withValues(alpha: 0.2),
    );

    // Three tomoe
    final tomeePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.accent;
    final headR = pupilR * 0.14;

    for (int i = 0; i < 3; i++) {
      final baseAngle = (i / 3) * _pi2 - pi / 2;

      // Head circle
      final headPos = Offset(
        center.dx + tomoeOrbitR * cos(baseAngle),
        center.dy + tomoeOrbitR * sin(baseAngle),
      );
      canvas.drawCircle(headPos, headR, tomeePaint);

      // Curved tail
      final tailStart = baseAngle + headR / tomoeOrbitR + 0.1;
      final tailEnd = baseAngle + 1.1;
      final midAngle = (tailStart + tailEnd) / 2;

      final outerStart = Offset(
        center.dx + (tomoeOrbitR + headR * 0.55) * cos(tailStart),
        center.dy + (tomoeOrbitR + headR * 0.55) * sin(tailStart),
      );
      final innerStart = Offset(
        center.dx + (tomoeOrbitR - headR * 0.55) * cos(tailStart),
        center.dy + (tomoeOrbitR - headR * 0.55) * sin(tailStart),
      );
      final tip = Offset(
        center.dx + tomoeOrbitR * cos(tailEnd),
        center.dy + tomoeOrbitR * sin(tailEnd),
      );
      final ctrlOuter = Offset(
        center.dx + (tomoeOrbitR + headR * 0.25) * cos(midAngle),
        center.dy + (tomoeOrbitR + headR * 0.25) * sin(midAngle),
      );
      final ctrlInner = Offset(
        center.dx + (tomoeOrbitR - headR * 0.25) * cos(midAngle),
        center.dy + (tomoeOrbitR - headR * 0.25) * sin(midAngle),
      );

      final tailPath = Path()
        ..moveTo(outerStart.dx, outerStart.dy)
        ..quadraticBezierTo(ctrlOuter.dx, ctrlOuter.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrlInner.dx, ctrlInner.dy, innerStart.dx, innerStart.dy)
        ..close();

      canvas.drawPath(tailPath, tomeePaint);
    }

    // Center glow dot
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, 1.5, Paint()..color = AppColors.accent);
  }

  void _drawHourLabels(Canvas canvas, Offset center, double radius) {
    final labelR = radius * 0.97;

    for (int i = 0; i < 24; i += 3) {
      final angle = (i / 24) * _pi2 - pi / 2;
      final pos = Offset(
        center.dx + labelR * cos(angle),
        center.dy + labelR * sin(angle),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SharinganRadarPainter old) =>
      old.hourCounts != hourCounts || old.selectedHour != selectedHour;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DAILY ACTIVITY BARS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DailyActivityBars extends StatelessWidget {
  final int year;
  final Map<int, int> dayCounts;
  final int peakCount;
  final int todayDoy;
  final LocaleProvider locale;

  const _DailyActivityBars({
    required this.year,
    required this.dayCounts,
    required this.peakCount,
    required this.todayDoy,
    required this.locale,
  });

  static const _barWidth = 3.0;
  static const _barGap = 1.0;
  static const _monthGap = 6.0;
  static const _maxBarHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final maxCount = peakCount > 0 ? peakCount : 1;
    final now = DateTime.now();
    final currentMonth = year == now.year ? now.month : 12;

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(currentMonth, (m) {
            final month = m + 1;
            final daysInMonth = (month == currentMonth && year == now.year)
                ? now.day
                : DateUtils.getDaysInMonth(year, month);
            final firstOfMonth = DateTime(year, month, 1);
            final startDoy =
                firstOfMonth.difference(DateTime(year, 1, 1)).inDays + 1;

            return Padding(
              padding: EdgeInsets.only(right: m < currentMonth - 1 ? _monthGap : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(daysInMonth, (d) {
                      final doy = startDoy + d;
                      final count = dayCounts[doy] ?? 0;
                      final ratio = count / maxCount;
                      final barHeight =
                          count == 0 ? 2.0 : 4.0 + ratio * _maxBarHeight;
                      final isToday = doy == todayDoy;

                      final color = count == 0
                          ? AppColors.bgCard.withValues(alpha: 0.3)
                          : Color.lerp(
                              AppColors.neonCyan.withValues(alpha: 0.2),
                              AppColors.neonCyan,
                              ratio,
                            )!;

                      return Padding(
                        padding: const EdgeInsets.only(right: _barGap),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: _barWidth,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.textBright
                                    : color,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(1.5)),
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: AppColors.textBright
                                              .withValues(alpha: 0.4),
                                          blurRadius: 4,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textBright,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    month.toString().padLeft(2, '0'),
                    style: locale.getTextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: month == currentMonth && year == now.year
                          ? AppColors.neonCyan
                          : AppColors.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
