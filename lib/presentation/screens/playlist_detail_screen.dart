import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../state/app_providers.dart';
import '../state/use_cases.dart';
import '../widgets/app_snack.dart';
import '../widgets/detail_header.dart';
import '../widgets/haptics.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  // Songs only move or go away in edit mode (from the ⋮ menu), so a stray
  // touch while scrolling never reorders the playlist.
  bool _editing = false;

  String get playlistId => widget.playlistId;

  void _setEditing(bool value) {
    Haptics.selection();
    setState(() => _editing = value);
  }

  /// Takes [track] out of the playlist, with an undo that puts it back in
  /// the same place.
  void _remove(Track track, int index) {
    final strings = ref.read(stringsProvider);
    Haptics.remove();
    final undo = ref.read(removeTrackFromPlaylistProvider)(playlistId, track, index);
    AppSnack.of(context).undo(strings.removedFromPlaylist, onUndo: () {
      Haptics.tap();
      undo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final playlist = ref.watch(playlistProvider).getPlaylist(playlistId);

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
              fontSize: AppFontSize.title,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Back leaves edit mode first.
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _setEditing(false);
      },
      child: Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: CustomScrollView(
        slivers: [
          // App bar with cover
          // T-01: the detail pages' shared header.
          DetailHeader(
            title: playlist.name,
            backLabel: strings.a11yBack,
            actions: [
              if (_editing)
                TextButton(
                  onPressed: () => _setEditing(false),
                  child: Text(
                    strings.playlistEditDone,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                )
              else
              PopupMenuButton<String>(
                tooltip: strings.a11yMoreOptions,
                icon: DetailHeaderDisc(
                    child: Icon(Icons.more_vert, color: AppColors.textBright, size: 20, semanticLabel: strings.a11yMoreOptions)),
                color: AppColors.bgCard,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _setEditing(true);
                      break;
                    case 'rename':
                      _showRenameDialog(context, playlist);
                      break;
                    case 'delete':
                      _showDeleteDialog(context, playlist);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  if (playlist.tracks.isNotEmpty)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.low_priority_rounded,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            strings.playlistEdit,
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.bodyLg,
                              color: AppColors.textBright,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppColors.accent, size: 18, semanticLabel: strings.a11yEditPlaylist),
                        const SizedBox(width: 10),
                        Text(
                          strings.renamePlaylist,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.bodyLg,
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
                            fontSize: AppFontSize.bodyLg,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                        ],
            background: CoverTintBackdrop(
                coverUrl: playlist.coverUrl,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: Column(
                      children: [
                        // Cover
                        ExcludeSemantics(child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
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
                                fontSize: AppFontSize.headline,
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
                            fontSize: AppFontSize.body,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ),

          if (_editing)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 6),
                child: Text(
                  strings.playlistEditHint,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.caption,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

          // Play controls
          if (playlist.tracks.isNotEmpty && !_editing)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () { Haptics.tap();
                          ref.read(playTracksProvider)(playlist.tracks);
                        },
                        icon: const Icon(Icons.play_arrow,
                            color: AppColors.accent, size: 18),
                        label: Text(
                          strings.playAll,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.micro,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.chip)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () { Haptics.tap();
                          ref.read(playTracksProvider)(playlist.tracks, shuffled: true);
                        },
                        icon: const Icon(Icons.shuffle,
                            color: AppColors.accent, size: 18),
                        label: Text(
                          strings.shuffle,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.micro,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.chip)),
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
                          fontSize: AppFontSize.bodyLg,
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
                            fontSize: AppFontSize.body, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Track list: plain songs, or reorderable rows in edit mode
          if (playlist.tracks.isNotEmpty && !_editing)
            SliverList.builder(
              itemCount: playlist.tracks.length,
              itemBuilder: (context, index) {
                final track = playlist.tracks[index];
                return TrackTile(
                  key: ValueKey(track.id),
                  track: track,
                  index: index,
                  queue: playlist.tracks,
                  showListenedCheckbox: false,
                  menuActions: [
                    TrackMenuAction(
                      icon: Icons.remove_circle_outline,
                      label: strings.playlistRemoveFromThis,
                      onTap: () => _remove(track, index),
                    ),
                  ],
                );
              },
            ),
          if (playlist.tracks.isNotEmpty && _editing)
            SliverReorderableList(
              itemCount: playlist.tracks.length,
              onReorderStart: (_) => Haptics.longPress(),
              onReorderItem: (oldIndex, newIndex) {
                Haptics.selection();
                ref.read(reorderPlaylistProvider)(playlistId, oldIndex, newIndex);
              },
              proxyDecorator: (child, _, __) => Material(
                color: AppColors.bgCard,
                elevation: 6,
                shadowColor: AppColors.accent.withValues(alpha: 0.4),
                child: child,
              ),
              itemBuilder: (context, index) {
                final track = playlist.tracks[index];
                return _EditRow(
                  key: ValueKey(track.id),
                  track: track,
                  index: index,
                  onRemove: () => _remove(track, index),
                );
              },
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
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
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);
    final controller = TextEditingController(text: playlist.name);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          strings.renamePlaylist,
          style: locale.getTextStyle(
            fontSize: AppFontSize.titleLg,
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
              strings.rename,
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

    if (name != null && name.trim().isNotEmpty && context.mounted) {
      unawaited(ref.read(renamePlaylistProvider)(playlistId, name));
      AppSnack.of(context).info(strings.playlistRenamed);
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, Playlist playlist) async {
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          strings.deletePlaylist,
          style: locale.getTextStyle(
            fontSize: AppFontSize.titleLg,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        content: Text(
          strings.deletePlaylistConfirm(playlist.name),
          style: locale.getTextStyle(
            fontSize: AppFontSize.bodyLg,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.delete,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      unawaited(ref.read(deletePlaylistProvider)(playlistId));
      Navigator.pop(context);
      AppSnack.of(context).info(strings.playlistDeleted);
    }
  }
}

/// A song in edit mode: remove on the left, drag handle on the right. The
/// row itself doesn't react to touches, so scrolling can't move anything.
class _EditRow extends ConsumerWidget {
  final Track track;
  final int index;
  final VoidCallback onRemove;

  const _EditRow({
    super.key,
    required this.track,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onRemove,
            tooltip: strings.a11yRemoveFromPlaylist,
            icon: Icon(Icons.remove_circle_outline,
                color: Colors.redAccent,
                size: 22,
                semanticLabel: strings.a11yRemoveFromPlaylist),
          ),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: SizedBox(
                width: 42,
                height: 42,
                child: track.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, 42),
                        imageUrl: track.coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.bgMid),
                      )
                    : Container(color: AppColors.bgMid),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.fullArtistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Icon(Icons.drag_handle_rounded,
                  color: AppColors.textMuted,
                  size: 24,
                  semanticLabel: strings.a11yReorder),
            ),
          ),
        ],
      ),
    );
  }
}
