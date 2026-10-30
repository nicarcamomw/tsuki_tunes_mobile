import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/cyber_page_route.dart';
import '../core/utils/formatters.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/album_detail_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/main_navigation_screen.dart';
import 'oni_mask_icon.dart';
import 'playlist_selector_sheet.dart';
import 'radio_control_sheet.dart';
import 'tap_scale.dart';

class _PlayingIndicator extends StatefulWidget {
  final bool isPlaying;

  const _PlayingIndicator({required this.isPlaying});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion && _controller.isAnimating) _controller.stop();
  }

  @override
  void didUpdateWidget(_PlayingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating && !_reduceMotion) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = widget.isPlaying ? _controller.value : 0.3;
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(height: 4 + 8 * _wave(t, 0.0)),
                const SizedBox(width: 2),
                _bar(height: 4 + 8 * _wave(t, 0.33)),
                const SizedBox(width: 2),
                _bar(height: 4 + 8 * _wave(t, 0.66)),
              ],
            );
          },
        ),
      ),
    );
  }

  double _wave(double t, double offset) {
    final v = (t + offset) % 1.0;
    return v < 0.5 ? v * 2 : 2 - v * 2;
  }

  Widget _bar({required double height}) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final int? index;
  final List<Track>? queue;
  final bool showListenedCheckbox;
  final VoidCallback? onUnmark;
  /// Swiping the song to the right adds it to the queue. Off where the row
  /// already has its own swipe (e.g. removing it from a playlist).
  final bool swipeToQueue;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.queue,
    this.showListenedCheckbox = true,
    this.onUnmark,
    this.swipeToQueue = true,
  });

  void _addToQueue(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.read<AudioProvider>().addToQueue(track);
    showTrackSnack(context, context.read<LocaleProvider>().strings.addedToQueue);
  }

  @override
  Widget build(BuildContext context) {
    final (currentTrackId, isAudioPlaying) = context.select<AudioProvider, (String?, bool)>(
        (a) => (a.currentTrack?.id, a.isPlaying));
    final isListened = context.select<LibraryProvider, bool>((l) => l.isTrackListened(track.id));
    final locale = context.read<LocaleProvider>();
    final isCurrent = currentTrackId == track.id;
    final isPlaying = isCurrent && isAudioPlaying;
    final strings = locale.strings;

    final tile = Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      customSemanticsActions: {
        CustomSemanticsAction(label: strings.addToQueue): () =>
            _addToQueue(context),
      },
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          context.read<AudioProvider>().playTrack(track, newQueue: queue);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showTrackActions(context, track);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.accentDim : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isCurrent
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              if (isCurrent)
                _PlayingIndicator(isPlaying: isPlaying)
              else if (index != null)
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      (index! + 1).toString().padLeft(2, '0'),
                      style: locale.getTextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // Album Cover Thumbnail
              ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: track.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (46).toDouble()),
                          imageUrl: track.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.bgMid),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgMid,
                            child: const Icon(Icons.music_note,
                                color: AppColors.accent, size: 20),
                          ),
                        )
                      : Container(
                          color: AppColors.bgMid,
                          child: const Icon(Icons.music_note,
                              color: AppColors.accent, size: 20),
                        ),
                ),
              ),
              ),

              const SizedBox(width: 14),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: locale.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isCurrent ? AppColors.accent : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (track.isExplicit) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'E',
                              style: locale.getTextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            track.fullArtistName,
                            style: locale.getTextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Duration
              Text(
                Formatters.formatSeconds(track.durationSeconds),
                style: locale.getTextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(width: 10),

              // Listened checkbox (mark/unmark) — disabled for guests
              if (showListenedCheckbox && !context.read<AuthProvider>().isGuest)
                Tooltip(
                  message: isListened
                      ? context.read<LocaleProvider>().strings.unmarkAsListened
                      : context.read<LocaleProvider>().strings.markAsListened,
                  child: TapScale(
                    semanticLabel: isListened
                        ? context.read<LocaleProvider>().strings.unmarkAsListened
                        : context.read<LocaleProvider>().strings.markAsListened,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final lib = context.read<LibraryProvider>();
                      if (isListened) {
                        if (onUnmark != null) {
                          onUnmark!();
                        } else {
                          lib.unmarkTrack(track.id);
                        }
                      } else {
                        lib.markTrack(track);
                      }
                    },
                    scaleDown: 0.8,
                    child: OniMaskIcon(
                      isActive: isListened,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
    if (!swipeToQueue) return tile;
    // Swipe right to queue it; the row springs back into place.
    return Dismissible(
      key: ValueKey('swipe_queue_${track.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      background: Container(
        color: AppColors.neonCyan.withValues(alpha: 0.14),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music, color: AppColors.neonCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.addToQueue,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.neonCyan,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        _addToQueue(context);
        return false;
      },
      child: tile,
    );
  }
}

/// A short confirmation for a song action, above the mini player (or
/// [bottom] from the screen's edge), with an optional undo-like [action].
void showTrackSnack(BuildContext context, String message,
    {SnackBarAction? action, double? bottom}) {
  final locale = context.read<LocaleProvider>();
  final hasTrack = context.read<AudioProvider>().currentTrack != null;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
      ),
      backgroundColor: AppColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      margin: EdgeInsets.only(
          bottom: bottom ?? (hasTrack ? 152 : 12), left: 16, right: 16),
      duration: Duration(seconds: action == null ? 2 : 4),
      action: action,
    ),
  );
}

