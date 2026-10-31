import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/image_cache_size.dart';
import '../../data/datasources/wrapped_service.dart';
import '../../domain/entities/wrapped_data.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';

/// Tsuki Wrapped as stories: the recap of a [year], or of one [month] of
/// it. Tap the sides to move, hold to pause, swipe down to close.
class WrappedScreen extends ConsumerStatefulWidget {
  final int year;

  /// 1–12 for a monthly recap; null for the whole year.
  final int? month;

  /// Shown as is instead of reading the play log (tests and previews).
  @visibleForTesting
  final WrappedData? previewData;

  const WrappedScreen(
      {super.key, required this.year, this.month, this.previewData});

  /// Opens full screen, over the bottom bar and the mini player.
  static Future<void> open(BuildContext context, {required int year, int? month}) =>
      WrappedRoute(year: year, month: month).push(context);


  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

typedef _SlideBuilder = Widget Function(GlobalKey shareKey);

class _WrappedScreenState extends ConsumerState<WrappedScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progress;
  WrappedData? _data;
  List<_SlideBuilder> _slides = const [];
  int _page = 0;
  bool _sharing = false;
  double _dragDown = 0;
  final Map<int, GlobalKey> _shareKeys = {};

  bool get _monthly => widget.month != null;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _generate();
  }

  Future<void> _generate() async {
    final preview = widget.previewData;
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final slides = _buildSlides(preview);
        setState(() {
          _data = preview;
          _slides = slides;
          for (var i = 0; i < slides.length; i++) {
            _shareKeys[i] = GlobalKey();
          }
        });
      });
      return;
    }
    final library = ref.read(libraryProvider);
    final y = widget.year;
    final m = widget.month;
    // The period and the one before it, to compare.
    final from = m == null ? DateTime(y - 1, 1, 1) : DateTime(y, m - 1, 1);
    final to = m == null ? DateTime(y, 12, 31) : DateTime(y, m + 1, 0);
    final days = await library.loadPlayDays(from, to);
    if (!mounted) return;
    final service = WrappedService();
    var data = service.generate(
      days: days,
      listened: library.listenedTracks,
      year: y,
      month: m,
    );
    if (data.basedOnPlays) {
      final prev = m == null
          ? service.minutesIn(days, y - 1)
          : service.minutesIn(days, from.year, month: from.month);
      data = data.withPreviousMinutes(prev > 0 ? prev : null);
    }
    final slides = _buildSlides(data);
    setState(() {
      _data = data;
      _slides = slides;
      for (var i = 0; i < slides.length; i++) {
        _shareKeys[i] = GlobalKey();
      }
    });
    if (!data.isEmpty) _startProgress();
  }

  void _startProgress() {
    _progress.forward(from: 0).then((_) {
      if (mounted && _page < _slides.length - 1) _goTo(_page + 1);
    });
  }

  void _goTo(int page) {
    if (page < 0 || page >= _slides.length) return;
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
    setState(() => _page = page);
    if (page == _slides.length - 1) {
      // The last slide (the recap to share) stays until closed.
      _progress.value = 1;
    } else {
      _startProgress();
    }
  }

  Future<void> _share() async {
    final key = _shareKeys[_page];
    final boundary = key?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _sharing = true);
    _progress.stop();
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final tag = _monthly ? '${widget.year}_${widget.month}' : '${widget.year}';
      final file = File('${dir.path}/tsuki_wrapped_${tag}_$_page.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      final strings = ref.read(stringsProvider);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Tsuki Wrapped · ${strings.wrappedPeriod(widget.year, widget.month)}');
    } catch (e) {
      debugPrint('[Wrapped] share error: $e');
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        if (_page < _slides.length - 1) _progress.forward();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  List<_SlideBuilder> _buildSlides(WrappedData d) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final since = d.playsSince;
    final start = DateTime(widget.year, widget.month ?? 1, 1);
    final note = !d.basedOnPlays
        ? strings.wrappedBasedOnDiscoveries
        : (since != null && since.difference(start).inDays > (_monthly ? 3 : 14))
            ? strings.wrappedPlaysSince(strings.longDate(since))
            : null;
    final ctx = _SlideContext(
      data: d,
      locale: locale,
      strings: strings,
      period: strings.wrappedPeriod(widget.year, widget.month),
      monthly: _monthly,
      previousLabel: _monthly
          ? strings.monthName(widget.month == 1 ? 12 : widget.month! - 1)
          : '${widget.year - 1}',
    );
    return [
      (k) => _IntroSlide(c: ctx, note: note, shareKey: k),
      (k) => _MinutesSlide(c: ctx, shareKey: k),
      if (d.topTracks.isNotEmpty) (k) => _TopSongSlide(c: ctx, shareKey: k),
      if (d.topArtists.isNotEmpty) (k) => _TopArtistSlide(c: ctx, shareKey: k),
      if (d.hourDistribution.isNotEmpty) (k) => _HourSlide(c: ctx, shareKey: k),
      (k) => _AuraSlide(c: ctx, shareKey: k),
      if (d.funFacts.isNotEmpty) (k) => _FactsSlide(c: ctx, shareKey: k),
      (k) => _SummarySlide(c: ctx, shareKey: k, onShare: _share),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final data = _data;
    return Scaffold(
      backgroundColor: Colors.black,
      body: data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : data.isEmpty
              ? _Empty(locale: locale, strings: strings, monthly: _monthly)
              : _buildStories(strings),
    );
  }

  Widget _buildStories(AppStrings strings) {
    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTapUp: (d) {
        final x = d.globalPosition.dx;
        if (x < size.width / 3) {
          _goTo(_page - 1);
        } else if (x > size.width * 2 / 3) {
          _goTo(_page + 1);
        }
      },
      onLongPressStart: (_) => _progress.stop(),
      onLongPressEnd: (_) {
        if (_page < _slides.length - 1) _progress.forward();
      },
      onVerticalDragUpdate: (d) => setState(() => _dragDown = math.max(0, _dragDown + d.delta.dy)),
      onVerticalDragEnd: (d) {
        if (_dragDown > 120 || (d.primaryVelocity ?? 0) > 900) {
          Navigator.of(context).pop();
        } else {
          setState(() => _dragDown = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragDown),
        child: Transform.scale(
          scale: 1 - math.min(_dragDown / size.height, 0.1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_dragDown > 0 ? 24 : 0),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _slides[i](_shareKeys[i]!),
                ),
                _buildTopBar(strings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppStrings strings) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: List.generate(_slides.length, (i) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: i < _page
                        ? const _BarFill(value: 1)
                        : i == _page
                            ? AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) => _BarFill(value: _progress.value),
                              )
                            : null,
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  tooltip: strings.a11yClose,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                  tooltip: strings.wrappedShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarFill extends StatelessWidget {
  final double value;
  const _BarFill({required this.value});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 6)],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shared pieces
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SlideContext {
  final WrappedData data;
  final LocaleProvider locale;
  final AppStrings strings;
  final String period;
  final bool monthly;
  final String previousLabel;

  const _SlideContext({
    required this.data,
    required this.locale,
    required this.strings,
    required this.period,
    required this.monthly,
    required this.previousLabel,
  });

  TextStyle text(double size,
          {FontWeight weight = FontWeight.w600,
          Color color = AppColors.textBright,
          double? spacing,
          double? height}) =>
      locale.getTextStyle(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: height);

  TextStyle kanji(double size, Color color) =>
      GoogleFonts.notoSansJp(fontSize: size, fontWeight: FontWeight.w900, color: color);
}

/// The look every slide shares: night background with a tint, an optional
/// blurred cover, a giant faint kanji, scanlines and room for the top bar.
class _Backdrop extends StatelessWidget {
  final GlobalKey shareKey;
  final Color tint;
  final String? coverUrl;
  final String? kanji;
  final Widget child;
  final bool center;

  const _Backdrop({
    required this.shareKey,
    required this.tint,
    required this.child,
    this.coverUrl,
    this.kanji,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: shareKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(tint, Colors.black, 0.55)!, const Color(0xFF0B0D13), Colors.black],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          if (coverUrl != null && coverUrl!.isNotEmpty)
            Opacity(
              opacity: 0.35,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: CachedNetworkImage(
                  imageUrl: coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: imageCacheSize(context, 120),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (kanji != null)
            Positioned(
              right: -40,
              bottom: 40,
              child: Text(
                kanji!,
                style: GoogleFonts.notoSansJp(
                  fontSize: 320,
                  fontWeight: FontWeight.w900,
                  color: tint.withValues(alpha: 0.07),
                  height: 1,
                ),
              ),
            ),
          const CustomPaint(painter: _Scanlines()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 76, 24, 28),
              child: center ? Center(child: child) : child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Scanlines extends CustomPainter {
  const _Scanlines();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.12);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Scanlines oldDelegate) => false;
}

/// Small spaced-out label with a red diamond.
class _Tag extends StatelessWidget {
  final _SlideContext c;
  final String text;
  final Color color;
  const _Tag(this.c, this.text, {this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('◈', style: c.text(11, color: color)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: c.text(12, weight: FontWeight.w800, color: color, spacing: 2.4)),
        ),
      ],
    );
  }
}

/// A number that counts up when the slide appears.
class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(_thousands(v.round()), style: style),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _Cover extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final bool glow;
  const _Cover(this.url, {required this.size, this.radius = 8, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 2),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: imageCacheSize(context, size),
                placeholder: (_, __) => Container(color: AppColors.bgHover),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.bgHover,
        child: Icon(Icons.music_note_rounded, color: AppColors.accent, size: size * 0.4),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Slides
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _IntroSlide extends StatelessWidget {
  final _SlideContext c;
  final String? note;
  final GlobalKey shareKey;
  const _IntroSlide({required this.c, required this.note, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final strings = c.strings;
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.accent,
      kanji: c.monthly ? '月' : '年',
      center: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('T S U K I', style: c.text(15, weight: FontWeight.w800, color: AppColors.accent, spacing: 6))
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 14),
          // One line whatever the screen: it scales down instead of wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'WRAPPED',
              maxLines: 1,
              style: c.text(72, weight: FontWeight.w900, spacing: 4, height: 1).copyWith(
                shadows: [Shadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 30)],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 700.ms, delay: 150.ms)
              .scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack, duration: 700.ms),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 1.4),
              color: AppColors.accent.withValues(alpha: 0.08),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 18)],
            ),
            child: Text(c.period,
                style: c.text(c.monthly ? 22 : 34, weight: FontWeight.w900, color: AppColors.accent, spacing: 5)),
          ).animate().fadeIn(duration: 600.ms, delay: 450.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(c.monthly ? strings.wrappedMonthlyLabel : strings.wrappedYearlyLabel,
                style: c.text(10, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 18),
          Text(strings.wrappedIntro(monthly: c.monthly),
                  textAlign: TextAlign.center, style: c.text(19, weight: FontWeight.w700))
              .animate()
              .fadeIn(duration: 600.ms, delay: 750.ms),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note!,
                textAlign: TextAlign.center,
                style: c.text(12, weight: FontWeight.w500, color: AppColors.textMuted, height: 1.45))
                .animate()
                .fadeIn(delay: 950.ms),
          ],
          const SizedBox(height: 36),
          Text('◈ ${strings.wrappedReportTag(monthly: c.monthly)}',
              style: GoogleFonts.notoSansJp(
                  fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent.withValues(alpha: 0.55), letterSpacing: 2.5)),
        ],
      ),
    );
  }
}

