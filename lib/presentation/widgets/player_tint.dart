import 'package:flutter/widgets.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// The player's accent colour: the aura of an equipped UL or DS mask, the
/// colour the user chose, the cover's colour, or the app's red. Set above
/// the mini player and the expanded player.
class PlayerTint extends InheritedWidget {
  final Color color;

  const PlayerTint({super.key, required this.color, required super.child});

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerTint>()?.color ?? AppColors.accent;

  /// The soft glow that goes with [of].
  static Color glowOf(BuildContext context) => of(context).withValues(alpha: 0.5);

  @override
  bool updateShouldNotify(PlayerTint old) => old.color != color;
}

/// A [PlayerTint] that fades to a new [color] instead of jumping, so the
/// player changes colour smoothly with each cover.
class AnimatedPlayerTint extends StatelessWidget {
  final Color color;
  final Widget child;

  static const duration = AppMotion.slow;

  const AnimatedPlayerTint({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: duration,
        curve: Curves.easeOut,
        builder: (_, c, child) => PlayerTint(color: c ?? color, child: child!),
        child: child,
      );
}
