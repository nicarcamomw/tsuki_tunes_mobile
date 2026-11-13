import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/weather.dart';
import '../state/ambient_provider.dart';
import '../state/app_providers.dart';
import '../state/use_cases.dart';
import '../state/weather_provider.dart';
import 'app_snack.dart';
import 'haptics.dart';
import 'moon_glyph.dart';
import 'weather_sheet.dart';

IconData skyIcon(Sky? sky, {required bool isDay, required DayPart part}) {
  final dark = part == DayPart.night || part == DayPart.lateNight;
  return switch (sky) {
    null => switch (part) {
        DayPart.morning => Icons.wb_twilight_rounded,
        DayPart.afternoon => Icons.wb_sunny_outlined,
        _ => Icons.bedtime_rounded,
      },
    Sky.clear =>
      isDay && !dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
    Sky.fewClouds =>
      isDay && !dark ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded,
    Sky.cloudy || Sky.overcast => Icons.cloud_rounded,
    Sky.fog => Icons.foggy,
    Sky.drizzle => Icons.grain_rounded,
    Sky.rain => Icons.umbrella_rounded,
    Sky.snow => Icons.ac_unit_rounded,
    Sky.storm => Icons.thunderstorm_rounded,
  };
}

Color skyColor(Sky? sky, {required bool isDay}) => switch (sky) {
      null => AppColors.textMuted,
      Sky.clear => isDay ? AppColors.warning : AppColors.textBright,
      Sky.fewClouds ||
      Sky.cloudy ||
      Sky.overcast ||
      Sky.fog =>
        AppColors.textMuted,
      Sky.drizzle || Sky.rain => AppColors.neonCyan,
      Sky.snow => AppColors.textBright,
      Sky.storm => AppColors.neonPurple,
    };

/// One quiet line under the home title that changes with the time of day,
/// the weather and the moon: "Tarde lluviosa · 14° · Luna menguante".
class SkyLine extends ConsumerStatefulWidget {
  @visibleForTesting
  final DateTime Function()? clock;

  const SkyLine({super.key, this.clock});

  @override
  ConsumerState<SkyLine> createState() => _SkyLineState();
}

class _SkyLineState extends ConsumerState<SkyLine> {
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    // The time of day changes even when nothing else does.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final (enabled, weather, loading) =
        ref.watch(weatherProvider.select(
            (w) => (w.enabled, w.current, w.loading)));
    final (
      moon,
      lit,
      waxing
    ) = ref.watch(moonProvider.select(
        (m) => (m.snapshot.name, m.snapshot.illumination, m.snapshot.waxing)));

    final part = dayPartAt((widget.clock ?? DateTime.now)());
    final w = enabled ? weather : null;
    final isDay =
        w?.isDay ?? (part == DayPart.morning || part == DayPart.afternoon);
    final head = w == null
        ? strings.dayPartName(part)
        : strings.skyPhrase(part, w.sky, isDay: isDay);
    final text = [
      head,
      if (w != null) '${w.temperature.round()}°',
      strings.moonPhaseName(moon),
    ].join('  ·  ');
    final color = skyColor(w?.sky, isDay: isDay);

    return Semantics(
      button: true,
      label: text,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: () {
          Haptics.tap();
          WeatherSheet.show(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // On a clear night the real moon stands in for the weather icon.
              if (!isDay &&
                  (w == null || w.sky == Sky.clear || w.sky == Sky.fewClouds))
                MoonGlyph(
                    size: 15, illumination: lit, waxing: waxing, halo: false)
              else
                Icon(skyIcon(w?.sky, isDay: isDay, part: part),
                    size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (loading && enabled) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.4, color: AppColors.textMuted),
                ),
              ] else if (!enabled) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.borderGlow),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text(
                        strings.weatherTitle,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Fall { none, drizzle, rain, storm, snow }

/// Puts falling rain (or snow) behind the home header while it is raining
/// where the listener is. Faint, and it fades out towards the bottom.
class SkyBackdrop extends ConsumerWidget {
  final Widget child;
  const SkyBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sky = ref.watch(weatherProvider.select(
        (w) => w.enabled ? w.current?.sky : null));
    final fall = switch (sky) {
      Sky.drizzle => _Fall.drizzle,
      Sky.rain => _Fall.rain,
      Sky.storm => _Fall.storm,
      Sky.snow => _Fall.snow,
      _ => _Fall.none,
    };
    if (fall == _Fall.none || MediaQuery.of(context).disableAnimations) {
      return child;
    }
    return Stack(
      children: [
        Positioned.fill(
            child: IgnorePointer(child: _Precipitation(fall: fall))),
        child,
      ],
    );
  }
}

class _Drop {
  final double x, speed, phase, length, width;
  const _Drop(this.x, this.speed, this.phase, this.length, this.width);
}

class _Precipitation extends StatefulWidget {
  final _Fall fall;
  const _Precipitation({required this.fall});

