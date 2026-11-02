part of '../profile_bottom_sheet.dart';

/// Asks before deleting the account, then deletes it: Google sign-in is
/// asked again, the data in Firestore and on this phone go, and the
/// sign-in account last.
Future<void> _confirmDeleteAccount(BuildContext context, AuthProvider auth) async {
  final locale = context.readState(localeProvider);
  final strings = locale.strings;
  final confirmed = await showDialog<bool>(
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
          const Icon(Icons.delete_forever_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              strings.deleteAccountConfirmTitle,
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        strings.deleteAccountConfirmMessage,
        style: locale.getTextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            strings.deleteAccountConfirm,
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
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  var progressShown = false;
  void showProgress() {
    if (progressShown) return;
    progressShown = true;
    unawaited(showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  strings.deleteAccountInProgress,
                  style: locale.getTextStyle(fontSize: 13, color: AppColors.textBright),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  final audio = context.readState(audioProvider);
  final library = context.readState(libraryProvider);
  final result = await auth.deleteAccount(beforeDelete: () async {
    // Shown once Google sign-in is done: only the deletion is waited on.
    if (context.mounted) showProgress();
    await audio.stop();
    // The Spotify link belongs to the person, not to this phone.
    await audio.spotify.disconnect();
    await audio.updateSpotifyState();
    // Nothing may sync the library back while it's being deleted.
    library.disconnectFirestore();
  });
  if (progressShown) navigator.pop();

  final message = switch (result) {
    AccountDeletionResult.deleted => strings.deleteAccountDone,
    AccountDeletionResult.offline => strings.deleteAccountOffline,
    AccountDeletionResult.failed => strings.deleteAccountFailed,
    AccountDeletionResult.cancelled => null,
  };
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
  if (!auth.isLoggedIn) router.go(AppPaths.login);
}
