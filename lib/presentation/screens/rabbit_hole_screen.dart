import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/artist.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state.dart';
import '../widgets/haptics.dart';

part 'rabbit_hole/rabbit_hole_widgets.dart';

// Canvas is far larger than the screen so nodes stay hit-testable anywhere.
const double _kCanvas = 6000;
const Offset _kOrigin = Offset(_kCanvas / 2, _kCanvas / 2);
const double _kMinScale = 0.2;
const double _kMaxScale = 2.5;
const int _kMaxNodes = 120;
const int _kRelatedLimit = 12;
// Children whose own connections are fetched ahead, so the next tap is instant.
const int _kPrefetchChildren = 4;
const double _kPanelHeight = 170;

const double _kRepulsion = 9000;
const double _kGravity = 0.0009;
const double _kDamping = 0.82;
const double _kMaxSpeed = 14;

enum _NodeState { idle, loading, expanded, deadEnd, error }

enum _SeedProblem { none, empty, offline }

class _GraphNode {
  final Artist artist;
  final String? parentId;
  final int depth;
  final double radius;
  Offset position;
  Offset velocity = Offset.zero;
  _NodeState state = _NodeState.idle;
  double appear = 0;
  bool pinned = false;
  int connections = 0;

  _GraphNode({
    required this.artist,
    required this.position,
    this.parentId,
    this.depth = 0,
  }) : radius = _radiusFor(artist.fansCount, depth);

  String get id => artist.id;

  static double radiusFor(Artist artist, int depth) => _radiusFor(artist.fansCount, depth);

  static double _radiusFor(int fans, int depth) {
    if (depth == 0) return 40;
    // 1k fans -> 0, 10M fans -> 1
    final popularity = ((log(max(fans, 1000)) / ln10) - 3) / 4;
    final base = 20 + popularity.clamp(0.0, 1.0) * 10;
    return max(16.0, base - (depth - 1) * 2);
  }
}

class _GraphEdge {
  final String a; // parent for tree edges
  final String b;
  final bool isTree;
  double appear = 0;

  _GraphEdge(this.a, this.b, {required this.isTree});

  bool touches(String id) => a == id || b == id;
  bool connects(String x, String y) =>
      (a == x && b == y) || (a == y && b == x);
}

class RabbitHoleScreen extends ConsumerStatefulWidget {
  final Artist seedArtist;
  const RabbitHoleScreen({super.key, required this.seedArtist});

  @override
  ConsumerState<RabbitHoleScreen> createState() => _RabbitHoleScreenState();
}

