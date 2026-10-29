import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_cache_size.dart';
import '../providers/locale_provider.dart';
import '../services/beat_clock.dart';
import '../services/bpm_flow.dart';

/// The spinning eye of the player. With the song's tempo (Deezer's BPM, or
/// tapped in by the listener) it turns once every four bars and pulses on
/// the beat. It works the same for Spotify, which gives no access to the
/// audio: only the tempo and the playback position are needed.
///
/// Tapping it on the beat three times lines the pulses up exactly with the
/// song; four taps also set the tempo of a song Deezer doesn't know. A long
/// press goes back to Deezer's tempo.
class RinneganVisualizer extends StatefulWidget {
  final bool isPlaying;
  final String? imageUrl;
  final double size;

  /// Enables the beat sync. Without it the eye just spins slowly.
  final String? trackId;
  /// Spotify plays the full song; a preview is a 30 s excerpt with its own
  /// beat positions, so taps are remembered separately for each.
  final bool fullSong;
  final Duration Function()? position;
  final double Function()? speed;
  @visibleForTesting
  final BpmService? tempoService;

  const RinneganVisualizer({
    super.key,
    required this.isPlaying,
    this.imageUrl,
    this.size = 220,
    this.trackId,
    this.fullSong = false,
    this.position,
    this.speed,
    this.tempoService,
  });

  @override
  State<RinneganVisualizer> createState() => _RinneganVisualizerState();
}

/// Everything the painters need for one frame.
class _Frame extends ChangeNotifier {
  double rotation = 0;
  /// Pulse brightness, 0..1, already scaled by accent and fade.
  double pulse = 0;
  /// Progress of the current pulse, 0..1.
  double phase = 0;
  /// Strength of the current pulse's shockwave (downbeats are stronger).
  double accent = 0;
  /// Fades the beat effects in and out (pause, track change).
  double level = 0;
  /// Base glow while playing.
  double glow = 0;
  /// Tap ripples: progress 0..1 of each.
  List<double> ripples = const [];

  void emit() => notifyListeners();
}

