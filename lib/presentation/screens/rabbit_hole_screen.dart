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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
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

/// Places each node centred on its position, scaled by how far it has
/// appeared. Runs at paint time, so physics steps never rebuild nodes.
class _NodeFlowDelegate extends FlowDelegate {
  final List<_GraphNode> nodes;

  _NodeFlowDelegate({required this.nodes, required Listenable frame})
      : super(repaint: frame);

  @override
  Size getSize(BoxConstraints constraints) => const Size(_kCanvas, _kCanvas);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  void paintChildren(FlowPaintingContext context) {
    final count = min(context.childCount, nodes.length);
    for (var i = 0; i < count; i++) {
      final node = nodes[i];
      final appear = node.appear.clamp(0.0, 1.0);
      if (appear < 0.01) continue;
      final width = context.getChildSize(i)!.width;
      final pop = Curves.easeOutBack.transform(appear);
      // Scale around the circle's centre, which sits one radius below the top.
      final transform = Matrix4.translationValues(
        _kOrigin.dx + node.position.dx,
        _kOrigin.dy + node.position.dy,
        0,
      )
        ..multiply(Matrix4.diagonal3Values(pop, pop, 1))
        ..multiply(Matrix4.translationValues(-width / 2, -node.radius, 0));
      // Scale only: an opacity here would push every appearing node
      // through its own offscreen layer each frame, the costliest part of
      // a burst of a dozen pop-ins.
      context.paintChild(i, transform: transform);
    }
  }

  @override
  bool shouldRepaint(covariant _NodeFlowDelegate old) =>
      !identical(old.nodes, nodes);
}

class _NodeView extends StatelessWidget {
  final _GraphNode node;
  final bool focused;
  final bool onTrail;
  final bool known;
  final LocaleProvider locale;
  final VoidCallback onActivate;

  const _NodeView({
    required this.node,
    required this.focused,
    required this.onTrail,
    required this.known,
    required this.locale,
    required this.onActivate,
  });

