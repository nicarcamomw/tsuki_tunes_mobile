import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/image_cache_size.dart';
import '../models/playlist.dart';
import '../providers/audio_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final playlist = context.watch<PlaylistProvider>().getPlaylist(playlistId);

    if (playlist == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textBright, semanticLabel: strings.a11yBack),
            tooltip: strings.a11yBack,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            strings.noTracksAvailable,
            style: locale.getTextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: CustomScrollView(
        slivers: [
          // App bar with cover
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textBright, semanticLabel: strings.a11yBack),
              tooltip: strings.a11yBack,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon:
                    Icon(Icons.more_vert, color: AppColors.textBright, semanticLabel: strings.a11yMoreOptions),
                color: AppColors.bgCard,
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context, playlist);
                      break;
                    case 'delete':
                      _showDeleteDialog(context, playlist);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppColors.accent, size: 18, semanticLabel: strings.a11yEditPlaylist),
                        const SizedBox(width: 10),
                        Text(
                          strings.renamePlaylist,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            color: AppColors.textBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 18, semanticLabel: strings.a11yDeletePlaylist),
                        const SizedBox(width: 10),
                        Text(
                          strings.deletePlaylist,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.bgDeep,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: Column(
                      children: [
                        // Cover
                        ExcludeSemantics(child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: playlist.coverUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  memCacheWidth: imageCacheSize(context, (140).toDouble()),
                                    imageUrl: playlist.coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _buildPlaceholderCover(),
                                  )
                                : _buildPlaceholderCover(),
                          ),
                        )),
                        const SizedBox(height: 12),
                        // Name
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Semantics(
                            header: true,
                            child: Text(
                              playlist.name,
                              style: locale.getTextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Meta
                        Text(
                          strings.playlistMeta(
                            playlist.trackCount,
                            Formatters.formatSeconds(
                                playlist.totalDurationSeconds),
                          ),
                          style: locale.getTextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Play controls
          if (playlist.tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final audio = context.read<AudioProvider>();
                          audio.playTrack(playlist.tracks.first,
                              newQueue: playlist.tracks);
                        },
                        icon: const Icon(Icons.play_arrow,
                            color: AppColors.accent, size: 18),
                        label: Text(
                          strings.playAll,
                          style: locale.getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final shuffled =
                              List.of(playlist.tracks)..shuffle();
                          final audio = context.read<AudioProvider>();
                          audio.playTrack(shuffled.first,
                              newQueue: shuffled);
                        },
                        icon: const Icon(Icons.shuffle,
                            color: AppColors.accent, size: 18),
                        label: Text(
                          strings.shuffle,
                          style: locale.getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Empty state
          if (playlist.tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music,
                          size: 54, color: AppColors.borderGlow, semanticLabel: strings.a11yEmptyPlaylist),
                      const SizedBox(height: 12),
                      Text(
                        strings.emptyPlaylistTitle,
                        textAlign: TextAlign.center,
                        style: locale.getTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.emptyPlaylistSubtitle,
                        textAlign: TextAlign.center,
                        style: locale.getTextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Track list (reorderable)
          if (playlist.tracks.isNotEmpty)
            SliverReorderableList(
              itemCount: playlist.tracks.length,
              onReorderItem: (oldIndex, newIndex) {
                context
                    .read<PlaylistProvider>()
                    .reorderTrack(playlistId, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final track = playlist.tracks[index];
                return ReorderableDragStartListener(
                  key: ValueKey(track.id),
                  index: index,
                  child: Dismissible(
                    key: ValueKey('dismiss_${track.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      child: Icon(Icons.delete_outline,
                          color: Colors.redAccent, semanticLabel: strings.a11yRemoveFromPlaylist),
                    ),
                    onDismissed: (_) {
                      context
                          .read<PlaylistProvider>()
                          .removeTrackFromPlaylist(playlistId, track.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.removedFromPlaylist,
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
                    },
                    child: TrackTile(
                      track: track,
                      index: index,
                      queue: playlist.tracks,
                      showListenedCheckbox: false,
                    ),
                  ),
                );
              },
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.bgMid,
      child: const Icon(Icons.queue_music, color: AppColors.accent, size: 48),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, Playlist playlist) async {
    final strings = context.read<LocaleProvider>().strings;
    final locale = context.read<LocaleProvider>();
    final controller = TextEditingController(text: playlist.name);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          strings.renamePlaylist,
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
              strings.rename,
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

    if (name != null && name.trim().isNotEmpty && context.mounted) {
      unawaited(context.read<PlaylistProvider>().renamePlaylist(playlistId, name));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.playlistRenamed,
            style: locale.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textBright,
            ),
          ),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, Playlist playlist) async {
    final strings = context.read<LocaleProvider>().strings;
    final locale = context.read<LocaleProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          strings.deletePlaylist,
          style: locale.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        content: Text(
          strings.deletePlaylistConfirm(playlist.name),
          style: locale.getTextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.delete,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      unawaited(context.read<PlaylistProvider>().deletePlaylist(playlistId));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.playlistDeleted,
            style: locale.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textBright,
            ),
          ),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
