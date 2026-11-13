import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_font_size.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/mask_provider.dart';
import '../widgets/haptics.dart';
import '../widgets/oni_mask_art.dart';
import '../widgets/permission_primer.dart';
import '../widgets/streak_card.dart';

const _bg = Color(0xFF0A0B10);

/// The daily streak: days in a row, the best run, moon shields, the last
/// five weeks, the goals (and the masks they wake) and the reminder.
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StreakScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.streakTitle,
            style: locale.getTextStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.w900, color: streakFlame, letterSpacing: 3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _Hero(masks: masks, locale: locale, strings: strings),
          const SizedBox(height: 12),
          _Stats(masks: masks, locale: locale, strings: strings),
          const SizedBox(height: 22),
          _Label(locale: locale, text: strings.streakCalendar),
          const SizedBox(height: 10),
          _Calendar(masks: masks, strings: strings),
          const SizedBox(height: 22),
          _Label(locale: locale, text: strings.streakGoalsTitle),
          const SizedBox(height: 10),
          _Goals(masks: masks, locale: locale, strings: strings),
          const SizedBox(height: 22),
          _ShieldInfo(locale: locale, strings: strings),
          const SizedBox(height: 12),
          _ReminderSwitch(masks: masks, locale: locale, strings: strings),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final LocaleProvider locale;
  final String text;
  const _Label({required this.locale, required this.text});

  @override
  Widget build(BuildContext context) => Text(text,
      style: locale.getTextStyle(fontSize: AppFontSize.label, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 2));
}

