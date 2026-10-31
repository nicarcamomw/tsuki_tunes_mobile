import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/cyber_page_route.dart';
import '../../core/utils/image_cache_size.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/release_radar_service.dart';
import '../../data/datasources/time_machine_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/radar_release.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/artist_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/moon_button.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/sky_line.dart';
import '../widgets/weekly_challenges_card.dart';
import '../widgets/wrapped_picker_sheet.dart';
import 'artist_detail_screen.dart';
import 'guess_song_screen.dart';
import 'listening_clock_screen.dart';
import 'main_navigation_screen.dart';
import 'rabbit_hole_screen.dart';
import 'release_radar_screen.dart';
import 'run_mode_screen.dart';
import 'time_machine_screen.dart';

part 'home/affinity_sheet.dart';
part 'home/entry_cards.dart';
part 'home/gear_profile_button.dart';
part 'home/home_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController scrollController = ScrollController();
  final DeezerApiService _api = DeezerApiService();
  List<Artist> _featuredArtists = [];
  List<Album> _latestReleases = [];
  List<_TopArtistDisplay> _topArtistsDisplay = [];
  List<Artist> _recommendedArtists = [];
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
    appNavigatorKey.currentState?.push(CyberPageRoute(builder: (_) => screen));
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
    final auth = ref.read(authProvider);
    ProfileBottomSheet.show(context, auth);
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _recommendedArtists = [];
    });
    try {
      final featured = await _api.getFeaturedArtists();
      if (!mounted) return;

      final library = ref.read(libraryProvider);
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
      unawaited(_loadPersonalizedRecommendations(topDisplay));
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
              artistName: needsName ? top.entry.name : a.artistName,
              artistId: needsId ? top.artist!.id : a.artistId,
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
              artistName: needsName ? artist.name : a.artistName,
              artistId: needsId ? artist.id : a.artistId,
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

  Future<void> _loadPersonalizedRecommendations(List<_TopArtistDisplay> tops) async {
    final seeds = tops.where((t) => t.artist != null).take(3).toList();
    if (seeds.isEmpty) return;
    final topIds = tops.map((t) => t.artist?.id).whereType<String>().toSet();
    final all = <Artist>[];
    final seenIds = <String>{...topIds};
    for (final seed in seeds) {
      try {
        final related = await _api.getRelatedArtists(seed.artist!.id, limit: 10);
        for (final a in related) {
          if (seenIds.add(a.id)) all.add(a);
        }
      } catch (_) {}
    }
    if (mounted && all.isNotEmpty) {
      setState(() => _recommendedArtists = all.take(15).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statsLoaded, listenedCount, artistsCount, albumsCount, topArtistName, topArtistScore) =
        ref.watch(libraryProvider.select((l) {
      final top = l.getTopArtists(limit: 1);
      return (
        l.listenedTracksLoaded,
        l.listenedCount,
        l.uniqueArtistsCount,
        l.uniqueAlbumsCount,
        top.isNotEmpty ? top.first.name : '---',
        top.isNotEmpty ? top.first.score.toString() : '0',
      );
    }));
    final isLoggedIn = ref.watch(authProvider.select((a) => a.isLoggedIn));
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final hasArtists =
        _topArtistsDisplay.isNotEmpty || _featuredArtists.isNotEmpty;

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
              child: _HomeHeader(locale: locale, isLoggedIn: isLoggedIn),
            ),
            const SliverToBoxAdapter(child: RainOfferCard()),

            if (_isLoading)
              const HomeSkeletonLoader()
            else if (_hasError)
              _HomeMessage(
                locale: locale,
                icon: Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.accent,
                  size: 28,
                  semanticLabel: strings.a11yOffline,
                ),
                title: strings.homeLoadError,
                subtitle: strings.homeLoadErrorSubtitle,
                actionLabel: strings.retry,
                onAction: _loadHomeData,
              )
            else if (isLoggedIn && statsLoaded && listenedCount == 0 && !hasArtists)
              _HomeMessage(
                locale: locale,
                icon: Image.asset(
                  'assets/images/tengu.png',
                  width: 28,
                  height: 28,
                  semanticLabel: strings.homeEmptyTitle,
                ),
                title: strings.homeEmptyTitle,
                subtitle: strings.homeEmptySubtitle,
                actionLabel: strings.homeEmptyAction,
                onAction: () => NavigationEvents.switchTab?.call(1),
              )
            else ...[
              if (isLoggedIn)
                SliverToBoxAdapter(
                  child: _buildStatsRow(
                    locale,
                    loaded: statsLoaded,
                    listenedCount: listenedCount,
                    artistsCount: artistsCount,
                    albumsCount: albumsCount,
                    topArtistName: topArtistName,
                    topArtistScore: topArtistScore,
                  ),
                ),

              SliverToBoxAdapter(child: _buildFeatureCards(locale)),

              // A reason to come back: this week's challenges and their mask.
              const SliverToBoxAdapter(child: WeeklyChallengesCard(compact: true)),

              if (isLoggedIn && listenedCount > 0)
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

              if (isLoggedIn && listenedCount > 0)
                const SliverToBoxAdapter(child: TimeMachineEntryCard()),

              if (isLoggedIn && ReleaseRadarService.isSupported)
                SliverToBoxAdapter(
                  child: _ReleaseRadarEntryCard(locale: locale, strings: strings),
                ),

              if (hasArtists)
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

              ..._buildTopArtistsSlivers(locale),
              ..._buildLatestReleasesSlivers(locale),
              ..._buildRecommendedSlivers(locale),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildStatsRow(
    LocaleProvider locale, {
    required bool loaded,
    required int listenedCount,
    required int artistsCount,
    required int albumsCount,
    required String topArtistName,
    required String topArtistScore,
  }) {
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: loaded ? null : const NeverScrollableScrollPhysics(),
        child: loaded
            ? IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatCard(
                      locale: locale,
                      label: strings.statsTracks,
                      value: '$listenedCount',
                      meta: strings.statsListened),
                  _StatCard(
                      locale: locale,
                      label: strings.statsArtists,
                      value: '$artistsCount',
                      meta: strings.statsInSystem),
                  _StatCard(
                      locale: locale,
                      label: strings.statsAlbums,
                      value: '$albumsCount',
                      meta: strings.statsInSystem),
                  _StatCard(
                    locale: locale,
                    label: strings.statsTopArtist,
                    value: topArtistName,
                    meta: strings.statsAffinity(topArtistScore),
                    isTextValue: true,
                  ),
                ],
              ),
              )
            : Row(
                children: List.generate(4, (_) => const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SkeletonLoader(width: 140, height: 76),
                )),
              ),
      ),
    );
  }

  /// Top artists by affinity, or featured ones while there are none.
  List<Widget> _buildTopArtistsSlivers(LocaleProvider locale) {
    final strings = locale.strings;
    if (_topArtistsDisplay.isNotEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Row(
              children: [
                // The title takes all the room left by the (?)
                // button: a Spacer here would take half of it.
                Expanded(
                  child: _SectionTitle(
                    locale: locale,
                    text: strings.topArtistsTitle,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                // Flush right, vertically centred on the title; the
                // glyph is an icon so it sits dead centre in the ring.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAffinityInfo(context, locale),
                  child: Semantics(
                    button: true,
                    label: strings.affinityInfoTitle,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.textMuted, width: 1),
                          ),
                          child: const Icon(
                            Icons.question_mark_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final top = _topArtistsDisplay[index];
              final rank = index + 1;
              return _ArtistRow(
                locale: locale,
                rank: rank,
                name: top.entry.name,
                subtitle: strings.affinityScore(top.entry.score),
                pictureUrl: top.artist?.pictureUrl ?? '',
                semanticsLabel: '${strings.tabArtists} $rank, ${top.entry.name}',
                placeholderIcon: true,
                onTap: () => _openTopArtist(top),
              );
            },
            childCount: _topArtistsDisplay.length,
          ),
        ),
      ];
    }
    if (_featuredArtists.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: _SectionTitle(locale: locale, text: strings.topArtistsTitle),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final artist = _featuredArtists[index];
            final rank = index + 1;
            return _ArtistRow(
              locale: locale,
              rank: rank,
              name: artist.name,
              subtitle: strings.featured,
              pictureUrl: artist.pictureUrl,
              semanticsLabel: '${strings.featured} $rank, ${artist.name}',
              placeholderIcon: false,
              onTap: () => _openArtist(artist),
            );
          },
          childCount: _featuredArtists.take(5).length,
        ),
      ),
    ];
  }

  void _openArtist(Artist artist) {
    appNavigatorKey.currentState?.push(
      CyberPageRoute(
        builder: (_) => ArtistDetailScreen(artist: artist),
      ),
    );
  }

  /// Opens a top artist, looking them up first when their picture search
  /// failed on load.
  Future<void> _openTopArtist(_TopArtistDisplay top) async {
    final artist = top.artist;
    if (artist != null) {
      _openArtist(artist);
      return;
    }
    final entry = top.entry;
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
      if (mounted && matched != null) _openArtist(matched);
    } catch (e) {
      debugPrint('[HomeScreen] retry artist search for ${entry.name}: $e');
    }
  }

  List<Widget> _buildLatestReleasesSlivers(LocaleProvider locale) {
    final strings = locale.strings;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: _SectionTitle(locale: locale, text: strings.latestReleasesTitle),
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
                  itemCount: _latestReleases.length,
                  itemBuilder: (context, index) {
                    return AlbumCard(
                        album: _latestReleases[index]);
                  },
                ),
              ),
      ),
    ];
  }

  /// Artists related to the top ones, or featured ones until those load.
  List<Widget> _buildRecommendedSlivers(LocaleProvider locale) {
    final artists =
        _recommendedArtists.isNotEmpty ? _recommendedArtists : _featuredArtists;
    if (artists.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: _SectionTitle(locale: locale, text: locale.strings.recommendedTitle),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) => ArtistCard(artist: artists[index]),
          ),
        ),
      ),
    ];
  }

  Future<void> _refreshDailyDone() async {
    final done = await GuessSongScreen.isDailyDone();
    if (mounted && done != _dailyDone) setState(() => _dailyDone = done);
  }

  Future<void> _openGuessGame() async {
    unawaited(HapticFeedback.lightImpact());
    await Navigator.of(context, rootNavigator: true).push(
      CyberPageRoute(builder: (_) => const GuessSongScreen()),
    );
    await _refreshDailyDone();
  }

  Widget _buildFeatureCards(LocaleProvider locale) {
    final strings = locale.strings;
    final ambientCount = ref.watch(ambientProvider.select(
        (a) => a.isPlaying ? a.activeSounds.length : 0));
    final run = ref.watch(runProvider.select(
        (r) => (r.active, r.active ? r.reading.spm?.round() : null, r.enabled)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FeatureCard(
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
                child: _FeatureCard(
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
            _FeatureCard(
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

}

class _TopArtistDisplay {
  final TopArtistEntry entry;
  final Artist? artist;
  _TopArtistDisplay({required this.entry, this.artist});
}
