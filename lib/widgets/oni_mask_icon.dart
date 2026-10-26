import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/mask_provider.dart';
import 'oni_mask_art.dart';

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

  /// The equipped collectible mask in full color when active, its muted
  /// silhouette when not. Without an equipped mask: the classic tengu.
  Widget _maskImage(OniMask? equipped, double t, Color mutedColor) {
    if (equipped == null || t < 0.5) {
      return Image.asset(
        equipped?.asset() ?? 'assets/images/tengu.png',
        fit: BoxFit.contain,
        color: mutedColor,
        colorBlendMode: BlendMode.srcIn,
      );
    }
    return Opacity(
      opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
      child: OniMaskArt.image(equipped, widget.size),
    );
  }

  OniMask? _equipped(BuildContext context) {
    try {
      return context.select<MaskProvider, OniMask?>((m) => m.equipped);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipped = _equipped(context);
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
            child: _maskImage(equipped, _glowAnimation.value, maskColor),
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
            // A dark plate keeps colored collectible masks readable on the glow.
            color: equipped != null ? AppColors.bgDeep : Colors.transparent,
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
              child: _maskImage(equipped, t, maskColor),
            ),
          ),
        );
      },
    );
  }
}
