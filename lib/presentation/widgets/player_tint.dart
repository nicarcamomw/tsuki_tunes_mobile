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

  /// [of] for text and small icons: lifted toward white as far as it takes
  /// to read on the player's dark background (AA, 4.5:1). The base red
  /// keeps its own text shade.
  static Color textOf(BuildContext context) => readableTint(of(context));

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

/// [tint] as text on the player's dark background: the base red gives its
/// text shade ([AppColors.accentText]); any other colour (a cover's blue,
/// a palette violet) is lifted toward white until it reaches [ratio]
/// against [on] and against a background tinted with its own hue. Light
/// colours come back as they are.
Color readableTint(Color tint, {Color on = AppColors.bgDeep, double ratio = 4.5}) {
  if (tint.toARGB32() == AppColors.accent.toARGB32()) return AppColors.accentText;
  final solid = tint.withValues(alpha: 1);
  // With colours from each song the player's top takes the cover's hue
  // (at most this saturated and light, see CoverColors): it must read on
  // that too, whichever is lighter.
  final ownBackground = HSLColor.fromColor(solid).withSaturation(0.6).withLightness(0.16).toColor();
  if (ownBackground.computeLuminance() > on.computeLuminance()) on = ownBackground;
  if (contrastRatio(solid, on) >= ratio) return solid;
  // Lightest first would wash it out: the least white that reaches it.
  for (var t = 0.05; t < 1; t += 0.05) {
    final lifted = Color.lerp(solid, const Color(0xFFFFFFFF), t)!;
    if (contrastRatio(lifted, on) >= ratio) return lifted;
  }
  return const Color(0xFFFFFFFF);
}

/// WCAG contrast ratio between two opaque colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