class _Hero extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _Hero({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final streak = masks.dayStreak;
    final alive = streak > 0;
    final state = masks.streakState;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          center: const Alignment(0, -0.7),
          radius: 1.1,
          colors: alive
              ? const [Color(0xFF3A1A0C), Color(0xFF181010), Color(0xFF0D0D12)]
              : const [Color(0xFF1E2029), Color(0xFF13141B), Color(0xFF0D0D12)],
        ),
        border: Border.all(color: (alive ? streakFlame : AppColors.border).withValues(alpha: alive ? 0.4 : 1)),
      ),
      child: Column(
        children: [
          StreakBadge(streak: streak, alive: alive, size: 104),
          const SizedBox(height: 12),
          Text(strings.streakUnit(streak),
              style: locale.getTextStyle(
                  fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w900, color: alive ? streakFlame : AppColors.textMuted, letterSpacing: 4)),
          Text(strings.streakInARow,
              style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  switch (state) {
                    StreakState.done => Icons.check_circle_rounded,
                    StreakState.atRisk => Icons.schedule_rounded,
                    StreakState.shielded => Icons.shield_rounded,
                    _ => Icons.local_fire_department_outlined,
                  },
                  size: 18,
                  color: switch (state) {
                    StreakState.done => AppColors.neonGreen,
                    StreakState.atRisk => AppColors.warning,
                    StreakState.shielded => streakShield,
                    _ => AppColors.textMuted,
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(strings.streakStateText(state.name),
                      style: locale.getTextStyle(
                          fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _Stats({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final today = masks.todayEpoch;
    final date = DateTime.fromMillisecondsSinceEpoch(today * 86400000, isUtc: true);
    final firstOfMonth = today - (date.day - 1);
    var thisMonth = 0;
    for (var d = firstOfMonth; d <= today; d++) {
      if (masks.playedOn(d)) thisMonth++;
    }

    Widget tile(String label, Widget value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SizedBox(height: 26, child: Center(child: value)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.micro, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
              ],
            ),
          ),
        );

    final big = locale.getTextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: AppColors.textBright);

    return Row(
      children: [
        tile(strings.streakBest, Text('${masks.bestStreak}', style: big)),
        const SizedBox(width: 8),
        tile(
          strings.streakShields,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < MaskProvider.maxShields; i++)
                Icon(
                  i < masks.shields ? Icons.shield_rounded : Icons.shield_outlined,
                  size: 22,
                  color: i < masks.shields ? streakShield : AppColors.textMuted.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        tile(strings.streakThisMonth, Text('$thisMonth', style: big)),
      ],
    );
  }
}

/// The last five weeks, Monday to Sunday, today in the last row.
class _Calendar extends StatelessWidget {
  final MaskProvider masks;
  final AppStrings strings;
  const _Calendar({required this.masks, required this.strings});

  @override
  Widget build(BuildContext context) {
    final today = masks.todayEpoch;
    final start = today - (weekdayOf(today) - 1) - 28;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in strings.streakWeekdays)
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var w = 0; w < 5; w++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(child: Center(child: _DayCell(day: start + w * 7 + i, today: today, masks: masks))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int today;
  final MaskProvider masks;
  const _DayCell({required this.day, required this.today, required this.masks});

  @override
  Widget build(BuildContext context) {
    final played = masks.playedOn(day);
    final shielded = !played && masks.shieldedOn(day);
    final future = day > today;
    final date = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: played
            ? streakFlame.withValues(alpha: 0.85)
            : shielded
                ? streakShield.withValues(alpha: 0.18)
                : future
                    ? Colors.transparent
                    : AppColors.bgMid,
        border: day == today ? Border.all(color: AppColors.textBright, width: 1.5) : null,
      ),
      child: shielded
          ? const Icon(Icons.shield_rounded, size: 15, color: streakShield)
          : Text(
              '${date.day}',
              style: TextStyle(
                fontSize: AppFontSize.label,
                fontWeight: FontWeight.w800,
                color: played
                    ? const Color(0xFF2A1206)
                    : future
                        ? AppColors.textMuted.withValues(alpha: 0.35)
                        : AppColors.textMuted,
              ),
            ),
    );
  }
}

/// The streak goals: reached by the best run, chased by the current one.
/// Those that wake a mask show it.
class _Goals extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _Goals({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final best = masks.bestStreak;
    final current = masks.dayStreak;
    final lang = locale.currentLanguage;
    final rewards = {
      for (final m in MaskCatalog.all)
        if (m.counter == 'streak' && m.goal != null) m.goal!: m,
    };
    // The goals, plus any streak mask's goal that isn't one of them.
    final goals = {...MaskProvider.streakGoals, ...rewards.keys}.toList()..sort();
    return Column(
      children: [
        for (final g in goals)
          Builder(builder: (context) {
            final reached = best >= g;
            final mask = rewards[g];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: reached ? streakFlame.withValues(alpha: 0.45) : AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached ? streakFlame : AppColors.bgMid,
                    ),
                    child: Text('$g',
                        style: TextStyle(
                            fontSize: g >= 100 ? AppFontSize.bodyLg : AppFontSize.heading,
                            fontWeight: FontWeight.w900,
                            color: reached ? const Color(0xFF2A1206) : AppColors.textMuted)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mask == null ? strings.streakDays(g) : '${strings.streakDays(g)} · ${mask.name(lang)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                              fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, color: AppColors.textBright),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: reached ? 1 : current / g,
                            minHeight: 4,
                            backgroundColor: AppColors.bgMid,
                            color: reached ? streakFlame : streakFlame.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reached ? strings.streakGoalReached : strings.streakGoalLeft(g - current),
                          style: locale.getTextStyle(
                              fontSize: AppFontSize.label,
                              fontWeight: FontWeight.w600,
                              color: reached ? streakFlame : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (mask != null) ...[
                    const SizedBox(width: 10),
                    OniMaskArt(mask: mask, size: 44, unlocked: masks.isUnlocked(mask.id)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _ShieldInfo extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  const _ShieldInfo({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: streakShield.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: streakShield.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: streakShield, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.streakShieldTitle,
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.label, fontWeight: FontWeight.w900, color: streakShield, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                Text(strings.streakShieldText(MaskProvider.shieldEvery, MaskProvider.maxShields),
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.body, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderSwitch extends ConsumerStatefulWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _ReminderSwitch({required this.masks, required this.locale, required this.strings});

  @override
  ConsumerState<_ReminderSwitch> createState() => _ReminderSwitchState();
}

class _ReminderSwitchState extends ConsumerState<_ReminderSwitch> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(streakReminderProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = widget.strings;
    final reminder = ref.read(streakReminderProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: reminder.enabled,
      builder: (context, on, _) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_none_rounded, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.streakReminderTitle,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, color: AppColors.textBright)),
                  const SizedBox(height: 2),
                  Text(strings.streakReminderSubtitle(reminder.remindHour),
                      style: locale.getTextStyle(
                          fontSize: AppFontSize.label, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
            Switch(
              value: on,
              activeTrackColor: streakFlame,
              onChanged: (v) async {
                Haptics.selection();
                await reminder.setEnabled(v, widget.masks.streakForReminder);
                // Turned on but Android won't notify: a way to settings, or
                // the reminder would silently never come.
                if (v && mounted && !await ref.read(releaseRadarProvider).hasPermission() && mounted) {
                  showNotificationsBlocked(this.context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