class _RinneganVisualizerState extends State<RinneganVisualizer>
    with SingleTickerProviderStateMixin {
  static const _hintKey = 'beat_sync_hint_shown';
  static const double _idleTurnSeconds = 12;
  /// One turn every 16 beats (four bars).
  static const double _beatsPerTurn = 16;
  static const Duration _rippleLength = Duration(milliseconds: 520);

  late final Ticker _ticker = createTicker(_onTick);
  final _frame = _Frame();
  final _wall = Stopwatch()..start();
  final _clock = PlaybackClock();
  final _taps = TapSync();
  final List<double> _rippleStarts = [];

  bool _reduceMotion = false;
  double _spin = 0; // rad/s
  double? _lastTick;
  double? _lastElapsed;
  BeatGrid? _grid;
  bool _gridFromTaps = false;
  int _lookupGen = 0;

  // Tap tracking: a pointer counts as a tap if it lifts quickly in place.
  Offset? _downAt;
  double? _downWall;

  // Status chip.
  String? _chip;
  Timer? _chipTimer;
  bool _hintPending = false;

  double get _now => _wall.elapsedMicroseconds / 1e6;
  BpmService get _tempo => widget.tempoService ?? BpmService.shared;

  @override
  void initState() {
    super.initState();
    _loadGrid();
    _checkHint();
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncTicker();
  }

  @override
  void didUpdateWidget(RinneganVisualizer old) {
    super.didUpdateWidget(old);
    if (old.trackId != widget.trackId || old.fullSong != widget.fullSong) {
      _taps.clear();
      _clock.reset();
      _loadGrid();
    }
    if (old.isPlaying != widget.isPlaying) _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _chipTimer?.cancel();
    _frame.dispose();
    super.dispose();
  }

  // --- Tempo ---

  String? get _key => widget.trackId == null || widget.trackId!.isEmpty
      ? null
      : BeatSyncStore.keyFor(widget.trackId!, fullSong: widget.fullSong);

  Future<void> _loadGrid() async {
    final gen = ++_lookupGen;
    final key = _key;
    _grid = null;
    _gridFromTaps = false;
    if (key == null) return;
    final id = widget.trackId!;

    await BeatSyncStore.shared.load();
    if (gen != _lookupGen || !mounted) return;
    final tapped = BeatSyncStore.shared.get(key);
    if (tapped != null) {
      _setGrid(tapped, fromTaps: true);
      return;
    }
    final known = _tempo.cached(id);
    if (known != null) {
      _setGrid(BeatGrid(known));
      return;
    }
    // One request, remembered for good (the same one the loudness uses).
    await _tempo.gainFor(id);
    if (gen != _lookupGen || !mounted) return;
    final bpm = _tempo.cached(id);
    if (bpm != null) _setGrid(BeatGrid(bpm));
  }

  void _setGrid(BeatGrid grid, {bool fromTaps = false}) {
    _grid = grid;
    _gridFromTaps = fromTaps;
    if (_hintPending && widget.isPlaying) _showHint();
    _syncTicker();
  }

  // --- Frame loop ---

  void _syncTicker() {
    if (_reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _frame
        ..rotation = 0
        ..pulse = 0
        ..level = 0
        ..glow = widget.isPlaying ? 1 : 0
        ..emit();
      return;
    }
    if (!_ticker.isActive && (widget.isPlaying || _needsFrames)) {
      _lastTick = null;
      _lastElapsed = null;
      _ticker.start();
    }
  }

  bool get _needsFrames =>
      _spin.abs() > 0.002 || _frame.level > 0.002 || _rippleStarts.isNotEmpty ||
      (_frame.glow - (widget.isPlaying ? 1 : 0)).abs() > 0.002;

  void _onTick(Duration elapsed) {
    final now = _now;
    // Animation steps follow the frame clock; song time follows the wall
    // clock, like the player.
    final e = elapsed.inMicroseconds / 1e6;
    final dt = _lastElapsed == null ? 0.0 : min(0.1, e - _lastElapsed!);
    _lastElapsed = e;
    _lastTick = now;
    final playing = widget.isPlaying;
    final grid = _grid;
    final rate = widget.speed?.call() ?? 1.0;

    double? t;
    final pos = widget.position;
    if (pos != null) {
      t = _clock.advance(pos(), Duration(microseconds: _wall.elapsedMicroseconds),
          playing: playing, rate: rate);
    }

    // Spin eases toward the song's pace (or to a stop when paused).
    final turnSeconds = grid == null ? _idleTurnSeconds : _beatsPerTurn * grid.period / rate;
    final target = playing ? 2 * pi / turnSeconds : 0.0;
    _spin += (target - _spin) * (1 - exp(-dt * 2.5));
    _frame.rotation = (_frame.rotation + _spin * dt) % (2 * pi);

    final ease = 1 - exp(-dt * 5);
    _frame.glow += ((playing ? 1.0 : 0.0) - _frame.glow) * ease;
    final beatOn = playing && grid != null && t != null;
    _frame.level += ((beatOn ? 1.0 : 0.0) - _frame.level) * ease;

    if (grid != null && t != null) {
      final pulseBeats = BeatPulse.pulseBeats(grid.bpm);
      final p = grid.beatsAt(t) / pulseBeats;
      final index = p.floor();
      final phase = p - index;
      final downbeat = grid.isDownbeat(index * pulseBeats.round());
      _frame
        ..phase = phase
        ..accent = downbeat ? 1.0 : 0.45
        ..pulse = BeatPulse.envelope(phase) * (downbeat ? 1.0 : 0.6) * _frame.level;
    } else {
      _frame.pulse *= 1 - ease;
    }

    _rippleStarts.removeWhere((s) => now - s > _rippleLength.inMicroseconds / 1e6 || now < s);
    _frame.ripples = [
      for (final s in _rippleStarts) (now - s) / (_rippleLength.inMicroseconds / 1e6),
    ];
    _frame.emit();

    if (!playing && !_needsFrames) _ticker.stop();
  }

  /// Song time at wall time [wall], from the smoothed clock.
  double? _songTimeAt(double wall) {
    final t = _clock.time;
    final last = _lastTick;
    if (t == null) return null;
    if (last == null || !widget.isPlaying) return t;
    return t + (wall - last) * (widget.speed?.call() ?? 1.0);
  }

  // --- Taps ---

  void _onPointerDown(PointerDownEvent e) {
    _downAt = e.localPosition;
    _downWall = _now;
  }

  void _onPointerUp(PointerUpEvent e) {
    final at = _downAt, wall = _downWall;
    _downAt = null;
    _downWall = null;
    if (at == null || wall == null) return;
    if ((e.localPosition - at).distance > 18 || _now - wall > 0.3) return;
    _onTap(wall);
  }

  void _onTap(double wall) {
    _rippleStarts.add(wall);
    _syncTicker();
    if (!widget.isPlaying || _key == null) return;
    final t = _songTimeAt(wall);
    if (t == null) return;
    HapticFeedback.selectionClick();

    final deezer = _gridFromTaps ? _tempo.cached(widget.trackId!) : _grid?.bpm;
    final result = _taps.tap(t, wall, bpm: deezer);
    final strings = context.read<LocaleProvider>().strings;
    if (result == null) {
      _showChip(strings.beatSyncTapping(_taps.count), hold: true);
      return;
    }
    final key = _key!;
    _setGrid(result.grid, fromTaps: true);
    unawaited(BeatSyncStore.shared.put(key, result.grid));
    HapticFeedback.mediumImpact();
    _showChip(result.tappedTempo
        ? strings.beatSyncTempo(result.grid.bpm.round())
        : strings.beatSyncLocked(result.grid.bpm.round()));
    _markHintSeen();
  }

  void _onLongPress() {
    // The lift that ends a long press is not a tap.
    _downAt = null;
    final key = _key;
    if (key == null) return;
    _taps.clear();
    HapticFeedback.mediumImpact();
    final strings = context.read<LocaleProvider>().strings;
    unawaited(BeatSyncStore.shared.remove(key));
    final bpm = _tempo.cached(widget.trackId!);
    _grid = bpm == null ? null : BeatGrid(bpm);
    _gridFromTaps = false;
    _showChip(bpm == null ? strings.beatSyncNoTempo : strings.beatSyncAuto(bpm.round()));
  }

  // --- Chip and first-time hint ---

  Future<void> _checkHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hintPending = !(prefs.getBool(_hintKey) ?? false);
      if (_hintPending && _grid != null && widget.isPlaying && mounted) _showHint();
    } catch (_) {}
  }

  void _showHint() {
    if (!mounted || _reduceMotion) return;
    _hintPending = false;
    _showChip(context.read<LocaleProvider>().strings.beatSyncHint, seconds: 5);
    _markHintSeen();
  }

  Future<void> _markHintSeen() async {
    _hintPending = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hintKey, true);
    } catch (_) {}
  }

  void _showChip(String text, {bool hold = false, int seconds = 2}) {
    _chipTimer?.cancel();
    setState(() => _chip = text);
    _chipTimer = Timer(Duration(seconds: hold ? 3 : seconds), () {
      if (mounted) setState(() => _chip = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final coverSize = size * 0.54;
    final disc = RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _VinylPainter(isPlaying: widget.isPlaying),
          child: Center(
            child: ExcludeSemantics(
              child: SizedBox(
                width: coverSize,
                height: coverSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox.expand(
                        child: widget.imageUrl != null &&
                                widget.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                memCacheWidth:
                                    imageCacheSize(context, coverSize),
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const _CoverPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    const _CoverPlaceholder(),
                              )
                            : const _CoverPlaceholder(iconSize: 40),
                      ),
                    ),
                    // Vignette softens cover edges into the vinyl
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x00000000),
                            Color(0x00000000),
                            Color(0x28000000),
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                    // Metallic center spindle
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.35, -0.35),
                          radius: 0.85,
                          colors: [
                            Color(0xFF606070),
                            Color(0xFF2A2A38),
                            Color(0xFF111118),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: GestureDetector(
        onLongPress: _onLongPress,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                    painter: _GlowPainter(_frame, widget.isPlaying)),
              ),
              AnimatedBuilder(
                animation: _frame,
                builder: (_, child) => Transform.scale(
                  scale: 1 + 0.02 * _frame.pulse,
                  child: Transform.rotate(
                      angle: _frame.rotation, child: child),
                ),
                child: disc,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                      painter: _SpecularPainter(_frame)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                      painter: _RingsPainter(_frame, widget.isPlaying)),
                ),
              ),
              Positioned(
                bottom: size * 0.1,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _chip == null
                        ? const SizedBox.shrink()
                        : _SyncChip(key: ValueKey(_chip), text: _chip!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final double iconSize;
  const _CoverPlaceholder({this.iconSize = 24});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bgMid,
        child: Icon(Icons.music_note, size: iconSize, color: AppColors.accent),
      );
}

class _SyncChip extends StatelessWidget {
  final String text;
  const _SyncChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: locale.getTextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textBright,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final _Frame f;
  final bool playing;
  _GlowPainter(this.f, this.playing) : super(repaint: f);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Soft drop shadow (fades as glow takes over)
    final shadowA = 0.35 * (1 - f.glow * 0.5);
    if (shadowA > 0.004) {
      canvas.drawCircle(
        Offset(c.dx + 1.5, c.dy + 4),
        r * 1.01,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
          ..color = const Color(0xFF000000).withValues(alpha: shadowA),
      );
    }

    // Red accent glow
    final a = f.glow * (0.24 + 0.56 * f.pulse);
    if (a <= 0.003) return;
    final outer = r * (1.16 + 0.12 * f.pulse);
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: a),
            AppColors.accent.withValues(alpha: a * 0.35),
            AppColors.accent.withValues(alpha: 0),
          ],
          stops: [r * 0.94 / outer, r * 1.04 / outer, 1],
        ).createShader(Rect.fromCircle(center: c, radius: outer)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.playing != playing;
}