class _MinutesSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _MinutesSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final prev = d.previousMinutes;
    final pct = prev == null || prev == 0
        ? null
        : (((d.totalMinutesListened - prev) / prev) * 100).round();
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonCyan,
      kanji: '時',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, d.basedOnPlays ? strings.wrappedListeningTime : strings.wrappedNewMusicTime,
              color: AppColors.neonCyan),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _CountUp(
              value: d.totalMinutesListened,
              style: c.text(110, weight: FontWeight.w900, height: 1).copyWith(
                shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 30)],
              ),
            ),
          ),
          Text(strings.wrappedMinutesLabel,
              style: c.text(16, weight: FontWeight.w800, color: AppColors.neonCyan, spacing: 3)),
          const SizedBox(height: 10),
          Text(strings.wrappedHoursOfMusic(d.totalMinutesListened ~/ 60),
              style: c.text(16, weight: FontWeight.w500, color: AppColors.textSecondary)),
          if (pct != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (pct >= 0 ? AppColors.neonGreen : AppColors.sakura).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (pct >= 0 ? AppColors.neonGreen : AppColors.sakura).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16, color: pct >= 0 ? AppColors.neonGreen : AppColors.sakura),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(strings.wrappedVsPrevious(pct, c.previousLabel),
                        style: c.text(12, weight: FontWeight.w700, color: pct >= 0 ? AppColors.neonGreen : AppColors.sakura)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 1400.ms).slideX(begin: -0.2, end: 0),
          ],
          const Spacer(),
          Row(
            children: [
              _Stat(c, d.totalTracksPlayed, d.basedOnPlays ? strings.wrappedPlaysLabel : strings.wrappedSongsLabel),
              _Stat(c, d.uniqueTracksCount, strings.wrappedSongsLabel),
              _Stat(c, d.uniqueArtistsCount, strings.wrappedArtistsLabel),
            ],
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
          if (d.periodDays > 0) ...[
            const SizedBox(height: 18),
            Text(strings.wrappedActiveDays(d.activeDays, d.periodDays),
                style: c.text(12, weight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _DaysBar(active: d.activeDays, total: d.periodDays),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final _SlideContext c;
  final int value;
  final String label;
  const _Stat(this.c, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border(left: BorderSide(color: AppColors.accent.withValues(alpha: 0.8), width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _CountUp(value: value, style: c.text(24, weight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  maxLines: 1,
                  style: c.text(9, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysBar extends StatelessWidget {
  final int active;
  final int total;
  const _DaysBar({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.08)),
            FractionallySizedBox(
              widthFactor: total == 0 ? 0 : (active / total).clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.sakura]),
                ),
              ),
            ).animate().scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 1200.ms, delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

class _TopSongSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _TopSongSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final top = d.topTracks.first;
    final rest = d.topTracks.skip(1).take(4).toList();
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.accent,
      coverUrl: top.coverUrl,
      kanji: '歌',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, d.basedOnPlays ? strings.wrappedTopSongLabel : strings.wrappedTopDiscoveries),
          const SizedBox(height: 22),
          Center(
            child: LayoutBuilder(builder: (context, box) {
              final size = math.min(box.maxWidth * 0.62, 240.0);
              return _Cover(top.coverUrl, size: size, radius: 6, glow: true);
            }),
          ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack, duration: 700.ms),
          const SizedBox(height: 20),
          Center(
            child: Text(top.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: c.text(26, weight: FontWeight.w900, height: 1.15)),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 4),
          Center(
            child: Text(top.artistName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.text(15, weight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          if (d.basedOnPlays) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 14)],
                ),
                child: Text(strings.wrappedPlays(top.playCount),
                    style: c.text(12, weight: FontWeight.w800, color: Colors.white)),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
          const Spacer(),
          if (rest.isNotEmpty) ...[
            Text(strings.wrappedRunnersUp,
                style: c.text(10, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
            const SizedBox(height: 8),
            for (var i = 0; i < rest.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 2}', style: c.text(16, weight: FontWeight.w900, color: AppColors.accent)),
                    ),
                    _Cover(rest[i].coverUrl, size: 38, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(13, weight: FontWeight.w700)),
                          Text(rest[i].artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(11, weight: FontWeight.w500, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (d.basedOnPlays)
                      Text('${rest[i].playCount}', style: c.text(13, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 700 + i * 120)).slideX(begin: 0.15, end: 0),
          ],
        ],
      ),
    );
  }
}

class _TopArtistSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _TopArtistSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final top = d.topArtists.first;
    final rest = d.topArtists.skip(1).take(4).toList();
    final maxCount = d.topArtists.first.playCount.clamp(1, 1 << 30);
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonPurple,
      coverUrl: top.coverUrl,
      kanji: '星',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, strings.wrappedTopArtistLabel, color: AppColors.neonPurple),
          const SizedBox(height: 26),
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.neonPurple, width: 2),
                boxShadow: [BoxShadow(color: AppColors.neonPurple.withValues(alpha: 0.5), blurRadius: 36)],
              ),
              child: ClipOval(child: _Cover(top.coverUrl ?? '', size: 170, radius: 0)),
            ),
          ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack, duration: 800.ms),
          const SizedBox(height: 22),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(top.name.toUpperCase(),
                  maxLines: 1,
                  style: c.text(34, weight: FontWeight.w900, spacing: 1.5).copyWith(
                    shadows: [Shadow(color: AppColors.neonPurple.withValues(alpha: 0.6), blurRadius: 24)],
                  )),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 6),
          Center(
            child: Text(
              d.basedOnPlays
                  ? '${strings.wrappedPlays(top.playCount)} · ${strings.wrappedMinutes(top.totalSeconds ~/ 60)}'
                  : strings.wrappedDiscoveredSongs(top.playCount),
              style: c.text(13, weight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          const Spacer(),
          if (rest.isNotEmpty) ...[
            Text(strings.wrappedRunnersUp,
                style: c.text(10, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
            const SizedBox(height: 10),
            for (var i = 0; i < rest.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 2}',
                          style: c.text(16, weight: FontWeight.w900, color: AppColors.neonPurple)),
                    ),
                    ClipOval(child: _Cover(rest[i].coverUrl ?? '', size: 34, radius: 0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(13, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 4,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (rest[i].playCount / maxCount).clamp(0.05, 1.0),
                                child: Container(color: AppColors.neonPurple.withValues(alpha: 0.8)),
                              ),
                            ),
                          ).animate().scaleX(
                              begin: 0,
                              end: 1,
                              alignment: Alignment.centerLeft,
                              delay: Duration(milliseconds: 800 + i * 120),
                              duration: 700.ms),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${rest[i].playCount}',
                        style: c.text(13, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 700 + i * 120)),
          ],
        ],
      ),
    );
  }
}

