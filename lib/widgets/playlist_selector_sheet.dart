import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_cache_size.dart';
import '../models/track.dart';
import '../providers/app_providers.dart';
import '../providers/playlist_provider.dart';

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
                      fontSize: 14,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              onTap: () async {
                unawaited(HapticFeedback.lightImpact());
                final name = await showPlaylistNameDialog(context);
                if (name != null && name.trim().isNotEmpty && context.mounted) {
                  final provider = ref.read(playlistProvider);
                  // One write with the song in it: a second write right
                  // after would hit the database's one-write-per-second
                  // limit and leave the new playlist empty.
                  final created =
                      await provider.createPlaylist(name, tracks: [track]);
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
                              fontSize: 12,
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
                          fontSize: 14,
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
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: alreadyAdded
                          ? Icon(Icons.check,
                              color: AppColors.accent, size: 18, semanticLabel: strings.a11ySelected)
                          : null,
                      onTap: alreadyAdded
                          ? () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.trackAlreadyInPlaylist,
                                    style: locale.getTextStyle(
                                      fontSize: 12,
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
                              unawaited(HapticFeedback.lightImpact());
                              final provider =
                                  ref.read(playlistProvider);
                              final full = playlist.tracks.length >=
                                  PlaylistProvider.maxTracks;
                              // It shows in the playlist at once; the upload
                              // goes on in the background.
                              if (!full) {
                                unawaited(provider.addTrackToPlaylist(
                                    playlist.id, track));
                              }
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
                                        fontSize: 12,
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
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textBright,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: PlaylistProvider.maxNameLength,
        style: locale.getTextStyle(
          fontSize: 14,
          color: AppColors.textBright,
        ),
        decoration: InputDecoration(
          hintText: strings.playlistNameHint,
          hintStyle: locale.getTextStyle(
            fontSize: 14,
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
              fontSize: 12,
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
              fontSize: 12,
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
      await context.readState(playlistProvider).createPlaylist(name, tracks: tracks);
  if (created == null || !context.mounted) return created != null;
  final strings = context.readState(stringsProvider);
  final locale = context.readState(localeProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        strings.playlistCreated,
        style: locale.getTextStyle(
          fontSize: 12,
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
