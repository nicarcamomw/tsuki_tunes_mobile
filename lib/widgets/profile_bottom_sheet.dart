import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import 'language_selector_sheet.dart';

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
                  if (auth.user?.photoURL != null)
                    CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(auth.user!.photoURL!),
                  ),
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
                const SizedBox(height: 20),

                // Spotify connection
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgMid,
                    borderRadius: BorderRadius.circular(6),
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
                        child: const Icon(Icons.music_note,
                            color: Colors.white, size: 20),
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
                              icon: const Icon(Icons.launch_rounded, size: 16, color: AppColors.accent),
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
                                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${strings.errorPrefix}: $e',
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

                const SizedBox(height: 14),

                // Crossfade Progresivo (Ajustes de audio DJ)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgMid,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: audioProvider.crossfadeSeconds > 0
                          ? AppColors.neonCyan.withValues(alpha: 0.35)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: audioProvider.crossfadeSeconds > 0
                                  ? AppColors.neonCyan.withValues(alpha: 0.15)
                                  : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: audioProvider.crossfadeSeconds > 0
                                    ? AppColors.neonCyan
                                    : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: audioProvider.crossfadeSeconds > 0
                                  ? AppColors.neonCyan
                                  : AppColors.textMuted,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.crossfadeTitle,
                                  style: locale.getTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.textBright,
                                  ),
                                ),
                                Text(
                                  strings.crossfadeSubtitle,
                                  style: locale.getTextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: audioProvider.crossfadeSeconds > 0
                                  ? AppColors.neonCyan.withValues(alpha: 0.12)
                                  : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: audioProvider.crossfadeSeconds > 0
                                    ? AppColors.neonCyan.withValues(alpha: 0.7)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              audioProvider.crossfadeSeconds > 0
                                  ? strings.crossfadeSecondsLabel(audioProvider.crossfadeSeconds)
                                  : strings.crossfadeOff,
                              style: locale.getTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: audioProvider.crossfadeSeconds > 0
                                    ? AppColors.neonCyan
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(ctx).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppColors.neonCyan,
                          inactiveTrackColor: AppColors.border,
                          thumbColor: AppColors.neonCyan,
                          overlayColor: AppColors.neonCyan.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: audioProvider.crossfadeSeconds.toDouble(),
                          min: 0,
                          max: 12,
                          divisions: 12,
                          onChanged: (val) {
                            final sec = val.round();
                            audioProvider.setCrossfadeSeconds(sec);
                            setModalState(() {});
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0s (${strings.crossfadeOff})',
                              style: locale.getTextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '3s (${strings.crossfadeDJ})',
                              style: locale.getTextStyle(
                                fontSize: 9,
                                color: audioProvider.crossfadeSeconds == 3
                                    ? AppColors.neonCyan
                                    : AppColors.textMuted,
                                fontWeight: audioProvider.crossfadeSeconds == 3
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '12s (${strings.crossfadeMax})',
                              style: locale.getTextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Language Selector Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (context.mounted) {
                        LanguageSelectorSheet.show(context);
                      }
                    },
                    icon: const Icon(
                      Icons.language_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.languageOption,
                          style: locale.getTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
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
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tutorial & Masks guide
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.neonCyan,
                      size: 16,
                    ),
                    label: Text(
                      strings.tutorialOption,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.neonCyan.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Logout
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _confirmLogout(context, auth);
                    },
                    icon: const Icon(Icons.logout, color: AppColors.accent),
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
                        borderRadius: BorderRadius.circular(4),
                      ),
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
