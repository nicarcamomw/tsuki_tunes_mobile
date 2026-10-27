import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../core/utils/formatters.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/artist_albums_page.dart';
import '../models/track.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/deezer_api_service.dart';
import '../services/lastfm_service.dart';
import '../services/release_radar_service.dart';
import '../widgets/app_custom_icons.dart';
import '../widgets/distorted_artist_name.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/track_tile.dart';
import 'album_detail_screen.dart';
import 'artist_discography_screen.dart';
import 'main_navigation_screen.dart';
import 'rabbit_hole_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final DeezerApiService _api = DeezerApiService();
  final ScrollController _scrollController = ScrollController();
  // Entry points like the track menu only know the artist's id and name, so
  // the full profile (photos, fans, release count) is fetched on open.
  late Artist _artist = widget.artist;
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
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadArtistInfo();
    _loadArtistData();
    _trackVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
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
      context.read<LibraryProvider>().trackArtistVisit(_artist.name);
    });
  }

  bool get _needsArtistInfo =>
      _artist.pictureUrl.isEmpty ||
      (_artist.fansCount == 0 && _artist.albumsCount == 0);

  Future<void> _loadArtistInfo() async {
    if (!_needsArtistInfo) return;
    final full = await _api.getArtist(widget.artist.id);
    if (mounted && full != null) {
      setState(() => _artist = full);
    }
  }

  Future<void> _loadArtistData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
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
        _api.getArtistTopTracks(_artist.id, limit: 10),
        _api.getArtistAlbumsPage(_artist.id, limit: 250, index: 0),
        LastFmService.getArtistTags(_artist.name),
        _api.getArtistCompilations(_artist.id),
        _api.getRelatedArtists(_artist.id),
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

  bool _isOwnRelease(Album a) {
    if (a.artistId.isNotEmpty) return a.artistId == _artist.id;
    return a.artistName.toLowerCase().trim() ==
        _artist.name.toLowerCase().trim();
  }

  /// Own releases (albums, EPs, singles) grouped by type + title, so that
  /// duplicate editions (explicit/clean, re-uploads) count as one release.
  /// Features and compilations are excluded.
  List<List<Album>> get _ownReleaseGroups {
    final groups = <String, List<Album>>{};
    for (final a in _albums) {
      if (!_isOwnRelease(a)) continue;
      final key = '${a.recordType}|${a.title.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(a);
    }
    return groups.values.toList();
  }

  Map<String, List<Album>> get _categorizedAlbums {
    final Map<String, List<Album>> cats = {
      'album': [],
      'ep': [],
      'single': [],
      'appears_on': [],
    };
    for (final a in _albums) {
      if (!_isOwnRelease(a)) {
        cats['appears_on']!.add(a);
      } else if (a.recordType == 'album') {
        cats['album']!.add(a);
      } else if (a.recordType == 'ep' || a.recordType == 'compile') {
        cats['ep']!.add(a);
      } else if (a.recordType == 'single') {
        cats['single']!.add(a);
      } else {
        cats['album']!.add(a);
      }
    }
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final library = context.watch<LibraryProvider>();

    library.ensureAlbumTrackCounts(_albums, _api.getAlbum);

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
    final isFollowed = library.isArtistFollowed(_artist.id);
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
        onRefresh: () => Future.wait([_loadArtistInfo(), _loadArtistData()]),
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
              duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
              child: Text(
                _artist.name,
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
              tooltip: strings.a11yBack,
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
                child: Icon(Icons.chevron_left,
                    color: AppColors.accent, size: 24, semanticLabel: strings.a11yBack),
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
                              const BoxShadow(
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
                  if (_artist.pictureUrl.isNotEmpty)
                    ExcludeSemantics(
                      child: CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (420).toDouble()),
                        imageUrl: _artist.getBestImage(size: 'xl'),
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
                    child: Semantics(
                      header: true,
                      child: DistortedArtistName(
                        name: _artist.name,
                        artistId: _artist.id,
                        fontSize: 30,
                      ),
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
                      if (_artist.fansCount > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppCustomIcons.persona(
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              strings.artistFans(Formatters.formatNumber(_artist.fansCount)),
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
                      if (_artist.albumsCount > 0)
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
                                strings.artistReleases(_artist.albumsCount),
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
                    Semantics(
                      button: true,
                      label: isFollowed ? strings.a11yUnfollowArtist : strings.a11yFollowArtist,
                      child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (isFollowed) {
                          library.unfollowArtist(_artist.id);
                        } else {
                          library.followArtist(_artist);
                          _announceRadar(strings);
                        }
                      },
                      child: AnimatedContainer(
                        duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
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
                              semanticLabel: isFollowed ? strings.a11yUnfollowArtist : strings.a11yFollowArtist,
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
                          if (cats['ep']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.ep(
                                  size: 15, color: AppColors.accent),
                              strings.epCountLabel(cats['ep']!.length),
                              locale,
                            ),
                          if (cats['single']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.nota(
                                  size: 15, color: AppColors.accent),
                              strings.singleCountLabel(cats['single']!.length),
                              locale,
                            ),
                          if (cats['appears_on']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.grupo(
                                  size: 15, color: AppColors.accent),
                              strings.appearsOnCountLabel(cats['appears_on']!.length),
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
                      Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
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
                            duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
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
            if (cats['ep']!.isNotEmpty)
              ..._buildCategorySection(strings.tabEps, cats['ep']!, 'ep', library, locale, strings, icon: Icons.album_outlined),
            if (cats['single']!.isNotEmpty)
              ..._buildCategorySection(strings.tabSingles, cats['single']!, 'single', library, locale, strings, icon: Icons.music_note_rounded),
            if (cats['appears_on']!.isNotEmpty)
              ..._buildCategorySection(strings.tabAppearsOn, cats['appears_on']!, 'appears_on', library, locale, strings, icon: Icons.groups_rounded),
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
                    Icon(icon, size: 16, color: AppColors.accent, semanticLabel: title),
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
                      unawaited(HapticFeedback.lightImpact());
                      final updated =
                          await appNavigatorKey.currentState?.push<List<Album>>(
                        MaterialPageRoute(
                          builder: (_) => ArtistDiscographyScreen(
                            artistId: _artist.id,
                            artistName: _artist.name,
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
                  child: _buildAlbumCover(album, isCompleted, strings),
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

  Widget _buildAlbumCover(Album album, bool isCompleted, AppStrings strings) {
    final image = ExcludeSemantics(
      child: album.coverUrl.isNotEmpty
          ? CachedNetworkImage(
            memCacheWidth: imageCacheSize(context, (200).toDouble()),
              imageUrl: album.coverUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              color: AppColors.bgMid,
              child: Icon(Icons.album, color: AppColors.accent, size: 40, semanticLabel: strings.a11yAlbumCover),
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

  /// Following is the moment the user wants alerts, so that's when we ask.
  Future<void> _announceRadar(AppStrings strings) async {
    final radar = ReleaseRadarService();
    if (!ReleaseRadarService.isSupported) return;
    await radar.askPermissionOnceForFollow();
    if (!mounted || !radar.notifyEnabled.value) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.radar, size: 16, color: AppColors.neonCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.radarFollowSnack(_artist.name),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
          ],
        ),
      ));
  }

  Widget _buildRelatedArtistsSection(LocaleProvider locale, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 16, color: AppColors.accent, semanticLabel: strings.a11yRelatedArtists),
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
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  appNavigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RabbitHoleScreen(seedArtist: widget.artist),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub, size: 12,
                          color: AppColors.neonPurple.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text(
                        strings.rabbitHoleViewGraph,
                        style: locale.getTextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonPurple,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
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
                return Semantics(
                  button: true,
                  label: artist.name,
                  child: GestureDetector(
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
                          child: ExcludeSemantics(child: ClipOval(
                            child: artist.pictureUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  memCacheWidth: imageCacheSize(context, (100).toDouble()),
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
                          )),
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
    final artistName = _artist.name;
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
      'appears_on': [],
    };
    for (final album in _albums) {
      if (!_isOwnRelease(album)) {
        albumCats['appears_on']!.add(album);
      } else if (album.recordType == 'ep' || album.recordType == 'compile') {
        albumCats['ep']!.add(album);
      } else if (album.recordType == 'single') {
        albumCats['single']!.add(album);
      } else {
        albumCats['album']!.add(album);
      }
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
                Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.accent, semanticLabel: strings.a11yStoredContent),
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
        // An opaque plate looks the same as the old backdrop blur over this
        // dark page, without blurring the screen on every scroll frame.
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.bgDeep),
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
                              child: _artist.pictureUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                    memCacheWidth: imageCacheSize(context, (44).toDouble()),
                                      imageUrl: _artist.pictureUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppColors.bgMid,
                                      child: Icon(Icons.person,
                                          color: AppColors.textMuted, size: 20, semanticLabel: strings.a11yArtistAvatar),
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
                                    albumCats['appears_on']!,
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
    LocaleProvider locale, {
    String? semanticLabel,
  }) {
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
                Icon(icon, size: 14, color: AppColors.accent, semanticLabel: semanticLabel ?? label),
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
