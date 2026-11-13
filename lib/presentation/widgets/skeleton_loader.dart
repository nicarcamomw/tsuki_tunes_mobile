import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';

// Skeletons: the shape of what's coming, while it comes.
//
// A [SkeletonScope] drives one shimmer for every bone under it, so a whole
// screen pulses as one wave on one ticker, and tells screen readers it's
// loading. Bones ([SkeletonLoader]) outside a scope run their own shimmer.
// [SkeletonSwitcher] fades from the skeleton to the content.
//
// Content loads show a skeleton; a spinner is only for an action in place
// (a button's progress, buffering, a field's search).

/// One shimmer for all the bones under it, plus the "loading" label.
class SkeletonScope extends ConsumerStatefulWidget {
  final Widget child;

  /// Read out instead of the bones; "Loading" when null.
  final String? label;

  /// Light bones, for skeletons over artwork or a coloured background.
  final bool onImage;

  const SkeletonScope({super.key, required this.child, this.label, this.onImage = false});

  @override
  ConsumerState<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends ConsumerState<SkeletonScope> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _SkeletonShimmer.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label ?? ref.watch(stringsProvider).a11yLoading,
        liveRegion: true,
        child: ExcludeSemantics(
          // The shimmer repaints only the bones, never what's around them.
          child: RepaintBoundary(
            child: _SkeletonShimmer(animation: _controller, onImage: widget.onImage, child: widget.child),
          ),
        ),
      );
}

class _SkeletonShimmer extends InheritedWidget {
  final Animation<double> animation;
  final bool onImage;

  static const period = Duration(milliseconds: 1500);

  const _SkeletonShimmer({required this.animation, required this.onImage, required super.child});

  static _SkeletonShimmer? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonShimmer>();

  @override
  bool updateShouldNotify(_SkeletonShimmer old) => old.animation != animation || old.onImage != onImage;
}

/// One bone: a rounded block with the shimmer passing over it.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppRadius.chip,
  });

  /// A round bone (an avatar or an artist).
  const SkeletonLoader.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = size / 2;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  static const _base = Color(0xFF1E2030);
  static const _highlight = Color(0xFF2A2E42);
  static const _baseOnImage = Color(0x14FFFFFF);
  static const _highlightOnImage = Color(0x2EFFFFFF);

  /// Only for a bone outside any [SkeletonScope].
  AnimationController? _own;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  Animation<double> _animation(BuildContext context, _SkeletonShimmer? scope) {
    if (scope != null) {
      _own?.dispose();
      _own = null;
      return scope.animation;
    }
    final own = _own ??= AnimationController(vsync: this, duration: _SkeletonShimmer.period);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      own
        ..stop()
        ..value = 0.5;
    } else if (!own.isAnimating) {
      own.repeat();
    }
    return own;
  }

  @override
  Widget build(BuildContext context) {
    final scope = _SkeletonShimmer.of(context);
    final animation = _animation(context, scope);
    final onImage = scope?.onImage ?? false;
    final base = onImage ? _baseOnImage : _base;
    final highlight = onImage ? _highlightOnImage : _highlight;
    // Painted, not rebuilt: each frame of the shimmer only repaints the
    // bone (a widget rebuild per bone per frame added up in long lists).
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _BonePainter(
          animation: animation,
          radius: widget.borderRadius,
          base: base,
          highlight: highlight,
        ),
      ),
    );
  }
}

class _BonePainter extends CustomPainter {
  final Animation<double> animation;
  final double radius;
  final Color base;
  final Color highlight;

  _BonePainter({required this.animation, required this.radius, required this.base, required this.highlight})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // -2 → 2 with an ease: the highlight sweeps left to right.
    final x = Curves.easeInOutSine.transform(animation.value) * 4 - 2;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(x - 1, 0),
        end: Alignment(x + 1, 0),
        colors: [base, highlight, base],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  }

  @override
  bool shouldRepaint(_BonePainter old) =>
      old.animation != animation ||
      old.radius != radius ||
      old.base != base ||
      old.highlight != highlight;
}

/// A bone [factor] of the available width, so lines in a list vary like text.
class SkeletonLine extends StatelessWidget {
  final double factor;
  final double height;

  const SkeletonLine({super.key, required this.factor, this.height = 12});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: factor,
        child: SkeletonLoader(height: height),
      );
}

/// Widths that look like real titles and subtitles, picked by row.
const _titleWidths = [0.62, 0.48, 0.71, 0.55, 0.66, 0.43];
const _subtitleWidths = [0.38, 0.30, 0.44, 0.34, 0.27, 0.41];

