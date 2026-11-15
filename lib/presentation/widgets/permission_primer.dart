import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import 'app_snack.dart';
import 'haptics.dart';
import 'motion.dart';
import 'swipeable_sheet.dart';

/// What a primer shows above its words: what the permission gives, acted
/// out once.
enum PrimerArt {
  /// A new-release notice arriving, the bell ringing.
  notifications,

  /// The phone locking while the music plays on.
  background,
}

/// Why Tsuki wants a permission, just before Android asks for it: a small
/// scene of what it gives, the question, three short lines, then "Allow"
/// (which opens the system's own dialog) or "Not now". Android 13+ shows
/// its notification dialog at most twice; asked cold, a "no" there is for
/// good, so the system dialog only comes after a yes here.
class PermissionPrimer extends ConsumerStatefulWidget {
  final PrimerArt art;
  final Color color;
  final String title;
  final List<(IconData, String)> points;

  const PermissionPrimer({super.key, required this.art, required this.color, required this.title, required this.points});

  /// True when the user chose "Allow".
  static Future<bool> show(
    BuildContext context, {
    required PrimerArt art,
    required Color color,
    required String title,
    required List<(IconData, String)> points,
  }) async {
    // As tall as its content, so both buttons always show (a fixed share
    // of the screen hid them on small phones and with large text); it
    // scrolls if the text needs more than the screen. Swipe down closes.
    final allowed = await showAppSheet<bool>(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: PermissionPrimer(art: art, color: color, title: title, points: points),
        ),
      ),
    );
    return allowed ?? false;
  }

  /// Before asking to send notifications: new music from followed artists.
  static Future<bool> notifications(BuildContext context) {
    final strings = ProviderScope.containerOf(context, listen: false).read(stringsProvider);
    return show(
      context,
      art: PrimerArt.notifications,
      color: AppColors.neonCyan,
      title: strings.permNotifTitle,
      points: [
        (Icons.new_releases_rounded, strings.permNotifPoint1),
        (Icons.do_not_disturb_on_rounded, strings.permNotifPoint2),
        (Icons.tune_rounded, strings.permNotifPoint3),
      ],
    );
  }

  /// Once some music has been heard, if Android limits Tsuki's battery:
  /// explains, then Android's own dialog. Asked once, whatever the answer.
  static Future<void> offerBackgroundIfNeeded(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final guide = container.read(batteryGuideProvider);
    if (!await guide.shouldOfferBackground() || !context.mounted) return;
    final strings = container.read(stringsProvider);
    final allowed = await show(
      context,
      art: PrimerArt.background,
      color: AppColors.success,
      title: strings.permBackgroundTitle,
      points: [
        (Icons.battery_alert_rounded, strings.permBgPoint1),
        (Icons.screen_lock_portrait_rounded, strings.permBgPoint2),
        (Icons.verified_user_rounded, strings.permBgPoint3),
      ],
    );
    if (allowed) {
      await guide.askToRunInBackground();
    } else {
      await guide.declineBackground();
    }
  }

  @override
  ConsumerState<PermissionPrimer> createState() => _PermissionPrimerState();
}

