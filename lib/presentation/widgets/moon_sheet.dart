import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/moon_provider.dart';
import '../state/use_cases.dart';
import 'cyber_glitch_text.dart';
import 'eco_widgets.dart';
import 'haptics.dart';
import 'moon_glyph.dart';
import 'swipeable_sheet.dart';

const _silver = Color(0xFFD6E0F5);
const _blood = Color(0xFFE0452B);

class MoonSheet extends ConsumerWidget {
  const MoonSheet({super.key});

  static Future<void> show(BuildContext context) {
    context.readState(moonProvider).refresh();
    context.readState(playHistoryProvider).load();
    return SwipeableSheet.show(
      context,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, controller) => const MoonSheet(),
    );
  }

  /// Bakes the moons this sheet shows while the app is idle, so it opens
  /// without drawing them all on its first frame.
  static void prewarm(BuildContext context, MoonProvider moon) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final s = moon.snapshot;
    final south = moon.southernHemisphere;
    MoonImageKey key(double size, double ill, bool waxing, {bool halo = false}) => MoonImageKey(
        size: size,
        dpr: dpr,
        illumination: ill,
        waxing: waxing,
        southern: south,
        eclipse: false,
        halo: halo);
    MoonImageCache.instance.warm([
      key(132, s.illumination, s.waxing, halo: true),
      for (final p in moon.cyclePhases) key(28, p.illumination, p.waxing),
      for (final e in s.upcoming)
        switch (e.kind) {
          MoonPhaseKind.newMoon => key(30, 0, true),
          MoonPhaseKind.firstQuarter => key(30, 0.5, true),
          MoonPhaseKind.fullMoon => key(30, 1, true),
          MoonPhaseKind.lastQuarter => key(30, 0.5, false),
        },
    ]);
  }

  /// "Faltan 3 días para luna llena", or "luna llena esta noche".
  static String countdown(AppStrings strings, MoonSnapshot s) {
    if (s.isFullMoonWindow) return strings.moonFullTonight;
    final diff = s.nextFull.time.difference(s.at);
    if (diff.inHours < 24) {
      return strings.moonUntilFull(hours: diff.inHours < 1 ? 1 : diff.inHours);
    }
    return strings.moonUntilFull(days: (diff.inMinutes / 1440).round());
  }

  /// The tracks of the mix: most played this lunar cycle, topped up with
  /// favorites and recents when the cycle was quiet.
  /// [topBetween] gives the most played songs in a time range (the play
  /// history); [fallback] fills a quiet cycle (favorites, then recents).
  static List<Track> buildMix(
    MoonSnapshot s, {
    required List<Track> Function(DateTime from, DateTime to) topBetween,
    required List<Track> fallback,
  }) {
    final from = s.isFullMoonWindow
        ? s.nearestFull.subtract(Duration(
            minutes: (MoonCalculator.synodicMonth * 1440).round()))
        : s.previousFull.time;
    final mix = topBetween(from, s.at);
    if (mix.isEmpty || mix.length >= 10) return mix;
    final seen = mix.map((t) => t.id).toSet();
    for (final t in fallback) {
      if (mix.length >= 10) break;
      if (seen.add(t.id)) mix.add(t);
    }
    return mix;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moon = ref.watch(moonProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final s = moon.snapshot;
    final eclipse = moon.eclipseActive;
    final accent = eclipse ? _blood : _silver;

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
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
            Text(
              strings.moonTonightTitle,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            _TappableMoon(
              moon: moon,
              eclipse: eclipse,
              phaseName: strings.moonPhaseName(s.name),
              illuminatedLabel: strings.moonIlluminated((s.illumination * 100).round()),
            ),
            const SizedBox(height: 6),
            Center(
              child: eclipse
                  ? CyberGlitchText(
                      text: strings.moonEclipseNow,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.titleLg,
                        fontWeight: FontWeight.w900,
                        color: _blood,
                        letterSpacing: 1.5,
                      ),
                    )
                  : Text(
                      strings.moonPhaseName(s.name),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.headline,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${strings.moonIlluminated((s.illumination * 100).round())} · ${strings.moonAge(s.ageDays.floor() + 1)}',
                style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sheet),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.brightness_1, size: 11, color: accent),
                    const SizedBox(width: 7),
                    Text(
                      countdown(strings, s),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),
            EcoLocked(feature: EcoFeature.moonMix, child: _FullMoonMixCard(snapshot: s)),

            const SizedBox(height: 22),
            Text(
              strings.moonCycleTitle,
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            _CycleStrip(phases: moon.cyclePhases, currentName: s.name, southern: moon.southernHemisphere, accent: accent),

            const SizedBox(height: 22),
            Text(
              strings.moonUpcomingTitle,
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final e in s.upcoming)
                  Expanded(child: _PhaseTile(event: e, southern: moon.southernHemisphere)),
              ],
            ),

            const SizedBox(height: 18),
            if (moon.nextEclipse != null && moon.eclipseNow == null)
              Row(
                children: [
                  const Icon(Icons.brightness_3_rounded, size: 14, color: _blood),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.moonNextEclipse(
                        strings.longDate(moon.nextEclipse!.greatest.toLocal()),
                        moon.nextEclipse!.kind,
                      ),
                      style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: moon.atmosphereEnabled,
              onChanged: (v) {
                Haptics.selection();
                moon.setAtmosphereEnabled(v);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accent,
              secondary: Icon(Icons.nightlight_round,
                  size: 18, color: moon.atmosphereEnabled ? _silver : AppColors.textMuted),
              title: Text(
                strings.moonAtmosphereTitle,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
              ),
              subtitle: Text(
                strings.moonAtmosphereSubtitle,
                style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleStrip extends ConsumerStatefulWidget {
  final List<CyclePhase> phases;
  final MoonPhaseName currentName;
  final bool southern;
  final Color accent;

  const _CycleStrip({required this.phases, required this.currentName, required this.southern, required this.accent});

  @override
  ConsumerState<_CycleStrip> createState() => _CycleStripState();
}

class _CycleStripState extends ConsumerState<_CycleStrip> {
  static const double _itemWidth = 74;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final phases = widget.phases;
    final current = phases.indexWhere((p) => p.name == widget.currentName);

    return LayoutBuilder(builder: (context, c) {
      // Start with today's phase centred.
      _scroll ??= ScrollController(
        initialScrollOffset: (current * _itemWidth - (c.maxWidth - _itemWidth) / 2)
            .clamp(0.0, (phases.length * _itemWidth - c.maxWidth).clamp(0.0, double.infinity)),
      );
      return SizedBox(
        // Room for two lines of phase name at the type scale's floor (D-02).
        height: 120,
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: phases.length,
          itemExtent: _itemWidth,
          itemBuilder: (_, i) {
            final p = phases[i];
            final isToday = i == current;
            return Semantics(
              selected: isToday,
              label: '${strings.moonPhaseName(p.name)}, ${strings.shortDate(p.time.toLocal())}',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                decoration: BoxDecoration(
                  color: isToday ? widget.accent.withValues(alpha: 0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: isToday ? widget.accent.withValues(alpha: 0.55) : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 14,
                      child: isToday
                          ? Text(
                              strings.moonToday,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.micro,
                                fontWeight: FontWeight.w900,
                                color: widget.accent,
                                letterSpacing: 1.2,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: p.name == MoonPhaseName.newMoon
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderGlow),
                            )
                          : null,
                      child: MoonGlyph(
                        size: 28,
                        illumination: p.illumination,
                        waxing: p.waxing,
                        southernHemisphere: widget.southern,
                        halo: false,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.moonPhaseName(p.name),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        height: 1.15,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday ? AppColors.textBright : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      strings.shortDate(p.time.toLocal()),
                      style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _PhaseTile extends ConsumerWidget {
  final MoonEvent event;
  final bool southern;

  const _PhaseTile({required this.event, required this.southern});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final local = event.time.toLocal();
    final (ill, waxing) = switch (event.kind) {
      MoonPhaseKind.newMoon => (0.0, true),
      MoonPhaseKind.firstQuarter => (0.5, true),
      MoonPhaseKind.fullMoon => (1.0, true),
      MoonPhaseKind.lastQuarter => (0.5, false),
    };
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: event.kind == MoonPhaseKind.newMoon
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlow),
                )
              : null,
          child: MoonGlyph(
            size: 30,
            illumination: ill,
            waxing: waxing,
            southernHemisphere: southern,
            halo: false,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.moonEventName(event.kind),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: locale.getTextStyle(
            fontSize: AppFontSize.micro,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${strings.shortDate(local)} · $hh:$mm',
          textAlign: TextAlign.center,
          style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _FullMoonMixCard extends ConsumerStatefulWidget {
  final MoonSnapshot snapshot;
  const _FullMoonMixCard({required this.snapshot});

  @override
  ConsumerState<_FullMoonMixCard> createState() => _FullMoonMixCardState();
}

class _FullMoonMixCardState extends ConsumerState<_FullMoonMixCard> {
  bool _saving = false;

  Future<void> _save(List<Track> mix, AppStrings strings) async {
    setState(() => _saving = true);
    Haptics.confirm();
    final name = strings.moonMixPlaylistName(
        strings.longDate(widget.snapshot.nearestFull.toLocal()));
    final created = await ref.read(createPlaylistProvider)(name, tracks: mix);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(created != null ? strings.moonMixSaved : strings.moonMixSaveFailed),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final s = widget.snapshot;
    final history = ref.watch(playHistoryProvider);
    final unlocked = s.isFullMoonWindow || ref.read(authProvider).isAdmin;
    final library = ref.read(libraryProvider);
    final mix = unlocked
        ? MoonSheet.buildMix(s,
            topBetween: history.topBetween,
            fallback: [...library.favoriteTracks, ...library.recentTracks])
        : const <Track>[];
    final cycleCount =
        unlocked ? 0 : history.countBetween(s.previousFull.time, s.at);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? [_silver.withValues(alpha: 0.16), AppColors.bgMid]
              : [AppColors.bgMid, AppColors.bgMid],
        ),
        border: Border.all(
          color: unlocked ? _silver.withValues(alpha: 0.6) : AppColors.border,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: _silver.withValues(alpha: 0.18), blurRadius: 20)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
                size: 16,
                color: unlocked ? _silver : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.moonMixTitle,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? AppColors.textBright : AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!unlocked) ...[
            Text(
              strings.moonMixLocked(strings.shortDate(s.nextFull.time.toLocal())),
              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              strings.moonMixProgress(cycleCount),
              style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
            ),
          ] else if (mix.isEmpty)
            Text(
              strings.moonMixEmpty,
              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
            )
          else ...[
            Text(
              strings.moonMixUnlocked(mix.length),
              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mix.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: mix[i].coverUrl.isEmpty
                      ? Container(width: 46, height: 46, color: AppColors.bgCard)
                      : CachedNetworkImage(
                          imageUrl: mix[i].coverUrl,
                          width: 46,
                          height: 46,
                          memCacheWidth: 138,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      ref.read(playTracksProvider)(mix);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      strings.moonMixPlay,
                      style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _silver,
                      foregroundColor: AppColors.bgDeep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(mix, strings),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _silver),
                          )
                        : const Icon(Icons.playlist_add_rounded, size: 18, color: _silver),
                    label: Text(
                      strings.moonMixSave,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w800,
                        color: _silver,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _silver.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TappableMoon extends StatefulWidget {
  final MoonProvider moon;
  final bool eclipse;
  final String phaseName;
  final String illuminatedLabel;

  const _TappableMoon({
    required this.moon,
    required this.eclipse,
    required this.phaseName,
    required this.illuminatedLabel,
  });

  @override
  State<_TappableMoon> createState() => _TappableMoonState();
}

class _TappableMoonState extends State<_TappableMoon>
    with SingleTickerProviderStateMixin {
  static const _requiredTaps = 10;
  static const _tapWindow = Duration(milliseconds: 600);

  int _tapCount = 0;
  DateTime _lastTap = DateTime(0);
  bool _rabbitVisible = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut));
    _fadeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _rabbitVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) > _tapWindow) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= _requiredTaps && !_rabbitVisible) {
      _tapCount = 0;
      Haptics.tap();
      setState(() => _rabbitVisible = true);
      _fadeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.moon.snapshot;
    return Center(
      child: Semantics(
        label: '${widget.phaseName}, ${widget.illuminatedLabel}',
        child: GestureDetector(
          onTap: _onTap,
          onLongPress: () {
            Haptics.longPress();
            widget.moon.previewEclipse();
          },
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    children: [
                      MoonBreathing(
                        active: widget.eclipse,
                        child: MoonGlyph(
                          size: 132,
                          illumination: s.illumination,
                          waxing: s.waxing,
                          southernHemisphere: widget.moon.southernHemisphere,
                          eclipse: widget.eclipse,
                        ),
                      ),
                      if (_rabbitVisible)
                        AnimatedBuilder(
                          animation: _fade,
                          builder: (context, child) => Opacity(
                            opacity: _fade.value,
                            child: ClipOval(
                              child: CustomPaint(
                                size: const Size.square(132),
                                painter: _MoonRabbitPainter(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_rabbitVisible)
                  AnimatedBuilder(
                    animation: _fade,
                    builder: (context, child) => Opacity(
                      opacity: _fade.value * 0.6,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '月のうさぎ',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: _silver.withValues(alpha: 0.7),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
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

class _MoonRabbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = const Color(0xFF1A1D27).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF1A1D27).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.035
      ..strokeCap = StrokeCap.round;

    final bodyX = c.dx + r * 0.08;
    final bodyY = c.dy + r * 0.18;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyX, bodyY),
        width: r * 0.42,
        height: r * 0.50,
      ),
      paint,
    );

    final headX = bodyX - r * 0.02;
    final headY = bodyY - r * 0.38;
    canvas.drawCircle(Offset(headX, headY), r * 0.14, paint);

    canvas.save();
    canvas.translate(headX - r * 0.08, headY - r * 0.14);
    canvas.rotate(-0.25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 0.09,
        height: r * 0.28,
      ),
      paint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(headX + r * 0.08, headY - r * 0.14);
    canvas.rotate(0.25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 0.09,
        height: r * 0.28,
      ),
      paint,
    );
    canvas.restore();

    final eyePaint = Paint()
      ..color = const Color(0xFF0A0C12).withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(headX - r * 0.05, headY - r * 0.02),
      r * 0.020,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headX + r * 0.05, headY - r * 0.02),
      r * 0.020,
      eyePaint,
    );

    final shoulderL = Offset(bodyX - r * 0.14, bodyY - r * 0.18);
    final shoulderR = Offset(bodyX + r * 0.14, bodyY - r * 0.18);
    final malletGrip = Offset(bodyX + r * 0.28, bodyY - r * 0.42);

    canvas.drawLine(shoulderL, malletGrip, strokePaint);
    canvas.drawLine(shoulderR, malletGrip, strokePaint);

    final malletEnd = Offset(malletGrip.dx + r * 0.18, malletGrip.dy - r * 0.08);
    canvas.drawLine(
      malletGrip,
      malletEnd,
      strokePaint..strokeWidth = r * 0.04,
    );

    canvas.save();
    canvas.translate(malletEnd.dx, malletEnd.dy);
    canvas.rotate(-0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(r * 0.06, 0), width: r * 0.16, height: r * 0.10),
        Radius.circular(r * 0.03),
      ),
      paint,
    );
    canvas.restore();

    final mortarY = bodyY + r * 0.32;
    final mortarX = bodyX + r * 0.26;
    final mortarPath = Path()
      ..moveTo(mortarX - r * 0.12, mortarY - r * 0.04)
      ..quadraticBezierTo(
        mortarX - r * 0.14, mortarY + r * 0.10,
        mortarX, mortarY + r * 0.11,
      )
      ..quadraticBezierTo(
        mortarX + r * 0.14, mortarY + r * 0.10,
        mortarX + r * 0.12, mortarY - r * 0.04,
      );
    canvas.drawPath(mortarPath, strokePaint..strokeWidth = r * 0.035);

    canvas.drawCircle(
      Offset(mortarX, mortarY + r * 0.03),
      r * 0.045,
      paint,
    );
  }

  @override
  bool shouldRepaint(_MoonRabbitPainter old) => false;
}
