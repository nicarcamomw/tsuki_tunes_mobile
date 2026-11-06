import 'package:flutter/widgets.dart';

import '../../core/constants/app_colors.dart';

/// The player's accent colour: the app's red, or the aura of an equipped
/// UL or DS mask. Set above the mini player and the expanded player.
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