class _HourSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _HourSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final parts = WrappedService.dayParts(d.hourDistribution);
    final maxCount = d.hourDistribution.values.fold<int>(1, math.max);
    const partColors = [AppColors.neonPurple, AppColors.warning, AppColors.accent, AppColors.neonCyan];
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.warning,
      kanji: '刻',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, strings.wrappedFavoriteHour, color: AppColors.warning),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(strings.wrappedHourLabel(d.favoriteHour),
                style: c.text(84, weight: FontWeight.w900, height: 1).copyWith(
                  shadows: [Shadow(color: AppColors.warning.withValues(alpha: 0.5), blurRadius: 30)],
                )),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 26),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final count = d.hourDistribution[h] ?? 0;
                final fav = h == d.favoriteHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: FractionallySizedBox(
                      heightFactor: math.max(count / maxCount, 0.03),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fav ? AppColors.warning : partColors[_partOf(h)].withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          boxShadow: fav
                              ? [BoxShadow(color: AppColors.warning.withValues(alpha: 0.7), blurRadius: 10)]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ).animate().scaleY(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.bottomCenter,
                    delay: Duration(milliseconds: 300 + h * 25),
                    duration: 500.ms);
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in const [0, 6, 12, 18, 23])
                Text(strings.wrappedHourLabel(h), style: c.text(9, color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          for (var p = 0; p < 4; p++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: partColors[p], shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: Text(strings.wrappedDayPart(p), style: c.text(13, weight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: 0.06)),
                            FractionallySizedBox(
                              widthFactor: parts[p],
                              child: Container(color: partColors[p]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text('${(parts[p] * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: c.text(12, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 900 + p * 120)),
        ],
      ),
    );
  }

  static int _partOf(int hour) => hour < 6 ? 0 : hour < 12 ? 1 : hour < 19 ? 2 : 3;
}

class _AuraSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _AuraSlide({required this.c, required this.shareKey});

  static const kanjiFor = {
    'night': '夜',
    'dawn': '朝',
    'loyal': '忠',
    'explorer': '探',
    'marathon': '走',
    'balance': '和',
  };

  @override
  Widget build(BuildContext context) {
    final strings = c.strings;
    final aura = WrappedService.auraOf(c.data);
    final (name, description) = strings.wrappedAura(aura);
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.sakura,
      center: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tag(c, strings.wrappedAuraTitle, color: AppColors.sakura),
          const SizedBox(height: 30),
          Container(
            width: 190,
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.sakura.withValues(alpha: 0.35),
                AppColors.accent.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
              border: Border.all(color: AppColors.sakura.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Text(kanjiFor[aura] ?? '和',
                style: c.kanji(104, Colors.white).copyWith(
                  shadows: [
                    Shadow(color: AppColors.sakura.withValues(alpha: 0.9), blurRadius: 24),
                    Shadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 48),
                  ],
                )),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
              .scaleXY(begin: 0.97, end: 1.03, duration: 2.seconds, curve: Curves.easeInOut),
          const SizedBox(height: 30),
          Text(name.toUpperCase(),
                  textAlign: TextAlign.center, style: c.text(28, weight: FontWeight.w900, spacing: 2))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(description,
                  textAlign: TextAlign.center,
                  style: c.text(15, weight: FontWeight.w500, color: AppColors.textSecondary, height: 1.5))
              .animate()
              .fadeIn(delay: 700.ms),
        ],
      ),
    );
  }
}

