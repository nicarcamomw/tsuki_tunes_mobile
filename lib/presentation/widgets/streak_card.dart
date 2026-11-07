import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../screens/streak_screen.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import 'haptics.dart';

/// The streak's flame: warm while the run is alive, grey once it's out.
const streakFlame = Color(0xFFFF8A3D);
const streakShield = Color(0xFF8FB8FF);

/// The epoch day's weekday, 1 (Monday) to 7 (Sunday).
int weekdayOf(int epochDay) => DateTime.fromMillisecondsSinceEpoch(epochDay * 86400000, isUtc: true).weekday;

/// The daily streak on Home: the days in a row, this week's days and what
/// today needs. Opens the streak screen.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final streak = masks.dayStreak;
    final state = masks.streakState;
    final alive = streak > 0;
    final today = masks.todayEpoch;
    final monday = today - (weekdayOf(today) - 1);

    TextStyle t(double size, {FontWeight w = FontWeight.w700, Color c = AppColors.textBright, double? spacing}) =>
        locale.getTextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: spacing);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Semantics(
        button: true,
        label: strings.a11yStreak,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Haptics.tap();
            StreakScreen.open(context);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (alive ? streakFlame : AppColors.border).withValues(alpha: alive ? 0.45 : 1)),
            ),
            child: Row(
              children: [
                StreakBadge(streak: streak, alive: alive, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alive ? '${strings.streakTitle} · ${strings.streakDays(streak).toUpperCase()}' : strings.streakTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(11, w: FontWeight.w800, c: alive ? streakFlame : AppColors.textMuted, spacing: 1.4),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            _WeekDot(
                              label: strings.streakWeekdays[i],
                              played: masks.playedOn(monday + i),
                              shielded: masks.shieldedOn(monday + i),
                              today: monday + i == today,
                              future: monday + i > today,
                            ),
                            if (i < 6) const SizedBox(width: 5),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (state == StreakState.done) ...[
                            const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.neonGreen),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              strings.streakStateShort(state.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t(10.5,
                                  w: FontWeight.w600,
                                  c: state == StreakState.atRisk ? AppColors.warning : AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round flame with the days in a row under it.
class StreakBadge extends StatelessWidget {
  final int streak;
  final bool alive;
  final double size;
  const StreakBadge({super.key, required this.streak, required this.alive, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = alive ? streakFlame : AppColors.textMuted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: alive
            ? const RadialGradient(colors: [Color(0xFF4A2412), Color(0xFF221410)])
            : const RadialGradient(colors: [AppColors.bgHover, AppColors.bgMid]),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
        boxShadow: alive ? [BoxShadow(color: streakFlame.withValues(alpha: 0.35), blurRadius: size * 0.35)] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department_rounded, color: color, size: size * 0.38),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: size * 0.27,
              height: 1,
              fontWeight: FontWeight.w900,
              color: alive ? AppColors.textBright : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  final String label;
  final bool played;
  final bool shielded;
  final bool today;
  final bool future;
  const _WeekDot({
    required this.label,
    required this.played,
    required this.shielded,
    required this.today,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final fill = played
        ? streakFlame
        : shielded
            ? streakShield.withValues(alpha: 0.25)
            : AppColors.bgMid;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: today ? Border.all(color: AppColors.textBright, width: 1.4) : null,
      ),
      child: shielded && !played
          ? const Icon(Icons.shield_rounded, size: 11, color: streakShield)
          : Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: played
                    ? const Color(0xFF2A1206)
                    : future
                        ? AppColors.textMuted.withValues(alpha: 0.4)
                        : AppColors.textMuted,
              ),
            ),
    );
  }
}
