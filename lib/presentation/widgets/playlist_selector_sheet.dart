import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/usecases/playlists/add_track_to_playlist.dart';
import '../state/app_providers.dart';
import '../state/use_cases.dart';
import 'haptics.dart';

Future<void> showPlaylistSelector(BuildContext context, Track track) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _PlaylistSelectorContent(track: track),
  );
}

class _PlaylistSelectorContent extends ConsumerWidget {
  final Track track;

  const _PlaylistSelectorContent({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);
    final playlists = ref.watch(playlistProvider).playlists;
    final sharedState = ref.watch(sharedPlaylistsProvider);
    final shared = sharedState.mine;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.playlist_add, color: AppColors.accent, size: 20, semanticLabel: strings.a11yAddToPlaylist),
                  const SizedBox(width: 10),
                  Text(
                    strings.selectPlaylist,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            ListTile(
              leading:
                  Icon(Icons.add_circle_outline, color: AppColors.accent, semanticLabel: strings.a11yCreatePlaylist),
              title: Text(
                strings.createPlaylist,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              onTap: () async {
                Haptics.tap();
                final name = await showPlaylistNameDialog(context);
                if (name != null && name.trim().isNotEmpty && context.mounted) {
                  final created =
                      await ref.read(createPlaylistProvider)(name, tracks: [track]);
                  if (created != null && context.mounted) {
                    final added = created.tracks.any((t) => t.id == track.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? strings.addedToPlaylist(created.name)
                                : strings.playlistCreated,
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBright,
                            ),
                          ),
                          backgroundColor: AppColors.bgCard,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            // Collaborative playlists: the song goes in for everyone.
            if (shared.isNotEmpty) ...[
              const Divider(color: AppColors.border, height: 1),
              for (final sp in shared)
                Builder(builder: (ctx) {
                  final added = sp.tracks.any((s) => s.track.id == track.id);
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.bgMid, borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.groups_rounded, color: AppColors.accent, size: 18),
                    ),
                    title: Text(sp.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w600,
                            color: added ? AppColors.textMuted : AppColors.textBright)),
                    subtitle: Text('${strings.sharedTitle} · ${strings.sharedMembers(sp.members.length)}',
                        style: locale.getTextStyle(fontSize: AppFontSize.label, color: AppColors.textSecondary)),
                    trailing: added ? const Icon(Icons.check, color: AppColors.accent, size: 18) : null,
                    onTap: added
                        ? null
                        : () async {
                            Haptics.confirm();
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            final ok = await sharedState.addTrack(sp.id, track);
                            messenger.showSnackBar(SnackBar(content: Text(ok ? sp.name : strings.bondsFailed)));
                          },
                  );
                }),
            ],
            if (playlists.isNotEmpty) ...[
              const Divider(color: AppColors.border, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (ctx, i) {
                    final playlist = playlists[i];
                    final alreadyAdded =
                        playlist.tracks.any((t) => t.id == track.id);
                    return Semantics(
                      selected: alreadyAdded,
                      child: ListTile(
                      leading: ExcludeSemantics(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: playlist.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                memCacheWidth: imageCacheSize(context, (40).toDouble()),
                                  imageUrl: playlist.coverUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.bgMid,
                                    child: const Icon(Icons.queue_music,
                                        color: AppColors.accent, size: 18),
                                  ),
                                )
                              : Container(
                                  color: AppColors.bgMid,
                                  child: const Icon(Icons.queue_music,
                                      color: AppColors.accent, size: 18),
                                ),
                        ),
                      )),
                      title: Text(
                        playlist.name,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w600,
                          color: alreadyAdded
                              ? AppColors.textMuted
                              : AppColors.textBright,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        strings.trackCountLabel(playlist.trackCount),
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.label,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: alreadyAdded
                          ? Icon(Icons.check,
                              color: AppColors.accent, size: 18, semanticLabel: strings.a11ySelected)
                          : null,
                      onTap: alreadyAdded
                          ? () {
                              Haptics.confirm();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.trackAlreadyInPlaylist,
                                    style: locale.getTextStyle(
                                      fontSize: AppFontSize.body,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textBright,
                                    ),
                                  ),
                                  backgroundColor: AppColors.bgCard,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : () {
                              Haptics.confirm();
                              final add = ref.read(addTrackToPlaylistProvider);
                              final full = add.check(playlist, track) ==
                                  AddToPlaylistResult.full;
                              // It shows in the playlist at once; the upload
                              // goes on in the background.
                              if (!full) unawaited(add(playlist, track));
                              {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      full
                                          ? strings.playlistFull
                                          : strings
                                              .addedToPlaylist(playlist.name),
                                      style: locale.getTextStyle(
                                        fontSize: AppFontSize.body,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textBright,
                                      ),
                                    ),
                                    backgroundColor: AppColors.bgCard,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                    ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Asks for a new playlist's name. Null when cancelled.
Future<String?> showPlaylistNameDialog(BuildContext context) {
  final strings = context.readState(stringsProvider);
  final locale = context.readState(localeProvider);
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        strings.newPlaylist,
        style: locale.getTextStyle(
          fontSize: AppFontSize.heading,
          fontWeight: FontWeight.w700,
          color: AppColors.textBright,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: PlaylistRepository.maxNameLength,
        style: locale.getTextStyle(
          fontSize: AppFontSize.title,
          color: AppColors.textBright,
        ),
        decoration: InputDecoration(
          hintText: strings.playlistNameHint,
          hintStyle: locale.getTextStyle(
            fontSize: AppFontSize.title,
            color: AppColors.textMuted,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (value) => Navigator.pop(ctx, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            strings.cancel,
            style: locale.getTextStyle(
              fontSize: AppFontSize.body,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(
            strings.create,
            style: locale.getTextStyle(
              fontSize: AppFontSize.body,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Creates a playlist named by the user with [tracks] (e.g. the queue) and
/// says so. Returns whether it was created.
Future<bool> saveTracksAsPlaylist(BuildContext context, List<Track> tracks) async {
  if (tracks.isEmpty) return false;
  final name = await showPlaylistNameDialog(context);
  if (name == null || name.trim().isEmpty || !context.mounted) return false;
  final created =
      await context.readState(createPlaylistProvider)(name, tracks: tracks);
  if (created == null || !context.mounted) return created != null;
  final strings = context.readState(stringsProvider);
  final locale = context.readState(localeProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        strings.playlistCreated,
        style: locale.getTextStyle(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w600,
          color: AppColors.textBright,
        ),
      ),
      backgroundColor: AppColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      duration: const Duration(seconds: 2),
    ),
  );
  return true;
}
