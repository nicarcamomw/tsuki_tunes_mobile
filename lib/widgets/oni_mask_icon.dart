import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class OniMaskIcon extends StatefulWidget {
  final bool isActive;
  final double size;
  final bool showContainer;

  const OniMaskIcon({
    super.key,
    this.isActive = false,
    this.size = 26,
    this.showContainer = true,
  });

  @override
  State<OniMaskIcon> createState() => _OniMaskIconState();
}

class _OniMaskIconState extends State<OniMaskIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  static const _plomoColor = Color(0xFF2E2E2E);
  static const _duration = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.isActive ? 1.0 : 0.0,
    );
    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.duration = Duration.zero;
      _controller.reverseDuration = Duration.zero;
    }
  }

  @override
  void didUpdateWidget(OniMaskIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showContainer) {
      return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final maskColor = Color.lerp(
            AppColors.textMuted.withValues(alpha: 0.5),
            _plomoColor,
            _glowAnimation.value,
          )!;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              'assets/images/tengu.png',
              fit: BoxFit.contain,
              color: maskColor,
              colorBlendMode: BlendMode.srcIn,
            ),
          );
        },
      );
    }

    final containerSize = widget.size + 14;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final t = _glowAnimation.value;
        final borderColor = Color.lerp(
          AppColors.accent.withValues(alpha: 0.4),
          AppColors.accent,
          t,
        )!;
        final maskColor = Color.lerp(
          AppColors.textMuted.withValues(alpha: 0.5),
          _plomoColor,
          t,
        )!;

        return Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: t > 0.01
                ? [
                    BoxShadow(
                      color: AppColors.accentGlow.withValues(alpha: t * 0.6),
                      blurRadius: 6 * t,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Image.asset(
                'assets/images/tengu.png',
                fit: BoxFit.contain,
                color: maskColor,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        );
      },
    );
  }
}
