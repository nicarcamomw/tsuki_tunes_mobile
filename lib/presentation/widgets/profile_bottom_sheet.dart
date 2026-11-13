import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firebase_emulators.dart';
import '../../core/constants/legal_links.dart';
import '../../core/localization/app_strings.dart';
import '../../core/logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../navigation/app_router.dart';
import '../navigation/routes.dart';
import '../screens/mask_collection_screen.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/auth_provider.dart';
import '../state/image_quality_setting.dart';
import '../state/locale_provider.dart';
import 'app_snack.dart';
import 'eco_widgets.dart';
import 'equalizer_sheet.dart';
import 'haptics.dart';
import 'language_selector_sheet.dart';
import 'oni_mask_art.dart';
import 'shuffle_mode_icon.dart';
import 'smart_shuffle_sheet.dart';
import 'swipeable_sheet.dart';
import 'weather_sheet.dart';

part 'profile/delete_account.dart';
part 'profile/logout.dart';
part 'profile/settings_sections.dart';
part 'profile/settings_widgets.dart';
part 'profile/spotify_card.dart';

final _log = Log.named('Profile');

class ProfileBottomSheet {
  static void show(BuildContext context, AuthProvider auth) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    SwipeableSheet.show(
      context,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (ctx, sheetController) =>
          _ProfileSheet(hostContext: context, auth: auth),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}

/// The sheet's content. [hostContext] is the screen that opened it: it
/// outlives the sheet, so navigation and snack bars that follow closing the
/// sheet go through it.
class _ProfileSheet extends ConsumerWidget {
  final BuildContext hostContext;
  final AuthProvider auth;

  const _ProfileSheet({required this.hostContext, required this.auth});

  /// Closes the sheet, then runs [then] on the host once it has gone.
  Future<void> _closeThen(
      BuildContext sheetContext, Future<void> Function() then) async {
    Navigator.pop(sheetContext);
    await Future.delayed(const Duration(milliseconds: 120));
    if (hostContext.mounted) await then();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SheetHandle(),
            _buildHeader(context, locale, strings),
            if (ref.watch(authProvider.select((a) => a.isAuthenticated))) ...[
              const SizedBox(height: 14),
              const EcoLevelCard(margin: EdgeInsets.zero),
            ],
            const SizedBox(height: 20),
            _SpotifyCard(hostContext: hostContext, locale: locale),
            const SizedBox(height: 20),
            _SectionHeader(locale: locale, title: strings.settingsPlaybackSection),
            const SizedBox(height: 8),
            _PlaybackSettings(hostContext: hostContext, locale: locale),
            const SizedBox(height: 20),
            _SectionHeader(locale: locale, title: strings.settingsStorageSection),
            const SizedBox(height: 8),
            _StorageSettings(hostContext: hostContext, locale: locale),
            const SizedBox(height: 20),
            _SectionHeader(locale: locale, title: strings.settingsGeneralSection),
            const SizedBox(height: 8),
            _GeneralSettings(
              hostContext: hostContext,
              locale: locale,
              closeThen: (then) => _closeThen(context, then),
            ),
            const SizedBox(height: 24),
            // ── Logout ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _confirmLogout(hostContext, auth);
                },
                icon: Icon(Icons.logout, color: AppColors.accent, size: 18, semanticLabel: strings.a11yLogout),
                label: Text(
                  strings.logoutOption,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (auth.isAuthenticated) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _confirmDeleteAccount(hostContext, auth);
                },
                icon: Icon(Icons.delete_forever_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                    semanticLabel: strings.a11yDeleteAccount),
                label: Text(
                  strings.deleteAccountOption,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _AppVersionLabel(locale: locale, hostContext: hostContext),
            // The data's sources, credited as they ask (Last.fm's API terms,
            // Open-Meteo's CC BY licence).
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Text(
                locale.strings.dataCredits,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar with the equipped mask, name, email and the masks shortcut.
  Widget _buildHeader(
      BuildContext context, LocaleProvider locale, AppStrings strings) {
    final masks = context.readState(maskProvider);
    final equipped = masks.equipped;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (auth.user?.photoURL != null)
              CircleAvatar(
                radius: 30,
                backgroundImage: ResizeImage(
                  CachedNetworkImageProvider(auth.user!.photoURL!),
                  width: imageCacheSize(hostContext, 60),
                ),
              )
            else
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.bgMid,
                child: Icon(Icons.person_rounded, color: AppColors.textMuted),
              ),
            if (equipped != null)
              Positioned(
                right: -14,
                bottom: -10,
                child: OniMaskArt(mask: equipped, size: 36, unlocked: true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          auth.user?.displayName ?? '',
          style: locale.getTextStyle(
            fontSize: AppFontSize.titleLg,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        Text(
          auth.user?.email ?? '',
          style: locale.getTextStyle(
            fontSize: AppFontSize.caption,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          onTap: () { Haptics.tap(); _closeThen(
              context, () => MaskCollectionScreen.open(hostContext)); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(AppRadius.sheet),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.theater_comedy_rounded, size: 15, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  '${strings.masksProfileRow} · ${strings.masksCount(masks.unlockedCount, masks.totalCount)}',
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        // Signed-in users have a public profile; guests don't.
        if (auth.isAuthenticated && auth.uid != null) ...[
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            onTap: () { Haptics.tap(); _closeThen(context, () => UserProfileRoute(uid: auth.uid!).push(hostContext)); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    strings.profileViewMine,
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.textBright),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            onTap: () { Haptics.tap(); _closeThen(context, () => const BondsRoute(tab: 1).push(hostContext)); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    strings.bondsTitle,
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.textBright),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
