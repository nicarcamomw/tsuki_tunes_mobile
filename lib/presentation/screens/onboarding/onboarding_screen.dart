library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../state/app_providers.dart';
import '../../state/locale_provider.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/haptics.dart';
import '../../widgets/moon_glyph.dart';
import '../../widgets/motion.dart';
import '../../widgets/oni_mask_icon.dart';
import '../../widgets/tsuki_sky.dart';

part 'onboarding_steps.dart';

/// The first-run guide, and the tutorial opened again from the settings
/// ([onComplete] given): four steps under the entrance's night, each with
/// a small live demo of the app on a card of liquid glass: marking songs
/// (the library), finding them (search, radios), hearing them (previews,
/// Spotify, lyrics) and the path (Echo, masks, the Lunar Testament).
///
/// Swiping or "Next" moves on, with a little parallax; the step shows as
/// moon phases filling up. Only the step on screen animates (TickerMode),
/// the sky repaints without rebuilding, and with less motion asked for the
/// demos show their final state, still.
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  static const int steps = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6);
  ui.FragmentShader? _shader;
  int _page = 0;
  bool _completing = false;

  bool get _tutorial => widget.onComplete != null;

  @override
  void initState() {
    super.initState();
    unawaited(
      tsukiNebulaProgram.then((program) {
        if (!mounted || program == null) return;
        setState(() => _shader = program.fragmentShader());
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    await ref.read(sessionGateProvider).saveOnboardingDone();
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }
    // First run: the router moves on to the main screen.
    ref.read(sessionGateProvider).onboardingCompleted();
  }

  /// To step [i]: a glide, or a cut with less motion asked for.
  void _goTo(int i) {
    if (reduceMotion(context)) {
      _pages.jumpToPage(i);
    } else {
      unawaited(_pages.animateToPage(i, duration: AppMotion.slow, curve: AppMotion.move));
    }
  }

  void _next() {
    if (_page < OnboardingScreen.steps - 1) {
      Haptics.tap();
      _goTo(_page + 1);
    } else {
      Haptics.success();
      unawaited(_complete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final still = reduceMotion(context);
    final last = _page == OnboardingScreen.steps - 1;
    const sky = AlwaysStoppedAnimation<double>(0.8);
    const none = AlwaysStoppedAnimation<double>(0);

    // Back steps back through the guide before it leaves it.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _page == 0) return;
        _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.splash,
        body: Stack(
          children: [
            if (_shader != null)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: NebulaPainter(_shader!, time: _time, intensity: sky, still: still),
                  ),
                ),
              ),
            if (!still)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: EmbersPainter(time: _time, intensity: sky, exit: none),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  // The guide's name and the way out.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, 4, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ExcludeSemantics(
                            child: Text.rich(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              TextSpan(
                                children: [
                                  TextSpan(text: strings.onboardingHeaderPrefix),
                                  TextSpan(
                                    text: strings.onboardingHeaderGlitch,
                                    style: const TextStyle(color: AppColors.accentText),
                                  ),
                                ],
                              ),
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textBright,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        if (_tutorial)
                          IconButton(
                            tooltip: strings.onbClose,
                            onPressed: () {
                              Haptics.tap();
                              unawaited(_complete());
                            },
                            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                          )
                        else
                          TextButton(
                            onPressed: () {
                              Haptics.tap();
                              unawaited(_complete());
                            },
                            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                            child: Text(
                              strings.onbSkip,
                              style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The steps; the one on screen is the only one animating.
                  Expanded(
                    child: BackdropGroup(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: OnboardingScreen.steps,
                        onPageChanged: (i) {
                          Haptics.selection();
                          setState(() => _page = i);
                        },
                        itemBuilder: (context, i) => TickerMode(
                          enabled: i == _page,
                          child: _StepPage(index: i, pages: _pages, still: still, locale: locale, step: _steps(strings)[i]),
                        ),
                      ),
                    ),
                  ),
                  // Where you are, and the way on.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
                    child: Row(
                      children: [
                        Semantics(
                          label: strings.onbStepOf(_page + 1, OnboardingScreen.steps),
                          child: ExcludeSemantics(
                            child: _MoonSteps(pages: _pages, count: OnboardingScreen.steps),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Spacer(),
                        Flexible(
                          flex: 8,
                          child: AnimatedSwitcher(
                            duration: AppMotion.fast,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
                            ),
                            child: FilledButton.icon(
                              key: ValueKey(last),
                              onPressed: _next,
                              iconAlignment: IconAlignment.end,
                              icon: Icon(
                                last ? (_tutorial ? Icons.check_rounded : Icons.play_arrow_rounded) : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(
                                last ? (_tutorial ? strings.onbDone : strings.onbStart) : strings.onbNext,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a step says and shows.
class _Step {
  const _Step({required this.kanji, required this.over, required this.title, required this.body, required this.chips, required this.demo});

  final String kanji;
  final String over;
  final String title;
  final String body;
  final List<(IconData, String)> chips;
  final Widget Function(bool still, LocaleProvider locale) demo;
}

List<_Step> _steps(AppStrings s) => [
  _Step(
    kanji: '庫',
    over: s.onb1Over,
    title: s.onb1Title,
    body: s.onb1Body,
    chips: [(Icons.album_rounded, s.onb1ChipA), (Icons.cloud_done_rounded, s.onb1ChipB), (Icons.queue_music_rounded, s.onb1ChipC)],
    demo: (still, locale) => _LibraryDemo(still: still, locale: locale),
  ),
  _Step(
    kanji: '探',
    over: s.onb2Over,
    title: s.onb2Title,
    body: s.onb2Body,
    chips: [(Icons.lyrics_rounded, s.onb2ChipA), (Icons.radio_rounded, s.onb2ChipB), (Icons.auto_awesome_rounded, s.onb2ChipC)],
    demo: (still, locale) => _SearchDemo(still: still, locale: locale),
  ),
  _Step(
    kanji: '聴',
    over: s.onb3Over,
    title: s.onb3Title,
    body: s.onb3Body,
    chips: [(Icons.graphic_eq_rounded, s.onb3ChipA), (Icons.subtitles_rounded, s.onb3ChipB), (Icons.equalizer_rounded, s.onb3ChipC)],
    demo: (still, locale) => _PlayerDemo(still: still, locale: locale),
  ),
  _Step(
    kanji: '道',
    over: s.onb4Over,
    title: s.onb4Title,
    body: s.onb4Body,
    chips: [(Icons.trending_up_rounded, s.onb4ChipA), (Icons.theater_comedy_rounded, s.onb4ChipB), (Icons.menu_book_rounded, s.onb4ChipC)],
    demo: (still, locale) => _PathDemo(still: still, locale: locale),
  ),
];

/// One step: its demo on liquid glass, then what it says. The demo and the
/// words drift a little as the page moves (parallax); a step that doesn't
/// fit scrolls.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.index, required this.pages, required this.still, required this.locale, required this.step});

  final int index;
  final PageController pages;
  final bool still;
  final LocaleProvider locale;
  final _Step step;

  double _offset() {
    if (!pages.hasClients || !pages.position.hasContentDimensions) return 0;
    return (pages.page ?? index.toDouble()) - index;
  }

  @override
  Widget build(BuildContext context) {
    final demo = RepaintBoundary(child: step.demo(still, locale));
    final words = _Words(step: step, locale: locale);
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    // A little below the middle, near its words.
                    alignment: const Alignment(0, 0.45),
                    child: AnimatedBuilder(
                      animation: pages,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // A glow behind the glass, for it to bend.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Transform.scale(
                                scale: 1.25,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(colors: [AppColors.accentDim, Colors.transparent], stops: [0.0, 0.7]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FrostedGlass(
                            color: AppColors.surface,
                            fill: AppGlass.clearFill + 0.15,
                            // Perf: unblurred. What's behind is a smooth
                            // glow and the nebula, which a blur leaves as
                            // they are, yet it re-read the screen every
                            // frame of the demos.
                            blur: 0,
                            borderRadius: BorderRadius.circular(AppRadius.sheet),
                            child: SizedBox(
                              width: double.infinity,
                              child: Center(heightFactor: 1, child: demo),
                            ),
                          ),
                        ],
                      ),
                      builder: (context, child) {
                        final o = still ? 0.0 : _offset();
                        return Opacity(
                          opacity: (1 - o.abs() * 0.7).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(-o * 70, 0),
                            child: Transform.scale(scale: 1 - o.abs() * 0.06, child: child),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: pages,
                  child: words,
                  builder: (context, child) {
                    final o = still ? 0.0 : _offset();
                    return Opacity(
                      opacity: (1 - o.abs() * 1.2).clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(-o * 30, 0), child: child),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A step's words: a kanji and its name, the title, the sentence, three
/// chips.
class _Words extends StatelessWidget {
  const _Words({required this.step, required this.locale});

  final _Step step;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                step.kanji,
                style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.accentText),
              ),
              const SizedBox(width: 10),
              Container(width: 18, height: 1, color: AppColors.textMuted.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Text(
                step.over,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: AppFontSize.headline,
              fontWeight: FontWeight.w900,
              color: AppColors.textBright,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          step.body,
          textAlign: TextAlign.center,
          style: locale.getTextStyle(fontSize: AppFontSize.title, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final (icon, label) in step.chips) _Chip(icon: icon, label: label, locale: locale)],
        ),
      ],
    );
  }
}

/// A small feature chip: a quiet translucent pill (no blur: many of them).
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.locale});

  final IconData icon;
  final String label;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 14, color: AppColors.accentText)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

/// The steps as moons: those behind are full, the next waxes as the page
/// moves towards it, those ahead are new.
class _MoonSteps extends StatelessWidget {
  const _MoonSteps({required this.pages, required this.count});

  final PageController pages;
  final int count;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pages,
    builder: (context, _) {
      final page = pages.hasClients && pages.position.hasContentDimensions ? (pages.page ?? 0) : 0.0;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _MoonDot(lit: (page - i + 1).clamp(0.0, 1.0), current: (page - i).abs() < 0.5),
          ],
        ],
      );
    },
  );
}

class _MoonDot extends StatelessWidget {
  const _MoonDot({required this.lit, required this.current});

  final double lit;
  final bool current;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.fast,
    width: current ? 18 : 14,
    height: current ? 18 : 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: current ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 10)] : null,
    ),
    child: CustomPaint(painter: MoonPainter(illumination: math.max(0.04, lit), waxing: true, southern: false, eclipse: false, halo: false)),
  );
}
