import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import '../widgets/motion.dart';

/// The first Flutter frame, while the session wakes up (auth, the
/// tutorial flag): it carries on Android's splash without a seam, the same
/// night and the same mask in the same place, then lets it breathe with a
/// red glow. If waking takes more than a moment, a line says so.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  /// The mask's width: as large as it is in Android 12's splash (240 dp
  /// icon, the mask about 100 dp of it, plus the image's own margin).
  static const double maskWidth = 120;

  /// How long before the line under the mask appears.
  static const Duration patience = Duration(milliseconds: 1200);

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: AppMotion.breath);
  Timer? _patience;
  bool _slow = false;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    _patience = Timer(LoadingScreen.patience, () {
      if (mounted) setState(() => _slow = true);
    });
    // The glow comes in after the first frame, so the hand-over from the
    // splash (which has none) is seamless.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lit = true);
    });
  }

  @override
  void dispose() {
    _patience?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localeProvider.select((l) => l.strings));
    final locale = ref.read(localeProvider);
    final still = reduceMotion(context);
    if (still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
    final breath = CurvedAnimation(parent: _breath, curve: Curves.easeInOut);

    return Scaffold(
      backgroundColor: AppColors.splash,
      body: Semantics(
        label: strings.a11yLoading,
        liveRegion: true,
        // The whole screen, so the mask sits at its centre, as in the splash.
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The red glow behind the mask, breathing with it.
              AnimatedOpacity(
                opacity: _lit ? 1 : 0,
                duration: AppMotion.slow,
                curve: AppMotion.enter,
                child: AnimatedBuilder(
                  animation: breath,
                  builder: (_, __) => Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.14 + 0.08 * (still ? 0 : breath.value)),
                          AppColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ScaleTransition(
                scale: still ? const AlwaysStoppedAnimation(1) : Tween(begin: 1.0, end: 1.03).animate(breath),
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/images/cyber_oni_mask.png',
                    width: LoadingScreen.maskWidth,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              // Under the mask, only if waking takes a moment.
              Positioned(
                left: 32,
                right: 32,
                bottom: MediaQuery.paddingOf(context).bottom + 72,
                child: AnimatedOpacity(
                  opacity: _slow ? 1 : 0,
                  duration: AppMotion.slow,
                  curve: AppMotion.enter,
                  child: ExcludeSemantics(
                    child: Text(
                      strings.loadingWaking,
                      textAlign: TextAlign.center,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