class _RabbitHoleScreenState extends ConsumerState<RabbitHoleScreen>
    with TickerProviderStateMixin {
  static const String _hintPrefKey = 'rabbit_hole_hint_seen';

  late final _api = ref.read(musicCatalogProvider);
  final Random _rng = Random();
  final Map<String, _GraphNode> _nodes = {};
  final List<_GraphEdge> _edges = [];
  final TransformationController _transform = TransformationController();

  late final Ticker _physics;
  late final AnimationController _pulse;
  late final AnimationController _camera;
  Animation<Matrix4>? _cameraAnim;
  // Bumped every physics step: only the painters and the node layout listen,
  // so moving nodes repaints without rebuilding the screen.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  String? _seedId;
  String? _focusedId;
  String? _draggingId;
  Size _viewport = Size.zero;
  double _topInset = 0;
  double _bottomInset = 0;
  bool _cameraReady = false;
  _SeedProblem _seedProblem = _SeedProblem.none;
  bool _showHint = false;
  bool _maxNotified = false;
  bool _reduceMotion = false;
  bool _startingPlayback = false;
  Timer? _hintTimer;
  // Lowercased names of artists the user has listened to.
  Set<String> _knownArtists = const {};
  // Completes once the page has finished sliding in: new nodes wait for it
  // so their pop-in doesn't fight the route transition for frames.
  final Completer<void> _routeSettled = Completer<void>();
  bool _routeHooked = false;
  Duration? _lastTick;
  Timer? _prefetchTimer;

  @override
  void initState() {
    super.initState();
    _knownArtists = {
      for (final e
          in ref.read(libraryProvider).getTopArtists(limit: 1 << 20))
        if (e.savedCount > 0) e.name.toLowerCase(),
    };
    _physics = createTicker(_onTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _camera = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..addListener(() {
        final anim = _cameraAnim;
        if (anim != null) _transform.value = anim.value;
      });
    _seed(widget.seedArtist);
    _loadHint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeHooked) {
      _routeHooked = true;
      final anim = ModalRoute.of(context)?.animation;
      if (anim == null || anim.isCompleted) {
        _routeSettled.complete();
      } else {
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
            anim.removeStatusListener(onStatus);
            if (!_routeSettled.isCompleted) _routeSettled.complete();
          }
        }

        anim.addStatusListener(onStatus);
      }
    }
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _prefetchTimer?.cancel();
    _physics.dispose();
    _pulse.dispose();
    _camera.dispose();
    _transform.dispose();
    _frame.dispose();
    super.dispose();
  }

  bool _isKnown(Artist artist) =>
      _knownArtists.contains(artist.name.toLowerCase());

  // ---------------------------------------------------------------------------
  // Graph building
  // ---------------------------------------------------------------------------

  void _seed(Artist artist) {
    _nodes.clear();
    _edges.clear();
    _maxNotified = false;
    _seedProblem = _SeedProblem.none;
    final node = _GraphNode(artist: artist, position: Offset.zero)
      ..appear = 1;
    _nodes[artist.id] = node;
    _seedId = artist.id;
    _focusedId = artist.id;
    _expand(artist.id);
  }

  Future<void> _expand(String id) async {
    final node = _nodes[id];
    if (node == null || node.state != _NodeState.idle) return;
    if (_nodes.length >= _kMaxNodes) {
      _notifyMaxReached();
      return;
    }

    setState(() => node.state = _NodeState.loading);
    List<Artist> related;
    try {
      related = await _api.getRelatedArtists(
        id,
        limit: _kRelatedLimit,
        throwOnError: true,
      );
    } catch (_) {
      // A network failure is not a dead end: keep the node retryable.
      if (!mounted || !identical(_nodes[id], node)) return;
      setState(() {
        node.state = _NodeState.error;
        if (node.depth == 0) _seedProblem = _SeedProblem.offline;
      });
      Haptics.error();
      return;
    }
    // Bail if the screen closed or the graph was re-seeded meanwhile.
    if (!mounted || !identical(_nodes[id], node)) return;

    final fresh =
        related.where((a) => a.id.isNotEmpty && a.id != id).toList();

    // Fetch and decode the newcomers' photos before they pop in (briefly, so
    // a slow image never holds the web back), and let the page finish
    // sliding in: both would otherwise land mid-animation and drop frames.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final photos = [
      for (final a in fresh.take(_kMaxNodes - _nodes.length))
        if (!_nodes.containsKey(a.id) && a.pictureUrl.isNotEmpty)
          precacheImage(
            _NodeView.imageProvider(a, _GraphNode.radiusFor(a, node.depth + 1), dpr),
            context,
          ),
    ];
    await Future.wait([
      _routeSettled.future,
      Future.wait(photos).timeout(const Duration(milliseconds: 450), onTimeout: () => const []),
    ]);
    if (!mounted || !identical(_nodes[id], node)) return;
    final newcomers = fresh.where((a) => !_nodes.containsKey(a.id)).length;
    final slots = min(newcomers, _kMaxNodes - _nodes.length);

    // Fan children away from where we came from so the web grows outward.
    final parent = node.parentId == null ? null : _nodes[node.parentId!];
    final outward = parent == null
        ? _rng.nextDouble() * 2 * pi
        : (node.position - parent.position).direction;
    const spread = pi * 1.3;

    var added = 0;
    final newIds = <String>[];
    for (final artist in fresh) {
      if (_nodes.containsKey(artist.id)) {
        if (!_edges.any((e) => e.connects(id, artist.id))) {
          _edges.add(_GraphEdge(id, artist.id, isTree: false));
        }
        continue;
      }
      if (added >= slots) continue;

      final angle = parent == null
          ? outward + 2 * pi * added / max(slots, 1)
          : outward -
              spread / 2 +
              spread * (slots <= 1 ? 0.5 : added / (slots - 1));
      final dist = 110 + _rng.nextDouble() * 30;
      _nodes[artist.id] = _GraphNode(
        artist: artist,
        parentId: id,
        depth: node.depth + 1,
        position: node.position + Offset.fromDirection(angle, dist),
      );
      _edges.add(_GraphEdge(id, artist.id, isTree: true));
      newIds.add(artist.id);
      added++;
    }

    setState(() {
      node.connections = fresh.length;
      node.state = fresh.isEmpty ? _NodeState.deadEnd : _NodeState.expanded;
      if (node.depth == 0 && fresh.isEmpty) _seedProblem = _SeedProblem.empty;
    });

    if (fresh.isEmpty && node.depth > 0) Haptics.error();
    if (added < newcomers) _notifyMaxReached();
    _wakePhysics();
    // Warm the next level once the pop-in is over, not during it.
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(_api.prefetchRelatedArtists(newIds.take(_kPrefetchChildren)));
    });
  }

  void _retrySeed() {
    final seed = _seedId == null ? null : _nodes[_seedId!];
    if (seed == null) return;
    setState(() {
      _seedProblem = _SeedProblem.none;
      seed.state = _NodeState.idle;
    });
    _expand(seed.id);
  }

  Future<void> _listen(_GraphNode node) async {
    if (_startingPlayback) return;
    Haptics.tap();
    final messenger = AppSnack.of(context, bottom: _kPanelHeight + 8);
    final strings = ref.read(stringsProvider);
    setState(() => _startingPlayback = true);
    try {
      final tracks = await _api.getArtistTopTracks(node.id);
      if (tracks.isEmpty) {
        messenger.info(strings.noTracksFound);
        return;
      }
      await ref.read(playTracksProvider)(tracks);
    } finally {
      if (mounted) setState(() => _startingPlayback = false);
    }
  }

  void _restartFromFocused() {
    final node = _focusedId == null ? null : _nodes[_focusedId!];
    if (node == null || node.depth == 0) return;
    Haptics.confirm();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _seed(node.artist);
    setState(() {});
    _flyToPoint(_kOrigin, 1.0);
  }

  void _notifyMaxReached() {
    if (_maxNotified || !mounted) return;
    _maxNotified = true;
    final strings = ref.read(stringsProvider);
    final focused = _focusedId == null ? null : _nodes[_focusedId!];
    AppSnack.of(context, bottom: _kPanelHeight + 8).info(
      strings.rabbitHoleMaxReached,
      duration: const Duration(seconds: 6),
      actionLabel: focused != null && focused.depth > 0 ? strings.rabbitHoleRestartHere : null,
      onAction: _restartFromFocused,
    );
  }

  // ---------------------------------------------------------------------------
  // Physics
  // ---------------------------------------------------------------------------

  void _wakePhysics() {
    if (!_physics.isActive) {
      _lastTick = null;
      _physics.start();
    }
  }

  void _onTick(Duration elapsed) {
    // Steps are tuned for 60 fps; scale by the real frame time so motion
    // keeps its speed on 90/120 Hz screens and after a dropped frame
    // (capped, so a long hitch slows the web instead of flinging it).
    final last = _lastTick;
    _lastTick = elapsed;
    final f = last == null
        ? 1.0
        : ((elapsed - last).inMicroseconds / 16667).clamp(0.25, 2.0);
    final settled = _step(f);
    _frame.value++;
    if (settled) _physics.stop();
  }

  bool _step(double f) {
    final nodes = _nodes.values.toList(growable: false);

    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        var delta = a.position - b.position;
        var dist = delta.distance;
        if (dist < 0.5) {
          delta = Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5);
          dist = max(delta.distance, 0.01);
        }
        if (dist > 1200) continue;
        var force = _kRepulsion / (dist * dist);
        // Hard-ish collision so circles and labels never overlap.
        final gap = a.radius + b.radius + 34;
        if (dist < gap) force += (gap - dist) * 0.2;
        final push = delta * (force * f / dist);
        a.velocity += push;
        b.velocity -= push;
      }
    }

    var animating = false;
    for (final e in _edges) {
      final a = _nodes[e.a];
      final b = _nodes[e.b];
      if (a == null || b == null) continue;
      final delta = b.position - a.position;
      final dist = max(delta.distance, 0.01);
      final ideal = (a.radius + b.radius + 70) * (e.isTree ? 1.0 : 1.8);
      final k = e.isTree ? 0.025 : 0.004;
      final pull = delta * ((dist - ideal) * k * f / dist);
      a.velocity += pull;
      b.velocity -= pull;
      if (e.appear < 1) {
        e.appear = min(1.0, e.appear + 0.035 * f);
        animating = true;
      }
    }

    const limit = _kCanvas / 2 - 150;
    var maxSpeed = 0.0;
    final damping = pow(_kDamping, f).toDouble();
    for (final n in nodes) {
      if (n.appear < 1) {
        n.appear = min(1.0, n.appear + 0.05 * f);
        animating = true;
      }
      if (n.pinned) {
        n.velocity = Offset.zero;
        continue;
      }
      n.velocity = (n.velocity - n.position * (_kGravity * f)) * damping;
      final speed = n.velocity.distance;
      if (speed > _kMaxSpeed) n.velocity = n.velocity * (_kMaxSpeed / speed);
      final next = n.position + n.velocity * f;
      n.position = Offset(
        next.dx.clamp(-limit, limit),
        next.dy.clamp(-limit, limit),
      );
      maxSpeed = max(maxSpeed, n.velocity.distance);
    }

    return !animating && maxSpeed < 0.06 && _draggingId == null;
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  _GraphNode? _nodeAt(Offset canvasPos) {
    final p = canvasPos - _kOrigin;
    final scale = _transform.value.getMaxScaleOnAxis();
    _GraphNode? hit;
    var best = double.infinity;
    for (final n in _nodes.values) {
      final d = (n.position - p).distance;
      // Keep a ~52px on-screen touch target even when zoomed far out.
      final reach = max(n.radius + 8, 26 / scale);
      if (d <= reach && d < best) {
        best = d;
        hit = n;
      }
    }
    return hit;
  }

  void _activate(_GraphNode node) {
    Haptics.selection();
    _dismissHint();
    setState(() {
      _focusedId = node.id;
      // Tapping a dead end or a failed node retries.
      if ((node.state == _NodeState.deadEnd && node.depth > 0) ||
          node.state == _NodeState.error) {
        node.state = _NodeState.idle;
        if (node.depth == 0) _seedProblem = _SeedProblem.none;
      }
    });
    _expand(node.id);
    _flyTo(node);
  }

  void _focusOnly(_GraphNode node) {
    Haptics.selection();
    setState(() => _focusedId = node.id);
    _flyTo(node);
  }

  void _onTapUp(TapUpDetails details) {
    final node = _nodeAt(details.localPosition);
    if (node != null) _activate(node);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final node = _nodeAt(details.localPosition);
    if (node == null) return;
    Haptics.longPress();
    _camera.stop();
    _dismissHint();
    setState(() {
      _draggingId = node.id;
      _focusedId = node.id;
      node.pinned = true;
    });
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    final node = _draggingId == null ? null : _nodes[_draggingId!];
    if (node == null) return;
    node.position = details.localPosition - _kOrigin;
    node.velocity = Offset.zero;
    _wakePhysics();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    final node = _draggingId == null ? null : _nodes[_draggingId!];
    node?.pinned = false;
    _draggingId = null;
    _wakePhysics();
  }

  void _openArtist(_GraphNode node) {
    Haptics.tap();
    ArtistRoute(id: node.artist.id, $extra: node.artist).push(context);
  }

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  Matrix4 _matrixFor(Offset canvasPoint, double scale) {
    final center = Offset(
      _viewport.width / 2,
      (_topInset + _viewport.height - _bottomInset) / 2,
    );
    return Matrix4.translationValues(
      center.dx - canvasPoint.dx * scale,
      center.dy - canvasPoint.dy * scale,
      0,
    )..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  void _flyTo(_GraphNode node, {double? scale}) {
    _flyToPoint(
      _kOrigin + node.position,
      scale ?? _transform.value.getMaxScaleOnAxis(),
    );
  }

  void _flyToPoint(Offset canvasPoint, double scale) {
    if (_viewport == Size.zero) return;
    final target = _matrixFor(canvasPoint, scale.clamp(_kMinScale, _kMaxScale));
    if (_reduceMotion) {
      _transform.value = target;
      return;
    }
    _cameraAnim = Matrix4Tween(begin: _transform.value.clone(), end: target)
        .animate(CurvedAnimation(parent: _camera, curve: Curves.easeOutCubic));
    _camera
      ..reset()
      ..forward();
  }

  void _recenter() {
    final node = _focusedId == null ? null : _nodes[_focusedId!];
    if (node != null) _flyTo(node, scale: 1.0);
  }

  void _fitAll() {
    if (_nodes.isEmpty || _viewport == Size.zero) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final n in _nodes.values) {
      minX = min(minX, n.position.dx - max(n.radius, 52));
      maxX = max(maxX, n.position.dx + max(n.radius, 52));
      minY = min(minY, n.position.dy - n.radius);
      maxY = max(maxY, n.position.dy + n.radius + 24);
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(24);
    final availH = _viewport.height - _topInset - _bottomInset;
    final scale = min(_viewport.width / bounds.width, availH / bounds.height)
        .clamp(_kMinScale, 1.2);
    _flyToPoint(_kOrigin + bounds.center, scale);
  }

  // ---------------------------------------------------------------------------
  // First-run hint
  // ---------------------------------------------------------------------------

  Future<void> _loadHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_hintPrefKey) ?? false) return;
      if (!mounted) return;
      setState(() => _showHint = true);
      _hintTimer = Timer(const Duration(seconds: 8), _dismissHint);
    } catch (_) {
      // Hint is a nicety; ignore storage failures.
    }
  }

  void _dismissHint() {
    if (!_showHint) return;
    _hintTimer?.cancel();
    if (mounted) setState(() => _showHint = false);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_hintPrefKey, true))
        .catchError((_) => false);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  List<_GraphNode> _trail() {
    final out = <_GraphNode>[];
    var node = _focusedId == null ? null : _nodes[_focusedId!];
    while (node != null) {
      out.add(node);
      node = node.parentId == null ? null : _nodes[node.parentId!];
    }
    return out.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final media = MediaQuery.of(context);
    _topInset = media.padding.top + kToolbarHeight;
    _bottomInset = _kPanelHeight + media.padding.bottom;

    final focused = _focusedId == null ? null : _nodes[_focusedId!];
    final trail = _trail();
    final trailIds = trail.map((n) => n.id).toSet();

    int z(_GraphNode n) =>
        n.id == _focusedId ? 2 : (trailIds.contains(n.id) ? 1 : 0);
    final ordered = _nodes.values.toList()
      ..sort((a, b) => z(a).compareTo(z(b)));

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          color: AppColors.textBright,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          strings.rabbitHoleTitle,
          style: locale.getTextStyle(
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, size: 20),
            color: AppColors.neonCyan,
            tooltip: strings.rabbitHoleFitAll,
            onPressed: () { Haptics.tap(); _fitAll(); },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, size: 20),
            color: AppColors.neonPurple,
            tooltip: strings.rabbitHoleRecenter,
            onPressed: () { Haptics.tap(); _recenter(); },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          if (!_cameraReady) {
            _cameraReady = true;
            _transform.value = _matrixFor(_kOrigin, 1.0);
          }

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _GridPainter(_transform)),
                ),
              ),
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(_kCanvas / 2),
                  minScale: _kMinScale,
                  maxScale: _kMaxScale,
                  onInteractionStart: (_) {
                    _camera.stop();
                    _dismissHint();
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    onLongPressStart: _onLongPressStart,
                    onLongPressMoveUpdate: _onLongPressMove,
                    onLongPressEnd: _onLongPressEnd,
                    child: SizedBox(
                      width: _kCanvas,
                      height: _kCanvas,
                      child: CustomPaint(
                        painter: _WebPainter(
                          nodes: _nodes,
                          edges: _edges,
                          focusedId: _focusedId,
                          trailIds: trailIds,
                          pulse: _pulse,
                          frame: _frame,
                          animate: !_reduceMotion,
                        ),
                        child: Flow(
                          delegate: _NodeFlowDelegate(
                            nodes: ordered,
                            frame: _frame,
                          ),
                          children: [
                            for (final node in ordered)
                              RepaintBoundary(
                                key: ValueKey(node.id),
                                child: _NodeView(
                                  node: node,
                                  focused: node.id == _focusedId,
                                  onTrail: trailIds.contains(node.id),
                                  known: _isKnown(node.artist),
                                  locale: locale,
                                  onActivate: () => _activate(node),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showHint)
                Positioned(
                  top: _topInset + 8,
                  left: 16,
                  right: 16,
                  child: _HintPill(text: strings.rabbitHoleHint, locale: locale),
                ),
              if (_seedProblem != _SeedProblem.none)
                Positioned.fill(
                  child: _EmptyState(
                    locale: locale,
                    offline: _seedProblem == _SeedProblem.offline,
                    onRetry: _retrySeed,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomPanel(
                  focused: focused,
                  known: focused != null && _isKnown(focused.artist),
                  trail: trail,
                  nodeCount: _nodes.length,
                  locale: locale,
                  onOpen: focused == null ? null : () => _openArtist(focused),
                  onListen: focused == null || _startingPlayback
                      ? null
                      : () => _listen(focused),
                  onRestart: _restartFromFocused,
                  onTrailTap: _focusOnly,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node
// ---------------------------------------------------------------------------
