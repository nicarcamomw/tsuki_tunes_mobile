part of 'onboarding_screen.dart';

// The guide's live demos: small, honest pieces of the app that play on a
// loop while their step is on screen (TickerMode stops the others). With
// less motion asked for, each shows its final state.

/// A demo's clock: [period] long, looping; [still] holds it at [rest].
mixin _DemoClock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController clock = AnimationController(vsync: this, duration: period);
  Duration get period;
  bool get still;
  double get rest => 0.9;

  /// Taken over by hand: the loop stays stopped.
  bool get held => false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant T old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (held) return;
    if (still) {
      clock.value = rest;
    } else if (!clock.isAnimating) {
      unawaited(clock.repeat());
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  /// 0..1 across [begin, end] of the loop.
  double phase(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((clock.value - begin) / (end - begin)).clamp(0.0, 1.0));

  /// Everything fades out at the loop's end, to start again clean.
  double get fadeOut => still ? 1 : 1 - phase(0.93, 1, Curves.easeIn);
}

const _cover = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.crimsonNeon, AppColors.neonPurple]);

/// A cover's colour coming in with [saturation] (0 grey, 1 full).
List<double> _saturate(double s) {
  final i = 1 - s;
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [r * i + s, g * i, b * i, 0, 0, r * i, g * i + s, b * i, 0, 0, r * i, g * i, b * i + s, 0, 0, 0, 0, 0, 1, 0];
}

// ── 1 · Library: songs marked with the mask, the album gaining colour ──

class _LibraryDemo extends StatefulWidget {
  const _LibraryDemo({required this.still, required this.locale});
  final bool still;
  final LocaleProvider locale;

  @override
  State<_LibraryDemo> createState() => _LibraryDemoState();
}

class _LibraryDemoState extends State<_LibraryDemo> with SingleTickerProviderStateMixin, _DemoClock {
  static const _songs = ['One More Time', 'Aerodynamic', 'Digital Love', 'Harder, Better, Faster, Stronger'];

  /// Songs tapped by hand: the loop stops and the demo is yours.
  final Set<int> _mine = {};
  bool _byHand = false;

  @override
  bool get held => _byHand;

  @override
  Duration get period => const Duration(seconds: 7);
  @override
  bool get still => widget.still;

  bool _marked(int i) => _byHand ? _mine.contains(i) : clock.value > 0.12 + i * 0.18;

  void _tap(int i) {
    Haptics.selection();
    setState(() {
      if (!_byHand) {
        _byHand = true;
        clock.stop();
        _mine.addAll([
          for (var k = 0; k < _songs.length; k++)
            if (clock.value > 0.12 + k * 0.18) k,
        ]);
      }
      if (!_mine.remove(i)) _mine.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final done = [for (var i = 0; i < _songs.length; i++) _marked(i)].where((m) => m).length;
        final progress = done / _songs.length;
        return Opacity(
          opacity: _byHand ? 1 : fadeOut,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // The cover gains its colour as the album completes.
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: 0.15 + 0.85 * progress),
                      duration: AppMotion.slow,
                      builder: (context, s, _) => ColorFiltered(
                        colorFilter: ColorFilter.matrix(_saturate(s)),
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(gradient: _cover, borderRadius: BorderRadius.circular(AppRadius.card)),
                          child: const Icon(Icons.album_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discovery',
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.titleLg,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textBright,
                            ),
                          ),
                          Text(
                            'Daft Punk',
                            style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(end: progress),
                                    duration: AppMotion.slow,
                                    curve: AppMotion.move,
                                    builder: (context, v, _) => LinearProgressIndicator(
                                      value: v,
                                      minHeight: 4,
                                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$done/${_songs.length}',
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.caption,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  tabular: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _songs.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    onTap: () => _tap(i),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted, tabular: true),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _songs[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.bodyLg,
                                fontWeight: FontWeight.w600,
                                color: _marked(i) ? AppColors.textBright : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          OniMaskIcon(isActive: _marked(i), size: 22),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 2 · Discover: typing a search, results arriving, an artist's radio ──

class _SearchDemo extends StatefulWidget {
  const _SearchDemo({required this.still, required this.locale});
  final bool still;
  final LocaleProvider locale;

  @override
  State<_SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<_SearchDemo> with SingleTickerProviderStateMixin, _DemoClock {
  @override
  Duration get period => const Duration(seconds: 6);
  @override
  bool get still => widget.still;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final typed = strings.onb2Typed;
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final letters = (typed.length * phase(0.04, 0.34, Curves.linear)).round();
        final caret = still || (clock.value * 12).floor().isEven;
        Widget arrive(double at, Widget child) {
          final a = phase(at, at + 0.08);
          return Opacity(
            opacity: a,
            child: Transform.translate(offset: Offset(0, 12 * (1 - a)), child: child),
          );
        }

        Widget result(IconData icon, String title, String sub, {bool round = false}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: _cover,
                  shape: round ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: round ? null : BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w700, color: AppColors.textBright),
                    ),
                    Text(
                      sub,
                      style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final radio = phase(0.6, 0.7);
        final glow = still ? 0.5 : 0.5 + 0.5 * math.sin(clock.value * math.pi * 8);
        return Opacity(
          opacity: fadeOut,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The search field, typing.
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        typed.substring(0, letters),
                        style: locale.getTextStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.w600, color: AppColors.textBright),
                      ),
                      Opacity(
                        opacity: caret ? 1 : 0,
                        child: Container(width: 2, height: 18, margin: const EdgeInsets.only(left: 1), color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                arrive(0.38, result(Icons.person_rounded, 'Daft Punk', strings.searchTopArtistKind, round: true)),
                arrive(0.45, result(Icons.music_note_rounded, 'One More Time', 'Daft Punk · Discovery')),
                arrive(0.52, result(Icons.album_rounded, 'Random Access Memories', 'Daft Punk · 2013')),
                const SizedBox(height: 14),
                // The artist's radio, glowing.
                Opacity(
                  opacity: radio,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * radio,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentFill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35 * glow), blurRadius: 16)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radio_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              strings.onb2Radio,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 3 · Listen: the disc turning, the preview running, the lyrics lighting ──

class _PlayerDemo extends StatefulWidget {
  const _PlayerDemo({required this.still, required this.locale});
  final bool still;
  final LocaleProvider locale;

  @override
  State<_PlayerDemo> createState() => _PlayerDemoState();
}

class _PlayerDemoState extends State<_PlayerDemo> with SingleTickerProviderStateMixin, _DemoClock {
  @override
  Duration get period => const Duration(seconds: 8);
  @override
  bool get still => widget.still;
  @override
  double get rest => 0.6;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final t = clock.value;
        final seconds = (t * 30).floor();
        Widget lyric(String text, double lit, {bool current = false}) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (b) =>
              LinearGradient(stops: [lit, lit], colors: const [AppColors.accentText, AppColors.textMuted]).createShader(b),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: current ? AppFontSize.titleLg : AppFontSize.title,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The disc, one turn per loop (seamless).
              Transform.rotate(
                angle: still ? 0 : t * 2 * math.pi,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.inkSoft,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.7), width: 1.5),
                    boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 18)],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final r in [50.0, 42.0, 34.0])
                        Container(
                          width: r * 2,
                          height: r * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                        ),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _cover),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'One More Time',
                style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w800, color: AppColors.textBright),
              ),
              Text(
                'Daft Punk',
                style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '0:${seconds.toString().padLeft(2, '0')}',
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted, tabular: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: t,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '0:30',
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted, tabular: true),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strings.onb3Preview,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              // Synced lyrics, word by word.
              lyric(strings.onb3LyricA, still ? 1 : phase(0.08, 0.48, Curves.linear), current: t < 0.5),
              const SizedBox(height: 4),
              lyric(strings.onb3LyricB, still ? 0.5 : phase(0.5, 0.9, Curves.linear), current: t >= 0.5),
            ],
          ),
        );
      },
    );
  }
}