class _FactsSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _FactsSlide({required this.c, required this.shareKey});

  static const _icons = {
    'late_night_song': Icons.nightlight_round,
    'marathon_day': Icons.local_fire_department_rounded,
    'loyal_artist': Icons.favorite_rounded,
    'dawn_listener': Icons.wb_twilight_rounded,
    'one_hit_wonder': Icons.repeat_one_rounded,
    'night_owl': Icons.dark_mode_rounded,
    'early_bird': Icons.wb_sunny_rounded,
    'weekend_warrior': Icons.celebration_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final facts = c.data.funFacts.take(4).toList();
    const colors = [AppColors.sakura, AppColors.neonCyan, AppColors.warning, AppColors.neonGreen];
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonGreen,
      kanji: '話',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, c.strings.wrappedFunFacts, color: AppColors.neonGreen),
          const Spacer(),
          for (var i = 0; i < facts.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors[i % colors.length].withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors[i % colors.length].withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i % colors.length].withValues(alpha: 0.15),
                    ),
                    child: Icon(_icons[facts[i].key] ?? Icons.auto_awesome,
                        color: colors[i % colors.length], size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_factText(facts[i]), style: c.text(14, weight: FontWeight.w600, height: 1.45)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 180)).slideX(begin: 0.12, end: 0),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  String _factText(WrappedFunFact fact) {
    final strings = c.strings;
    final d = fact.data;
    final count = (d['count'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse('${d['date'] ?? ''}');
    final dateLabel = date == null ? '${d['date'] ?? ''}' : strings.longDate(date);
    final plays = c.data.basedOnPlays;
    return switch (fact.key) {
      'late_night_song' => strings.wrappedFactLateNight('${d['title'] ?? ''}', '${d['artistName'] ?? ''}'),
      'marathon_day' => plays
          ? strings.wrappedFactMarathon(dateLabel, count)
          : strings.wrappedFactMarathonDiscovery(dateLabel, count),
      'loyal_artist' => plays
          ? strings.wrappedFactLoyal('${d['name'] ?? ''}', count)
          : strings.wrappedFactLoyalDiscovery('${d['name'] ?? ''}', count),
      'dawn_listener' => strings.wrappedFactDawn(count),
      'one_hit_wonder' => strings.wrappedFactOneHit('${d['title'] ?? ''}', '${d['artistName'] ?? ''}', count),
      'night_owl' => strings.wrappedFactNightOwl((d['percentage'] as num?)?.toInt() ?? 0),
      'early_bird' => strings.wrappedFactEarlyBird((d['percentage'] as num?)?.toInt() ?? 0),
      'weekend_warrior' => strings.wrappedFactWeekend(
          (d['weekendAvg'] as num?)?.toInt() ?? 0, (d['weekdayAvg'] as num?)?.toInt() ?? 0),
      _ => '',
    };
  }
}

/// The last slide: a card with the whole recap, made to be shared.
class _SummarySlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  final VoidCallback onShare;
  const _SummarySlide({required this.c, required this.shareKey, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final aura = WrappedService.auraOf(d);
    final (auraName, _) = strings.wrappedAura(aura);
    final topCover = d.topTracks.isNotEmpty ? d.topTracks.first.coverUrl : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 70, 18, 18),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: RepaintBoundary(
                    key: shareKey,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.8), width: 1.4),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A0A0F), Color(0xFF12141C), Color(0xFF0A0B10)],
                        ),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 30)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -30,
                            child: Text(c.monthly ? '月' : '年',
                                style: c.kanji(200, AppColors.accent.withValues(alpha: 0.08))),
                          ),
                          const Positioned.fill(child: CustomPaint(painter: _Scanlines())),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (topCover != null) _Cover(topCover, size: 64, radius: 6, glow: true),
                                    if (topCover != null) const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('TSUKI WRAPPED',
                                              style: c.text(11, weight: FontWeight.w800, color: AppColors.accent, spacing: 3)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(c.period,
                                                maxLines: 1, style: c.text(26, weight: FontWeight.w900, spacing: 1)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _SummaryList(
                                        c: c,
                                        title: strings.wrappedTopArtistsShort,
                                        items: [for (final a in d.topArtists.take(5)) a.name],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _SummaryList(
                                        c: c,
                                        title: strings.wrappedTopSongsShort,
                                        items: [for (final t in d.topTracks.take(5)) t.title],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: AppColors.border, height: 26),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c, label: strings.wrappedMinutesLabel, value: _thousands(d.totalMinutesListened)),
                                    ),
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c,
                                          label: d.basedOnPlays ? strings.wrappedPlaysLabel : strings.wrappedSongsLabel,
                                          value: _thousands(d.totalTracksPlayed)),
                                    ),
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c,
                                          label: strings.wrappedFavoriteHour,
                                          value: strings.wrappedHourLabel(d.favoriteHour)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.sakura.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.sakura.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_AuraSlide.kanjiFor[aura] ?? '和',
                                          style: c.kanji(26, Colors.white).copyWith(shadows: [
                                            Shadow(color: AppColors.sakura.withValues(alpha: 0.9), blurRadius: 12),
                                          ])),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(strings.wrappedAuraTitle,
                                                style: c.text(8.5, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
                                            Text(auraName, style: c.text(16, weight: FontWeight.w900)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text('◈ ${strings.wrappedReportTag(monthly: c.monthly)}',
                                    style: GoogleFonts.notoSansJp(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent.withValues(alpha: 0.6),
                                        letterSpacing: 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(strings.wrappedOutroFor(monthly: c.monthly),
                    style: c.text(12, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onShare,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
                    label: Text(strings.wrappedShareCta,
                        style: c.text(13, weight: FontWeight.w900, color: Colors.white, spacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryList extends StatelessWidget {
  final _SlideContext c;
  final String title;
  final List<String> items;
  const _SummaryList({required this.c, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: c.text(9.5, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.6)),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text('${i + 1}', style: c.text(12, weight: FontWeight.w900, color: AppColors.accent)),
                ),
                Expanded(
                  child: Text(items[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: c.text(12, weight: i == 0 ? FontWeight.w800 : FontWeight.w600, height: 1.25)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  final _SlideContext c;
  final String label;
  final String value;
  const _SummaryNumber({required this.c, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label,
              maxLines: 1,
              style: c.text(8.5, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: c.text(20, weight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  final bool monthly;
  const _Empty({required this.locale, required this.strings, required this.monthly});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(monthly ? '月' : '年',
                  style: GoogleFonts.notoSansJp(
                      fontSize: 72, fontWeight: FontWeight.w900, color: AppColors.accent.withValues(alpha: 0.35))),
              const SizedBox(height: 18),
              Text(strings.wrappedNoDataFor(monthly: monthly),
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textBright)),
              const SizedBox(height: 10),
              Text(strings.wrappedNoDataSubtitle,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accent)),
                child: Text(strings.a11yBack,
                    style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