  @override
  State<_Precipitation> createState() => _PrecipitationState();
}

class _PrecipitationState extends State<_Precipitation>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  final ValueNotifier<double> _time = ValueNotifier(0);
  late List<_Drop> _drops = _make(widget.fall);
  final Random _rng = Random(7);
  double _nextFlash = 5;
  double _flashAt = -10;

  static List<_Drop> _make(_Fall fall) {
    final rng = Random(11);
    final count = switch (fall) {
      _Fall.drizzle => 26,
      _Fall.rain => 44,
      _Fall.storm => 70,
      _Fall.snow => 36,
      _Fall.none => 0,
    };
    final snow = fall == _Fall.snow;
    return [
      for (var i = 0; i < count; i++)
        _Drop(
          rng.nextDouble(),
          snow ? 0.10 + rng.nextDouble() * 0.08 : 0.85 + rng.nextDouble() * 0.6,
          rng.nextDouble(),
          snow ? 0 : 8 + rng.nextDouble() * (fall == _Fall.drizzle ? 5 : 12),
          snow
              ? 1 + rng.nextDouble() * 1.4
              : (fall == _Fall.drizzle ? 0.8 : 1.1),
        ),
    ];
  }

  @override
  void didUpdateWidget(_Precipitation old) {
    super.didUpdateWidget(old);
    if (old.fall != widget.fall) _drops = _make(widget.fall);
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    if (widget.fall == _Fall.storm && t >= _nextFlash) {
      _flashAt = t;
      _nextFlash = t + 7 + _rng.nextDouble() * 9;
    }
    _time.value = t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FallPainter(
          drops: _drops,
          fall: widget.fall,
          time: _time,
          flashAt: () => _flashAt,
        ),
      ),
    );
  }
}

class _FallPainter extends CustomPainter {
  final List<_Drop> drops;
  final _Fall fall;
  final ValueNotifier<double> time;
  final double Function() flashAt;

  _FallPainter(
      {required this.drops,
      required this.fall,
      required this.time,
      required this.flashAt})
      : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final h = size.height, w = size.width;
    if (h <= 0 || w <= 0) return;
    final snow = fall == _Fall.snow;
    final base = switch (fall) {
      _Fall.drizzle => 0.16,
      _Fall.rain => 0.22,
      _Fall.storm => 0.26,
      _Fall.snow => 0.35,
      _Fall.none => 0.0,
    };
    // Wind: rain leans a little, harder in a storm.
    final slant = fall == _Fall.storm ? 0.32 : 0.16;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final d in drops) {
      final cycle = (d.phase + t * d.speed) % 1.0;
      final y = cycle * (h + d.length + 10) - d.length;
      final fade = (1 - (y / h)).clamp(0.0, 1.0);
      final alpha = base * fade * fade;
      if (alpha < 0.01) continue;
      if (snow) {
        final x = d.x * w + sin(t * 0.9 + d.phase * 12) * 7;
        paint.color = AppColors.textBright.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), d.width, paint);
      } else {
        final x = d.x * (w + h * slant) - y * slant;
        paint
          ..color = AppColors.neonCyan.withValues(alpha: alpha)
          ..strokeWidth = d.width;
        canvas.drawLine(
            Offset(x, y), Offset(x - d.length * slant, y + d.length), paint);
      }
    }

    // Distant lightning: two quick flickers, very soft.
    if (fall == _Fall.storm) {
      final since = t - flashAt();
      if (since >= 0 && since < 0.45) {
        final flick =
            since < 0.08 ? 1.0 : (since > 0.16 && since < 0.24 ? 0.6 : 0.0);
        if (flick > 0) {
          canvas.drawRect(
            Offset.zero & size,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.textBright.withValues(alpha: 0.07 * flick),
                  AppColors.textBright.withValues(alpha: 0),
                ],
              ).createShader(Offset.zero & size),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FallPainter old) =>
      old.fall != fall || old.drops != drops;
}

