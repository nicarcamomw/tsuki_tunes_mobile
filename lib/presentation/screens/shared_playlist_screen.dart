import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/shared_playlist.dart';
import '../../domain/entities/social.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';
import 'bonds_screen.dart' show PersonAvatar;

/// One collaborative playlist, live.
final sharedPlaylistProvider = StreamProvider.autoDispose.family<SharedPlaylist?, String>(
  (ref, id) => ref.read(sharedPlaylistsProvider).repository.watch(id),
);

/// A collaborative playlist: its people (and who's invited), its songs with
/// who added each, and what each one can do: everyone plays, adds and
/// removes songs; the owner invites Bonds, renames and deletes it; the
/// others can leave.
class SharedPlaylistScreen extends ConsumerWidget {
  const SharedPlaylistScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final me = ref.watch(sharedPlaylistsProvider.select((c) => c.me));
    final async = ref.watch(sharedPlaylistProvider(id));
    final p = async.value;
    final owner = p != null && p.owner == me;

    Widget body;
    if (async.isLoading && p == null) {
      body = const SkeletonDetailPage();
    } else if (p == null || me == null || !(p.isMember(me) || p.isInvited(me))) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(strings.sharedGone,
              textAlign: TextAlign.center,
              style: locale.getTextStyle(fontSize: AppFontSize.title, color: AppColors.textSecondary)),
        ),
      );
    } else {
      body = _Body(playlist: p, me: me, locale: locale);
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        actions: [
          if (p != null && me != null && p.isMember(me))
            PopupMenuButton<String>(
              color: AppColors.bgCard,
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textBright),
              onSelected: (v) => _menu(context, ref, p, v),
              itemBuilder: (_) => [
                if (owner) PopupMenuItem(value: 'rename', child: Text(strings.sharedRename)),
                if (owner)
                  PopupMenuItem(value: 'delete', child: Text(strings.sharedDelete, style: const TextStyle(color: AppColors.accentText)))
                else
                  PopupMenuItem(value: 'leave', child: Text(strings.sharedLeave)),
              ],
            ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, SharedPlaylist p, String action) async {
    final strings = ref.read(stringsProvider);
    final c = ref.read(sharedPlaylistsProvider);
    switch (action) {
      case 'rename':
        final name = await _askName(context, strings.sharedRename, p.name, strings.cancel);
        if (name != null && name.trim().isNotEmpty) await c.rename(p.id, name.trim());
      case 'leave':
        if (await c.leave(p.id) && context.mounted) Navigator.of(context).maybePop();
      case 'delete':
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Text(strings.sharedDelete),
            content: Text(strings.sharedDeleteBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(strings.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(strings.sharedDelete, style: const TextStyle(color: AppColors.accentText)),
              ),
            ],
          ),
        );
        if (yes == true && await c.delete(p.id) && context.mounted) Navigator.of(context).maybePop();
    }
  }
}

/// Asks for a playlist name; null when cancelled.
Future<String?> _askName(BuildContext context, String title, String initial, String cancel) {
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        maxLength: 100,
        style: const TextStyle(color: AppColors.textBright),
        onSubmitted: (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(cancel)),
        TextButton(onPressed: () => Navigator.pop(d, field.text), child: const Text('OK')),
      ],
    ),
  );
}

