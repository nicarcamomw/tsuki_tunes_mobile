import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
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
  void didUpdateWidget(_PlayingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating) {
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

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.queue,
    this.showListenedCheckbox = true,
    this.onUnmark,
  });

  @override
  Widget build(BuildContext context) {
    final currentTrackId = context.select<AudioProvider, String?>((a) => a.currentTrack?.id);
    final isAudioPlaying = context.select<AudioProvider, bool>((a) => a.isPlaying);
    final isListened = context.select<LibraryProvider, bool>((l) => l.isTrackListened(track.id));
    final locale = context.read<LocaleProvider>();
    final isCurrent = currentTrackId == track.id;
    final isPlaying = isCurrent && isAudioPlaying;

    return Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          context.read<AudioProvider>().playTrack(track, newQueue: queue);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showTrackMenu(context);
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
  }

  void _showTrackMenu(BuildContext context) {
    final strings = context.read<LocaleProvider>().strings;
    final locale = context.read<LocaleProvider>();
    final hasTrack = context.read<AudioProvider>().currentTrack != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: hasTrack ? 140 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: track.coverUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(color: AppColors.bgMid),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: locale.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBright,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.fullArtistName,
                          style: locale.getTextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
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
            ListTile(
              leading: const Icon(Icons.playlist_play, color: AppColors.accent),
              title: Text(
                strings.playNext,
                style: locale.getTextStyle(
                  fontSize: 14,
                  color: AppColors.textBright,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                context.read<AudioProvider>().playNext(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      strings.addedPlayNext,
                      style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                    ),
                    backgroundColor: AppColors.bgCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    margin: EdgeInsets.only(bottom: hasTrack ? 152 : 12, left: 16, right: 16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: AppColors.accent),
              title: Text(
                strings.addToQueue,
                style: locale.getTextStyle(
                  fontSize: 14,
                  color: AppColors.textBright,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                context.read<AudioProvider>().addToQueue(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      strings.addedToQueue,
                      style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                    ),
                    backgroundColor: AppColors.bgCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    margin: EdgeInsets.only(bottom: hasTrack ? 152 : 12, left: 16, right: 16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppColors.accent),
              title: Text(
                strings.addToPlaylist,
                style: locale.getTextStyle(
                  fontSize: 14,
                  color: AppColors.textBright,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                showPlaylistSelector(context, track);
              },
            ),
            if (track.artistId.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.accent),
                title: Text(
                  strings.goToArtist,
                  style: locale.getTextStyle(
                    fontSize: 14,
                    color: AppColors.textBright,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                  appNavigatorKey.currentState?.push(
                    MaterialPageRoute(
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
              ListTile(
                leading: const Icon(Icons.album_outlined, color: AppColors.accent),
                title: Text(
                  strings.goToAlbum,
                  style: locale.getTextStyle(
                    fontSize: 14,
                    color: AppColors.textBright,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                  appNavigatorKey.currentState?.push(
                    MaterialPageRoute(
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
            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }
}