class _RingsPainter extends CustomPainter {
  final _Frame f;
  final bool playing;
  _RingsPainter(this.f, this.playing) : super(repaint: f);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width;
    final r = w / 2;

    // Groove rings light up on the beat, the outer one most.
    const radii = [0.44, 0.38, 0.32];
    for (var i = 0; i < radii.length; i++) {
      final lift = f.pulse * (1 - i * 0.3);
      canvas.drawCircle(
        c,
        w * radii[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 1.2 * lift
          ..color = playing
              ? AppColors.accent.withValues(alpha: (0.28 + 0.62 * lift).clamp(0.0, 1.0))
              : AppColors.border,
      );
    }

    // The iris: a thin ring hugging the cover flashes with the pulse.
    if (f.pulse > 0.01) {
      canvas.drawCircle(
        c,
        w * 0.275,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: 0.75 * f.pulse),
      );
    }

    // A shockwave leaves the rim on each pulse, strongest on the downbeat.
    if (f.level > 0.01) {
      final p = f.phase;
      final eased = 1 - pow(1 - p, 3).toDouble();
      final alpha = pow(1 - p, 1.6) * 0.7 * f.accent * f.level;
      if (alpha > 0.004) {
        canvas.drawCircle(
          c,
          r * (1.03 + (0.1 + 0.16 * f.accent) * eased),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 - 2.4 * p
            ..color = AppColors.accent.withValues(alpha: alpha.clamp(0.0, 1.0)),
        );
      }
    }

