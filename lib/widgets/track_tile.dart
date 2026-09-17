import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import 'audio_visualizer.dart';
import 'oni_mask_icon.dart';
import 'tap_scale.dart';

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
    final audio = context.watch<AudioProvider>();
    final library = context.watch<LibraryProvider>();
    final isCurrent = audio.currentTrack?.id == track.id;
    final isPlaying = isCurrent && audio.isPlaying;
    final isListened = library.isTrackListened(track.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          audio.playTrack(track, newQueue: queue);
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
              // Index or playing equalizer
              if (isCurrent)
                SizedBox(
                  width: 24,
                  child: AudioVisualizer(
                    isPlaying: isPlaying,
                    barCount: 3,
                    maxHeight: 14,
                    activeColor: AppColors.accent,
                  ),
                )
              else if (index != null)
                SizedBox(
                  width: 24,
                  child: Text(
                    (index! + 1).toString().padLeft(2, '0'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // Album Cover Thumbnail
              ClipRRect(
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

              const SizedBox(width: 14),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
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
                            style: GoogleFonts.plusJakartaSans(
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(width: 10),

              // Listened checkbox (mark/unmark)
              if (showListenedCheckbox)
                TapScale(
                  onTap: () {
                    if (isListened) {
                      if (onUnmark != null) {
                        onUnmark!();
                      } else {
                        library.unmarkTrack(track.id);
                      }
                    } else {
                      library.markTrack(track);
                    }
                  },
                  scaleDown: 0.8,
                  child: OniMaskIcon(
                    isActive: isListened,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