/// An extra entry for [showTrackActions], shown first.
class TrackMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const TrackMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// The song actions sheet (play next, add to queue, playlists, artist,
/// album) for any song in the app, with [extra] entries on top.
void showTrackActions(BuildContext context, Track track,
    {List<TrackMenuAction> extra = const []}) {
  final strings = context.read<LocaleProvider>().strings;
  final locale = context.read<LocaleProvider>();
  final hasTrack = context.read<AudioProvider>().currentTrack != null;

  void showConfirmation(String message) => showTrackSnack(context, message);

  Widget menuItem({
    required IconData icon,
    required String label,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minTileHeight: 52,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20, semanticLabel: semanticLabel),
      ),
      title: Text(
        label,
        style: locale.getTextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textBright,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  // Root navigator so the sheet sits above the bottom bar and mini player
  // instead of being partially hidden behind them.
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bgCard,
    constraints: BoxConstraints(
      maxWidth: 600,
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                            memCacheWidth: imageCacheSize(context, (56).toDouble()),
                              imageUrl: track.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppColors.bgMid),
                              errorWidget: (_, __, ___) => Container(color: AppColors.bgMid),
                            )
                          : Container(color: AppColors.bgMid),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: locale.getTextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBright,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.fullArtistName,
                          style: locale.getTextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (track.albumTitle.isNotEmpty)
                          Text(
                            track.albumTitle,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 6),
            for (final a in extra)
              menuItem(
                icon: a.icon,
                label: a.label,
                semanticLabel: a.label,
                onTap: () {
                  Navigator.pop(ctx);
                  a.onTap();
                },
              ),
            menuItem(
              icon: Icons.sensors,
              label: strings.radioStart,
              semanticLabel: strings.radioStart,
              onTap: () {
                Navigator.pop(ctx);
                startRadioWithFeedback(context, track,
                    bottomMargin: hasTrack ? 152 : 12);
              },
            ),
            menuItem(
              icon: Icons.playlist_play,
              label: strings.playNext,
              semanticLabel: strings.a11yPlayNext,
              onTap: () {
                Navigator.pop(ctx);
                context.read<AudioProvider>().playNext(track);
                showConfirmation(strings.addedPlayNext);
              },
            ),
            menuItem(
              icon: Icons.queue_music,
              label: strings.addToQueue,
              semanticLabel: strings.a11yAddToQueue,
              onTap: () {
                Navigator.pop(ctx);
                context.read<AudioProvider>().addToQueue(track);
                showConfirmation(strings.addedToQueue);
              },
            ),
            menuItem(
              icon: Icons.playlist_add,
              label: strings.addToPlaylist,
              semanticLabel: strings.a11yAddToPlaylist,
              onTap: () {
                Navigator.pop(ctx);
                showPlaylistSelector(context, track);
              },
            ),
            if (track.artistId.isNotEmpty || track.albumId.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Divider(color: AppColors.border, height: 1),
              ),
            if (track.artistId.isNotEmpty)
              menuItem(
                icon: Icons.person_outline,
                label: strings.goToArtist,
                semanticLabel: strings.a11yGoToArtist,
                onTap: () {
                  Navigator.pop(ctx);
                  // ArtistDetailScreen fetches the full profile (photo,
                  // fans, releases) from the id on open.
                  appNavigatorKey.currentState?.push(
                    CyberPageRoute(
                      builder: (_) => ArtistDetailScreen(
                        artist: Artist(
                          id: track.artistId,
                          name: track.artistName,
                          pictureUrl: '',
                          fansCount: 0,
                          albumsCount: 0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (track.albumId.isNotEmpty)
              menuItem(
                icon: Icons.album_outlined,
                label: strings.goToAlbum,
                semanticLabel: strings.a11yGoToAlbum,
                onTap: () {
                  Navigator.pop(ctx);
                  appNavigatorKey.currentState?.push(
                    CyberPageRoute(
                      builder: (_) => AlbumDetailScreen(
                        album: Album(
                          id: track.albumId,
                          title: track.albumTitle,
                          coverUrl: track.coverUrl,
                          artistId: track.artistId,
                          artistName: track.artistName,
                          releaseDate: '',
                          recordType: 'album',
                          fansCount: 0,
                          tracksCount: 0,
                          tracks: [],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