    // Tap ripples.
    for (final p in f.ripples) {
      final eased = 1 - pow(1 - p, 2).toDouble();
      canvas.drawCircle(
        c,
        r * (0.62 + 0.5 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.textBright.withValues(alpha: 0.5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.playing != playing;
}

/// The vinyl record surface: base, grooves, label zone, rim bevel and
/// iridescent sweep. Baked once into the RepaintBoundary and only
/// repaints when play state changes the accent ring.
class _VinylPainter extends CustomPainter {
  final bool isPlaying;
  const _VinylPainter({required this.isPlaying});

  static const double _coverR = 0.54;
  static const double _labelR = 0.58;
  static const double _grooveR = 0.93;
  static const int _grooveCount = 35;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Base vinyl with depth gradient
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFF151520),
            Color(0xFF0E0E16),
            Color(0xFF0A0A10),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Outer rim bevel (metallic sweep)
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF3A3A4A),
            Color(0xFF1E1E28),
            Color(0xFF101018),
            Color(0xFF1E1E28),
            Color(0xFF3A3A4A),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Edge light catch (bright arc on upper-left rim)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 0.25),
      -pi * 0.85,
      pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x22FFFFFF),
    );

    // Accent ring on rim when playing
    if (isPlaying) {
      canvas.drawCircle(
        c,
        r - 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppColors.accent.withValues(alpha: 0.35),
      );
    }

    // Label zone (between cover art and grooves)
    final labelInner = r * _coverR;
    final labelOuter = r * _labelR;
    canvas.drawCircle(
      c,
      (labelInner + labelOuter) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = labelOuter - labelInner
        ..color = const Color(0xFF16161F),
    );
    canvas.drawCircle(
      c,
      labelInner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF282838),
    );
    canvas.drawCircle(
      c,
      labelOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF222232),
    );

    // Groove lines
    final grooveZone = r * _grooveR - labelOuter;
    for (var i = 0; i < _grooveCount; i++) {
      final t = i / (_grooveCount - 1);
      final gr = labelOuter + t * grooveZone;
      final isBand = i > 0 && i % 9 == 0;
      final alpha = isBand ? 0.13 : (0.045 + 0.02 * sin(i * 1.3));
      canvas.drawCircle(
        c,
        gr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBand ? 1.0 : 0.45
          ..color = Color.fromRGBO(180, 190, 225, alpha),
      );
    }

    // Iridescent rainbow sweep over grooves
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: c, radius: r * _grooveR))
        ..addOval(Rect.fromCircle(center: c, radius: labelOuter))
        ..fillType = PathFillType.evenOdd,
    );
    canvas.drawCircle(
      c,
      r * _grooveR,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0x054400FF),
            Color(0x0700AAFF),
            Color(0x0500FF88),
            Color(0x07FFAA00),
            Color(0x05FF0066),
            Color(0x054400FF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * _grooveR)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.isPlaying != isPlaying;
}