/// Fades from [skeleton] to [child] when [loading] ends.
class SkeletonSwitcher extends StatelessWidget {
  final bool loading;
  final Widget skeleton;
  final Widget child;

  const SkeletonSwitcher({super.key, required this.loading, required this.skeleton, required this.child});

  static const duration = AppMotion.normal;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(loading), child: loading ? skeleton : child),
      );
}

// ── Rows ──

/// A song row: number, cover, title and artist, duration.
class SkeletonTrackRow extends StatelessWidget {
  final int index;

  const SkeletonTrackRow({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SkeletonLoader(width: 24, height: 12),
            const SizedBox(width: 8),
            const SkeletonLoader(width: 46, height: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(factor: _titleWidths[index % _titleWidths.length], height: 14),
                  const SizedBox(height: 6),
                  SkeletonLine(factor: _subtitleWidths[index % _subtitleWidths.length], height: 11),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SkeletonLoader(width: 30, height: 11),
          ],
        ),
      );
}

/// A row with a picture and two lines: a person, a playlist, a device.
class SkeletonListRow extends StatelessWidget {
  final int index;
  final double leading;
  final bool round;
  final bool trailing;

  const SkeletonListRow({super.key, this.index = 0, this.leading = 44, this.round = false, this.trailing = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (round) SkeletonLoader.circle(size: leading) else SkeletonLoader(width: leading, height: leading),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(factor: _titleWidths[index % _titleWidths.length], height: 13),
                  const SizedBox(height: 6),
                  SkeletonLine(factor: _subtitleWidths[index % _subtitleWidths.length], height: 10),
                ],
              ),
            ),
            if (trailing) ...[const SizedBox(width: 12), const SkeletonLoader(width: 22, height: 22, borderRadius: AppRadius.chip)],
          ],
        ),
      );
}

/// [count] song rows, as a box.
class SkeletonTrackList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final String? label;

  const SkeletonTrackList({super.key, this.count = 8, this.padding = const EdgeInsets.symmetric(horizontal: 16), this.label});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < count; i++) SkeletonTrackRow(index: i)],
          ),
        ),
      );
}

/// [count] picture-and-two-lines rows, as a box.
class SkeletonRowList extends StatelessWidget {
  final int count;
  final double leading;
  final bool round;
  final bool trailing;
  final EdgeInsetsGeometry padding;
  final String? label;

  const SkeletonRowList({
    super.key,
    this.count = 6,
    this.leading = 44,
    this.round = false,
    this.trailing = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.label,
  });

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                SkeletonListRow(index: i, leading: leading, round: round, trailing: trailing),
            ],
          ),
        ),
      );
}

/// Lyrics coming: lines of different lengths, centred like the real ones.
class SkeletonLyrics extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double gap;
  final bool onImage;
  final String? label;

  const SkeletonLyrics({super.key, this.lines = 8, this.lineHeight = 18, this.gap = 18, this.onImage = true, this.label});

  static const _widths = [0.72, 0.54, 0.80, 0.46, 0.66, 0.58, 0.76, 0.50];

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        onImage: onImage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) SizedBox(height: gap),
              FractionallySizedBox(
                widthFactor: _widths[i % _widths.length],
                child: SkeletonLoader(height: lineHeight, borderRadius: lineHeight / 2),
              ),
            ],
          ],
        ),
      );
}

/// An album, playlist or artist page: the picture, its titles, its songs.
class SkeletonDetailPage extends StatelessWidget {
  final String? label;

  const SkeletonDetailPage({super.key, this.label});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const SkeletonLoader(width: 200, height: 200, borderRadius: AppRadius.card),
              const SizedBox(height: 20),
              const FractionallySizedBox(widthFactor: 0.6, child: SkeletonLoader(height: 20)),
              const SizedBox(height: 10),
              const FractionallySizedBox(widthFactor: 0.38, child: SkeletonLoader(height: 13)),
              const SizedBox(height: 28),
              for (var i = 0; i < 6; i++) SkeletonTrackRow(index: i),
            ],
          ),
        ),
      );
}

/// A public profile: avatar, name, the stat cards, a list.
class SkeletonProfile extends StatelessWidget {
  final String? label;

