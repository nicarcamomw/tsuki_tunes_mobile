import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_environment.dart';
import '../../core/logger.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/album.dart';
import '../navigation/routes.dart';
import '../state/album_downloads_provider.dart';
import '../state/app_providers.dart';
import '../state/use_cases.dart';
import '../widgets/album_progress_bar.dart';
import '../widgets/eco_widgets.dart' show becomeBearer;
import '../widgets/error_state.dart';
import '../widgets/haptics.dart';
import '../widgets/listened_undo.dart';
import '../widgets/pop_on_change.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/spectrum_wave_visualizer.dart';
import '../widgets/track_tile.dart';


final _log = Log.named('AlbumDetail');

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  late final _catalog = ref.read(musicCatalogProvider);
  final ScrollController _scroll = ScrollController();
  Album? _fullAlbum;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadAlbumDetails() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final isOnline = ref.read(connectivityProvider).isOnline;
    // A downloaded album opens without internet, with its songs.
    final saved = ref.read(albumDownloadsProvider).savedAlbum(widget.album.id);
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _hasError = saved == null;
          _fullAlbum = saved ?? widget.album;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final res = await _catalog.getAlbum(widget.album.id);
      if (mounted && res != null) {
        final totalTracks =
            res.tracks.isNotEmpty ? res.tracks.length : res.tracksCount;
        if (totalTracks > 0) {
          ref.read(libraryProvider).registerAlbumTrackCount(
                res.id,
                totalTracks,
              );
        }
        setState(() {
          _fullAlbum = res;
          _isLoading = false;
        });
        unawaited(_enrichTracks(res));
      } else if (mounted) {
        setState(() {
          _fullAlbum = widget.album;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log.severe('loadAlbumDetails error: $e');
      if (mounted) {
        setState(() {
          _hasError = saved == null;
          _fullAlbum = saved ?? widget.album;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enrichTracks(Album album) async {
    if (album.tracks.isEmpty) return;
    try {
      final enriched = await _catalog.enrichTracksWithContributors(album.tracks);
      if (mounted) {
        setState(() {
          _fullAlbum = album.copyWith(tracks: enriched);
        });
      }
    } catch (e) {
      _log.severe('enrichTracks error: $e');
    }
  }

  /// Downloads the album's previews, or offers to remove a download.
  Future<void> _onDownload(Album albumData) async {
    final strings = ref.read(localeProvider).strings;
    final downloads = ref.read(albumDownloadsProvider);
    final messenger = ScaffoldMessenger.of(context);
    Haptics.tap();
    if (ref.read(maskProvider).isObserver) {
      messenger.showSnackBar(SnackBar(
        content: Text(strings.downloadAlbumObserver),
        action: SnackBarAction(label: strings.ecoObserverAction, onPressed: () => becomeBearer(context)),
      ));
      return;
    }
    if (downloads.isDownloaded(albumData.id)) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(strings.downloadAlbumRemove),
          content: Text(strings.downloadAlbumRemoveBody(albumData.title)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.downloadAlbumRemove, style: const TextStyle(color: AppColors.accentText)),
            ),
          ],
        ),
      );
      if (remove == true) await downloads.remove(albumData.id);
      return;
    }
    if (!albumData.tracks.any((t) => t.previewUrl.isNotEmpty)) {
      messenger.showSnackBar(SnackBar(content: Text(strings.downloadAlbumNone)));
      return;
    }
    final all = await downloads.download(albumData);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(all ? strings.downloadAlbumDone : strings.downloadAlbumPartial)));
  }

  void _toggleAll(Album albumData) {
    Haptics.confirm();
    final toggle = ref.read(toggleAlbumListenedProvider);
    if (toggle.isAllListened(albumData)) {
      // A whole album unmarked by mistake comes back with one tap.
      unawaited(unmarkWithUndo(context, ref, [for (final t in albumData.tracks) t.id]));
    } else {
      unawaited(toggle(albumData));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final albumData = _fullAlbum ?? widget.album;
    final tracks = albumData.tracks;
    // Select only what the screen shows: watching the whole provider would
    // rebuild the album on every playback position tick.
    final audio = ref.read(audioProvider);
    final useSpotify = ref.watch(audioProvider.select((a) => a.useSpotify));
    final library = ref.watch(libraryProvider);

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
        onRefresh: () {
          Haptics.threshold();
          return _loadAlbumDetails();
        },
        child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
            leading: IconButton(
              tooltip: strings.a11yBack,
              icon: Icon(Icons.arrow_back, color: AppColors.textBright, semanticLabel: strings.a11yBack),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              strings.albumDetailsTitle,
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textBright,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: strings.shareAction,
                icon: Icon(Icons.share_rounded,
                    color: AppColors.accent, size: 20, semanticLabel: strings.shareAction),
                onPressed: () {
                  Haptics.tap();
                  SharePlus.instance.share(ShareParams(
                      text: strings.albumShareText(
                          albumData.title, albumData.artistName, appLink('album/${albumData.id}'))));
                },
              ),
              if (tracks.isNotEmpty) _DownloadButton(album: albumData, onTap: () => _onDownload(albumData)),
              if (albumData.link != null || useSpotify)
                IconButton(
                  tooltip: useSpotify ? 'Spotify' : 'Deezer',
                  icon: Icon(Icons.open_in_new,
                      color: AppColors.accent, size: 20, semanticLabel: strings.a11yOpenExternal),
                  onPressed: () async { Haptics.tap();
                    try {
                      if (audio.useSpotify) {
                        final searchQuery = Uri.encodeComponent(
                            '${albumData.title} ${albumData.artistName}');
                        final uri = Uri.parse(
                            'https://open.spotify.com/search/$searchQuery');
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } else if (albumData.link != null) {
                        // The link comes from the API: only ever open a
                        // Deezer web page, never another scheme or site.
                        final uri = Uri.tryParse(albumData.link!);
                        final host = uri?.host.toLowerCase() ?? '';
                        if (uri != null &&
                            uri.scheme == 'https' &&
                            (host == 'deezer.com' || host.endsWith('.deezer.com'))) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      }
                    } catch (e) {
                      _log.severe('Could not launch external album URL: $e');
                    }
                  },
                ),
            ],
          ),

          // Album Hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Cover with parallax
                  AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, child) {
                      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                      return Transform.translate(
                        offset: Offset(0, offset * 0.25),
                        child: child,
                      );
                    },
                    child: Center(
                    child: Hero(
                      tag: 'album-cover-${widget.album.id}',
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
                          child: ExcludeSemantics(
                            child: (albumData.coverXl ?? albumData.coverUrl)
                                    .isNotEmpty
                                ? CachedNetworkImage(
                                  memCacheWidth: imageCacheSize(context, (260).toDouble()),
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
                      style: locale.getTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Semantics(
                    header: true,
                    child: Text(
                      albumData.title,
                      style: locale.getTextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Artist name (clickable)
                  Semantics(
                    button: true,
                    label: strings.goToArtist,
                    child: GestureDetector(
                      onTap: () async {
                        Haptics.tap();
                        // The artist page loads the profile from the id.
                        if (albumData.artistId.isNotEmpty) {
                          unawaited(ArtistRoute(id: albumData.artistId).push(context));
                        }
                      },
                      child: Text(
                        albumData.artistName,
                        style: locale.getTextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
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
                      // Guests have no listened marks (they need an account).
                      if (!ref.watch(authProvider.select((a) => a.isGuest)))
                        // Mark all / All listened
                        Expanded(
                          child: Material(
                            color: allListened
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: tracks.isNotEmpty
                                  ? () => _toggleAll(albumData)
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
                                    PopOnChange(
                                      value: allListened,
                                      child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: library.syncing
                                          ? const CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: AppColors.accent,
                                            )
                                          : Image.asset(
                                              'assets/images/tengu.png',
                                              color: allListened
                                                  ? AppColors.accent
                                                  : AppColors.textMuted,
                                              colorBlendMode: BlendMode.srcIn,
                                            ),
                                    ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      library.syncing
                                          ? strings.syncing
                                          : (allListened
                                              ? strings.allListened
                                              : strings.markAll),
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
                          onPressed: () { Haptics.tap();
                            ref.read(playTracksProvider)(tracks);
                          },
                          icon: Icon(Icons.play_arrow,
                              color: AppColors.accent, size: 18, semanticLabel: strings.a11yPlayAll),
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
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Spectrum wave visualizer separator
          const SliverToBoxAdapter(
            child: SpectrumWaveVisualizer(height: 36),
          ),

          // Tracklist
          if (_isLoading)
            const AlbumDetailSkeletonLoader()
          else if (_hasError && tracks.isEmpty)
            SliverToBoxAdapter(
              child: ErrorState(message: strings.loadError, onRetry: _loadAlbumDetails),
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

/// Download, its progress, or downloaded (tap to remove).
class _DownloadButton extends ConsumerWidget {
  final Album album;
  final VoidCallback onTap;
  const _DownloadButton({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localeProvider).strings;
    final downloads = ref.watch(albumDownloadsProvider);
    final progress = downloads.progressOf(album.id);
    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Semantics(
          label: strings.downloadAlbumProgress((progress * 100).round()),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress == 0 ? null : progress,
              strokeWidth: 2.4,
              color: AppColors.accent,
              backgroundColor: AppColors.border,
            ),
          ),
        ),
      );
    }
    final saved = downloads.isDownloaded(album.id);
    return IconButton(
      tooltip: saved ? strings.downloadAlbumRemove : strings.downloadAlbum,
      icon: Icon(saved ? Icons.download_done_rounded : Icons.download_rounded,
          color: saved ? AppColors.accent : AppColors.textBright,
          size: 22,
          semanticLabel: saved ? strings.downloadAlbumSaved : strings.downloadAlbum),
      onPressed: onTap,
    );
  }
}
