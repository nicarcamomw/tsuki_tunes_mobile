import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../models/artist.dart';
import '../providers/locale_provider.dart';
import '../services/deezer_api_service.dart';
import 'artist_detail_screen.dart';
import 'main_navigation_screen.dart';

// Canvas is far larger than the screen so nodes stay hit-testable anywhere.
const double _kCanvas = 6000;
const Offset _kOrigin = Offset(_kCanvas / 2, _kCanvas / 2);
const double _kMinScale = 0.2;
const double _kMaxScale = 2.5;
const int _kMaxNodes = 80;
const int _kRelatedLimit = 10;
const double _kPanelHeight = 170;

const double _kRepulsion = 9000;
const double _kGravity = 0.0009;
const double _kDamping = 0.82;
const double _kMaxSpeed = 14;

enum _NodeState { idle, loading, expanded, deadEnd }

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

class RabbitHoleScreen extends StatefulWidget {
  final Artist seedArtist;
  const RabbitHoleScreen({super.key, required this.seedArtist});

  @override
  State<RabbitHoleScreen> createState() => _RabbitHoleScreenState();
}

class _RabbitHoleScreenState extends State<RabbitHoleScreen>
    with TickerProviderStateMixin {
  static const String _hintPrefKey = 'rabbit_hole_hint_seen';

  final DeezerApiService _api = DeezerApiService();
  final Random _rng = Random();
  final Map<String, _GraphNode> _nodes = {};
  final List<_GraphEdge> _edges = [];
  final TransformationController _transform = TransformationController();

  late final Ticker _physics;
  late final AnimationController _pulse;
  late final AnimationController _camera;
  Animation<Matrix4>? _cameraAnim;

  String? _seedId;
  String? _focusedId;
  String? _draggingId;
  Size _viewport = Size.zero;
  double _topInset = 0;
  double _bottomInset = 0;
  bool _cameraReady = false;
  bool _seedFailed = false;
  bool _showHint = false;
  bool _maxNotified = false;
  bool _reduceMotion = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _physics = createTicker(_onTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _camera = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
    _physics.dispose();
    _pulse.dispose();
    _camera.dispose();
    _transform.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Graph building
  // ---------------------------------------------------------------------------

  void _seed(Artist artist) {
    _nodes.clear();
    _edges.clear();
    _maxNotified = false;
    _seedFailed = false;
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
    final related = await _api.getRelatedArtists(id, limit: _kRelatedLimit);
    // Bail if the screen closed or the graph was re-seeded meanwhile.
    if (!mounted || !identical(_nodes[id], node)) return;

    final fresh =
        related.where((a) => a.id.isNotEmpty && a.id != id).toList();
    final newcomers = fresh.where((a) => !_nodes.containsKey(a.id)).length;
    final slots = min(newcomers, _kMaxNodes - _nodes.length);

    // Fan children away from where we came from so the web grows outward.
    final parent = node.parentId == null ? null : _nodes[node.parentId!];
    final outward = parent == null
        ? _rng.nextDouble() * 2 * pi
        : (node.position - parent.position).direction;
    const spread = pi * 1.3;

    var added = 0;
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
      added++;
    }

    setState(() {
      node.connections = fresh.length;
      node.state = fresh.isEmpty ? _NodeState.deadEnd : _NodeState.expanded;
      if (node.depth == 0 && fresh.isEmpty) _seedFailed = true;
    });

    if (fresh.isEmpty && node.depth > 0) HapticFeedback.lightImpact();
    if (added < newcomers) _notifyMaxReached();
    _wakePhysics();
  }

  void _retrySeed() {
    final seed = _seedId == null ? null : _nodes[_seedId!];
    if (seed == null) return;
    setState(() {
      _seedFailed = false;
      seed.state = _NodeState.idle;
    });
    _expand(seed.id);
  }

  void _restartFromFocused() {
    final node = _focusedId == null ? null : _nodes[_focusedId!];
    if (node == null || node.depth == 0) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _seed(node.artist);
    setState(() {});
    _flyToPoint(_kOrigin, 1.0);
  }

  void _notifyMaxReached() {
    if (_maxNotified || !mounted) return;
    _maxNotified = true;
    final strings = context.read<LocaleProvider>().strings;
    final focused = _focusedId == null ? null : _nodes[_focusedId!];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, _kPanelHeight + 8),
        backgroundColor: AppColors.bgCard,
        duration: const Duration(seconds: 6),
        content: Text(
          strings.rabbitHoleMaxReached,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
        action: focused != null && focused.depth > 0
            ? SnackBarAction(
                label: strings.rabbitHoleRestartHere,
                textColor: AppColors.neonCyan,
                onPressed: _restartFromFocused,
              )
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Physics
  // ---------------------------------------------------------------------------

  void _wakePhysics() {
    if (!_physics.isActive) _physics.start();
  }

  void _onTick(Duration _) {
    final settled = _step();
    setState(() {});
    if (settled) _physics.stop();
  }

  bool _step() {
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
        final push = delta * (force / dist);
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
      final pull = delta * ((dist - ideal) * k / dist);
      a.velocity += pull;
      b.velocity -= pull;
      if (e.appear < 1) {
        e.appear = min(1.0, e.appear + 0.035);
        animating = true;
      }
    }

    const limit = _kCanvas / 2 - 150;
    var maxSpeed = 0.0;
    for (final n in nodes) {
      if (n.appear < 1) {
        n.appear = min(1.0, n.appear + 0.05);
        animating = true;
      }
      if (n.pinned) {
        n.velocity = Offset.zero;
        continue;
      }
      n.velocity = (n.velocity - n.position * _kGravity) * _kDamping;
      final speed = n.velocity.distance;
      if (speed > _kMaxSpeed) n.velocity = n.velocity * (_kMaxSpeed / speed);
      final next = n.position + n.velocity;
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
    HapticFeedback.selectionClick();
    _dismissHint();
    setState(() {
      _focusedId = node.id;
      if (node.state == _NodeState.deadEnd && node.depth > 0) {
        node.state = _NodeState.idle; // tapping a dead end retries
      }
    });
    _expand(node.id);
    _flyTo(node);
  }

  void _focusOnly(_GraphNode node) {
    HapticFeedback.selectionClick();
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
    HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(artist: node.artist),
      ),
    );
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
    final locale = Provider.of<LocaleProvider>(context);
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
            fontSize: 14,
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
            onPressed: _fitAll,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, size: 20),
            color: AppColors.neonPurple,
            tooltip: strings.rabbitHoleRecenter,
            onPressed: _recenter,
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
                          animate: !_reduceMotion,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final node in ordered)
                              _NodeView(
                                key: ValueKey(node.id),
                                node: node,
                                focused: node.id == _focusedId,
                                onTrail: trailIds.contains(node.id),
                                locale: locale,
                                onActivate: () => _activate(node),
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
              if (_seedFailed)
                Positioned.fill(
                  child: _EmptyState(locale: locale, onRetry: _retrySeed),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomPanel(
                  focused: focused,
                  trail: trail,
                  nodeCount: _nodes.length,
                  locale: locale,
                  onOpen: focused == null ? null : () => _openArtist(focused),
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

class _NodeView extends StatelessWidget {
  final _GraphNode node;
  final bool focused;
  final bool onTrail;
  final LocaleProvider locale;
  final VoidCallback onActivate;

  const _NodeView({
    super.key,
    required this.node,
    required this.focused,
    required this.onTrail,
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

  Widget _placeholder(double r) => Container(
        color: AppColors.bgCard,
        alignment: Alignment.center,
        child: Icon(Icons.person, size: r * 0.8, color: AppColors.textMuted),
      );

  @override
  Widget build(BuildContext context) {
    final r = node.radius;
    final width = max(r * 2, _labelWidth);
    final appear = node.appear.clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(appear);
    final ring = focused
        ? AppColors.neonPurple
        : onTrail
            ? AppColors.accent
            : switch (node.state) {
                _NodeState.expanded => AppColors.neonCyan,
                _NodeState.deadEnd => AppColors.textMuted,
                _ => AppColors.textSecondary,
              };
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget image = node.artist.pictureUrl.isEmpty
        ? _placeholder(r)
        : CachedNetworkImage(
            imageUrl: node.artist.getBestImage(size: 'medium'),
            fit: BoxFit.cover,
            memCacheWidth: (r * 2 * dpr).round(),
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => _placeholder(r),
            errorWidget: (_, __, ___) => _placeholder(r),
          );
    if (node.state == _NodeState.deadEnd) {
      image = ColorFiltered(colorFilter: _greyscale, child: image);
    }

    final labelAlpha = focused ? 1.0 : (1.0 - node.depth * 0.08).clamp(0.55, 1.0);

    return Positioned(
      left: _kOrigin.dx + node.position.dx - width / 2,
      top: _kOrigin.dy + node.position.dy - r,
      width: width,
      child: Semantics(
        button: true,
        selected: focused,
        label: node.artist.name,
        onTap: onActivate,
        child: Opacity(
          opacity: appear,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: pop,
                child: SizedBox.square(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(3),
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
      ),
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
    required this.animate,
  }) : super(repaint: pulse);

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
      duration: const Duration(milliseconds: 400),
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, -8 * (1 - v)), child: child),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.35)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 10.5,
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
  final VoidCallback onRetry;
  const _EmptyState({required this.locale, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Container(
      color: AppColors.bgDeep.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 36,
              color: AppColors.neonPurple.withValues(alpha: 0.8)),
          const SizedBox(height: 14),
          Text(
            strings.rabbitHoleEmpty,
            style: locale.getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.rabbitHoleEmptySubtitle,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(strings.retry),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.neonCyan,
              side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panel
// ---------------------------------------------------------------------------

class _BottomPanel extends StatelessWidget {
  final _GraphNode? focused;
  final List<_GraphNode> trail;
  final int nodeCount;
  final LocaleProvider locale;
  final VoidCallback? onOpen;
  final VoidCallback onRestart;
  final ValueChanged<_GraphNode> onTrailTap;

  const _BottomPanel({
    required this.focused,
    required this.trail,
    required this.nodeCount,
    required this.locale,
    required this.onOpen,
    required this.onRestart,
    required this.onTrailTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final node = focused;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 28, 16, 12 + bottom),
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
              duration: const Duration(milliseconds: 220),
              child: _FocusCard(
                key: ValueKey(node.id),
                node: node,
                locale: locale,
                onOpen: onOpen,
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
                      borderRadius: BorderRadius.circular(3),
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
                        fontSize: 9.5,
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
  final LocaleProvider locale;
  final VoidCallback? onOpen;
  final VoidCallback onRestart;

  const _FocusCard({
    super.key,
    required this.node,
    required this.locale,
    required this.onOpen,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final (status, statusColor) = switch (node.state) {
      _NodeState.loading => (strings.rabbitHoleLoading, AppColors.neonPurple),
      _NodeState.expanded =>
        (strings.rabbitHoleConnections(node.connections), AppColors.neonCyan),
      _NodeState.deadEnd => (strings.rabbitHoleDeadEnd, AppColors.textMuted),
      _NodeState.idle => (strings.rabbitHoleTapToExpand, AppColors.neonPurple),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: node.artist.pictureUrl.isEmpty
                ? Container(
                    width: 44,
                    height: 44,
                    color: AppColors.bgMid,
                    child: const Icon(Icons.person, color: AppColors.textMuted),
                  )
                : CachedNetworkImage(
                    imageUrl: node.artist.getBestImage(size: 'medium'),
                    width: 44,
                    height: 44,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (node.depth > 0)
            IconButton(
              tooltip: strings.rabbitHoleRestartHere,
              icon: const Icon(Icons.filter_center_focus, size: 20),
              color: AppColors.neonCyan,
              onPressed: onRestart,
            ),
          const SizedBox(width: 2),
          Material(
            color: AppColors.neonPurple.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onOpen,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.rabbitHoleOpenArtist,
                      style: locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward,
                        size: 12, color: AppColors.neonPurple),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
