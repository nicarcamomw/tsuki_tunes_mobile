import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../di/injection.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../state/app_providers.dart';
import '../widgets/oni_mask_art.dart';

/// Someone's published profile (null: private or missing).
final publicProfileProvider = FutureProvider.autoDispose.family<PublicProfile?, String>(
  (ref, uid) => getIt<ProfileRepository>().getProfile(uid),
);

/// A user's profile: their numbers and top artists. Your own shows live,
/// with the public/private switch and the share button; someone else's is
/// read from the server and only shows when they made it public.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(profileControllerProvider);
    final mine = controller.uid == uid;
    final strings = ref.watch(stringsProvider);

    Widget body;
    if (mine) {
      body = _ProfileBody(profile: controller.current!, own: true);
    } else {
      body = ref.watch(publicProfileProvider(uid)).when(
            data: (p) => p == null ? _Unavailable(text: strings.profileUnavailable) : _ProfileBody(profile: p, own: false),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            error: (_, __) => _Unavailable(text: strings.profileUnavailable),
          );
    }
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: body,
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ],
          ),
        ),
      );
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.own});

  final PublicProfile profile;
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final locale = ref.watch(localeProvider);
    final mask = MaskCatalog.byId(profile.maskId);
    TextStyle style(double size, {Color color = AppColors.textBright, FontWeight weight = FontWeight.w700}) =>
        locale.getTextStyle(fontSize: size, fontWeight: weight, color: color);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      children: [
        Center(child: _Avatar(photoUrl: profile.photoUrl, mask: mask, name: profile.displayName)),
        const SizedBox(height: 12),
        Text(profile.displayName, textAlign: TextAlign.center, style: style(22, weight: FontWeight.w800)),
        const SizedBox(height: 24),
        Row(
          children: [
            _Stat(value: profile.stats.tracks, label: strings.profileSongs),
            const SizedBox(width: 10),
            _Stat(value: profile.stats.albums, label: strings.profileAlbums),
            const SizedBox(width: 10),
            _Stat(value: profile.stats.artists, label: strings.profileArtists),
          ],
        ),
        if (profile.topArtists.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(strings.profileTopArtists, style: style(12, color: AppColors.textSecondary).copyWith(letterSpacing: 2)),
          const SizedBox(height: 10),
          for (final (i, a) in profile.topArtists.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: style(16, color: AppColors.accent))),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.bgCard,
                    backgroundImage: a.pictureUrl == null ? null : NetworkImage(a.pictureUrl!),
                    child: a.pictureUrl == null ? const Icon(Icons.person, color: AppColors.textMuted) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name, style: style(14), overflow: TextOverflow.ellipsis)),
                  Text(strings.profileArtistSongs(a.count), style: style(12, color: AppColors.textSecondary, weight: FontWeight.w500)),
                ],
              ),
            ),
        ],
        if (own) ...[
          const SizedBox(height: 28),
          _OwnControls(profile: profile),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.mask, required this.name});

  final String? photoUrl;
  final OniMask? mask;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final Widget inner = mask != null
        ? OniMaskArt.image(mask!, size * 0.8)
        : photoUrl != null
            ? ClipOval(child: Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover))
            : Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.textBright, fontSize: 40, fontWeight: FontWeight.w800));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 2),
      ),
      child: inner,
    );
  }
}

class _Stat extends ConsumerWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text('$value', style: locale.getTextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: locale.getTextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Your own profile: public or private, and the link to share it.
class _OwnControls extends ConsumerWidget {
  const _OwnControls({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final controller = ref.watch(profileControllerProvider);
    final isPublic = controller.isPublic;
    return Column(
      children: [
        SwitchListTile(
          value: isPublic,
          onChanged: controller.available
              ? (v) {
                  HapticFeedback.selectionClick();
                  controller.setPublic(v);
                }
              : null,
          activeThumbColor: AppColors.accent,
          title: Text(strings.profilePublic, style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.w700)),
          subtitle: Text(isPublic ? strings.profilePublicHint : strings.profilePrivateHint,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isPublic && controller.shareLink != null
                ? () => SharePlus.instance.share(
                    ShareParams(text: strings.profileShareText(controller.shareLink!)))
                : null,
            icon: const Icon(Icons.share_rounded),
            label: Text(isPublic ? strings.profileShare : strings.profileMakePublicFirst),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
