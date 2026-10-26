import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/artist.dart';
import '../providers/locale_provider.dart';
import '../services/deezer_api_service.dart';
import 'artist_detail_screen.dart';
import 'main_navigation_screen.dart';

// ---------------------------------------------------------------------------
// Graph data structures
// ---------------------------------------------------------------------------

class _GraphNode {
  final String artistId;
  final String name;
  final String imageUrl;
  final int fans;
  Offset position;
  Offset velocity;
  double radius;
  int depth;
  bool expanded;
  bool loading;
  double opacity;
  double scale;

  _GraphNode({
    required this.artistId,
    required this.name,
    required this.imageUrl,
    this.fans = 0,
    required this.position,
    this.depth = 0,
    this.expanded = false,
    this.loading = false,
    double? radius,
  })  : velocity = Offset.zero,
        opacity = 0.0,
        scale = 0.0,
        radius = radius ?? _radiusForFans(fans, depth);

  static double _radiusForFans(int fans, int depth) {
    final base = 24.0 + (log(max(fans, 1000)) / log(10)) * 4;
    final depthScale = 1.0 - depth * 0.12;
    return (base * depthScale).clamp(18.0, 42.0);
  }
}

class _GraphEdge {
  final String fromId;
  final String toId;
  double opacity;

  _GraphEdge({required this.fromId, required this.toId}) : opacity = 0.0;
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class RabbitHoleScreen extends StatefulWidget {
  final Artist seedArtist;
  const RabbitHoleScreen({super.key, required this.seedArtist});

  @override
  State<RabbitHoleScreen> createState() => _RabbitHoleScreenState();
}

class _RabbitHoleScreenState extends State<RabbitHoleScreen>
    with TickerProviderStateMixin {
  final DeezerApiService _api = DeezerApiService();
  final Map<String, _GraphNode> _nodes = {};
  final List<_GraphEdge> _edges = [];
  final Set<String> _expandedIds = {};
  final Random _rng = Random();

  late final AnimationController _physicsController;
  final TransformationController _transformController =
      TransformationController();

  String? _focusedNodeId;
  bool _initialLoad = true;
  int _totalExpansions = 0;
  static const int _maxNodes = 80;
  static const int _relatedLimit = 10;

  @override
  void initState() {
    super.initState();
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_tickPhysics);

    _addSeedNode();
  }

