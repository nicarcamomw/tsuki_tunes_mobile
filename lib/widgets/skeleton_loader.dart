import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

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

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: AppColors.bgCard.withValues(alpha: _animation.value),
        ),
      ),
    );
  }
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
