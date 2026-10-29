import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/moon_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/play_history.dart';
import 'cyber_glitch_text.dart';
import 'moon_glyph.dart';
import 'swipeable_sheet.dart';

const _silver = Color(0xFFD6E0F5);
const _blood = Color(0xFFE0452B);

class MoonSheet extends StatelessWidget {
  const MoonSheet({super.key});

  static Future<void> show(BuildContext context) {
    context.read<MoonProvider>().refresh();
    context.read<PlayHistory>().load();
    return SwipeableSheet.show(
      context,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, controller) => const MoonSheet(),
    );
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
  static List<Track> buildMix(MoonSnapshot s, PlayHistory history, LibraryProvider library) {
    final from = s.isFullMoonWindow
        ? s.nearestFull.subtract(Duration(
            minutes: (MoonCalculator.synodicMonth * 1440).round()))
        : s.previousFull.time;
    final mix = history.topBetween(from, s.at);
    if (mix.isEmpty || mix.length >= 10) return mix;
    final seen = mix.map((t) => t.id).toSet();
    for (final t in [...library.favoriteTracks, ...library.recentTracks]) {
      if (mix.length >= 10) break;
      if (seen.add(t.id)) mix.add(t);
    }
    return mix;
  }

  @override
  Widget build(BuildContext context) {
    final moon = context.watch<MoonProvider>();
    final history = context.watch<PlayHistory>();
    final locale = context.read<LocaleProvider>();
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              strings.moonTonightTitle,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Semantics(
                label: '${strings.moonPhaseName(s.name)}, ${strings.moonIlluminated((s.illumination * 100).round())}',
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.heavyImpact();
                    moon.previewEclipse();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: MoonBreathing(
                      active: eclipse,
                      child: MoonGlyph(
                        size: 132,
                        illumination: s.illumination,
                        waxing: s.waxing,
                        southernHemisphere: moon.southernHemisphere,
                        eclipse: eclipse,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: eclipse
                  ? CyberGlitchText(
                      text: strings.moonEclipseNow,
                      style: locale.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _blood,
                        letterSpacing: 1.5,
                      ),
                    )
                  : Text(
                      strings.moonPhaseName(s.name),
                      style: locale.getTextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${strings.moonIlluminated((s.illumination * 100).round())} · ${strings.moonAge(s.ageDays.floor() + 1)}',
                style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  countdown(strings, s),
                  style: locale.getTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),
            _FullMoonMixCard(snapshot: s, history: history),

            const SizedBox(height: 22),
            Text(
              strings.moonCycleTitle,
              style: locale.getTextStyle(
                fontSize: 10,
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
                fontSize: 10,
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
                      style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: moon.atmosphereEnabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
              ),
              subtitle: Text(
                strings.moonAtmosphereSubtitle,
                style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleStrip extends StatefulWidget {
  final List<CyclePhase> phases;
  final MoonPhaseName currentName;
  final bool southern;
  final Color accent;

  const _CycleStrip({required this.phases, required this.currentName, required this.southern, required this.accent});

  @override
  State<_CycleStrip> createState() => _CycleStripState();
}

class _CycleStripState extends State<_CycleStrip> {
  static const double _itemWidth = 74;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>();
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
        height: 112,
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday ? widget.accent.withValues(alpha: 0.55) : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 12,
                      child: isToday
                          ? Text(
                              strings.moonToday,
                              style: locale.getTextStyle(
                                fontSize: 8,
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
                        fontSize: 9,
                        height: 1.15,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday ? AppColors.textBright : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      strings.shortDate(p.time.toLocal()),
                      style: locale.getTextStyle(fontSize: 8.5, color: AppColors.textMuted),
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

class _PhaseTile extends StatelessWidget {
  final MoonEvent event;
  final bool southern;

  const _PhaseTile({required this.event, required this.southern});

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>();
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
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${strings.shortDate(local)} · $hh:$mm',
          textAlign: TextAlign.center,
          style: locale.getTextStyle(fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _FullMoonMixCard extends StatefulWidget {
  final MoonSnapshot snapshot;
  final PlayHistory history;

  const _FullMoonMixCard({required this.snapshot, required this.history});

  @override
  State<_FullMoonMixCard> createState() => _FullMoonMixCardState();
}

class _FullMoonMixCardState extends State<_FullMoonMixCard> {
  bool _saving = false;

  Future<void> _save(List<Track> mix, AppStrings strings) async {
    setState(() => _saving = true);
    unawaited(HapticFeedback.lightImpact());
    final name = strings.moonMixPlaylistName(
        strings.longDate(widget.snapshot.nearestFull.toLocal()));
    final created = await context.read<PlaylistProvider>().createPlaylist(name, tracks: mix);
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
    final locale = context.read<LocaleProvider>();
    final strings = locale.strings;
    final s = widget.snapshot;
    final unlocked = s.isFullMoonWindow;
    final mix = unlocked
        ? MoonSheet.buildMix(s, widget.history, context.read<LibraryProvider>())
        : const <Track>[];
    final cycleCount = unlocked
        ? 0
        : widget.history.countBetween(s.previousFull.time, s.at);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
                    fontSize: 12,
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
              style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              strings.moonMixProgress(cycleCount),
              style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ] else if (mix.isEmpty)
            Text(
              strings.moonMixEmpty,
              style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          else ...[
            Text(
              strings.moonMixUnlocked(mix.length),
              style: locale.getTextStyle(fontSize: 11, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mix.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
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
                      HapticFeedback.lightImpact();
                      context.read<AudioProvider>().playTrack(mix.first, newQueue: mix);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      strings.moonMixPlay,
                      style: locale.getTextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _silver,
                      foregroundColor: AppColors.bgDeep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _silver,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _silver.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
