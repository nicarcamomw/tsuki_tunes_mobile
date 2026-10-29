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
    final disc = RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgDeep,
          border: Border.all(
            color: widget.isPlaying ? AppColors.accent : AppColors.border,
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fine grooves, depth and the turning marks: drawn once, then
            // spun along with the disc.
            Positioned.fill(
              child: CustomPaint(
                painter: _DiscSurfacePainter(playing: widget.isPlaying),
              ),
            ),
            ExcludeSemantics(
              child: ClipOval(
                child: SizedBox(
                  width: size * 0.58,
                  height: size * 0.58,
                  child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          memCacheWidth: imageCacheSize(context, size * 0.58),
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _CoverPlaceholder(),
                          errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                        )
                      : const _CoverPlaceholder(iconSize: 40),
                ),
              ),
            ),
            // Center pin
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgDeep,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              alignment: const Alignment(-0.35, -0.35),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
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
              // Glow behind, groove rings and shockwaves on top: both are
              // circles, so they stay out of the rotation and only repaint
              // themselves; the disc with its cover is recorded once.
              Positioned.fill(
                child: CustomPaint(painter: _GlowPainter(_frame, widget.isPlaying)),
              ),
              AnimatedBuilder(
                animation: _frame,
                builder: (_, child) => Transform.scale(
                  scale: 1 + 0.02 * _frame.pulse,
                  child: Transform.rotate(angle: _frame.rotation, child: child),
                ),
                child: disc,
              ),
              // A fixed light catching the grooves: the disc turns under it,
              // like a record under a lamp.
              const Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _SheenPainter()),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _RingsPainter(_frame, widget.isPlaying)),
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

/// The disc's face between the cover and the rim: a touch of depth, fine
/// vinyl grooves, a hairline inside the rim, the cover's label edge and
/// three small tomoe marks that show it turning.
class _DiscSurfacePainter extends CustomPainter {
  final bool playing;
  const _DiscSurfacePainter({required this.playing});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Matches the cover (0.58 of the full disc, which is 2 px wider).
    final cover = (size.width + 4) * 0.29;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.bgDeep,
            Color.lerp(AppColors.bgDeep, AppColors.bgHover, 0.55)!,
            AppColors.bgDeep,
          ],
          stops: const [0.55, 0.86, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final inner = cover + 4;
    final outer = r - 6;
    const count = 22;
    for (var i = 0; i < count; i++) {
      final gr = inner + (outer - inner) * i / (count - 1);
      groove.color =
          Colors.white.withValues(alpha: i.isEven ? 0.035 : 0.02);
      canvas.drawCircle(c, gr, groove);
    }

    // Hairline inside the rim, for a crisp double edge.
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = (playing ? AppColors.accent : AppColors.border)
            .withValues(alpha: playing ? 0.3 : 0.6),
    );

    // The cover's label edge: a soft shadow ring around it.
    canvas.drawCircle(
      c,
      cover + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Three tomoe marks between the cover and the grooves' middle.
    final markR = cover + (outer - cover) * 0.32;
    final mark = Paint()
      ..color = (playing ? AppColors.accent : AppColors.textMuted)
          .withValues(alpha: playing ? 0.55 : 0.35);
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + i * 2 * pi / 3;
      final p = c + Offset(cos(a), sin(a)) * markR;
      canvas.drawCircle(p, 2.4, mark);
      // A short tail trailing the turn.
      final tail = Path()
        ..addArc(Rect.fromCircle(center: c, radius: markR), a - 0.22, 0.2);
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.4
          ..color = mark.color.withValues(alpha: mark.color.a * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_DiscSurfacePainter old) => old.playing != playing;
}

/// Two soft, fixed highlights on the disc's face (not on the cover).
class _SheenPainter extends CustomPainter {
  const _SheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final cover = size.width * 0.29;
    final ring = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..addOval(Rect.fromCircle(center: c, radius: cover + 2))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      ring,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.035),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.08, 0.18, 0.5, 0.58, 0.68, 1.0],
          transform: const GradientRotation(-pi * 0.8),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => false;
}

class _GlowPainter extends CustomPainter {
  final _Frame f;
  final bool playing;
  _GlowPainter(this.f, this.playing) : super(repaint: f);

  @override
  void paint(Canvas canvas, Size size) {
    final a = f.glow * (0.24 + 0.56 * f.pulse);
    if (a <= 0.003) return;
    final c = size.center(Offset.zero);
    final r = size.width / 2;
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
        w * 0.295,
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
