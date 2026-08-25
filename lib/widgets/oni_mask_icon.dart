import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class OniMaskIcon extends StatelessWidget {
  final bool isActive;
  final double size;

  const OniMaskIcon({
    super.key,
    this.isActive = false,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: isActive
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/images/tengu.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: isActive
            ? AppColors.accent
            : AppColors.textMuted.withValues(alpha: 0.5),
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

