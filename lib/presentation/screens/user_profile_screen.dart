import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../../core/utils/image_cache_size.dart';
import '../../di/injection.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/profile_repository.dart';
import '../state/app_providers.dart';
import '../widgets/eco_widgets.dart' show EcoRank;
import '../widgets/haptics.dart';
import '../widgets/oni_mask_art.dart';
import '../widgets/skeleton_loader.dart';
import 'bonds_screen.dart';

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
            data: (p) => p == null
                ? _Unavailable(text: strings.profileUnavailable, uid: uid)
                : _ProfileBody(profile: p, own: false),
            loading: () => const SkeletonProfile(),
            error: (_, __) => _Unavailable(text: strings.profileUnavailable, uid: uid),
          );
    }
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: body,
    );
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.text, required this.uid});

  final String text;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A private profile reached by its link can still be asked for a Bond.
    final social = ref.watch(socialProvider);
    final known = [...social.received, ...social.sent, ...social.bonds].where((p) => p.uid == uid).firstOrNull;
    final person = known ?? SocialPerson(uid: uid, name: ref.watch(stringsProvider).ecoRankName(EcoRank.portador));
    return Center(
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
              if (social.available && social.me != uid) ...[
                const SizedBox(height: 20),
                BondButton(person: person),
              ],
            ],
          ),
        ),
      );
  }
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
        Text(profile.displayName, textAlign: TextAlign.center, style: style(AppFontSize.headline, weight: FontWeight.w800)),
        if (!own) ...[
          const SizedBox(height: 16),
          BondButton(
            person: SocialPerson(
                uid: profile.uid, name: profile.displayName, photoUrl: profile.photoUrl, maskId: profile.maskId),
          ),
          if (ref.watch(socialProvider.select((s) => s.available))) ...[
            const SizedBox(height: 16),
            _SintoniaCard(profile: profile),
          ],
        ],
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
          Text(strings.profileTopArtists, style: style(AppFontSize.body, color: AppColors.textSecondary).copyWith(letterSpacing: 2)),
          const SizedBox(height: 10),
          for (final (i, a) in profile.topArtists.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 26, child: Text('${i + 1}', style: style(AppFontSize.heading, color: AppColors.accent))),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.bgCard,
                    backgroundImage: a.pictureUrl == null
                        ? null
                        : ResizeImage(NetworkImage(a.pictureUrl!), width: imageCacheSize(context, 40)),
                    child: a.pictureUrl == null ? const Icon(Icons.person, color: AppColors.textMuted) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name, style: style(AppFontSize.title), overflow: TextOverflow.ellipsis)),
                  Text(strings.profileArtistSongs(a.count), style: style(AppFontSize.body, color: AppColors.textSecondary, weight: FontWeight.w500)),
                ],
              ),
            ),
        ],
        if (profile.milestones.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text((own ? strings.bondsYourResonances : strings.bondsTabResonances).toUpperCase(),
              style: style(AppFontSize.body, color: AppColors.textSecondary).copyWith(letterSpacing: 2)),
          const SizedBox(height: 10),
          for (final m in profile.milestones)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ResonanceTile(
                showPerson: false,
                resonance: Resonance(
                  person: SocialPerson(uid: profile.uid, name: profile.displayName),
                  milestone: m,
                ),
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

/// How close our music is: the percentage, its name, and the artists we
/// share.
class _SintoniaCard extends ConsumerWidget {
  const _SintoniaCard({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    // Mine is rebuilt as my library changes.
    ref.watch(profileControllerProvider);
    final s = ref.read(socialProvider).sintoniaWith(profile);
    final color = Color.lerp(AppColors.textMuted, AppColors.accent, (s.percent / 100).clamp(0.2, 1.0))!;
    return Semantics(
      label: '${strings.sintoniaTitle}: ${s.percent}%. ${strings.sintoniaLabel(s.percent)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(strings.sintoniaTitle.toUpperCase(),
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.label, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 2)),
                const Spacer(),
                Text('${s.percent}%',
                    style: locale.getTextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: s.percent / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: color,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(strings.sintoniaLabel(s.percent),
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, color: AppColors.textBright)),
            const SizedBox(height: 4),
            Text(
              s.shared.isEmpty
                  ? strings.sintoniaNone
                  : '${strings.sintoniaShared(s.shared.length)}: ${s.shared.take(5).join(', ')}${s.shared.length > 5 ? '…' : ''}',
              style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
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
            ? ClipOval(
                child: Image.network(photoUrl!,
                    width: size, height: size, fit: BoxFit.cover, cacheWidth: imageCacheSize(context, size)))
            : Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.textBright, fontSize: AppFontSize.hero, fontWeight: FontWeight.w800));
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
            Text('$value', style: locale.getTextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w800, color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                  Haptics.selection();
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
                ? () {
                    Haptics.tap();
                    SharePlus.instance.share(
                        ShareParams(text: strings.profileShareText(controller.shareLink!)));
                  }
                : null,
            icon: const Icon(Icons.share_rounded),
            label: Text(isPublic ? strings.profileShare : strings.profileMakePublicFirst),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentText,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
