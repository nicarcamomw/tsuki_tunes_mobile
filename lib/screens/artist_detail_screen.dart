import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/connectivity_provider.dart';
import '../core/localization/app_strings.dart';
import '../widgets/track_tile.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/distorted_artist_name.dart';
import '../widgets/app_custom_icons.dart';
import '../services/lastfm_service.dart';
import '../models/artist_albums_page.dart';
import 'album_detail_screen.dart';
import 'artist_discography_screen.dart';
import 'main_navigation_screen.dart';
import '../widgets/skeleton_loader.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final DeezerApiService _api = DeezerApiService();
  final ScrollController _scrollController = ScrollController();
  List<Track> _topTracks = [];
  List<Album> _albums = [];
  int _totalAlbums = 0;
  List<String> _artistTags = [];
  List<Artist> _relatedArtists = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _showStats = false;
  bool _showAllTracks = false;
  bool _showTitleInAppBar = false;
  bool _showStoredContent = false;
  bool _hasMoreAlbums = false;
  // Albums whose real track count has already been requested from Deezer.
  final Set<String> _trackCountRequests = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArtistData();
    _trackVisit();
  }

  void _onScroll() {
    final show = _scrollController.offset > 200;
    if (show != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _trackVisit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().trackArtistVisit(widget.artist.name);
    });
  }

  Future<void> _loadArtistData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _trackCountRequests.clear();
    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        _api.getArtistTopTracks(widget.artist.id, limit: 10),
        _api.getArtistAlbumsPage(widget.artist.id, limit: 250, index: 0),
        LastFmService.getArtistTags(widget.artist.name),
        _api.getArtistCompilations(widget.artist.id),
        _api.getRelatedArtists(widget.artist.id),
      ]);
      if (mounted) {
        final pagedAlbums = results[1] as ArtistAlbumsPage;
        final compilations = results[3] as List<Album>;
        final existingIds = pagedAlbums.items.map((a) => a.id).toSet();
        final uniqueCompilations =
            compilations.where((c) => !existingIds.contains(c.id)).toList();
        final allAlbums = [...pagedAlbums.items, ...uniqueCompilations];
        setState(() {
          _topTracks = results[0] as List<Track>;
          _albums = allAlbums;
          _totalAlbums = pagedAlbums.total + uniqueCompilations.length;
          _hasMoreAlbums = pagedAlbums.hasMore;
          _artistTags = results[2] as List<String>;
          _relatedArtists = results[4] as List<Artist>;
          _isLoading = false;
        });
        final library = context.read<LibraryProvider>();
        for (final a in allAlbums) {
          if (a.tracksCount > 0 && library.getAlbumTracksCount(a.id) <= 0) {
            library.registerAlbumTrackCount(a.id, a.tracksCount);
          }
        }
      }
    } catch (e) {
      debugPrint('[ArtistDetail] loadArtistData error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Deezer's artist/albums listing omits nb_tracks, so an album can only be
  /// judged complete once its real track count is known. Requests that count
  /// for every release with listened tracks and no known total. Runs from
  /// build so it also covers listened tracks that arrive after the screen
  /// loaded (Firestore sync, marking from the player or album screen).
  void _fetchMissingTrackCounts(LibraryProvider library) {
    if (_albums.isEmpty || !library.listenedTracksLoaded) return;
    final listenedAlbumIds =
        library.listenedTracks.map((t) => t.albumId).toSet();
    final toFetch = <Album>[];
    for (final a in _albums) {
      if (!listenedAlbumIds.contains(a.id)) continue;
      if (a.tracksCount > 0 || library.getAlbumTracksCount(a.id) > 0) continue;
      if (_trackCountRequests.add(a.id)) toFetch.add(a);
    }
    if (toFetch.isEmpty) return;

    Future.wait(toFetch.map((a) => _api.getAlbum(a.id))).then((results) {
      if (!mounted) return;
      for (final res in results) {
        if (res == null) continue;
        final count =
            res.tracks.isNotEmpty ? res.tracks.length : res.tracksCount;
        if (count > 0) library.registerAlbumTrackCount(res.id, count);
      }
    }).catchError((Object e) {
      debugPrint('[ArtistDetail] _fetchMissingTrackCounts error: $e');
    });
  }

  /// Own releases (albums, EPs, singles) grouped by type + title, so that
  /// duplicate editions (explicit/clean, re-uploads) count as one release.
  /// "Appears on" compilations are excluded: they are mostly other artists'
  /// tracks and would make the discography impossible to complete.
  List<List<Album>> get _ownReleaseGroups {
    final groups = <String, List<Album>>{};
    for (final a in _albums) {
      if (a.recordType == 'compile') continue;
      final key = '${a.recordType}|${a.title.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(a);
    }
    return groups.values.toList();
  }

  Map<String, List<Album>> get _categorizedAlbums {
    final Map<String, List<Album>> cats = {
      'album': [],
      'single_ep': [],
      'compile': [],
    };
    for (final a in _albums) {
      if (a.recordType == 'album') {
        cats['album']!.add(a);
      } else if (a.recordType == 'single' || a.recordType == 'ep') {
        cats['single_ep']!.add(a);
      } else if (a.recordType == 'compile') {
        cats['compile']!.add(a);
      }
    }
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final library = context.watch<LibraryProvider>();

    _fetchMissingTrackCounts(library);

    // The mask lights up when every own release has all its tracks listened.
    final releaseGroups = _ownReleaseGroups;
    final completedReleases = releaseGroups
        .where((group) => group.any((album) => library.isAlbumCompleted(
            album.id,
            albumTracksCount: album.tracksCount)))
        .length;
    final bool isArtistComplete = !_isLoading &&
        !_hasMoreAlbums &&
        releaseGroups.isNotEmpty &&
        completedReleases == releaseGroups.length;
    final isFollowed = library.isArtistFollowed(widget.artist.id);
    final isGuest = context.watch<AuthProvider>().isGuest;

    final cats = _categorizedAlbums;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadArtistData,
        child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero with parallax
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
            title: AnimatedOpacity(
              opacity: _showTitleInAppBar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.artist.name,
                style: locale.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.chevron_left,
                    color: AppColors.accent, size: 24),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message: isArtistComplete
                      ? strings.artistCompleteTooltip
                      : strings.artistDiscographyProgress(
                          completedReleases, releaseGroups.length),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isArtistComplete
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.4),
                        width: isArtistComplete ? 1.5 : 1,
                      ),
                      boxShadow: isArtistComplete
                          ? [
                              BoxShadow(
                                color: AppColors.accentGlow,
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: OniMaskIcon(
                      isActive: isArtistComplete,
                      size: 22,
                      showContainer: false,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.artist.pictureUrl.isNotEmpty)
                    ExcludeSemantics(
                      child: CachedNetworkImage(
                        imageUrl: widget.artist.getBestImage(size: 'xl'),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.45, 0.80, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x990B0D13),
                          AppColors.bgDeep,
                        ],
                      ),
                    ),
                  ),
                  // Name rendered directly on top of the photo with room for descenders
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 22,
                    child: DistortedArtistName(
                      name: widget.artist.name,
                      artistId: widget.artist.id,
                      fontSize: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      if (widget.artist.fansCount > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppCustomIcons.persona(
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              strings.artistFans(Formatters.formatNumber(widget.artist.fansCount)),
                              style: locale.getTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (widget.artist.albumsCount > 0)
                        Semantics(
                          button: true,
                          label: _showStats ? strings.a11yHideStats : strings.a11yShowStats,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showStats = !_showStats);
                            },
                            behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppCustomIcons.cd(
                                size: 16,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strings.artistReleases(widget.artist.albumsCount),
                                style: locale.getTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  decoration: _showStats
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationColor: AppColors.accent,
                                  decorationThickness: 2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _showStats ? 0.25 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                child: const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                    ],
                  ),

                  // Follow button
                  if (!isGuest) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (isFollowed) {
                          library.unfollowArtist(widget.artist.id);
                        } else {
                          library.followArtist(widget.artist);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: isFollowed
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFollowed
                                ? AppColors.accent
                                : AppColors.accent.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: isFollowed
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentGlow.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowed ? Icons.check : Icons.add,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFollowed
                                  ? strings.unfollowArtist
                                  : strings.followArtist,
                              style: locale.getTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Animated Glass Capsule Breakdown
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x730C0C12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (cats['album']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.libreria(
                                  size: 15, color: AppColors.accent),
                              strings.albumCountLabel(cats['album']!.length),
                              locale,
                            ),
                          if (_albums
                              .where((a) => a.recordType == 'ep')
                              .isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.ep(
                                  size: 15, color: AppColors.accent),
                              strings.epCountLabel(_albums.where((a) => a.recordType == 'ep').length),
                              locale,
                            ),
                          if (_albums
                              .where((a) => a.recordType == 'single')
                              .isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.nota(
                                  size: 15, color: AppColors.accent),
                              strings.singleCountLabel(_albums.where((a) => a.recordType == 'single').length),
                              locale,
                            ),
                          if (cats['compile']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.grupo(
                                  size: 15, color: AppColors.accent),
                              strings.appearsOnCountLabel(cats['compile']!.length),
                              locale,
                            ),
                        ],
                      ),
                    ),
                    crossFadeState: _showStats
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),

                  // Artist Category/Genre Tags
                  if (_artistTags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _artistTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            border:
                                Border.all(color: AppColors.accent, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            style: locale.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Top Tracks header
                  Row(
                    children: [
                      AppCustomIcons.fuego(
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strings.popularTracks,
                        style: locale.getTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Top Tracks
          if (_isLoading)
            const ArtistDetailSkeletonLoader()
          else if (_hasError && _topTracks.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        strings.loadError,
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
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _loadArtistData();
                        },
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
          else if (_topTracks.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  strings.noTracksFound,
                  style: locale.getTextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  for (int i = 0; i < (_topTracks.length > 5 ? 5 : _topTracks.length); i++)
                    TrackTile(
                      track: _topTracks[i],
                      index: i,
                      queue: _topTracks,
                    ),
                  if (_topTracks.length > 5)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: _showAllTracks
                            ? [
                                for (int i = 5; i < _topTracks.take(10).length; i++)
                                  TrackTile(
                                    track: _topTracks[i],
                                    index: i,
                                    queue: _topTracks,
                                  ),
                              ]
                            : const [],
                      ),
                    ),
                  if (_topTracks.length > 5)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Semantics(
                          button: true,
                          label: _showAllTracks ? strings.a11yShowLessTracks : strings.a11yShowAllTracks,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showAllTracks = !_showAllTracks);
                            },
                            child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.textBright.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.textBright.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showAllTracks ? strings.showLessTracks : strings.showMoreTracks,
                                  style: locale.getTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedRotation(
                                  turns: _showAllTracks ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
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
                ],
              ),
            ),
          ],

          // Discography by category
          // Stored content section
          if (!_isLoading) ...[
            SliverToBoxAdapter(
              child: _buildStoredContentSection(library, locale, strings),
            ),
          ],

          // Similar Artists
          if (!_isLoading && _relatedArtists.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRelatedArtistsSection(locale, strings),
            ),

          if (!_isLoading && _albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '// ',
                        style: locale.getTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextSpan(
                        text: strings.discography.replaceAll('// ', ''),
                        style: locale.getTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textBright,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (cats['album']!.isNotEmpty)
              ..._buildCategorySection(strings.tabAlbums, cats['album']!, 'album', library, locale, strings, icon: Icons.album_rounded),
            if (_albums.where((a) => a.recordType == 'ep').isNotEmpty)
              ..._buildCategorySection(
                strings.tabEps,
                _albums.where((a) => a.recordType == 'ep').toList(),
                'ep',
                library,
                locale,
                strings,
                icon: Icons.album_outlined,
              ),
            if (_albums.where((a) => a.recordType == 'single').isNotEmpty)
              ..._buildCategorySection(
                strings.tabSingles,
                _albums.where((a) => a.recordType == 'single').toList(),
                'single',
                library,
                locale,
                strings,
                icon: Icons.music_note_rounded,
              ),
            if (cats['compile']!.isNotEmpty)
              ..._buildCategorySection(strings.tabAppearsOn, cats['compile']!, 'compile', library, locale, strings, icon: Icons.groups_rounded),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      ),
      ),
      ),
    );
  }

  List<Widget> _buildCategorySection(
      String title, List<Album> albums, String filterKey, LibraryProvider library, LocaleProvider locale, AppStrings strings, {IconData? icon}) {
    const maxVisible = 8;
    final visible = albums.take(maxVisible).toList();
    final hasMore = albums.length > maxVisible;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                  ] else ...[
                    Container(
                      width: 3,
                      height: 14,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  Text(
                    title,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (hasMore)
                Semantics(
                  button: true,
                  label: strings.a11yViewDiscography,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final updated =
                          await appNavigatorKey.currentState?.push<List<Album>>(
                        MaterialPageRoute(
                          builder: (_) => ArtistDiscographyScreen(
                            artistId: widget.artist.id,
                            artistName: widget.artist.name,
                            albums: _albums,
                            totalAlbums: _totalAlbums,
                            initialFilter: filterKey,
                          ),
                        ),
                      );
                      if (mounted) {
                        if (updated != null && updated.length > _albums.length) {
                          setState(() {
                            _albums = updated;
                            _hasMoreAlbums = updated.length < _totalAlbums;
                          });
                        }
                        setState(() {});
                      }
                    },
                    child: Text(
                      strings.seeMore,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 4,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildDiscographyItem(context, visible[index], library, locale, strings),
            childCount: visible.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildDiscographyItem(
      BuildContext context, Album album, LibraryProvider library, LocaleProvider locale, AppStrings strings) {
    final isCompleted =
        library.isAlbumCompleted(album.id, albumTracksCount: album.tracksCount);

    return Semantics(
      button: true,
      label: '${album.title}, ${album.artistName}',
      child: GestureDetector(
        onTap: () async {
          await appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailScreen(album: album),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _buildAlbumCover(album, isCompleted),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.title,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCompleted ? AppColors.accent : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${album.year}  ·  ${strings.albumTypeLabel(album.recordType)}',
              style: locale.getTextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCover(Album album, bool isCompleted) {
    final image = ExcludeSemantics(
      child: album.coverUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: album.coverUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              color: AppColors.bgMid,
              child: const Icon(Icons.album, color: AppColors.accent, size: 40),
            ),
    );

    if (isCompleted) return image;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: image,
    );
  }

  Widget _buildRelatedArtistsSection(LocaleProvider locale, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                strings.similarArtists,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _relatedArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final artist = _relatedArtists[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appNavigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(artist: artist),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: artist.pictureUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: artist.getBestImage(size: 'medium'),
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                  )
                                : Container(
                                    color: AppColors.bgMid,
                                    child: const Icon(Icons.person,
                                        color: AppColors.textMuted, size: 36),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          style: locale.getTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (artist.fansCount > 0)
                          Text(
                            strings.artistFansCompact(
                                Formatters.formatNumber(artist.fansCount)),
                            style: locale.getTextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoredContentSection(
      LibraryProvider library, LocaleProvider locale, AppStrings strings) {
    final artistName = widget.artist.name;
    final artistNameLower = artistName.toLowerCase().trim();
    final albumIds = _albums.map((a) => a.id).toSet();

    final artistTracks = library.listenedTracks.where((t) {
      if (albumIds.contains(t.albumId)) return true;
      final trackArtists = t.artistName.toLowerCase().split(',').map((s) => s.trim());
      return trackArtists.any((a) => a == artistNameLower);
    }).toList();
    final songCount = artistTracks.length;

    final albumCats = <String, List<Album>>{
      'album': [],
      'ep': [],
      'single': [],
      'compile': [],
    };
    for (final album in _albums) {
      final key = albumCats.containsKey(album.recordType)
          ? album.recordType
          : 'album';
      albumCats[key]!.add(album);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  strings.storedContentTitle,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                // Header - tappable to expand
                Semantics(
                  button: true,
                  label: _showStoredContent ? strings.a11yCollapseStoredContent : strings.a11yExpandStoredContent,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showStoredContent = !_showStoredContent);
                    },
                    behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: widget.artist.pictureUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.artist.pictureUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppColors.bgMid,
                                      child: const Icon(Icons.person,
                                          color: AppColors.textMuted, size: 20),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.storedContentSongs(songCount),
                                style: locale.getTextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textBright,
                                ),
                              ),
                              Text(
                                strings.storedContentFrom(artistName),
                                style: locale.getTextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _showStoredContent ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: songCount > 0
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),

                // Expandable content
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  child: _showStoredContent
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            children: [
                              Container(
                                height: 1,
                                color: AppColors.border.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildStoredStat(
                                    Icons.album_rounded,
                                    strings.tabAlbums,
                                    albumCats['album']!,
                                    library,
                                    locale,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStoredStat(
                                    Icons.disc_full_rounded,
                                    strings.tabEps,
                                    albumCats['ep']!,
                                    library,
                                    locale,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildStoredStat(
                                    Icons.music_note_rounded,
                                    strings.tabSingles,
                                    albumCats['single']!,
                                    library,
                                    locale,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStoredStat(
                                    Icons.people_rounded,
                                    strings.tabAppearsOn,
                                    albumCats['compile']!,
                                    library,
                                    locale,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildStoredStat(
    IconData icon,
    String label,
    List<Album> albums,
    LibraryProvider library,
    LocaleProvider locale,
  ) {
    final completed =
        albums.where((a) => library.isAlbumCompleted(a.id, albumTracksCount: a.tracksCount)).length;
    final total = albums.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgDeep.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: completed > 0
                ? AppColors.accent.withValues(alpha: 0.3)
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: locale.getTextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completed/$total',
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: completed > 0 ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: AppColors.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed == total && total > 0
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(Widget icon, String label, LocaleProvider locale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: locale.getTextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