// ── 4 · Your path: Echo filling the level, beings waking one by one ──

class _PathDemo extends StatefulWidget {
  const _PathDemo({required this.still, required this.locale});
  final bool still;
  final LocaleProvider locale;

  @override
  State<_PathDemo> createState() => _PathDemoState();
}

class _PathDemoState extends State<_PathDemo> with SingleTickerProviderStateMixin, _DemoClock {
  /// Three beings of the catalogue, one of each of the first rarities.
  static const _beings = [
    ('assets/images/masks/r/eizou.webp', 'R'),
    ('assets/images/masks/sr/fubuki.webp', 'SR'),
    ('assets/images/masks/ssr/kabuto.webp', 'SSR'),
  ];

  @override
  Duration get period => const Duration(seconds: 7);
  @override
  bool get still => widget.still;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final eco = phase(0.08, 0.72, Curves.easeInOutCubic);
        final plus = phase(0.72, 0.8);
        return Opacity(
          opacity: fadeOut,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      strings.onb4Level(eco >= 1 ? 8 : 7),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textBright,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: plus,
                      child: Transform.translate(
                        offset: Offset(0, 6 * (1 - plus)),
                        child: Text(
                          '+40 ECO',
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentText,
                            tabular: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: 0.2 + 0.8 * eco,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < _beings.length; i++)
                      _Being(asset: _beings[i].$1, rarity: _beings[i].$2, locale: locale, awake: phase(0.22 + i * 0.18, 0.32 + i * 0.18)),
                  ],
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: phase(0.6, 0.7),
                  child: Text(
                    strings.onb4Woke,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentText,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A being: a dark silhouette, then its colours, a halo and its rarity
/// as it wakes.
class _Being extends StatelessWidget {
  const _Being({required this.asset, required this.rarity, required this.locale, required this.awake});

  final String asset;
  final String rarity;
  final LocaleProvider locale;
  final double awake;

  @override
  Widget build(BuildContext context) {
    final pop = awake <= 0 || awake >= 1 ? 1.0 : 1 + 0.14 * math.sin(awake * math.pi);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: pop,
          child: SizedBox(
            width: 76,
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // The halo, round, behind it.
                Transform.scale(
                  scale: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.30 * awake),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),
                ),
                // Asleep: the silhouette.
                Image.asset(asset, color: AppColors.borderGlow, colorBlendMode: BlendMode.srcIn, gaplessPlayback: true),
                Opacity(opacity: awake, child: Image.asset(asset, gaplessPlayback: true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rarity,
          style: locale.getTextStyle(
            fontSize: AppFontSize.micro,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Color.lerp(AppColors.textMuted, AppColors.accentText, awake),
          ),
        ),
      ],
    );
  }
}