  @override
  void dispose() {
    _physicsController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Graph building
  // ---------------------------------------------------------------------------

  void _addSeedNode() {
    final a = widget.seedArtist;
    final node = _GraphNode(
      artistId: a.id,
      name: a.name,
      imageUrl: a.getBestImage(size: 'medium'),
      fans: a.fansCount,
      position: Offset.zero,
      depth: 0,
      radius: 42,
    );
    _nodes[a.id] = node;
    _focusedNodeId = a.id;
    _expandNode(a.id);
  }

  Future<void> _expandNode(String artistId) async {
    if (_expandedIds.contains(artistId)) return;
    if (_nodes.length >= _maxNodes) return;

    final node = _nodes[artistId];
    if (node == null) return;

    setState(() {
      node.loading = true;
      _expandedIds.add(artistId);
    });

    try {
      final related = await _api.getRelatedArtists(artistId, limit: _relatedLimit);
      if (!mounted) return;

      final parentPos = node.position;
      final existingCount = _edges.where(
        (e) => e.fromId == artistId || e.toId == artistId,
      ).length;
      final startAngle = _rng.nextDouble() * 2 * pi;
      int added = 0;

      for (var i = 0; i < related.length && _nodes.length < _maxNodes; i++) {
        final r = related[i];
        if (_nodes.containsKey(r.id)) {
          if (!_edges.any((e) =>
              (e.fromId == artistId && e.toId == r.id) ||
              (e.fromId == r.id && e.toId == artistId))) {
            _edges.add(_GraphEdge(fromId: artistId, toId: r.id));
          }
          continue;
        }

        final angle = startAngle +
            (2 * pi / min(related.length, _relatedLimit)) *
                (added + existingCount);
        final dist = 120.0 + node.depth * 30 + _rng.nextDouble() * 40;
        final pos = parentPos + Offset(cos(angle) * dist, sin(angle) * dist);

        _nodes[r.id] = _GraphNode(
          artistId: r.id,
          name: r.name,
          imageUrl: r.getBestImage(size: 'medium'),
          fans: r.fansCount,
          position: pos,
          depth: node.depth + 1,
        );
        _edges.add(_GraphEdge(fromId: artistId, toId: r.id));
        added++;
      }

      setState(() {
        node.expanded = true;
        node.loading = false;
        _totalExpansions++;
        if (_initialLoad) _initialLoad = false;
      });

      if (!_physicsController.isAnimating) {
        _physicsController.repeat();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          node.loading = false;
          _expandedIds.remove(artistId);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Physics simulation
  // ---------------------------------------------------------------------------

  void _tickPhysics() {
    if (_nodes.length < 2) return;

    const double repulsionStrength = 8000;
    const double attractionStrength = 0.008;
    const double idealEdgeLength = 140;
    const double damping = 0.85;
    const double centerGravity = 0.003;
    const double maxSpeed = 8.0;

    final nodeList = _nodes.values.toList();

    // Repulsion between all pairs
    for (var i = 0; i < nodeList.length; i++) {
      for (var j = i + 1; j < nodeList.length; j++) {
        final a = nodeList[i];
        final b = nodeList[j];
        var delta = a.position - b.position;
        var dist = delta.distance;
        if (dist < 1) {
          delta = Offset(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5);
          dist = 1;
        }
        final force = repulsionStrength / (dist * dist);
        final fd = delta / dist * force;
        a.velocity += fd;
        b.velocity -= fd;
      }
    }

    // Edge spring attraction
    for (final edge in _edges) {
      final a = _nodes[edge.fromId];
      final b = _nodes[edge.toId];
      if (a == null || b == null) continue;
      var delta = b.position - a.position;
      var dist = delta.distance;
      if (dist < 1) dist = 1;
      final displacement = dist - idealEdgeLength;
      final force = displacement * attractionStrength;
      final fd = delta / dist * force;
      a.velocity += fd;
      b.velocity -= fd;
    }

    // Center gravity + apply velocity
    double totalKinetic = 0;
    for (final node in nodeList) {
      node.velocity -= node.position * centerGravity;
      node.velocity *= damping;

      // Clamp speed
      if (node.velocity.distance > maxSpeed) {
        node.velocity = node.velocity / node.velocity.distance * maxSpeed;
      }

      node.position += node.velocity;
      totalKinetic += node.velocity.distanceSquared;

      // Animate opacity and scale for new nodes
      if (node.opacity < 1.0) {
        node.opacity = (node.opacity + 0.06).clamp(0.0, 1.0);
      }
      if (node.scale < 1.0) {
        node.scale = (node.scale + 0.08).clamp(0.0, 1.0);
      }
    }

    // Animate edge opacity
    for (final edge in _edges) {
      if (edge.opacity < 1.0) {
        edge.opacity = (edge.opacity + 0.04).clamp(0.0, 1.0);
      }
    }

    // Stop when settled
    if (totalKinetic < 0.1 &&
        nodeList.every((n) => n.opacity >= 1.0) &&
        _edges.every((e) => e.opacity >= 1.0)) {
      _physicsController.stop();
    }

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  void _onNodeTap(String artistId) {
    HapticFeedback.lightImpact();
    setState(() => _focusedNodeId = artistId);

    if (!_expandedIds.contains(artistId)) {
      _expandNode(artistId);
    }
  }

  void _onNodeDoubleTap(String artistId) {
    final node = _nodes[artistId];
    if (node == null) return;
    HapticFeedback.mediumImpact();

    // Navigate to artist detail
    final artist = Artist(
      id: node.artistId,
      name: node.name,
      pictureUrl: node.imageUrl,
      pictureMedium: node.imageUrl,
      fansCount: node.fans,
    );
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)),
    );
  }

  void _centerOnNode(String artistId) {
    final node = _nodes[artistId];
    if (node == null) return;

    final size = MediaQuery.of(context).size;
    final matrix = Matrix4.identity()
      ..translate(
        size.width / 2 - node.position.dx,
        size.height / 2 - node.position.dy,
      );
    _transformController.value = matrix;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
    if (_focusedNodeId != null) {
      _centerOnNode(_focusedNodeId!);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final strings = locale.strings;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textBright,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.rabbitHoleTitle,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            color: AppColors.neonPurple,
            tooltip: strings.rabbitHoleRecenter,
            onPressed: _resetView,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background grid
          CustomPaint(
            size: size,
            painter: _GridPainter(),
          ),

          // Graph canvas
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.15,
            maxScale: 3.0,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _GraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                  focusedId: _focusedNodeId,
                  center: Offset(size.width / 2, size.height / 2),
                ),
                child: Stack(
                  children: _nodes.values.map((node) {
                    final screenPos = Offset(
                      size.width / 2 + node.position.dx,
                      size.height / 2 + node.position.dy,
                    );
                    return _NodeWidget(
                      key: ValueKey(node.artistId),
                      node: node,
                      position: screenPos,
                      isFocused: node.artistId == _focusedNodeId,
                      onTap: () => _onNodeTap(node.artistId),
                      onDoubleTap: () => _onNodeDoubleTap(node.artistId),
                      locale: locale,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Bottom info bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomInfoBar(
              focusedNode:
                  _focusedNodeId != null ? _nodes[_focusedNodeId] : null,
              totalNodes: _nodes.length,
              totalExpansions: _totalExpansions,
              locale: locale,
              onNavigate: _focusedNodeId != null
                  ? () => _onNodeDoubleTap(_focusedNodeId!)
                  : null,
            ),
          ),

          // Loading overlay on first load
          if (_initialLoad)
            Container(
              color: AppColors.bgDeep.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.neonPurple.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.rabbitHoleLoading,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node widget with cached image
// ---------------------------------------------------------------------------

class _NodeWidget extends StatelessWidget {
  final _GraphNode node;
  final Offset position;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final LocaleProvider locale;

  const _NodeWidget({
    super.key,
    required this.node,
    required this.position,
    required this.isFocused,
    required this.onTap,
    required this.onDoubleTap,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final r = node.radius * node.scale;
    if (r < 1) return const SizedBox.shrink();

    final accentColor = isFocused
        ? AppColors.neonPurple
        : node.expanded
            ? AppColors.neonCyan
            : AppColors.textMuted;

    return Positioned(
      left: position.dx - r,
      top: position.dy - r,
      child: Opacity(
        opacity: node.opacity,
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: SizedBox(
            width: r * 2,
            height: r * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow ring
                      if (isFocused)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.neonPurple.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      // Border ring
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isFocused ? 0.9 : 0.6,
                            ),
                            width: isFocused ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                      // Artist image
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: node.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.bgCard,
                              child: Icon(Icons.person,
                                  size: r * 0.5,
                                  color: AppColors.textMuted),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.bgCard,
                              child: Icon(Icons.person,
                                  size: r * 0.5,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                      // Loading spinner
                      if (node.loading)
                        SizedBox(
                          width: r * 1.2,
                          height: r * 1.2,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                AppColors.neonPurple.withValues(alpha: 0.7),
                          ),
                        ),
                      // Expand hint
                      if (!node.expanded && !node.loading)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.bgDeep,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.add,
                                size: 9, color: accentColor),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                // Name label
                SizedBox(
                  width: r * 3,
                  child: Text(
                    node.name,
                    style: locale.getTextStyle(
                      fontSize: (8 + node.radius * 0.08).clamp(7.0, 11.0),
                      fontWeight:
                          isFocused ? FontWeight.w800 : FontWeight.w600,
                      color: isFocused
                          ? AppColors.textBright
                          : AppColors.textBright.withValues(
                              alpha: (1.0 - node.depth * 0.1).clamp(0.4, 0.9)),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ---------------------------------------------------------------------------
// Graph painter (edges + decorations)
// ---------------------------------------------------------------------------

class _GraphPainter extends CustomPainter {
  final Map<String, _GraphNode> nodes;
  final List<_GraphEdge> edges;
  final String? focusedId;
  final Offset center;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    this.focusedId,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = nodes[edge.fromId];
      final to = nodes[edge.toId];
      if (from == null || to == null) continue;
      if (from.opacity < 0.01 || to.opacity < 0.01) continue;

      final isFocusEdge =
          focusedId == edge.fromId || focusedId == edge.toId;
      final alpha = edge.opacity * (isFocusEdge ? 0.5 : 0.15);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          center + from.position,
          center + to.position,
          [
            (isFocusEdge ? AppColors.neonPurple : AppColors.neonCyan)
                .withValues(alpha: alpha),
            (isFocusEdge ? AppColors.neonCyan : AppColors.neonPurple)
                .withValues(alpha: alpha * 0.3),
          ],
        )
        ..strokeWidth = isFocusEdge ? 1.5 : 0.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        center + from.position,
        center + to.position,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}

// ---------------------------------------------------------------------------
// Background grid painter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonPurple.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Radial rings
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = AppColors.neonPurple.withValues(alpha: 0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (var r = 100.0; r < size.width; r += 100) {
      canvas.drawCircle(center, r, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Bottom info bar
// ---------------------------------------------------------------------------

class _BottomInfoBar extends StatelessWidget {
  final _GraphNode? focusedNode;
  final int totalNodes;
  final int totalExpansions;
  final LocaleProvider locale;
  final VoidCallback? onNavigate;

  const _BottomInfoBar({
    this.focusedNode,
    required this.totalNodes,
    required this.totalExpansions,
    required this.locale,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgDeep.withValues(alpha: 0.0),
            AppColors.bgDeep.withValues(alpha: 0.85),
            AppColors.bgDeep,
          ],
          stops: const [0, 0.3, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Focused artist info
          if (focusedNode != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: GestureDetector(
                key: ValueKey(focusedNode!.artistId),
                onTap: onNavigate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: focusedNode!.imageUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              focusedNode!.name,
                              style: locale.getTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              focusedNode!.expanded
                                  ? strings.rabbitHoleExpanded
                                  : strings.rabbitHoleTapToExpand,
                              style: locale.getTextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: focusedNode!.expanded
                                    ? AppColors.neonCyan
                                    : AppColors.neonPurple,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.neonPurple.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.hub,
                label: strings.rabbitHoleNodes(totalNodes),
                color: AppColors.neonCyan,
                locale: locale,
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.unfold_more,
                label: strings.rabbitHoleDepth(totalExpansions),
                color: AppColors.neonPurple,
                locale: locale,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final LocaleProvider locale;

  const _StatChip({
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
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
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
