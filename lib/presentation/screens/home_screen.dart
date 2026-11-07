import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/logger.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_progress.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/notification_payloads.dart';
import '../../domain/entities/radar_release.dart';
import '../../domain/entities/top_artist.dart';
import '../../domain/logic/completion_recommendations.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/album_card.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/artist_card.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/glass_card.dart';
import '../widgets/moon_button.dart';
import '../widgets/profile_bottom_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/sky_line.dart';
import '../widgets/streak_card.dart';
import '../widgets/tap_scale.dart';
import '../widgets/weekly_challenges_card.dart';
import '../widgets/wrapped_picker_sheet.dart';
import 'guess_song_screen.dart';
import 'main_navigation_screen.dart';
import 'run_mode_screen.dart';
import 'streak_screen.dart';
import 'time_machine_screen.dart';

part 'home/affinity_sheet.dart';
part 'home/completion_sections.dart';
part 'home/entry_cards.dart';
part 'home/gear_profile_button.dart';
part 'home/home_widgets.dart';

final _log = Log.named('HomeScreen');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController scrollController = ScrollController();
  // Read once: dispose can't use ref.
  late final _radar = ref.read(releaseRadarProvider);
  List<Artist> _featuredArtists = [];
  List<Album> _latestReleases = [];
  List<_TopArtistDisplay> _topArtistsDisplay = [];
  List<Artist> _recommendedArtists = [];
  List<CompletionRecommendation> _completionRecs = [];

  // The completed albums the "because you completed" rows were built from
  // (null before the first build), and a counter that drops stale loads.
  String? _completionSeedKey;
  int _completionLoad = 0;
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
    _radar.openRequests.addListener(_openRadarIfRequested);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openRadarIfRequested());
  }

  void _openRadarIfRequested() {
    if (!mounted) return;
    final payload = _radar.consumePendingOpen();
    if (payload == null) return;
    if (payload == NotificationPayloads.timeMachine) {
      unawaited(const TimeMachineRoute().push(context));
    } else if (payload == NotificationPayloads.streak) {
      unawaited(StreakScreen.open(context));
    } else {
      unawaited(const ReleaseRadarRoute().push(context));
    }
  }

  @override
  void dispose() {
    _radar.openRequests.removeListener(_openRadarIfRequested);
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
      _completionSeedKey = null;
    });
    try {
      final featured = await ref.read(musicCatalogProvider).getFeaturedArtists();
      if (!mounted) return;

      final library = ref.read(libraryProvider);
      final topEntries = library.getTopArtists(limit: 5);

      List<_TopArtistDisplay> topDisplay = [];
      List<Album> releases = [];

      if (topEntries.isNotEmpty) {
        topDisplay = await _fetchTopArtistPictures(topEntries);
        if (!mounted) return;
        releases = await ref.read(getLatestReleasesProvider)([
          for (final t in topDisplay)
            if (t.artist != null) t.artist!,
        ]);
      } else if (featured.isNotEmpty) {
        releases =
            await ref.read(getLatestReleasesProvider)(featured.take(6).toList());
      }
      if (!mounted) return;

      setState(() {
        _featuredArtists = featured;
        _topArtistsDisplay = topDisplay;
        _latestReleases = releases;
        _isLoading = false;
      });
      unawaited(_loadPersonalizedRecommendations(topDisplay));
      unawaited(_loadCompletionRecommendations());
    } catch (e) {
      _log.severe('loadHomeData error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Each top artist (the library knows names) with their catalog entry,
  /// for the picture and to open them; null when not found.
  Future<List<_TopArtistDisplay>> _fetchTopArtistPictures(List<TopArtistEntry> entries) {
    final find = ref.read(findArtistByNameProvider);
    return Future.wait(entries.map((entry) async =>
        _TopArtistDisplay(entry: entry, artist: await find(entry.name))));
  }

  Future<void> _loadPersonalizedRecommendations(List<_TopArtistDisplay> tops) async {
    final found = [for (final t in tops) if (t.artist != null) t.artist!];
    if (found.isEmpty) return;
    final similar = await ref.read(getSimilarArtistsProvider)(
      found.take(3).toList(),
      exclude: {for (final a in found) a.id},
    );
    if (mounted && similar.isNotEmpty) {
      setState(() => _recommendedArtists = similar);
    }
  }

  /// The completed albums that seed the "because you completed" rows.
  static String _completionSeedKeyOf(List<AlbumProgress> completed) =>
      completed.map((a) => a.albumId).join(',');

  /// "Because you completed X": artists similar to the ones behind the
  /// latest completed albums that the user has not listened to yet.
  Future<void> _loadCompletionRecommendations() async {
    final library = ref.read(libraryProvider);
    final key = _completionSeedKeyOf(library.completedAlbums(limit: 6));
    _completionSeedKey = key;
    final load = ++_completionLoad;
    final completed = library.completedAlbums(limit: 6);
    if (completed.isEmpty) {
      if (_completionRecs.isNotEmpty) setState(() => _completionRecs = []);
      return;
    }
    final known = {
      for (final t in library.listenedTracks)
        for (final a in t.artists) a.toLowerCase(),
    };
    final catalog = ref.read(musicCatalogProvider);
    final rows = await CompletionRecommendations(
      findArtist: ref.read(findArtistByNameProvider).call,
      relatedArtists: (id) => catalog.getRelatedArtists(id, limit: 20),
    ).build(
      completed: completed,
      knownArtistNames: known,
      excludeIds: {
        for (final t in _topArtistsDisplay)
          if (t.artist != null) t.artist!.id,
      },
    );
    if (!mounted || load != _completionLoad) return;
    setState(() => _completionRecs = rows);
  }

  @override
  Widget build(BuildContext context) {
    // Completing (or un-completing) an album changes the seeds: rebuild
    // the "because you completed" rows once the home has loaded.
    ref.listen<String>(
        libraryProvider.select(
            (l) => _completionSeedKeyOf(l.completedAlbums(limit: 6))),
        (_, next) {
      if (_completionSeedKey != null && next != _completionSeedKey) {
        unawaited(_loadCompletionRecommendations());
      }
    });
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

              // Reasons to come back: the daily streak, and this week's
              // challenges and their mask.
              if (isLoggedIn) const SliverToBoxAdapter(child: EcoLevelCard()),
              if (isLoggedIn)
                const SliverToBoxAdapter(
                  child: EcoLocked(feature: EcoFeature.streak, child: StreakCard()),
                ),
              const SliverToBoxAdapter(
                child: EcoLocked(feature: EcoFeature.weekly, child: WeeklyChallengesCard(compact: true)),
              ),

              if (isLoggedIn && listenedCount > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            child: EcoLocked(
                                feature: EcoFeature.wrapped,
                                child: _WrappedEntryCard(locale: locale, strings: strings))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: EcoLocked(
                                feature: EcoFeature.listeningClock,
                                child: _ListeningClockEntryCard(locale: locale, strings: strings))),
                      ],
                    ),
                  ),
                ),

              if (isLoggedIn && listenedCount > 0)
                const SliverToBoxAdapter(
                  child: EcoLocked(feature: EcoFeature.timeMachine, child: TimeMachineEntryCard()),
                ),

              if (isLoggedIn && ref.watch(releaseRadarSupportedProvider))
                SliverToBoxAdapter(
                  child: _ReleaseRadarEntryCard(locale: locale, strings: strings),
                ),

              if (hasArtists)
                SliverToBoxAdapter(
                  child: EcoLocked(
                    feature: EcoFeature.rabbitHole,
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
                ),

              ..._buildTopArtistsSlivers(locale),
              if (isLoggedIn && listenedCount > 0)
                SliverToBoxAdapter(
                    child: _AlmostCompleteSection(locale: locale)),
              ..._buildLatestReleasesSlivers(locale),
              ..._buildCompletionSlivers(locale),
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
    ArtistRoute(id: artist.id, $extra: artist).push(context);
  }

  /// Opens a top artist, looking them up first when their picture search
  /// failed on load.
  Future<void> _openTopArtist(_TopArtistDisplay top) async {
    final artist = top.artist;
    if (artist != null) {
      _openArtist(artist);
      return;
    }
    final matched = await ref.read(findArtistByNameProvider)(top.entry.name);
    if (mounted && matched != null) _openArtist(matched);
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

  /// A row of similar artists for each of the latest completed albums.
  List<Widget> _buildCompletionSlivers(LocaleProvider locale) {
    return [
      for (final rec in _completionRecs) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: _SectionTitle(
              locale: locale,
              text: locale.strings.becauseYouCompleted(rec.album.title),
              maxLines: 2,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rec.artists.length,
              itemBuilder: (context, index) =>
                  ArtistCard(artist: rec.artists[index]),
            ),
          ),
        ),
      ],
    ];
  }

  /// Artists related to the top ones, or featured ones until those load.
  /// Those already suggested by a completed album are left out.
  List<Widget> _buildRecommendedSlivers(LocaleProvider locale) {
    final shown = {
      for (final rec in _completionRecs)
        for (final a in rec.artists) a.id,
    };
    final artists = (_recommendedArtists.isNotEmpty
            ? _recommendedArtists
            : _featuredArtists)
        .where((a) => !shown.contains(a.id))
        .toList();
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
    if (!ecoAllows(context, EcoFeature.guessSong)) return;
    unawaited(HapticFeedback.lightImpact());
    await const GuessSongRoute().push(context);
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
                    if (!ecoAllows(context, EcoFeature.ambient)) return;
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
                if (!ecoAllows(context, EcoFeature.running)) return;
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
