part of '../rabbit_hole_screen.dart';

// The graph's pieces: node layout and views, badges, trail, focus card, panel, painters.
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
