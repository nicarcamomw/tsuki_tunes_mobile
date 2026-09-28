import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';
import '../providers/library_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/artist_card.dart';
import '../widgets/album_card.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../screens/artist_detail_screen.dart';
import 'main_navigation_screen.dart';
import '../providers/locale_provider.dart';
import '../widgets/skeleton_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController scrollController = ScrollController();
  final DeezerApiService _api = DeezerApiService();
  List<Artist> _featuredArtists = [];
  List<Album> _latestReleases = [];
  List<_TopArtistDisplay> _topArtistsDisplay = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _releasesLoading = false;

  @override
  void initState() {
    super.initState();
    NavigationEvents.onHomeScrollToTop = scrollToTop;
    NavigationEvents.onHomeOpenProfile = openProfile;
    NavigationEvents.onHomeRefresh = _loadHomeData;
    _loadHomeData();
  }

  @override
  void dispose() {
    if (NavigationEvents.onHomeScrollToTop == scrollToTop) {
      NavigationEvents.onHomeScrollToTop = null;
    }
    if (NavigationEvents.onHomeOpenProfile == openProfile) {
      NavigationEvents.onHomeOpenProfile = null;
    }
    if (NavigationEvents.onHomeRefresh == _loadHomeData) {
      NavigationEvents.onHomeRefresh = null;
    }
    scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void openProfile() {
    final auth = context.read<AuthProvider>();
    ProfileBottomSheet.show(context, auth);
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final featured = await _api.getFeaturedArtists();
      if (mounted) {
        setState(() {
          _featuredArtists = featured;
          _isLoading = false;
        });
      }

      if (mounted) _computeTopArtists();
    } catch (e) {
      debugPrint('[HomeScreen] loadHomeData error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _computeTopArtists() {
    final library = context.read<LibraryProvider>();
    final topEntries = library.getTopArtists(limit: 5);

    if (topEntries.isEmpty) {
      _loadLatestFromFeatured();
      return;
    }

    _fetchTopArtistPictures(topEntries);
  }

  Future<void> _fetchTopArtistPictures(List<TopArtistEntry> entries) async {
    final display = await Future.wait(entries.map((entry) async {
      try {
        final results = await _api.searchArtists(entry.name, limit: 3);
        Artist? matched;
        for (final a in results) {
          if (a.name.toLowerCase() == entry.name.toLowerCase()) {
            matched = a;
            break;
          }
        }
        matched ??= results.isNotEmpty ? results.first : null;
        return _TopArtistDisplay(entry: entry, artist: matched);
      } catch (e) {
        debugPrint('[HomeScreen] fetchTopArtistPictures error: $e');
        return _TopArtistDisplay(entry: entry, artist: null);
      }
    }));

    if (mounted) {
      setState(() => _topArtistsDisplay = display);
      _loadLatestFromTopArtists(display);
    }
  }

  Future<void> _loadLatestFromTopArtists(List<_TopArtistDisplay> tops) async {
    setState(() => _releasesLoading = true);
    final validTops = tops.take(5).where((t) => t.artist != null).toList();
    final results = await Future.wait(validTops.map((top) async {
      try {
        final artistAlbums = await _api.getArtistAlbums(top.artist!.id);
        return artistAlbums.isNotEmpty ? artistAlbums.first : null;
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromTopArtists error for ${top.entry.name}: $e');
        return null;
      }
    }));

    final albums = <Album>[];
    final seenIds = <String>{};
    for (final album in results) {
      if (album != null && !seenIds.contains(album.id)) {
        seenIds.add(album.id);
        albums.add(album);
      }
    }

    if (mounted) {
      setState(() {
        _latestReleases = albums;
        _releasesLoading = false;
      });
    }
  }

  Future<void> _loadLatestFromFeatured() async {
    if (!mounted) return;
    setState(() => _releasesLoading = true);
    final results = await Future.wait(_featuredArtists.take(4).map((artist) async {
      try {
        final artistAlbums = await _api.getArtistAlbums(artist.id);
        return artistAlbums.isNotEmpty ? artistAlbums.first : null;
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromFeatured error: $e');
        return null;
      }
    }));
    final albums = results.whereType<Album>().toList();

    if (mounted) {
      setState(() {
        _latestReleases = albums;
        _releasesLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenedCount = context.select<LibraryProvider, int>((l) => l.listenedTracks.length);
    final artistsCount = context.select<LibraryProvider, int>((l) => l.uniqueArtistsCount);
    final albumsCount = context.select<LibraryProvider, int>((l) => l.uniqueAlbumsCount);
    final (topArtistName, topArtistScore) = context.select<LibraryProvider, (String, String)>((l) {
      final top = l.getTopArtists(limit: 1);
      if (top.isEmpty) return ('---', '0');
      return (top.first.name, top.first.score.toString());
    });
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadHomeData,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                strings.homeHeader.replaceAll(' // 01', ''),
                                style: locale.getTextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textBright,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                ' // 01',
                                style: locale.getTextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.homeTelemetry,
                            style: GoogleFonts.notoSansJp(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent.withValues(alpha: 0.8),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Consumer<AudioProvider>(
                            builder: (context, audio, _) {
                              final isSpotify = audio.useSpotify || audio.spotify.isConnected;
                              final badgeColor = AppColors.accent;
                              final badgeBg = AppColors.accentDim;
                              final badgeText = isSpotify ? 'SPOTIFY' : 'DEEZER';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: badgeColor.withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: badgeColor.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: badgeColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: badgeColor.withValues(alpha: 0.7),
                                            blurRadius: 4,
                                            spreadRadius: 0.5,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      badgeText,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (auth.isLoggedIn) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              button: true,
                              label: strings.profileTitle,
                              child: GestureDetector(
                              onTap: () => ProfileBottomSheet.show(context, auth),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.bgCard,
                                backgroundImage: auth.user?.photoURL != null
                                    ? NetworkImage(auth.user!.photoURL!)
                                    : null,
                                child: auth.user?.photoURL == null
                                    ? const Icon(Icons.person,
                                        size: 16, color: AppColors.accent)
                                    : null,
                              ),
                            ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const HomeSkeletonLoader()
            else if (_hasError)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.1),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          strings.homeLoadError,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.homeLoadErrorSubtitle,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _loadHomeData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.6),
                              ),
                              borderRadius: BorderRadius.circular(2),
                              color: AppColors.accent.withValues(alpha: 0.08),
                            ),
                            child: Text(
                              strings.retry,
                              style: locale.getTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (auth.isLoggedIn && listenedCount == 0 && _topArtistsDisplay.isEmpty && _featuredArtists.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.headphones_rounded,
                              color: AppColors.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            strings.homeEmptyTitle,
                            textAlign: TextAlign.center,
                            style: locale.getTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.homeEmptySubtitle,
                            textAlign: TextAlign.center,
                            style: locale.getTextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              NavigationEvents.switchTab?.call(1);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.6),
                                ),
                                borderRadius: BorderRadius.circular(2),
                                color: AppColors.accent.withValues(alpha: 0.08),
                              ),
                              child: Text(
                                strings.homeEmptyAction,
                                style: locale.getTextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
              if (auth.isLoggedIn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatCard(
                              strings.statsTracks, '$listenedCount', strings.statsListened,
                              locale: locale),
                          _buildStatCard(
                              strings.statsArtists, '$artistsCount', strings.statsInSystem,
                              locale: locale),
                          _buildStatCard(
                              strings.statsAlbums, '$albumsCount', strings.statsInSystem,
                              locale: locale),
                          _buildStatCard(
                            strings.statsTopArtist,
                            topArtistName,
                            strings.statsAffinity(topArtistScore),
                            isTextValue: true,
                            locale: locale,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_topArtistsDisplay.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text(
                      strings.topArtistsTitle,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final top = _topArtistsDisplay[index];
                      return _buildRankedArtistRow(
                          context, top.entry, top.artist, index + 1, locale);
                    },
                    childCount: _topArtistsDisplay.length,
                  ),
                ),
              ] else if (_featuredArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text(
                      strings.topArtistsTitle,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final artist = _featuredArtists[index];
                      return _buildFeaturedArtistRow(context, artist, index + 1, locale);
                    },
                    childCount: _featuredArtists.take(5).length,
                  ),
                ),
              ],

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    strings.latestReleasesTitle,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _releasesLoading
                    ? SizedBox(
                        height: 185,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: List.generate(3, (_) => const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLoader(width: 135, height: 135),
                                SizedBox(height: 8),
                                SkeletonLoader(width: 110, height: 13),
                                SizedBox(height: 4),
                                SkeletonLoader(width: 80, height: 11),
                              ],
                            ),
                          )),
                        ),
                      )
                    : _latestReleases.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              strings.emptyReleases,
                              style: locale.getTextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 185,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _latestReleases.length,
                              itemBuilder: (context, index) {
                                return AlbumCard(
                                    album: _latestReleases[index]);
                              },
                            ),
                          ),
              ),

              if (_featuredArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      strings.recommendedTitle,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _featuredArtists.length,
                      itemBuilder: (context, index) {
                        return ArtistCard(artist: _featuredArtists[index]);
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
            ],
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String meta,
      {bool isTextValue = false, LocaleProvider? locale}) {
    return Semantics(
      label: '$label: $value, $meta',
      child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: locale?.getTextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ) ??
                GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: isTextValue
                ? (locale?.getTextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sakura,
                    ) ??
                    GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sakura,
                    ))
                : (locale?.getTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sakura,
                    ) ??
                    GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sakura,
                    )),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: locale?.getTextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ) ??
                GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRankedArtistRow(
      BuildContext context, TopArtistEntry entry, Artist? artist, int rank, LocaleProvider locale) {
    return Semantics(
      button: true,
      label: '${locale.strings.tabArtists} $rank, ${entry.name}',
      child: InkWell(
      onTap: () {
        if (artist != null) {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ArtistDetailScreen(artist: artist),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: artist != null && artist.pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.bgCard,
                        child: const Icon(Icons.person,
                            color: AppColors.accent, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    locale.strings.affinityScore(entry.score),
                    style: locale.getTextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildFeaturedArtistRow(
      BuildContext context, Artist artist, int rank, LocaleProvider locale) {
    return Semantics(
      button: true,
      label: '${locale.strings.featured} $rank, ${artist.name}',
      child: InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: artist.pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(color: AppColors.bgCard),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    locale.strings.featured,
                    style: locale.getTextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    ),
    );
  }
}

class _TopArtistDisplay {
  final TopArtistEntry entry;
  final Artist? artist;
  _TopArtistDisplay({required this.entry, this.artist});
}
