import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/party.dart';
import '../../domain/entities/social.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../widgets/app_snack.dart';
import '../widgets/eco_widgets.dart' show becomeBearer;
import '../widgets/haptics.dart';
import 'bonds_screen.dart' show PersonAvatar;

/// Listening together: open a party and invite Bonds, or join one you were
/// invited to; then the song, who's listening, and the way out.
class PartyScreen extends ConsumerWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final party = ref.watch(partyProvider);
    // The host's own card follows the player.
    final playing = ref.watch(audioProvider.select((a) => a.currentTrack));
    TextStyle style(double size, {Color color = AppColors.textBright, FontWeight w = FontWeight.w600}) =>
        locale.getTextStyle(fontSize: size, color: color, fontWeight: w, height: 1.4);

    Widget body;
    if (!party.available) {
      body = _Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(strings.partyObserver, textAlign: TextAlign.center, style: style(AppFontSize.title)),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill),
              onPressed: () => becomeBearer(context),
              child: Text(strings.ecoObserverAction),
            ),
          ],
        ),
      );
    } else if (party.inParty) {
      final p = party.party!;
      final hosting = party.hosting;
      final Track? track = hosting ? playing : p.track;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        children: [
          Text((hosting ? strings.partyYouHost : strings.partyHostedBy(p.hostName)).toUpperCase(),
              style: style(AppFontSize.caption, color: AppColors.accent, w: FontWeight.w900).copyWith(letterSpacing: 2)),
          const SizedBox(height: 14),
          _NowPlaying(track: track, locale: locale, empty: strings.partyNothing),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(hosting ? Icons.podcasts_rounded : (p.playing ? Icons.sync_rounded : Icons.pause_rounded),
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hosting
                      ? strings.partyListening(p.members.length)
                      : (p.playing ? strings.partySynced : strings.partyHostPaused),
                  style: style(AppFontSize.body, color: AppColors.success, w: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (!ref.watch(audioProvider.select((a) => a.useSpotify))) ...[
            const SizedBox(height: 6),
            Text(strings.partyPreviewNote, style: style(AppFontSize.caption, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final uid in [p.host, ...p.members, ...p.invited])
                Opacity(
                  opacity: p.invited.contains(uid) ? 0.45 : 1,
                  child: SizedBox(
                    width: 58,
                    child: Column(
                      children: [
                        PersonAvatar(person: SocialPerson(uid: uid, name: p.nameOf(uid)), size: 44),
                        const SizedBox(height: 4),
                        Text(p.invited.contains(uid) ? '...' : p.nameOf(uid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style(AppFontSize.micro, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (hosting)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentText,
                side: const BorderSide(color: AppColors.accent),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () { Haptics.tap(); _invite(context, ref, p); },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(strings.partyInvite),
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Haptics.remove();
              unawaited(party.leave());
            },
            child: Text(hosting ? strings.partyEnd : strings.partyLeave,
                style: style(AppFontSize.bodyLg, color: AppColors.textSecondary, w: FontWeight.w800)),
          ),
        ],
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        children: [
          if (party.ended) ...[
            Text(strings.partyEnded, style: style(AppFontSize.bodyLg, color: AppColors.textMuted)),
            const SizedBox(height: 12),
          ],
          const Icon(Icons.headphones_rounded, size: 56, color: AppColors.accent),
          const SizedBox(height: 14),
          Text(strings.partyHint, textAlign: TextAlign.center, style: style(AppFontSize.title)),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentFill, minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              Haptics.confirm();
              final ok = await party.host();
              if (!ok && context.mounted) {
                AppSnack.maybeOf(context)?.info(strings.bondsFailed);
              }
            },
            icon: const Icon(Icons.podcasts_rounded),
            label: Text(strings.partyOpen, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (party.invitations.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(strings.partyInvitations.toUpperCase(),
                style: style(AppFontSize.caption, color: AppColors.textMuted, w: FontWeight.w900).copyWith(letterSpacing: 2)),
            const SizedBox(height: 8),
            for (final inv in party.invitations)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PersonAvatar(person: SocialPerson(uid: inv.host, name: inv.hostName), size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(strings.partyHostedBy(inv.hostName),
                              style: style(AppFontSize.title, w: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border)),
                            onPressed: () { Haptics.remove(); party.decline(inv.host); },
                            child: Text(strings.sharedDecline),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill),
                            onPressed: () {
                              Haptics.confirm();
                              unawaited(party.join(inv.host));
                            },
                            child: Text(strings.sharedJoin, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: true,
        title: Text(strings.partyTitle.toUpperCase(),
            style: locale.getTextStyle(
                fontSize: AppFontSize.title, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 3)),
      ),
      body: body,
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref, Party p) async {
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);
    final bonds = ref
        .read(socialProvider)
        .bonds
        .where((b) => !p.members.contains(b.uid) && !p.invited.contains(b.uid))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.partyInvite.toUpperCase(),
                  style: locale.getTextStyle(
                      fontSize: AppFontSize.body, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 2)),
              const SizedBox(height: 8),
              if (bonds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(strings.sharedInviteNone,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in bonds)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: PersonAvatar(person: b, size: 40),
                          title: Text(b.name,
                              style: locale.getTextStyle(
                                  fontSize: AppFontSize.title, fontWeight: FontWeight.w700, color: AppColors.textBright)),
                          trailing: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent),
                          onTap: () {
                            Haptics.confirm();
                            Navigator.pop(sheet);
                            unawaited(ref.read(partyProvider).invite(b.uid));
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.track, required this.locale, required this.empty});
  final Track? track;
  final LocaleProvider locale;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              width: 72,
              height: 72,
              child: t == null || t.coverUrl.isEmpty
                  ? const ColoredBox(color: AppColors.bgMid, child: Icon(Icons.music_note_rounded, color: AppColors.textMuted))
                  : CachedNetworkImage(imageUrl: t.coverUrl, memCacheWidth: imageCacheSize(context, 72), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: t == null
                ? Text(empty, style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                              fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                      const SizedBox(height: 3),
                      Text(t.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: child));
}
