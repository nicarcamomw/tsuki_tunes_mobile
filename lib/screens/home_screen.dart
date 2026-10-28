import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/radar_release.dart';
import '../providers/ambient_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/run_provider.dart';
import '../screens/artist_detail_screen.dart';
import '../services/deezer_api_service.dart';
import '../services/release_radar_service.dart';
import '../services/time_machine_service.dart';
import '../widgets/album_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/artist_card.dart';
import '../widgets/moon_button.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/sky_line.dart';
import 'guess_song_screen.dart';
import 'listening_clock_screen.dart';
import 'main_navigation_screen.dart';
import 'rabbit_hole_screen.dart';
import 'release_radar_screen.dart';
import 'run_mode_screen.dart';
import 'time_machine_screen.dart';
import 'wrapped_screen.dart';

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
  bool _dailyDone = false;

  @override
  void initState() {
    super.initState();
    NavigationEvents.onHomeScrollToTop = scrollToTop;
    NavigationEvents.onHomeOpenProfile = openProfile;
    NavigationEvents.onHomeRefresh = _loadHomeData;
    _loadHomeData();
    _refreshDailyDone();
    ReleaseRadarService().openRequests.addListener(_openRadarIfRequested);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openRadarIfRequested());
  }

  void _openRadarIfRequested() {
    if (!mounted) return;
    final payload = ReleaseRadarService().consumePendingOpen();
    if (payload == null) return;
    final Widget screen = payload == TimeMachineService.payload
        ? const TimeMachineScreen()
        : const ReleaseRadarScreen();
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    ReleaseRadarService().openRequests.removeListener(_openRadarIfRequested);
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
      if (!mounted) return;

      final library = context.read<LibraryProvider>();
      final topEntries = library.getTopArtists(limit: 5);

      List<_TopArtistDisplay> topDisplay = [];
      List<Album> releases = [];

      if (topEntries.isNotEmpty) {
        topDisplay = await _fetchTopArtistPictures(topEntries);
        if (!mounted) return;
        releases = await _loadLatestFromTopArtists(topDisplay);
      } else if (featured.isNotEmpty) {
        releases = await _loadLatestFromFeatured(featured);
      }
      if (!mounted) return;

      setState(() {
        _featuredArtists = featured;
        _topArtistsDisplay = topDisplay;
        _latestReleases = releases;
        _isLoading = false;
      });
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

  Future<List<_TopArtistDisplay>> _fetchTopArtistPictures(List<TopArtistEntry> entries) async {
    return await Future.wait(entries.map((entry) async {
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
  }

  Future<List<Album>> _loadLatestFromTopArtists(List<_TopArtistDisplay> tops) async {
    final validTops = tops.take(10).where((t) => t.artist != null).toList();
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final results = await Future.wait(validTops.map((top) async {
      try {
        final artistAlbums = await _api.getArtistAlbums(top.artist!.id);
        if (artistAlbums.isEmpty) return <Album>[];
        return artistAlbums.map((a) {
          final needsName = a.artistName == 'Unknown Artist' || a.artistName.isEmpty;
          final needsId = a.artistId.isEmpty;
          if (needsName || needsId) {
            return a.copyWith(
              artistName: needsName ? top.entry.name : null,
              artistId: needsId ? top.artist!.id : null,
            );
          }
          return a;
        }).toList();
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromTopArtists error for ${top.entry.name}: $e');
        return <Album>[];
      }
    }));

    final allAlbums = <Album>[];
    final seenIds = <String>{};
    for (final albumList in results) {
      for (final album in albumList) {
        if (!seenIds.contains(album.id) && album.releaseDate.isNotEmpty) {
          final parsed = DateTime.tryParse(album.releaseDate);
          if (parsed != null && parsed.isAfter(cutoff)) {
            seenIds.add(album.id);
            allAlbums.add(album);
          }
        }
      }
    }

    allAlbums.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    return allAlbums.take(15).toList();
  }

  Future<List<Album>> _loadLatestFromFeatured(List<Artist> featured) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final results = await Future.wait(featured.take(6).map((artist) async {
      try {
        final artistAlbums = await _api.getArtistAlbums(artist.id);
        if (artistAlbums.isEmpty) return <Album>[];
        return artistAlbums.map((a) {
          final needsName = a.artistName == 'Unknown Artist' || a.artistName.isEmpty;
          final needsId = a.artistId.isEmpty;
          if (needsName || needsId) {
            return a.copyWith(
              artistName: needsName ? artist.name : null,
              artistId: needsId ? artist.id : null,
            );
          }
          return a;
        }).toList();
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromFeatured error: $e');
        return <Album>[];
      }
    }));

    final allAlbums = <Album>[];
    final seenIds = <String>{};
    for (final albumList in results) {
      for (final album in albumList) {
        if (!seenIds.contains(album.id) && album.releaseDate.isNotEmpty) {
          final parsed = DateTime.tryParse(album.releaseDate);
          if (parsed != null && parsed.isAfter(cutoff)) {
            seenIds.add(album.id);
            allAlbums.add(album);
          }
        }
      }
    }

    allAlbums.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    return allAlbums.take(15).toList();
  }

  @override
  Widget build(BuildContext context) {
    final statsLoaded = context.select<LibraryProvider, bool>((l) => l.listenedTracksLoaded);
    final listenedCount = context.select<LibraryProvider, int>((l) => l.listenedCount);
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
              child: SkyBackdrop(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
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
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  strings.homeTelemetry,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent.withValues(alpha: 0.8),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const MoonButton(),
                                const SizedBox(width: 4),
                                Selector<AudioProvider, bool>(
                                  selector: (_, audio) =>
                                      audio.useSpotify || audio.spotify.isConnected,
                                  builder: (context, isSpotify, _) {
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
                                            style: locale.getTextStyle(
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
                                  _GearProfileButton(
                                    auth: auth,
                                    label: strings.profileTitle,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: SkyLine(),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: RainOfferCard()),

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
                          child: Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.accent,
                            size: 28,
                            semanticLabel: strings.a11yOffline,
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
              if (auth.isLoggedIn && statsLoaded && listenedCount == 0 && _topArtistsDisplay.isEmpty && _featuredArtists.isEmpty)
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
                            child: Icon(
                              Icons.headphones_rounded,
                              color: AppColors.accent,
                              size: 28,
                              semanticLabel: strings.homeEmptyTitle,
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
                      physics: statsLoaded ? null : const NeverScrollableScrollPhysics(),
                      child: statsLoaded
                          ? Row(
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
                            )
                          : Row(
                              children: List.generate(4, (_) => const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: SkeletonLoader(width: 140, height: 76),
                              )),
                            ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(child: _buildFeatureCards(locale)),

              if (auth.isLoggedIn && listenedCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            child: _WrappedEntryCard(
                                locale: locale, strings: strings)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _ListeningClockEntryCard(
                                locale: locale, strings: strings)),
                      ],
                    ),
                  ),
                ),

              if (auth.isLoggedIn && listenedCount > 0)
                const SliverToBoxAdapter(child: TimeMachineEntryCard()),

              if (auth.isLoggedIn && ReleaseRadarService.isSupported)
                SliverToBoxAdapter(
                  child: _ReleaseRadarEntryCard(locale: locale, strings: strings),
                ),

              // Rabbit Hole entry
              if (_topArtistsDisplay.isNotEmpty ||
                  _featuredArtists.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RabbitHoleEntryCard(
                    locale: locale,
                    strings: strings,
                    seedArtist: _topArtistsDisplay.isNotEmpty &&
                            _topArtistsDisplay.first.artist != null
                        ? _topArtistsDisplay.first.artist!
                        : _featuredArtists.isNotEmpty
                            ? _featuredArtists.first
                            : null,
                  ),
                ),

              if (_topArtistsDisplay.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Semantics(
                      header: true,
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
                    child: Semantics(
                      header: true,
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
                  child: Semantics(
                    header: true,
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
              ),
              SliverToBoxAdapter(
                child: _latestReleases.isEmpty
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
                          cacheExtent: 300,
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
                    child: Semantics(
                      header: true,
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
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      cacheExtent: 300,
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

  Future<void> _refreshDailyDone() async {
    final done = await GuessSongScreen.isDailyDone();
    if (mounted && done != _dailyDone) setState(() => _dailyDone = done);
  }

  Future<void> _openGuessGame() async {
    unawaited(HapticFeedback.lightImpact());
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const GuessSongScreen()),
    );
    await _refreshDailyDone();
  }

  Widget _buildFeatureCards(LocaleProvider locale) {
    final strings = locale.strings;
    final ambientCount = context.select<AmbientProvider, int>(
        (a) => a.isPlaying ? a.activeSounds.length : 0);
    final run = context.select<RunProvider, (bool, int?, bool)>(
        (r) => (r.active, r.active ? r.reading.spm?.round() : null, r.enabled));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _featureCard(
                  locale: locale,
                  icon: Icons.music_note_rounded,
                  color: AppColors.accent,
                  title: strings.guessTitle,
                  subtitle: _dailyDone ? strings.guessDailyDone : strings.guessModeDaily,
                  highlight: !_dailyDone,
                  onTap: _openGuessGame,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _featureCard(
                  locale: locale,
                  icon: Icons.water_drop_rounded,
                  color: AppColors.neonCyan,
                  title: strings.ambientTitle,
                  subtitle: ambientCount > 0
                      ? strings.ambientPlayingCount(ambientCount)
                      : strings.homeAmbientCardSubtitle,
                  highlight: ambientCount > 0,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AmbientMixerSheet.show(context);
                  },
                ),
              ),
            ],
          ),
          if (run.$3) ...[
            const SizedBox(height: 10),
            _featureCard(
              locale: locale,
              icon: Icons.directions_run_rounded,
              color: AppColors.neonGreen,
              title: strings.runTitle,
              subtitle: run.$1 ? strings.runCardActive(run.$2) : strings.runCardSubtitle,
              highlight: run.$1,
              onTap: () {
                HapticFeedback.lightImpact();
                RunModeScreen.open(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureCard({
    required LocaleProvider locale,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool highlight,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: GlassCard(
          color: color,
          highlightAlpha: highlight ? 0.18 : 0.08,
          dimAlpha: highlight ? 0.08 : 0.03,
          borderAlpha: highlight ? 0.6 : 0.3,
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: 10, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String meta,
      {bool isTextValue = false, required LocaleProvider locale}) {
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
            style: locale.getTextStyle(
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
                ? locale.getTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  )
                : locale.getTextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: locale.getTextStyle(
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
      onTap: () async {
        if (artist != null) {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ArtistDetailScreen(artist: artist),
            ),
          );
        } else {
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
            if (mounted && matched != null) {
              appNavigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => ArtistDetailScreen(artist: matched!),
                ),
              );
            }
          } catch (e) {
            debugPrint('[HomeScreen] retry artist search for ${entry.name}: $e');
          }
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
                style: locale.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: artist != null && artist.pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                      memCacheWidth: imageCacheSize(context, (40).toDouble()),
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.bgCard,
                        child: Icon(Icons.person,
                            color: AppColors.accent, size: 20, semanticLabel: locale.strings.a11yArtistAvatar),
                      ),
              ),
            )),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: locale.getTextStyle(
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
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted, semanticLabel: locale.strings.a11ySeeAll),
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
        appNavigatorKey.currentState?.push(
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
                style: locale.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: artist.pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                      memCacheWidth: imageCacheSize(context, (40).toDouble()),
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(color: AppColors.bgCard),
              ),
            )),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: locale.getTextStyle(
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
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted, semanticLabel: locale.strings.a11ySeeAll),
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

class _GearProfileButton extends StatefulWidget {
  final AuthProvider auth;
  final String label;
  const _GearProfileButton({required this.auth, required this.label});

  @override
  State<_GearProfileButton> createState() => _GearProfileButtonState();
}

class _GearProfileButtonState extends State<_GearProfileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_reduceMotion) _controller.forward(from: 0.0);
    ProfileBottomSheet.show(context, widget.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: _onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _GearBorderPainter(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  rotation: _controller.value * pi / 4,
                ),
                child: child,
              );
            },
            child: Center(
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.bgCard,
                backgroundImage: widget.auth.user?.photoURL != null
                    ? NetworkImage(widget.auth.user!.photoURL!)
                    : null,
                child: widget.auth.user?.photoURL == null
                    ? Icon(Icons.person,
                        size: 14, color: AppColors.accent, semanticLabel: widget.label)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GearBorderPainter extends CustomPainter {
  final Color color;
  final double rotation;
  const _GearBorderPainter({required this.color, this.rotation = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 3.5;
    const teethCount = 8;
    const toothWidth = 0.28;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final path = Path();
    for (int i = 0; i < teethCount; i++) {
      final angle = (i / teethCount) * 2 * pi - pi / 2;
      final nextAngle = ((i + 1) / teethCount) * 2 * pi - pi / 2;
      final toothStart = angle - toothWidth / 2;
      final toothEnd = angle + toothWidth / 2;
      final gapStart = toothEnd;
      final gapEnd = nextAngle - toothWidth / 2;

      if (i == 0) {
        path.moveTo(
          center.dx + outerRadius * cos(toothStart),
          center.dy + outerRadius * sin(toothStart),
        );
      }
      path.arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        toothStart,
        toothEnd - toothStart,
        false,
      );
      path.lineTo(
        center.dx + innerRadius * cos(gapStart),
        center.dy + innerRadius * sin(gapStart),
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        gapStart,
        gapEnd - gapStart,
        false,
      );
      path.lineTo(
        center.dx + outerRadius * cos(gapEnd),
        center.dy + outerRadius * sin(gapEnd),
      );
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GearBorderPainter old) =>
      old.color != color || old.rotation != rotation;
}

class _WrappedEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _WrappedEntryCard({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Semantics(
      button: true,
      label: strings.a11yWrapped,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => WrappedScreen(year: year)),
          );
        },
        child: GlassCard(
          color: AppColors.accent,
          highlightAlpha: 0.12,
          dimAlpha: 0.04,
          borderAlpha: 0.4,
          borderRadius: 6,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6)),
                ),
                child: Center(
                  child: Text(
                    '月',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'WRAPPED $year',
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                strings.wrappedViewYourWrapped,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningClockEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _ListeningClockEntryCard(
      {required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: strings.a11yClock,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ListeningClockScreen()),
          );
        },
        child: GlassCard(
          color: AppColors.neonCyan,
          highlightAlpha: 0.08,
          dimAlpha: 0.03,
          borderAlpha: 0.3,
          borderRadius: 6,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.radar,
                    color: AppColors.neonCyan, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                strings.clockTitle,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                strings.clockViewClock,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonCyan,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RabbitHoleEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  final Artist? seedArtist;
  const _RabbitHoleEntryCard({
    required this.locale,
    required this.strings,
    this.seedArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (seedArtist == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: strings.a11yRabbitHole,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => RabbitHoleScreen(seedArtist: seedArtist!),
            ),
          );
        },
        child: GlassCard(
          color: AppColors.neonPurple,
          highlightAlpha: 0.10,
          dimAlpha: 0.04,
          borderAlpha: 0.3,
          borderRadius: 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.neonPurple.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(Icons.hub,
                    color: AppColors.neonPurple, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.rabbitHoleTitle,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.rabbitHoleSubtitle,
                      style: locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neonPurple.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (seedArtist != null)
                ClipOval(
                  child: CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, 30),
                    imageUrl: seedArtist!.getBestImage(size: 'small'),
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: AppColors.neonPurple.withValues(alpha: 0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseRadarEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _ReleaseRadarEntryCard({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final radar = ReleaseRadarService();
    return ValueListenableBuilder<List<RadarRelease>>(
      valueListenable: radar.releases,
      builder: (context, releases, _) {
        final unread = releases.where((r) => r.isUnread).length;
        return ValueListenableBuilder<int>(
          valueListenable: radar.watchedCount,
          builder: (context, watched, _) {
            final hasNews = unread > 0;
            final accent = hasNews ? AppColors.accent : AppColors.neonCyan;
            return Semantics(
              button: true,
              label: hasNews
                  ? '${strings.a11yRadar}. ${strings.radarNewCount(unread)}'
                  : strings.a11yRadar,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  appNavigatorKey.currentState?.push(
                    MaterialPageRoute(
                        builder: (_) => const ReleaseRadarScreen()),
                  );
                },
                child: GlassCard(
                  color: accent,
                  highlightAlpha: hasNews ? 0.12 : 0.08,
                  dimAlpha: hasNews ? 0.04 : 0.03,
                  borderAlpha: hasNews ? 0.55 : 0.3,
                  borderRadius: 6,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.5)),
                            ),
                            child: Icon(Icons.radar, color: accent, size: 20),
                          ),
                          if (hasNews)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 18, minHeight: 18),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: AppColors.bgDeep, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: locale.getTextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textBright,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.radarTitle,
                              style: locale.getTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasNews
                                  ? strings.radarNewCount(unread)
                                  : strings.radarWatching(watched),
                              style: locale.getTextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accent.withValues(alpha: 0.85),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: accent.withValues(alpha: 0.7), size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

