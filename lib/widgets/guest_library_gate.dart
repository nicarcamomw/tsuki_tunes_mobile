import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/cyber_page_route.dart';
import '../providers/app_providers.dart';
import '../screens/login_screen.dart';

class GuestLibraryGate extends ConsumerWidget {
  const GuestLibraryGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              semanticLabel: strings.a11yLoginRequired,
              size: 48,
              color: AppColors.accent.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              strings.guestLibraryTitle,
              style: locale.getTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textBright,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              strings.guestLibraryDesc,
              style: locale.getTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    CyberPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  strings.guestLoginAction,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