/// Non-rotating specular highlight and groove shimmer that sits on top
/// of the rotating disc, simulating a fixed light source.
class _SpecularPainter extends CustomPainter {
  final _Frame f;
  _SpecularPainter(this.f) : super(repaint: f);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Clip to disc bounds
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.96)));

    // Broad specular highlight (upper-left)
    final a = 0.045 + 0.02 * f.glow;
    final hl = Offset(c.dx - r * 0.28, c.dy - r * 0.35);
    canvas.drawOval(
      Rect.fromCenter(center: hl, width: r * 1.2, height: r * 0.55),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 255, 255, a),
            Color.fromRGBO(255, 255, 255, a * 0.25),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCenter(
            center: hl, width: r * 1.2, height: r * 0.55)),
    );

    // Tight bright spot
    final sp = Offset(c.dx - r * 0.15, c.dy - r * 0.2);
    canvas.drawCircle(
      sp,
      r * 0.12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 255, 255, a * 0.5),
            const Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: sp, radius: r * 0.12)),
    );
    canvas.restore();

    // Groove shimmer: counter-rotates slowly to simulate light
    // catching different grooves as the disc turns.
    if (f.glow > 0.01) {
      final grooveOuter = r * _VinylPainter._grooveR;
      final grooveInner = r * _VinylPainter._labelR;
      canvas.save();
      canvas.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: c, radius: grooveOuter))
          ..addOval(Rect.fromCircle(center: c, radius: grooveInner))
          ..fillType = PathFillType.evenOdd,
      );
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-f.rotation * 0.5);
      canvas.translate(-c.dx, -c.dy);

      final sA = 0.04 * f.glow;
      canvas.drawCircle(
        c,
        grooveOuter,
        Paint()
          ..shader = SweepGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, sA),
              const Color(0x00FFFFFF),
              Color.fromRGBO(255, 255, 255, sA * 0.5),
              const Color(0x00FFFFFF),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75],
          ).createShader(Rect.fromCircle(center: c, radius: grooveOuter)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SpecularPainter old) => false;
}
