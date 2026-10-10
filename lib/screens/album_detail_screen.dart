import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_progress_bar.dart';
import '../widgets/spectrum_wave_visualizer.dart';
import '../widgets/oni_mask_icon.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../widgets/skeleton_loader.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final DeezerApiService _api = DeezerApiService();
  Album? _fullAlbum;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _fullAlbum = widget.album;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final res = await _api.getAlbum(widget.album.id);
      if (mounted && res != null) {
        final totalTracks =
            res.tracksCount > 0 ? res.tracksCount : res.tracks.length;
        if (totalTracks > 0) {
          context.read<LibraryProvider>().registerAlbumTrackCount(
                res.id,
                totalTracks,
              );
        }
        setState(() {
          _fullAlbum = res;
          _isLoading = false;
        });
        _enrichTracks(res);
      } else if (mounted) {
        setState(() {
          _fullAlbum = widget.album;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AlbumDetail] loadAlbumDetails error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _fullAlbum = widget.album;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enrichTracks(Album album) async {
    if (album.tracks.isEmpty) return;
    try {
      final enriched = await _api.enrichTracksWithContributors(album.tracks);
      if (mounted) {
        setState(() {
          _fullAlbum = album.copyWith(tracks: enriched);
        });
      }
    } catch (e) {
      debugPrint('[AlbumDetail] enrichTracks error: $e');
    }
  }

  void _toggleAll(Album albumData, LibraryProvider library) {
    HapticFeedback.mediumImpact();
    final tracks = albumData.tracks;
    final trackIds = tracks.map((t) => t.id).toList();
    final listenedInAlbum =
        trackIds.where((id) => library.isTrackListened(id)).toList();
    final allListened = listenedInAlbum.length >= tracks.length;

    if (allListened) {
      library.unmarkAlbumTracks(trackIds);
    } else {
      final toMark =
          tracks.where((t) => !library.isTrackListened(t.id)).toList();
      library.markAlbumTracks(
        toMark,
        albumId: albumData.id,
        totalTracks: albumData.tracksCount > 0
            ? albumData.tracksCount
            : tracks.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final albumData = _fullAlbum ?? widget.album;
    final tracks = albumData.tracks;
    final audio = context.read<AudioProvider>();
    final library = context.watch<LibraryProvider>();

    final trackIds = tracks.map((t) => t.id).toList();
    final listenedCount =
        trackIds.where((id) => library.isTrackListened(id)).length;
    final allListened = listenedCount >= tracks.length && tracks.isNotEmpty;
    final totalDuration = albumData.totalDurationSeconds;
    final typeLabel = strings.albumTypeLabel(albumData.recordType);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadAlbumDetails,
        child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textBright),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              strings.albumDetailsTitle,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 2,
              ),
            ),
          ),

          // Album Hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Cover
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: allListened
                              ? AppColors.accent
                              : AppColors.accent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: allListened
                                ? AppColors.accent.withValues(alpha: 0.4)
                                : AppColors.accentGlow,
                            blurRadius: allListened ? 24 : 18,
                            spreadRadius: allListened ? 4 : 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: (albumData.coverXl ?? albumData.coverUrl)
                                .isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl:
                                    albumData.coverXl ?? albumData.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.bgMid),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.bgMid,
                                  child: const Icon(Icons.album,
                                      size: 50, color: AppColors.accent),
                                ),
                              )
                            : Container(
                                color: AppColors.bgMid,
                                child: const Icon(Icons.album,
                                    size: 50, color: AppColors.accent),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentDim,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      typeLabel.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    albumData.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 4),

                  // Artist name (clickable)
                  GestureDetector(
                    onTap: () async {
                      if (albumData.artistId.isNotEmpty) {
                        final artist =
                            await _api.getArtist(albumData.artistId);
                        if (mounted && artist != null) {
                          appNavigatorKey.currentState?.push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ArtistDetailScreen(artist: artist),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      albumData.artistName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Meta
                  Text(
                    strings.albumMeta(
                      albumData.year.isNotEmpty ? albumData.year : "N/A",
                      tracks.isNotEmpty ? tracks.length : albumData.tracksCount,
                      Formatters.formatSeconds(totalDuration),
                    ),
                    style: locale.getTextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress bar
                  if (tracks.isNotEmpty)
                    AlbumProgressBar(
                      listened: listenedCount,
                      total: tracks.length,
                    ),

                  const SizedBox(height: 14),

                  // Action buttons row
                  Row(
                    children: [
                      // Mark all / All listened
                      Expanded(
                        child: Material(
                          color: allListened
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: tracks.isNotEmpty
                                ? () => _toggleAll(albumData, library)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: allListened
                                      ? AppColors.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Image.asset(
                                      'assets/images/tengu.png',
                                      color: allListened
                                          ? AppColors.accent
                                          : AppColors.textMuted,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    allListened
                                        ? strings.allListened
                                        : strings.markAll,
                                    style: locale.getTextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: allListened
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play album
                      if (tracks.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            audio.playTrack(tracks.first, newQueue: tracks);
                          },
                          icon: const Icon(Icons.play_arrow,
                              color: AppColors.accent, size: 18),
                          label: Text(
                            strings.play,
                            style: locale.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      // Deezer link
                      if (albumData.link != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Deezer',
                          icon: const Icon(Icons.open_in_new,
                              color: AppColors.accent, size: 20),
                          onPressed: () async {
                            try {
                              final uri = Uri.parse(albumData.link!);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              debugPrint('Could not launch external album URL: $e');
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Sync indicator
                  if (library.syncing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.syncing,
                          style: locale.getTextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Spectrum wave visualizer separator
          SliverToBoxAdapter(
            child: SpectrumWaveVisualizer(height: 36),
          ),

          // Tracklist
          if (_isLoading)
            const AlbumDetailSkeletonLoader()
          else if (_hasError && tracks.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        strings.searchError,
                        style: locale.getTextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        button: true,
                        label: strings.retry,
                        child: GestureDetector(
                        onTap: _loadAlbumDetails,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            strings.retry,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (tracks.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    strings.noTracksAvailable,
                    style: locale.getTextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return TrackTile(
                    track: track,
                    index: index,
                    queue: tracks,
                  );
                },
                childCount: tracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      ),
      ),
      ),
    );
  }
}