  const SkeletonProfile({super.key, this.label});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            children: [
              const SkeletonLoader.circle(size: 96),
              const SizedBox(height: 14),
              const FractionallySizedBox(widthFactor: 0.5, child: SkeletonLoader(height: 22)),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: SkeletonLoader(height: 64, borderRadius: AppRadius.card)),
                  SizedBox(width: 10),
                  Expanded(child: SkeletonLoader(height: 64, borderRadius: AppRadius.card)),
                  SizedBox(width: 10),
                  Expanded(child: SkeletonLoader(height: 64, borderRadius: AppRadius.card)),
                ],
              ),
              const SizedBox(height: 28),
              const Align(alignment: AlignmentDirectional.centerStart, child: SkeletonLoader(width: 140, height: 14)),
              const SizedBox(height: 12),
              for (var i = 0; i < 5; i++) SkeletonListRow(index: i, round: true),
            ],
          ),
        ),
      );
}

/// A story page (the Wrapped): its progress bars, a big title, a card.
class SkeletonStory extends StatelessWidget {
  const SkeletonStory({super.key});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        onImage: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      const Expanded(child: SkeletonLoader(height: 3, borderRadius: AppRadius.chip)),
                    ],
                  ],
                ),
                const Spacer(),
                const FractionallySizedBox(widthFactor: 0.4, child: SkeletonLoader(height: 14)),
                const SizedBox(height: 16),
                const FractionallySizedBox(widthFactor: 0.85, child: SkeletonLoader(height: 36, borderRadius: AppRadius.chip)),
                const SizedBox(height: 10),
                const FractionallySizedBox(widthFactor: 0.6, child: SkeletonLoader(height: 36, borderRadius: AppRadius.chip)),
                const SizedBox(height: 32),
                const SkeletonLoader(height: 180, borderRadius: AppRadius.sheet),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
}

/// A genre page: a row of artists, then songs.
class SkeletonGenre extends StatelessWidget {
  const SkeletonGenre({super.key});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonLoader(width: 120, height: 14)),
              const SizedBox(height: 14),
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (var i = 0; i < 5; i++)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            SkeletonLoader.circle(size: 96),
                            SizedBox(height: 10),
                            SkeletonLoader(width: 70, height: 11),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonLoader(width: 150, height: 14)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [for (var i = 0; i < 6; i++) SkeletonTrackRow(index: i)]),
              ),
            ],
          ),
        ),
      );
}

/// A row of album cards, for a grid that's loading more.
class SkeletonAlbumRow extends StatelessWidget {
  final int count;

  const SkeletonAlbumRow({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) => SkeletonScope(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(aspectRatio: 1, child: SkeletonLoader(height: double.infinity)),
                      SizedBox(height: 8),
                      SkeletonLine(factor: 0.8, height: 13),
                      SizedBox(height: 4),
                      SkeletonLine(factor: 0.55, height: 11),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

// ── Screens already shaped by their own skeleton ──

class HomeSkeletonLoader extends StatelessWidget {
  const HomeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SkeletonScope(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(4, (_) => const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SkeletonLoader(width: 140, height: 76),
                  )),
                ),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SkeletonLoader(width: 200, height: 14),
              ),
              const SizedBox(height: 14),
              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ArtistRowSkeleton(index: i),
              )),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SkeletonLoader(width: 180, height: 14),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: _AlbumCardSkeleton(),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtistDetailSkeletonLoader extends StatelessWidget {
  const ArtistDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SkeletonScope(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SkeletonLoader(width: 120, height: 14),
              ),
              const SizedBox(height: 14),
              ...List.generate(5, (i) => SkeletonTrackRow(index: i)),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SkeletonLoader(width: 160, height: 14),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: _AlbumCardSkeleton(),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumDetailSkeletonLoader extends StatelessWidget {
  const AlbumDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SkeletonScope(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ...List.generate(8, (i) => SkeletonTrackRow(index: i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistRowSkeleton extends StatelessWidget {
  final int index;

  const _ArtistRowSkeleton({this.index = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgMid.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 24, height: 14),
          const SizedBox(width: 8),
          const SkeletonLoader.circle(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(factor: _titleWidths[index % _titleWidths.length], height: 14),
                const SizedBox(height: 4),
                SkeletonLine(factor: _subtitleWidths[index % _subtitleWidths.length], height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCardSkeleton extends StatelessWidget {
  const _AlbumCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLoader(width: 135, height: 135),
        SizedBox(height: 8),
        SkeletonLoader(width: 110, height: 13),
        SizedBox(height: 4),
        SkeletonLoader(width: 80, height: 11),
      ],
    );
  }
}
