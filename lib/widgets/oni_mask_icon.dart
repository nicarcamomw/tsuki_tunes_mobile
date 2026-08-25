import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class OniMaskIcon extends StatelessWidget {
  final bool isActive;
  final double size;
  final bool showContainer;

  const OniMaskIcon({
    super.key,
    this.isActive = false,
    this.size = 26,
    this.showContainer = true,
  });

  static const _plomoColor = Color(0xFF2E2E2E);

  @override
  Widget build(BuildContext context) {
    final maskColor = isActive
        ? _plomoColor
        : AppColors.textMuted.withValues(alpha: 0.5);

    final mask = Image.asset(
      'assets/images/tengu.png',
      fit: BoxFit.contain,
      color: maskColor,
      colorBlendMode: BlendMode.srcIn,
    );

    if (!showContainer) {
      return SizedBox(
        width: size,
        height: size,
        child: mask,
      );
    }

    final containerSize = size + 14;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isActive
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: mask,
        ),
      ),
    );
  }
}
