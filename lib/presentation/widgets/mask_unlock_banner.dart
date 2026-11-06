import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import 'eco_widgets.dart';
import 'oni_mask_art.dart';
import 'oni_mask_colors.dart';

/// App-wide layer that announces newly unlocked masks, one at a time.
class MaskUnlockLayer extends ConsumerWidget {
  final Widget child;
  /// Opens the collection when the banner is tapped.
  final VoidCallback? onOpenCollection;

  const MaskUnlockLayer({super.key, required this.child, this.onOpenCollection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(maskProvider.select((m) => m.pendingCelebration));
    final mask = MaskCatalog.byId(pending);
    // A level reached waits for the masks to be announced first.
    final levelUp = ref.watch(maskProvider.select((m) => m.pendingLevelUp));
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (mask != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _UnlockBanner(
              key: ValueKey(mask.id),
              mask: mask,
              onTap: onOpenCollection,
            ),
          )
        else if (levelUp != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: EcoLevelUpBanner(key: ValueKey('lv${levelUp.$2}'), from: levelUp.$1, to: levelUp.$2),
          ),
      ],
    );
  }
}

class _UnlockBanner extends ConsumerStatefulWidget {
  final OniMask mask;
  final VoidCallback? onTap;

  const _UnlockBanner({super.key, required this.mask, this.onTap});

  @override
  ConsumerState<_UnlockBanner> createState() => _UnlockBannerState();
}

class _UnlockBannerState extends ConsumerState<_UnlockBanner> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _autoClose;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _enter.forward();
    _burst.forward();
    _autoClose = Timer(const Duration(milliseconds: 5200), _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _enter.duration = const Duration(milliseconds: 1);
      _burst.value = 1;
    }
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _autoClose?.cancel();
    await _enter.reverse();
    if (mounted) ref.read(maskProvider).dismissCelebration();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _enter.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final mask = widget.mask;
    final color = mask.rarityColor;
    final slide = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _burst]),
        builder: (context, _) {
          final dy = (1 - slide.value) * -140;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: _enter.value.clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Semantics(
                  liveRegion: true,
                  button: true,
                  label: '${strings.maskUnlockedTitle}: ${mask.name(locale.currentLanguage)}',
                  child: GestureDetector(
                    onTap: () {
                      _close();
                      widget.onTap?.call();
                    },
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < 0) _close();
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.22), AppColors.bgCard],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          border: Border.all(color: color.withValues(alpha: 0.7)),
                          boxShadow: [
                            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24),
                            const BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CustomPaint(
                                painter: _BurstPainter(_burst.value, color),
                                child: Transform.scale(
                                  scale: 0.6 + 0.4 * Curves.elasticOut.transform(_burst.value.clamp(0.0, 1.0)),
                                  child: OniMaskArt(mask: mask, size: 64, unlocked: true),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    strings.maskUnlockedTitle,
                                    style: locale.getTextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${mask.kanji}  ${mask.name(locale.currentLanguage)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: locale.getTextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textBright,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mask.description(locale.currentLanguage),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: locale.getTextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rays of light bursting out behind the mask as it appears.
class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;

  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55 * fade)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + t * 0.6;
      final r0 = size.width * (0.3 + 0.35 * t);
      final r1 = r0 + size.width * 0.22 * fade;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * r0, c + Offset(cos(a), sin(a)) * r1, paint);
    }
    canvas.drawCircle(
      c,
      size.width * (0.3 + 0.5 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.6 * fade),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
