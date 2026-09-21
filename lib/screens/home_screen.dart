import 'package:flutter/material.dart';
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
import '../screens/artist_detail_screen.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../providers/locale_provider.dart';
import '../widgets/language_selector_sheet.dart';

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

  /// Scroll to top suave para respuesta a Double-Tap o tap en Home
  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Abre el menú de perfil y Spotify para respuesta a Long-Press en Home
  void openProfile() {
    final auth = context.read<AuthProvider>();
    _showProfileMenu(context, auth);
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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
    final display = <_TopArtistDisplay>[];

    for (final entry in entries) {
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
        display.add(_TopArtistDisplay(
          entry: entry,
          artist: matched,
        ));
      } catch (e) {
        debugPrint('[HomeScreen] fetchTopArtistPictures error: $e');
        display.add(_TopArtistDisplay(entry: entry, artist: null));
      }
    }

    if (mounted) {
      setState(() => _topArtistsDisplay = display);
      _loadLatestFromTopArtists(display);
    }
  }

  Future<void> _loadLatestFromTopArtists(List<_TopArtistDisplay> tops) async {
    setState(() => _releasesLoading = true);
    final albums = <Album>[];
    final seenIds = <String>{};

    for (final top in tops.take(5)) {
      if (top.artist == null) continue;
      try {
        final artistAlbums = await _api.getArtistAlbums(top.artist!.id);
        if (artistAlbums.isNotEmpty) {
          final album = artistAlbums.first;
          if (!seenIds.contains(album.id)) {
            seenIds.add(album.id);
            albums.add(album);
          }
        }
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromTopArtists error for ${top.entry.name}: $e');
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
    final albums = <Album>[];

    for (final artist in _featuredArtists.take(4)) {
      try {
        final artistAlbums = await _api.getArtistAlbums(artist.id);
        if (artistAlbums.isNotEmpty) {
          albums.add(artistAlbums.first);
        }
      } catch (e) {
        debugPrint('[HomeScreen] loadLatestFromFeatured error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _latestReleases = albums;
        _releasesLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    final listenedCount = library.listenedTracks.length;
    final artistsCount = library.uniqueArtistsCount;
    final albumsCount = library.uniqueAlbumsCount;
    final topArtists = library.getTopArtists(limit: 1);
    final topArtistName = topArtists.isNotEmpty ? topArtists.first.name : '---';
    final topArtistScore =
        topArtists.isNotEmpty ? topArtists.first.score.toString() : '0';

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.bgCard,
        onRefresh: _loadHomeData,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // Header: INICIO //
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
                            GestureDetector(
                              onTap: () => _showProfileMenu(context, auth),
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
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else ...[
              // Stats Row
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

              // Top Artists (real ranking)
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

              // Latest Releases
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
                    ? const SizedBox(
                        height: 185,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accent)),
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

              // Recommendations (featured artists)
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
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider auth) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final audioProvider = context.read<AudioProvider>();
        final spotify = audioProvider.spotify;
        final locale = context.read<LocaleProvider>();
        final strings = locale.strings;

        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.borderGlow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (auth.user?.photoURL != null)
                    CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(auth.user!.photoURL!),
                  ),
                const SizedBox(height: 12),
                Text(
                  auth.user?.displayName ?? '',
                  style: locale.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                ),
                Text(
                  auth.user?.email ?? '',
                  style: locale.getTextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Spotify connection
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgMid,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: spotify.isConnected
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spotify',
                              style: locale.getTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textBright,
                              ),
                            ),
                            Text(
                              spotify.isConnected
                                  ? (spotify.isPremium
                                      ? 'Premium · ${spotify.displayName ?? strings.spotifyDefaultUser}'
                                      : '${strings.spotifyConnected} · ${spotify.displayName ?? strings.spotifyDefaultUser}')
                                  : strings.spotifyNotConnected,
                              style: locale.getTextStyle(
                                fontSize: 10,
                                color: spotify.isConnected
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (spotify.isConnected)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.launch_rounded, size: 16, color: AppColors.accent),
                              tooltip: strings.openSpotifyTooltip,
                              onPressed: () => spotify.openSpotifyApp(),
                            ),
                            TextButton(
                              onPressed: () async {
                                await spotify.disconnect();
                                await audioProvider.updateSpotifyState();
                                setModalState(() {});
                              },
                              child: Text(
                                strings.spotifyDisconnect,
                                style: locale.getTextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton(
                          onPressed: () async {
                            setModalState(() {});
                            try {
                              final success = await spotify.connect();
                              if (success) {
                                await audioProvider.updateSpotifyState();
                                setModalState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(strings.spotifySyncSuccess),
                                      backgroundColor: AppColors.accent,
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  final rawError = spotify.lastError;
                                  String msg = strings.spotifyConnectError;
                                  if (rawError != null) {
                                    final lower = rawError.toLowerCase();
                                    if (lower.contains('cancel') || lower.contains('cancelada') || lower.contains('canceled_by_user')) {
                                      msg = strings.spotifyCanceledByUser;
                                    }
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        msg,
                                        style: locale.getTextStyle(fontSize: 12, color: Colors.white),
                                      ),
                                      backgroundColor: AppColors.accent,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${strings.errorPrefix}: $e'),
                                    backgroundColor: AppColors.accent,
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                          ),
                          child: Text(
                            strings.spotifyConnect,
                            style: locale.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (spotify.isConnected) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          spotify.isPremium ? Icons.verified_rounded : Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spotify.isPremium
                                ? (spotify.activeDeviceName != null
                                    ? strings.spotifyActiveDevice(spotify.activeDeviceName!)
                                    : strings.spotifyPremiumActive)
                                : strings.spotifyStandardPreview,
                            style: locale.getTextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Language Selector Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (context.mounted) {
                        LanguageSelectorSheet.show(context);
                      }
                    },
                    icon: const Icon(
                      Icons.language_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.languageOption,
                          style: locale.getTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            locale.currentLanguage.tag,
                            style: locale.getTextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tutorial & Masks guide
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (pushedCtx) => OnboardingScreen(
                              onComplete: () {
                                if (Navigator.of(pushedCtx).canPop()) {
                                  Navigator.of(pushedCtx).pop();
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.neonCyan,
                      size: 16,
                    ),
                    label: Text(
                      strings.tutorialOption,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.neonCyan.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Logout
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _confirmLogout(context, auth);
                    },
                    icon: const Icon(Icons.logout, color: AppColors.accent),
                    label: Text(
                      strings.logoutOption,
                      style: locale.getTextStyle(
                        fontSize: 12,
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
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final locale = context.read<LocaleProvider>();
    final strings = locale.strings;
    final shouldLogout = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.logoutConfirmTitle,
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Text(
          strings.logoutConfirmMessage,
          style: locale.getTextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              strings.cancel,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              strings.logout,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await _handleLogout(context, auth);
    }
  }

  Future<void> _handleLogout(BuildContext context, AuthProvider auth) async {
    try {
      // 1. Detener reproducción activa y vaciar cola
      final audioProvider = context.read<AudioProvider>();
      await audioProvider.stop();

      // 2. Desconectar listener de Firestore de la librería
      if (context.mounted) {
        context.read<LibraryProvider>().disconnectFirestore();
      }

      // 3. Cerrar sesión en Firebase y Google
      await auth.logout();
    } catch (e) {
      debugPrint('Error durante el cierre de sesión: $e');
    } finally {
      // 4. Navegar a LoginScreen limpiando todo el árbol de navegación
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (route) => false,
        );
      }
    }
  }

  Widget _buildStatCard(String label, String value, String meta,
      {bool isTextValue = false, LocaleProvider? locale}) {
    return Container(
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
    );
  }

  Widget _buildRankedArtistRow(
      BuildContext context, TopArtistEntry entry, Artist? artist, int rank, LocaleProvider locale) {
    return InkWell(
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
    );
  }

  Widget _buildFeaturedArtistRow(
      BuildContext context, Artist artist, int rank, LocaleProvider locale) {
    return InkWell(
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
    );
  }
}

class _TopArtistDisplay {
  final TopArtistEntry entry;
  final Artist? artist;
  _TopArtistDisplay({required this.entry, this.artist});
}
