import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/album_categorizer.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/lastfm_service.dart';
import '../../data/datasources/release_radar_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/artist_albums_page.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/artist_features.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/app_custom_icons.dart';
import '../widgets/distorted_artist_name.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/track_tile.dart';

part 'artist_detail/artist_header.dart';
part 'artist_detail/top_tracks.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  final DeezerApiService _api = DeezerApiService();
  final ScrollController _scrollController = ScrollController();
  // Entry points like the track menu only know the artist's id and name, so
  // the full profile (photos, fans, release count) is fetched on open.
  late Artist _artist = widget.artist;
  List<Track> _topTracks = [];
  /// Songs by others where this artist is featured.
  List<Track> _features = [];
  bool _showAllFeatures = false;
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
      ref.read(libraryProvider).trackArtistVisit(_artist.name);
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
    final isOnline = ref.read(connectivityProvider).isOnline;
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
        // Deezer's top mixes the artist's own songs with their features;
        // a longer list leaves enough of both after splitting them.
        _api.getArtistTopTracks(_artist.id, limit: 50),
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
        final split = ArtistFeatures.split(results[0] as List<Track>,
            artistId: _artist.id, artistName: _artist.name);
        setState(() {
          _topTracks = split.own.take(10).toList();
          _features = split.features.take(20).toList();
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

  bool _isOwnRelease(Album a) =>
      AlbumCategorizer.isOwnRelease(a, artistId: _artist.id, artistName: _artist.name);

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

  Map<String, List<Album>> get _categorizedAlbums =>
      AlbumCategorizer.categorize(_albums, artistId: _artist.id, artistName: _artist.name);

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final library = ref.watch(libraryProvider);

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
    final isGuest = ref.watch(authProvider.select((a) => a.isGuest));

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
          _ArtistHeroAppBar(
            artist: _artist,
            locale: locale,
            showTitle: _showTitleInAppBar,
            reduceMotion: _reduceMotion,
            isComplete: isArtistComplete,
            completedReleases: completedReleases,
            totalReleases: releaseGroups.length,
          ),

          SliverToBoxAdapter(
            child: _ArtistInfoSection(
              artist: _artist,
              locale: locale,
              categories: cats,
              tags: _artistTags,
              showStats: _showStats,
              onToggleStats: () => setState(() => _showStats = !_showStats),
              canFollow: !isGuest,
              isFollowed: isFollowed,
              onToggleFollow: () async {
                final followed = await ref.read(toggleFollowArtistProvider)(_artist);
                if (followed) unawaited(_announceRadar(strings));
              },
              reduceMotion: _reduceMotion,
            ),
          ),

          _TopTracksSliver(
            tracks: _topTracks,
            locale: locale,
            isLoading: _isLoading,
            hasError: _hasError,
            onRetry: _loadArtistData,
            showAll: _showAllTracks,
            onToggleShowAll: () =>
                setState(() => _showAllTracks = !_showAllTracks),
            reduceMotion: _reduceMotion,
          ),

          if (!_isLoading && _features.isNotEmpty)
            _FeaturesSliver(
              tracks: _features,
              locale: locale,
              showAll: _showAllFeatures,
              onToggleShowAll: () =>
                  setState(() => _showAllFeatures = !_showAllFeatures),
              reduceMotion: _reduceMotion,
            ),

          // Stored content section
          if (!_isLoading)
            SliverToBoxAdapter(
              child: _buildStoredContentSection(library, locale, strings),
            ),

          // Similar Artists
          if (!_isLoading && _relatedArtists.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRelatedArtistsSection(locale, strings),
            ),

          if (!_isLoading && _albums.isNotEmpty)
            ..._buildDiscographySlivers(cats, library, locale, strings),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      ),
      ),
      ),
    );
  }

  /// Discography heading, then one section per release type.
  List<Widget> _buildDiscographySlivers(Map<String, List<Album>> cats,
      LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings) {
    return [
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
        ..._buildCategorySection(strings.tabAppearsOn, cats['appears_on']!, 'appears_on', library, locale, strings, icon: Icons.groups_rounded, isAppearsOn: true),
    ];
  }

  List<Widget> _buildCategorySection(
      String title, List<Album> albums, String filterKey, LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings, {IconData? icon, bool isAppearsOn = false}) {
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
                          await ArtistDiscographyRoute(
                        id: _artist.id,
                        filter: filterKey,
                        $extra: DiscographyArgs(
                          artistName: _artist.name,
                          albums: _albums,
                          totalAlbums: _totalAlbums,
                        ),
                      ).push<List<Album>>(context);
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
                _buildDiscographyItem(context, visible[index], library, locale, strings, isAppearsOn: isAppearsOn),
            childCount: visible.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildDiscographyItem(
      BuildContext context, Album album, LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings,
      {bool isAppearsOn = false}) {
    final isCompleted =
        library.isAlbumCompleted(album.id, albumTracksCount: album.tracksCount);
    final subtitle = isAppearsOn
        ? '${album.year}  ·  ${album.artistName}'
        : '${album.year}  ·  ${strings.albumTypeLabel(album.recordType)}';

    return Semantics(
      button: true,
      label: '${album.title}, ${album.artistName}',
      child: GestureDetector(
        onTap: () async {
          await AlbumRoute(id: album.id, $extra: album).push(context);
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
              subtitle,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // The loaded artist, so the graph's centre has its
                    // picture and fans even when this page was opened from
                    // a bare link.
                    RabbitHoleRoute(id: _artist.id, $extra: _artist).push(context);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.neonPurple.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hub, size: 14,
                            color: AppColors.neonPurple.withValues(alpha: 0.9)),
                        const SizedBox(width: 6),
                        Text(
                          strings.rabbitHoleViewGraph,
                          style: locale.getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neonPurple,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
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
                    ArtistRoute(id: artist.id, $extra: artist).push(context);
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
      LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings) {
    final artistName = _artist.name;
    final artistNameLower = artistName.toLowerCase().trim();
    final albumIds = _albums.map((a) => a.id).toSet();

    final artistTracks = library.listenedTracks.where((t) {
      if (albumIds.contains(t.albumId)) return true;
      final trackArtists = t.artists.map((a) => a.toLowerCase());
      return trackArtists.any((a) => a == artistNameLower);
    }).toList();
    final songCount = artistTracks.length;

    final albumCats = AlbumCategorizer.categorize(
      _albums, artistId: _artist.id, artistName: _artist.name,
    );

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
    LibraryRepositoryImpl library,
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
}