/// "It's raining where you are: play something for the rain?" Shown once per
/// rain, only with the weather on.
class RainOfferCard extends ConsumerStatefulWidget {
  /// The songs to pick from; the user's favorites and recents by default.
  @visibleForTesting
  final List<Track>? library;

  const RainOfferCard({super.key, this.library});

  @override
  ConsumerState<RainOfferCard> createState() => _RainOfferCardState();
}

enum _OfferState { asking, preparing, empty }

class _RainOfferCardState extends ConsumerState<RainOfferCard> {
  _OfferState _state = _OfferState.asking;
  bool _addRain = false;

  Future<void> _accept() async {
    Haptics.confirm();
    setState(() => _state = _OfferState.preparing);
    final library = ref.read(libraryProvider);
    final ambient = ref.read(ambientProvider);
    final weather = ref.read(weatherProvider);
    final strings = ref.read(stringsProvider);
    final messenger = AppSnack.maybeOf(context);

    final tracks =
        widget.library ?? [...library.favoriteTracks, ...library.recentTracks];
    final list = await ref.read(rainMixProvider)(
      library: tracks,
      favoriteArtists: [...library.favoriteArtists.map((a) => a.name)],
    );
    if (!mounted) return;
    if (list.isEmpty) {
      setState(() => _state = _OfferState.empty);
      return;
    }
    unawaited(ref.read(playTracksProvider)(list));
    if (_addRain && !ambient.isOn(AmbientSound.rain)) {
      unawaited(ambient.toggle(AmbientSound.rain));
    }
    unawaited(weather.dismissRainOffer());
    setState(() => _state = _OfferState.asking);
    messenger?.info(strings.rainOfferPlaying(list.length));
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(weatherProvider.select((w) => w.rainOffer));
    final place = ref.watch(weatherProvider.select(
        (w) => w.source == WeatherSource.place ? w.place?.name : null));
    final locale = ref.read(localeProvider);
    final strings = locale.strings;

    final Widget body;
    if (!offer && _state != _OfferState.empty) {
      body = const SizedBox(width: double.infinity);
    } else {
      body = Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.neonCyan.withValues(alpha: 0.14),
              AppColors.bgCard
            ],
          ),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.umbrella_rounded,
                    color: AppColors.neonCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.rainOfferTitle(place),
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.bodyLg,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                switch (_state) {
                  _OfferState.asking => strings.rainOfferQuestion,
                  _OfferState.preparing => strings.rainOfferPreparing,
                  _OfferState.empty => strings.rainOfferEmpty,
                },
                style: locale.getTextStyle(
                    fontSize: AppFontSize.body, color: AppColors.textMuted, height: 1.35),
              ),
            ),
            const SizedBox(height: 8),
            if (_state == _OfferState.asking)
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterChip(
                      selected: _addRain,
                      onSelected: (v) => setState(() => _addRain = v),
                      avatar: const Icon(Icons.water_drop_rounded,
                          size: 14, color: AppColors.neonCyan),
                      label: Text(strings.rainOfferAddRain),
                      labelStyle: locale.getTextStyle(
                          fontSize: AppFontSize.caption, color: AppColors.textPrimary),
                      showCheckmark: false,
                      selectedColor: AppColors.neonCyan.withValues(alpha: 0.2),
                      backgroundColor: AppColors.bgDeep,
                      side: BorderSide(
                          color: _addRain
                              ? AppColors.neonCyan
                              : AppColors.borderGlow),
                    ),
                    // Wraps instead of overflowing with large text sizes.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: () {
                              Haptics.selection();
                              unawaited(ref
                                  .read(weatherProvider)
                                  .dismissRainOffer());
                            },
                            child: Text(
                              strings.rainOfferNo,
                              style: locale.getTextStyle(
                                  fontSize: AppFontSize.body, color: AppColors.textMuted),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.neonCyan,
                              foregroundColor: AppColors.bgDeep,
                            ),
                            onPressed: _accept,
                            child: Text(
                              strings.rainOfferYes,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w800,
                                color: AppColors.bgDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_state == _OfferState.preparing)
              const Padding(
                padding: EdgeInsets.only(left: 30, bottom: 6),
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                      color: AppColors.neonCyan, minHeight: 2),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () { Haptics.tap();
                    setState(() => _state = _OfferState.asking);
                    ref.read(weatherProvider).dismissRainOffer();
                  },
                  child: Text(
                    MaterialLocalizations.of(context).closeButtonLabel,
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.body, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: body,
    );
  }
}
