import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Whether the user asked the system for less motion (Android's "Remove
/// animations", iOS's "Reduce Motion"). Then decoration stays still and
/// entrances show their end at once; what tells state (a progress bar, a
/// fade) still moves.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

extension CalmAnimate on Widget {
  /// flutter_animate's [animate], which starts at its end, without moving,
  /// when the user asked for less motion. [onPlay] (a repeat, say) only
  /// runs when it plays.
  Animate animateCalm(BuildContext context, {AnimateCallback? onPlay}) {
    final still = reduceMotion(context);
    // Moving, exactly as animate() would; still, parked at the end.
    return still ? animate(autoPlay: false, value: 1) : animate(onPlay: onPlay);
  }
}
