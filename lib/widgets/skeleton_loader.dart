import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/constants/app_colors.dart';

class _SharedPulse {
  static final _SharedPulse instance = _SharedPulse._();
  _SharedPulse._();

  final ValueNotifier<double> value = ValueNotifier(0.5);
  int _refs = 0;
  Ticker? _ticker;

  void ref() {
    if (++_refs == 1) {
      _ticker = Ticker(_onTick)..start();
    }
  }

  void unref() {
    if (--_refs <= 0) {
      _refs = 0;
      _ticker?.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds % 2400;
    final t = ms < 1200 ? ms / 1200.0 : 2.0 - ms / 1200.0;
    value.value = 0.3 + 0.4 * (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t);
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> {
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _SharedPulse.instance.ref();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    _SharedPulse.instance.unref();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: AppColors.bgCard.withValues(alpha: 0.5),
        ),
      );
    }
    return CustomPaint(
      painter: _PulsePainter(
        borderRadius: widget.borderRadius,
        color: AppColors.bgCard,
        pulse: _SharedPulse.instance.value,
      ),
      child: SizedBox(width: widget.width, height: widget.height),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double borderRadius;
  final Color color;
  final ValueNotifier<double> pulse;

  _PulsePainter({
    required this.borderRadius,
    required this.color,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(borderRadius),
      ),
      Paint()..color = color.withValues(alpha: pulse.value),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.borderRadius != borderRadius || old.color != color;
}

class HomeSkeletonLoader extends StatelessWidget {
  const HomeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
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
            ...List.generate(4, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _ArtistRowSkeleton(),
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
    );
  }
}

class ArtistDetailSkeletonLoader extends StatelessWidget {
  const ArtistDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
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
            ...List.generate(5, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: _TrackRowSkeleton(),
            )),
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
    );
  }
}

class AlbumDetailSkeletonLoader extends StatelessWidget {
  const AlbumDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            ...List.generate(8, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: _TrackRowSkeleton(),
            )),
          ],
        ),
      ),
    );
  }
}

class _ArtistRowSkeleton extends StatelessWidget {
  const _ArtistRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgMid.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          SkeletonLoader(width: 24, height: 14),
          SizedBox(width: 8),
          SkeletonLoader(width: 40, height: 40, borderRadius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(height: 14, width: 120),
                SizedBox(height: 4),
                SkeletonLoader(height: 11, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackRowSkeleton extends StatelessWidget {
  const _TrackRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        children: [
          SkeletonLoader(width: 24, height: 12),
          SizedBox(width: 8),
          SkeletonLoader(width: 46, height: 46),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(height: 14, width: 150),
                SizedBox(height: 4),
                SkeletonLoader(height: 11, width: 100),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonLoader(width: 30, height: 11),
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