class _PermissionPrimerState extends ConsumerState<PermissionPrimer> with SingleTickerProviderStateMixin {
  /// The scene, played once as the sheet opens (and the lines after it).
  late final AnimationController _play = AnimationController(vsync: this, duration: AppMotion.revealLong);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _play.value = 1;
    } else if (_play.isDismissed) {
      _play.forward();
    }
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final color = widget.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: SizedBox(
              height: 156,
              child: RepaintBoundary(
                child: switch (widget.art) {
                  PrimerArt.notifications => _NoticeScene(play: _play, color: color, locale: locale),
                  PrimerArt.background => _LockScene(play: _play, color: color, locale: locale),
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: locale.getTextStyle(
                fontSize: AppFontSize.headline,
                fontWeight: FontWeight.w900,
                color: AppColors.textBright,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < widget.points.length; i++)
            _Point(
              icon: widget.points[i].$1,
              label: widget.points[i].$2,
              color: color,
              locale: locale,
              // One after the other, as the scene ends.
              reveal: CurvedAnimation(
                parent: _play,
                curve: Interval(0.45 + i * 0.12, 0.75 + i * 0.08, curve: AppMotion.enter),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                Haptics.confirm();
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: Text(
                strings.permAllow,
                style: locale.getTextStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.w800, color: AppColors.textBright),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () {
                Haptics.tap();
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(shape: const StadiumBorder()),
              child: Text(
                strings.permNotNow,
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of what the permission gives: its icon in a soft disc of the
/// primer's colour, then the words. Rises in with [reveal].
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.label, required this.color, required this.locale, required this.reveal});

  final IconData icon;
  final String label;
  final Color color;
  final LocaleProvider locale;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: reveal,
    child: AnimatedBuilder(
      animation: reveal,
      builder: (context, child) => Transform.translate(offset: Offset(0, 8 * (1 - reveal.value)), child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.bodyLg,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 0..1 across [begin, end] of [t].
double _span(double t, double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

/// The scene's ground: a glow of the primer's colour, for things to stand
/// in.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: 0.75,
        colors: [
          color.withValues(alpha: 0.16 * strength),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

/// Notifications: the bell rings, and a notice from the Radar drops in, as
/// Android would show it, with a second one behind it for depth.
class _NoticeScene extends StatelessWidget {
  const _NoticeScene({required this.play, required this.color, required this.locale});

  final Animation<double> play;
  final Color color;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return AnimatedBuilder(
      animation: play,
      builder: (context, _) {
        final t = play.value;
        // The bell: two swings that die away.
        final ring = t < 0.4 ? math.sin(t / 0.4 * math.pi * 4) * (1 - t / 0.4) * 0.45 : 0.0;
        final drop = _span(t, 0.18, 0.6, Curves.easeOutBack);
        final behind = _span(t, 0.3, 0.7);
        Widget notice({required double width, required double opacity, required bool main}) => Opacity(
          opacity: opacity,
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: main ? AppColors.surfaceCard : AppColors.surfaceCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withValues(alpha: main ? 0.10 : 0.05)),
              boxShadow: main ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))] : null,
            ),
            child: main
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentFill),
                            child: Image.asset('assets/images/tsuki_mask.webp', gaplessPlayback: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tsuki Tunes · ${strings.permNow}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.radarNotifSingle('Daft Punk', 'album'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, color: AppColors.textBright),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.permPreviewRelease,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : const SizedBox(height: 44),
          ),
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: _Glow(color: color, strength: 0.4 + 0.6 * drop),
            ),
            // The bell, above.
            Positioned(
              top: 0,
              child: Transform.rotate(
                angle: ring,
                alignment: Alignment.topCenter,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.notifications_active_rounded, color: color, size: 22),
                ),
              ),
            ),
            // The notice behind, then the one in front.
            Positioned(
              top: 72 + 14 * behind,
              child: Transform.scale(scale: 0.92, child: notice(width: 260, opacity: 0.5 * behind, main: false)),
            ),
            Positioned(
              top: 54 + 10 * drop,
              child: Transform.translate(
                offset: Offset(0, -26 * (1 - drop)),
                child: notice(width: 280, opacity: drop.clamp(0.0, 1.0), main: true),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Background: a phone, playing; its screen locks and goes dark, and the
/// song on it plays on: the bars keep moving, the time keeps running.
class _LockScene extends StatelessWidget {
  const _LockScene({required this.play, required this.color, required this.locale});

  final Animation<double> play;
  final Color color;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: play,
    builder: (context, _) {
      final t = play.value;
      final lock = _span(t, 0.25, 0.55, Curves.easeInOut);
      final played = 0.35 + 0.25 * t;
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: _Glow(color: color, strength: 0.4 + 0.6 * lock),
          ),
          Container(
            width: 92,
            height: 152,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.sheet + 2),
              border: Border.all(color: AppColors.borderGlow, width: 1.5),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12 + 0.12 * lock), blurRadius: 24)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sheet - 3),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Unlocked: the app, lit.
                  Opacity(
                    opacity: 1 - lock,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.crimsonInk, AppColors.surfaceCard],
                        ),
                      ),
                    ),
                  ),
                  // Locked: the clock and the moon.
                  Opacity(
                    opacity: lock,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          Icon(Icons.lock_rounded, size: 10, color: AppColors.textMuted.withValues(alpha: 0.8)),
                          const SizedBox(height: 4),
                          Text(
                            '23:41',
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.titleLg,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textBright,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // The song: stays lit, and plays on.
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.chip),
                                  gradient: const LinearGradient(colors: [AppColors.crimsonNeon, AppColors.neonPurple]),
                                ),
                              ),
                              const Spacer(),
                              _Bars(t: t, color: color),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: played,
                              minHeight: 2,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// A little equaliser, moving with [t].
class _Bars extends StatelessWidget {
  const _Bars({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 4; i++)
        Container(
          width: 3,
          height: 4 + 8 * (0.5 + 0.5 * math.sin(t * math.pi * 6 + i * 1.7)).abs(),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
    ],
  );
}

/// Android won't ask again (notifications turned off for Tsuki): says so,
/// with a way to its settings page.
void showNotificationsBlocked(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final strings = container.read(stringsProvider);
  AppSnack.of(context).info(
    strings.permNotifBlocked,
    actionLabel: strings.permOpenSettings,
    onAction: () => container.read(batteryGuideProvider).openTsukiSettings(),
  );
}