  static const double _labelWidth = 104;
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.7, 0,
  ]);

  static int _photoWidth(double r, double dpr) => (r * 2 * dpr).round();

  /// The provider [build]'s image resolves to (same URL and decode size),
  /// so precaching it means the photo is ready the moment the node shows.
  static ImageProvider imageProvider(Artist artist, double r, double dpr) =>
      ResizeImage.resizeIfNeeded(
        _photoWidth(r, dpr),
        null,
        CachedNetworkImageProvider(artist.getBestImage(size: 'medium')),
      );

  Widget _placeholder(double r) => Container(
        color: AppColors.bgCard,
        alignment: Alignment.center,
        child: Icon(Icons.person, size: r * 0.8, color: AppColors.textMuted),
      );

  @override
  Widget build(BuildContext context) {
    final r = node.radius;
    final width = max(r * 2, _labelWidth);
    final ring = focused
        ? AppColors.neonPurple
        : onTrail
            ? AppColors.accent
            : switch (node.state) {
                _NodeState.expanded => AppColors.neonCyan,
                _NodeState.deadEnd => AppColors.textMuted,
                _NodeState.error => AppColors.warning,
                _ => AppColors.textSecondary,
              };
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget image = node.artist.pictureUrl.isEmpty
        ? _placeholder(r)
        : CachedNetworkImage(
            imageUrl: node.artist.getBestImage(size: 'medium'),
            fit: BoxFit.cover,
            memCacheWidth: _photoWidth(r, dpr),
            fadeInDuration: AppMotion.fast,
            placeholder: (_, __) => _placeholder(r),
            errorWidget: (_, __, ___) => _placeholder(r),
          );
    if (node.state == _NodeState.deadEnd) {
      image = ColorFiltered(colorFilter: _greyscale, child: image);
    }

    final labelAlpha = focused ? 1.0 : (1.0 - node.depth * 0.08).clamp(0.55, 1.0);

    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        selected: focused,
        label: node.artist.name,
        onTap: onActivate,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: r * 2,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgCard,
                      border: Border.all(
                        color: ring.withValues(alpha: focused ? 1 : 0.75),
                        width: focused ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        if (focused || onTrail)
                          BoxShadow(
                            color: ring.withValues(alpha: 0.45),
                            blurRadius: focused ? 18 : 10,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(focused ? 3 : 2.5),
                      child: ClipOval(child: image),
                    ),
                  ),
                  if (node.state == _NodeState.loading)
                    const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neonPurple,
                    ),
                  if (node.state == _NodeState.idle)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgDeep,
                          border: Border.all(color: ring, width: 1),
                        ),
                        child: Icon(Icons.add, size: 11, color: ring),
                      ),
                    ),
                  if (node.state == _NodeState.error)
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: _Badge(
                        icon: Icons.wifi_off,
                        color: AppColors.warning,
                      ),
                    ),
                  if (known)
                    const Positioned(
                      left: -2,
                      top: -2,
                      child: _Badge(
                        icon: Icons.headphones,
                        color: AppColors.neonGreen,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                node.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: (focused || node.depth == 0) ? 11 : 9.5,
                  fontWeight: focused ? FontWeight.w800 : FontWeight.w600,
                  color: (focused ? AppColors.textBright : AppColors.textPrimary)
                      .withValues(alpha: labelAlpha),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgDeep,
        border: Border.all(color: color, width: 1),
      ),
      child: Icon(icon, size: 10, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _WebPainter extends CustomPainter {
  final Map<String, _GraphNode> nodes;
  final List<_GraphEdge> edges;
  final String? focusedId;
  final Set<String> trailIds;
  final Animation<double> pulse;
  final bool animate;

  _WebPainter({
    required this.nodes,
    required this.edges,
    required this.focusedId,
    required this.trailIds,
    required this.pulse,
    required Listenable frame,
    required this.animate,
  }) : super(repaint: Listenable.merge([pulse, frame]));

  bool _onTrail(_GraphEdge e) =>
      e.isTree && trailIds.contains(e.a) && trailIds.contains(e.b);

  @override
  void paint(Canvas canvas, Size size) {
    final t = pulse.value;

    for (final e in edges) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      if (a == null || b == null) continue;
      final vis = e.appear * min(a.appear, b.appear);
      if (vis <= 0.01) continue;

      final p1 = _kOrigin + a.position;
      // Edges grow out of the parent as they appear.
      final p2 = Offset.lerp(
        p1,
        _kOrigin + b.position,
        Curves.easeOut.transform(e.appear),
      )!;

      if (_onTrail(e)) {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.35 * vis)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.9 * vis)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      } else if (focusedId != null && e.touches(focusedId!)) {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..shader = ui.Gradient.linear(p1, p2, [
              AppColors.neonPurple.withValues(alpha: 0.75 * vis),
              AppColors.neonCyan.withValues(alpha: 0.35 * vis),
            ])
            ..strokeWidth = 1.4,
        );
      } else {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = (e.isTree ? AppColors.neonCyan : AppColors.neonPurple)
                .withValues(alpha: (e.isTree ? 0.2 : 0.12) * vis)
            ..strokeWidth = e.isTree ? 0.9 : 0.6,
        );
      }
    }

    if (animate) _paintFlow(canvas, t);

    final focus = focusedId == null ? null : nodes[focusedId!];
    if (focus != null && focus.appear >= 1) {
      final ringT = animate ? t : 0.0;
      canvas.drawCircle(
        _kOrigin + focus.position,
        focus.radius + 6 + 14 * ringT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.neonPurple
              .withValues(alpha: animate ? 0.55 * (1 - ringT) : 0.4),
      );
    }
  }

  // Data packets: down the trail (seed -> focus) and outward from the focus.
  void _paintFlow(Canvas canvas, double t) {
    final dot = Paint();
    var k = 0;
    for (final e in edges) {
      if (e.appear < 1) continue;
      final a = nodes[e.a];
      final b = nodes[e.b];
      if (a == null || b == null) continue;
      final trail = _onTrail(e);
      final touchesFocus = focusedId != null && e.touches(focusedId!);
      if (!trail && !touchesFocus) continue;

      final fromA = trail || e.a == focusedId;
      final from = fromA ? a.position : b.position;
      final to = fromA ? b.position : a.position;
      final phase = (t + k * 0.137) % 1.0;
      k++;
      dot.color = (trail ? AppColors.accent : AppColors.neonCyan)
          .withValues(alpha: 0.9 * sin(phase * pi));
      canvas.drawCircle(
        _kOrigin + Offset.lerp(from, to, phase)!,
        trail ? 2.6 : 2.0,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WebPainter old) => true;
}

/// Screen-space grid that follows the camera, so it stays crisp at any zoom.
class _GridPainter extends CustomPainter {
  final TransformationController transform;
  _GridPainter(this.transform) : super(repaint: transform);

  @override
  void paint(Canvas canvas, Size size) {
    final m = transform.value;
    final s = m.getMaxScaleOnAxis();
    final tr = m.getTranslation();
    final origin = Offset(tr.x + _kOrigin.dx * s, tr.y + _kOrigin.dy * s);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          origin,
          max(size.width, size.height) * 0.9,
          [const Color(0xFF1A1030), AppColors.bgDeep],
        ),
    );

    var spacing = 64 * s;
    while (spacing < 24) {
      spacing *= 2;
    }
    final line = Paint()
      ..color = AppColors.neonPurple.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (var x = origin.dx % spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = origin.dy % spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.neonPurple.withValues(alpha: 0.06);
    for (var k = 1; k <= 8; k++) {
      canvas.drawCircle(origin, 220.0 * k * s, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.transform != transform;
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

class _HintPill extends StatelessWidget {
  final String text;
  final LocaleProvider locale;
  const _HintPill({required this.text, required this.locale});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, -8 * (1 - v)), child: child),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.35)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LocaleProvider locale;
  final bool offline;
  final VoidCallback onRetry;
  const _EmptyState({
    required this.locale,
    required this.offline,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Container(
      color: AppColors.bgDeep.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: EmptyState(
        icon: offline ? Icons.wifi_off : Icons.link_off,
        tone: AppColors.neonPurple,
        title: offline ? strings.rabbitHoleOffline : strings.rabbitHoleEmpty,
        message: offline ? strings.rabbitHoleOfflineSubtitle : strings.rabbitHoleEmptySubtitle,
        actionLabel: strings.retry,
        onAction: onRetry,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panel
// ---------------------------------------------------------------------------

class _BottomPanel extends StatelessWidget {
  final _GraphNode? focused;
  final bool known;
  final List<_GraphNode> trail;
  final int nodeCount;
  final LocaleProvider locale;
  final VoidCallback? onOpen;
  final VoidCallback? onListen;
  final VoidCallback onRestart;
  final ValueChanged<_GraphNode> onTrailTap;

  const _BottomPanel({
    required this.focused,
    required this.known,
    required this.trail,
    required this.nodeCount,
    required this.locale,
    required this.onOpen,
    required this.onListen,
    required this.onRestart,
    required this.onTrailTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final node = focused;

    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, 28, AppSpacing.page, 12 + bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgDeep.withValues(alpha: 0),
            AppColors.bgDeep.withValues(alpha: 0.9),
            AppColors.bgDeep,
          ],
          stops: const [0, 0.25, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trail.length > 1) ...[
            _Breadcrumbs(trail: trail, locale: locale, onTap: onTrailTap),
            const SizedBox(height: 8),
          ],
          if (node != null)
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: _FocusCard(
                key: ValueKey(node.id),
                node: node,
                known: known,
                locale: locale,
                onOpen: onOpen,
                onListen: onListen,
                onRestart: onRestart,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(
                icon: Icons.hub,
                label: strings.rabbitHoleNodes(nodeCount),
                color: AppColors.neonCyan,
                locale: locale,
              ),
              const SizedBox(width: 18),
              _Stat(
                icon: Icons.south,
                label: strings.rabbitHoleDepth(node?.depth ?? 0),
                color: AppColors.accent,
                locale: locale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  final List<_GraphNode> trail;
  final LocaleProvider locale;
  final ValueChanged<_GraphNode> onTap;

  const _Breadcrumbs({
    required this.trail,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // keep the newest step in view
        child: Row(
          children: [
            for (final (i, n) in trail.indexed) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right,
                      size: 14, color: AppColors.textMuted),
                ),
              Semantics(
                button: true,
                label: n.artist.name,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(n),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                        color: (i == trail.length - 1
                                ? AppColors.accent
                                : AppColors.textMuted)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      n.artist.name,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: i == trail.length - 1
                            ? AppColors.textBright
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  final _GraphNode node;
  final bool known;
  final LocaleProvider locale;
  final VoidCallback? onOpen;
  final VoidCallback? onListen;
  final VoidCallback onRestart;

  const _FocusCard({
    super.key,
    required this.node,
    required this.known,
    required this.locale,
    required this.onOpen,
    required this.onListen,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final (state, statusColor) = switch (node.state) {
      _NodeState.loading => (strings.rabbitHoleLoading, AppColors.neonPurple),
      _NodeState.expanded =>
        (strings.rabbitHoleConnections(node.connections), AppColors.neonCyan),
      _NodeState.deadEnd => (strings.rabbitHoleDeadEnd, AppColors.textMuted),
      _NodeState.error => (strings.rabbitHoleNodeError, AppColors.warning),
      _NodeState.idle => (strings.rabbitHoleTapToExpand, AppColors.neonPurple),
    };
    final status = known ? '$state · ${strings.rabbitHoleKnown}' : state;

    // Two tiers: who it is (full name, up to two lines), then what to do.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipOval(
                child: node.artist.pictureUrl.isEmpty
                    ? Container(
                        width: 52,
                        height: 52,
                        color: AppColors.bgMid,
                        child: const Icon(Icons.person, color: AppColors.textMuted),
                      )
                    : CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, 52),
                        imageUrl: node.artist.getBestImage(size: 'medium'),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.artist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.titleLg,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FocusAction(
                  icon: Icons.play_circle_outline,
                  label: strings.rabbitHoleListenShort,
                  tooltip: strings.rabbitHoleListen,
                  color: AppColors.neonGreen,
                  locale: locale,
                  onTap: onListen,
                ),
              ),
              if (node.depth > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _FocusAction(
                    icon: Icons.filter_center_focus,
                    label: strings.rabbitHoleRestartHere,
                    color: AppColors.neonCyan,
                    locale: locale,
                    onTap: onRestart,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _FocusAction(
                  icon: Icons.arrow_forward,
                  label: strings.rabbitHoleOpenArtist,
                  color: AppColors.neonPurple,
                  locale: locale,
                  onTap: onOpen,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One of the focus card's actions: icon and label in a small button.
class _FocusAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color color;
  final LocaleProvider locale;
  final VoidCallback? onTap;
  final bool filled;

  const _FocusAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.locale,
    required this.onTap,
    this.tooltip,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint = enabled ? color : AppColors.textMuted;
    final button = Material(
      color: filled ? tint.withValues(alpha: 0.18) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(color: tint.withValues(alpha: filled ? 0 : 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onTap,
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.micro,
                      fontWeight: FontWeight.w800,
                      color: enabled ? AppColors.textBright : AppColors.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final LocaleProvider locale;

  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.75)),
        const SizedBox(width: 4),
        Text(
          label,
          style: locale.getTextStyle(
            fontSize: AppFontSize.micro,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
