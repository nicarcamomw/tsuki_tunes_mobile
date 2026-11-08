

part of '../profile_bottom_sheet.dart';

Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
  final locale = context.readState(localeProvider);
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
            backgroundColor: AppColors.accentFill,
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

Future<void> _handleLogout(BuildContext context, AuthProvider auth) async {
  try {
    final audio = context.readState(audioProvider);
    await audio.stop();
    // The Spotify link belongs to the person, not the device: the next
    // account on this phone must not control their Spotify.
    await audio.spotify.disconnect();
    await audio.updateSpotifyState();

    if (context.mounted) {
      context.readState(libraryProvider).disconnectFirestore();
    }

    await auth.logout();
  } catch (e) {
    _log.severe('Error durante el cierre de sesión: $e');
  } finally {
    if (context.mounted) {
      // Signed out, the router shows the login on its own; this covers a
      // sign-out that failed halfway.
      GoRouter.of(context).go(AppPaths.login);
    }
  }
}
