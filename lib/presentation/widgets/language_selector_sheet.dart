import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';
import 'tap_scale.dart';

class LanguageSelectorSheet extends ConsumerWidget {
  const LanguageSelectorSheet({super.key});

  static void show(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    SwipeableSheet.show(
      context,
      backgroundColor: AppColors.bgDeep,
      initialChildSize: 0.50,
      maxChildSize: 0.80,
      builder: (_, controller) => const LanguageSelectorSheet(),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final currentLang = locale.currentLanguage;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGlow,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.languageSelectorTitle,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.bodyLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBright,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.languageSelectorSubtitle,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: strings.a11yClose,
                  icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary, semanticLabel: strings.a11yClose),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Options List
            ...AppLanguage.values.map((lang) {
              final isSelected = lang == currentLang;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  selected: isSelected,
                  child: TapScale(
                  haptic: Haptics.selection,
                  onTap: () async {
                    if (!isSelected) {
                      await ref.read(localeProvider).setLanguage(
                            lang,
                            ref.read(storageProvider),
                          );
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  scaleDown: 0.98,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accentDim : AppColors.bgMid,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.border,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Tag box [ES] / [EN] / [JA]
                        Container(
                          width: 42,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.bgDeep,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.borderGlow,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            lang.tag,
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.bodyLg,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Clean Localized Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.label,
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.title,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.textBright
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.languageCardSubtitle(lang),
                                style: lang == AppLanguage.ja
                                    ? GoogleFonts.notoSansJp(
                                        fontSize: AppFontSize.caption,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      )
                                    : locale.getTextStyle(
                                        fontSize: AppFontSize.caption,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Active Indicator Pill / Radio
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentGlow,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  strings.activeStatus,
                                  style: locale.getTextStyle(
                                    fontSize: AppFontSize.micro,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderGlow,
                                width: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            }),

            const SizedBox(height: 6),

            // Information Notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgMid.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Text(
                strings.languageInfoNotice,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
