import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/mask_provider.dart';
import '../providers/moon_provider.dart';
import '../screens/login_screen.dart';
import '../screens/mask_collection_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/audio_precache_service.dart';
import 'language_selector_sheet.dart';
import 'oni_mask_art.dart';

class ProfileBottomSheet {
  static void show(BuildContext context, AuthProvider auth) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final audioProvider = context.read<AudioProvider>();
        final moon = context.read<MoonProvider>();
        final masks = context.read<MaskProvider>();
        final spotify = audioProvider.spotify;
        final locale = context.read<LocaleProvider>();
        final strings = locale.strings;

        bool isConnecting = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.borderGlow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Profile header
                  Builder(builder: (_) {
                    final equipped = masks.equipped;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (auth.user?.photoURL != null)
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(auth.user!.photoURL!),
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
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    auth.user?.displayName ?? '',
                    style: locale.getTextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                  Text(
                    auth.user?.email ?? '',
                    style: locale.getTextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (context.mounted) await MaskCollectionScreen.open(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentDim,
                        borderRadius: BorderRadius.circular(20),
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
                              fontSize: 11,
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
                  const SizedBox(height: 20),

                  // ── Spotify connection ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: spotify.isConnected
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.music_note,
                              color: Colors.white, size: 20, semanticLabel: strings.a11yMusicNote),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spotify',
                                style: locale.getTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textBright,
                                ),
                              ),
                              Text(
                                isConnecting
                                    ? strings.spotifyConnecting
                                    : spotify.isConnected
                                        ? (spotify.isPremium
                                            ? 'Premium · ${spotify.displayName ?? strings.spotifyDefaultUser}'
                                            : '${strings.spotifyConnected} · ${spotify.displayName ?? strings.spotifyDefaultUser}')
                                        : strings.spotifyNotConnected,
                                style: locale.getTextStyle(
                                  fontSize: 10,
                                  color: isConnecting
                                      ? AppColors.accent
                                      : spotify.isConnected
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (spotify.isConnected)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.launch_rounded, size: 16, color: AppColors.accent, semanticLabel: strings.a11yOpenExternal),
                                tooltip: strings.openSpotifyTooltip,
                                onPressed: () => spotify.openSpotifyApp(),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await spotify.disconnect();
                                  await audioProvider.updateSpotifyState();
                                  setModalState(() {});
                                },
                                child: Text(
                                  strings.spotifyDisconnect,
                                  style: locale.getTextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (isConnecting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        else
                          OutlinedButton(
                            onPressed: () async {
                              isConnecting = true;
                              setModalState(() {});
                              try {
                                final success = await spotify.connect();
                                isConnecting = false;
                                if (success) {
                                  await audioProvider.updateSpotifyState();
                                  setModalState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          strings.spotifySyncSuccess,
                                          style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                                        ),
                                        backgroundColor: AppColors.bgCard,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {});
                                  if (context.mounted) {
                                    final rawError = spotify.lastError;
                                    String msg = strings.spotifyConnectError;
                                    if (rawError != null) {
                                      final lower = rawError.toLowerCase();
                                      if (lower.contains('cancel') || lower.contains('cancelada') || lower.contains('canceled_by_user')) {
                                        msg = strings.spotifyCanceledByUser;
                                      }
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          msg,
                                          style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                                        ),
                                        backgroundColor: AppColors.bgCard,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                isConnecting = false;
                                setModalState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: AppColors.error, size: 18, semanticLabel: strings.a11yPlaybackError),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              strings.spotifyConnectError,
                                              style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.bgCard,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(color: AppColors.error, width: 1.2),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                            ),
                            child: Text(
                              strings.spotifyConnect,
                              style: locale.getTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (spotify.isConnected) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            spotify.isPremium ? Icons.verified_rounded : Icons.info_outline_rounded,
                            size: 13,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              spotify.isPremium
                                  ? (spotify.activeDeviceName != null
                                      ? strings.spotifyActiveDevice(spotify.activeDeviceName!)
                                      : strings.spotifyPremiumActive)
                                  : strings.spotifyStandardPreview,
                              style: locale.getTextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── PLAYBACK section ──
                  _sectionHeader(locale, strings.settingsPlaybackSection),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _settingSwitch(
                          locale: locale,
                          icon: Icons.graphic_eq_rounded,
                          title: strings.crossfadeTitle,
                          subtitle: strings.crossfadeSubtitle,
                          value: audioProvider.crossfadeSeconds > 0,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            audioProvider.setCrossfadeSeconds(v ? 3 : 0);
                            setModalState(() {});
                          },
                        ),
                        if (audioProvider.crossfadeSeconds > 0) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Row(
                              children: [
                                Text(
                                  '0s',
                                  style: locale.getTextStyle(
                                    fontSize: 9,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(ctx).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: AppColors.accent,
                                      inactiveTrackColor: AppColors.border,
                                      thumbColor: AppColors.accent,
                                      overlayColor: AppColors.accent.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: audioProvider.crossfadeSeconds.toDouble(),
                                      min: 1,
                                      max: 12,
                                      divisions: 11,
                                      onChanged: (val) {
                                        final sec = val.round();
                                        audioProvider.setCrossfadeSeconds(sec);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  '12s',
                                  style: locale.getTextStyle(
                                    fontSize: 9,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                strings.crossfadeSecondsLabel(audioProvider.crossfadeSeconds),
                                style: locale.getTextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                        _settingSwitch(
                          locale: locale,
                          icon: Icons.task_alt_rounded,
                          title: strings.autoMarkTitle,
                          subtitle: strings.autoMarkSubtitle,
                          value: audioProvider.autoMarkListened,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            audioProvider.setAutoMarkListened(v);
                            setModalState(() {});
                          },
                        ),
                        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                        _settingSwitch(
                          locale: locale,
                          icon: Icons.equalizer_rounded,
                          title: strings.normalizeTitle,
                          subtitle: strings.normalizeSubtitle,
                          value: audioProvider.normalizeVolume,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            audioProvider.setNormalizeVolume(v);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── STORAGE section ──
                  _sectionHeader(locale, strings.settingsStorageSection),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _settingSwitch(
                          locale: locale,
                          icon: Icons.wifi_rounded,
                          title: strings.precacheWifiTitle,
                          subtitle: strings.precacheWifiSubtitle,
                          value: audioProvider.precacheWifiOnly,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            audioProvider.setPrecacheWifiOnly(v);
                            setModalState(() {});
                          },
                        ),
                        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AudioPrecacheService().clearCache();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.audioCacheCleared)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded,
                                    color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yClearCache),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.clearAudioCache,
                                    style: locale.getTextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── GENERAL section ──
                  _sectionHeader(locale, strings.settingsGeneralSection),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _settingSwitch(
                          locale: locale,
                          icon: Icons.nightlight_round,
                          title: strings.moonAtmosphereTitle,
                          subtitle: strings.moonAtmosphereSubtitle,
                          value: moon.atmosphereEnabled,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            moon.setAtmosphereEnabled(v);
                            setModalState(() {});
                          },
                        ),
                        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                        // Language
                        InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await Future.delayed(const Duration(milliseconds: 120));
                            if (context.mounted) {
                              LanguageSelectorSheet.show(context);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.language_rounded,
                                    color: AppColors.accent, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.languageOption,
                                    style: locale.getTextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textBright,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentDim,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    locale.currentLanguage.tag,
                                    style: locale.getTextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                        // Tutorial
                        InkWell(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await Future.delayed(const Duration(milliseconds: 120));
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (pushedCtx) => OnboardingScreen(
                                    onComplete: () {
                                      if (Navigator.of(pushedCtx).canPop()) {
                                        Navigator.of(pushedCtx).pop();
                                      }
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_stories_rounded,
                                    color: AppColors.neonCyan, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.tutorialOption,
                                    style: locale.getTextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textBright,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _confirmLogout(context, auth);
                      },
                      icon: Icon(Icons.logout, color: AppColors.accent, size: 18, semanticLabel: strings.a11yLogout),
                      label: Text(
                        strings.logoutOption,
                        style: locale.getTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  static Widget _sectionHeader(LocaleProvider locale, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: locale.getTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  static Widget _settingSwitch({
    required LocaleProvider locale,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      activeThumbColor: AppColors.accent,
      secondary: Icon(icon,
          size: 18, color: value ? AppColors.accent : AppColors.textMuted),
      title: Text(
        title,
        style: locale.getTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textBright,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
    );
  }

  static Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final locale = context.read<LocaleProvider>();
    final strings = locale.strings;
    final shouldLogout = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.logoutConfirmTitle,
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Text(
          strings.logoutConfirmMessage,
          style: locale.getTextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              strings.cancel,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              strings.logout,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await _handleLogout(context, auth);
    }
  }

  static Future<void> _handleLogout(BuildContext context, AuthProvider auth) async {
    try {
      final audioProvider = context.read<AudioProvider>();
      await audioProvider.stop();

      if (context.mounted) {
        context.read<LibraryProvider>().disconnectFirestore();
      }

      await auth.logout();
    } catch (e) {
      debugPrint('Error durante el cierre de sesión: $e');
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (route) => false,
        );
      }
    }
  }
}