/// Creates a collaborative playlist (asking its name) and opens it.
Future<void> createSharedPlaylist(BuildContext context, WidgetRef ref) async {
  final strings = ref.read(stringsProvider);
  final c = ref.read(sharedPlaylistsProvider);
  final name = await _askName(context, strings.sharedNew, '', strings.cancel);
  if (name == null || name.trim().isEmpty) return;
  final id = await c.create(name.trim());
  if (id != null && context.mounted) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SharedPlaylistScreen(id: id))));
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.playlist, required this.me, required this.locale});

  final SharedPlaylist playlist;
  final String me;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = locale.strings;
    final p = playlist;
    final c = ref.read(sharedPlaylistsProvider);
    final owner = p.owner == me;
    final invitedMe = p.isInvited(me) && !p.isMember(me);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SizedBox(
                width: 96,
                height: 96,
                child: p.coverUrl.isEmpty
                    ? const ColoredBox(
                        color: AppColors.bgCard, child: Icon(Icons.groups_rounded, color: AppColors.accent, size: 40))
                    : CachedNetworkImage(
                        imageUrl: p.coverUrl, memCacheWidth: imageCacheSize(context, 96), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.sharedTitle.toUpperCase(),
                      style: locale.getTextStyle(
                          fontSize: AppFontSize.micro, fontWeight: FontWeight.w900, color: AppColors.accent, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                  const SizedBox(height: 4),
                  Text('${strings.sharedMembers(p.members.length)} · ${strings.trackCountLabel(p.tracks.length)}',
                      style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (invitedMe)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
                  onPressed: () { Haptics.remove(); c.decline(p.id); },
                  child: Text(strings.sharedDecline),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill),
                  onPressed: () {
                    Haptics.confirm();
                    c.join(p.id);
                  },
                  child: Text(strings.sharedJoin, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill),
                  onPressed: p.tracks.isEmpty
                      ? null
                      : () { Haptics.tap();
                          final songs = [for (final s in p.tracks) s.track];
                          ref.read(audioProvider).playTrack(songs.first, newQueue: songs);
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(strings.sharedPlayAll, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              if (owner) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentText, side: const BorderSide(color: AppColors.accent)),
                    onPressed: () { Haptics.tap(); _showInvite(context, ref, p); },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(strings.sharedInvite),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 18),
        // The people: members first, then the invited.
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final uid in [...p.members, ...p.invited])
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onLongPress: owner && uid != me ? () { Haptics.longPress(); _confirmRemove(context, ref, p, uid); } : null,
                    child: Opacity(
                      opacity: p.isMember(uid) ? 1 : 0.5,
                      child: SizedBox(
                        width: 58,
                        child: Column(
                          children: [
                            PersonAvatar(person: SocialPerson(uid: uid, name: p.nameOf(uid)), size: 42),
                            const SizedBox(height: 4),
                            Text(
                              uid == p.owner
                                  ? strings.sharedOwnerTag
                                  : p.isMember(uid)
                                      ? p.nameOf(uid)
                                      : strings.sharedInvitedTag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (p.tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(strings.sharedEmpty,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textMuted, height: 1.4)),
          )
        else
          for (final (i, s) in p.tracks.indexed)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: s.track.coverUrl.isEmpty
                      ? const ColoredBox(color: AppColors.bgCard)
                      : CachedNetworkImage(
                          imageUrl: s.track.coverUrl, memCacheWidth: imageCacheSize(context, 44), fit: BoxFit.cover),
                ),
              ),
              title: Text(s.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.w700, color: AppColors.textBright)),
              subtitle: Text('${s.track.artistName} · ${strings.sharedAddedBy(p.nameOf(s.addedBy))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)),
              trailing: p.isMember(me) && (owner || s.addedBy == me)
                  ? IconButton(
                      tooltip: strings.cancel,
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textMuted, size: 20),
                      onPressed: () {
                        Haptics.remove();
                        c.removeTrack(p.id, s.track.id);
                      },
                    )
                  : null,
              onTap: p.isMember(me)
                  ? () { Haptics.tap();
                      final songs = [for (final x in p.tracks) x.track];
                      ref.read(audioProvider).playTrack(songs[i], newQueue: songs);
                    }
                  : null,
            ),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, SharedPlaylist p, String uid) async {
    final strings = ref.read(stringsProvider);
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(p.nameOf(uid)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(strings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(strings.bondsDecline, style: const TextStyle(color: AppColors.accentText)),
          ),
        ],
      ),
    );
    if (yes == true) await ref.read(sharedPlaylistsProvider).removePerson(p.id, uid);
  }

  Future<void> _showInvite(BuildContext context, WidgetRef ref, SharedPlaylist p) async {
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);
    final bonds = ref.read(socialProvider).bonds.where((b) => !p.isMember(b.uid) && !p.isInvited(b.uid)).toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.sharedInviteTitle.toUpperCase(),
                  style: locale.getTextStyle(
                      fontSize: AppFontSize.body, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 2)),
              const SizedBox(height: 10),
              if (bonds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(strings.sharedInviteNone,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary, height: 1.4)),
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
                          onTap: () async {
                            Haptics.confirm();
                            Navigator.pop(sheet);
                            await ref.read(sharedPlaylistsProvider).invite(p.id, b.uid);
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
