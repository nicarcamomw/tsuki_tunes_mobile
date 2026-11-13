import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_providers.dart';
import 'haptics.dart';

/// Why Tsuki wants a permission, just before Android asks for it: what it
/// gives, in a sentence or two, then "Allow" (which opens the system's own
/// dialog) or "Not now". Android 13+ shows its notification dialog at most
/// twice; asked cold, a "no" there is for good, so the system dialog only
/// comes after a yes here.
class PermissionPrimer extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const PermissionPrimer({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  /// True when the user chose "Allow".
  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) async {
    // As tall as its content, so both buttons always show (a fixed share
    // of the screen hid them on small phones and with large text); it
    // scrolls if the text needs more than the screen. Swipe down closes.
    final allowed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: PermissionPrimer(icon: icon, color: color, title: title, body: body),
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
      icon: Icons.notifications_active_rounded,
      color: AppColors.neonCyan,
      title: strings.permNotifTitle,
      body: strings.permNotifBody,
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
      icon: Icons.battery_charging_full_rounded,
      color: AppColors.success,
      title: strings.permBackgroundTitle,
      body: strings.permBackgroundBody,
    );
    if (allowed) {
      await guide.askToRunInBackground();
    } else {
      await guide.declineBackground();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: locale.getTextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textBright),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                Haptics.confirm();
                Navigator.of(context).pop(true);
              },
              child: Text(strings.permAllow,
                  style: locale.getTextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textBright)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.permNotNow,
                  style: locale.getTextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android won't ask again (notifications turned off for Tsuki): says so,
/// with a way to its settings page.
void showNotificationsBlocked(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final strings = container.read(stringsProvider);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgCard,
      content: Text(strings.permNotifBlocked, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      action: SnackBarAction(
        label: strings.permOpenSettings,
        textColor: AppColors.accentText,
        onPressed: () {
          Haptics.tap();
          container.read(batteryGuideProvider).openTsukiSettings();
        },
      ),
    ));
}
