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
import '../widgets/artist_card.dart';
import '../widgets/album_card.dart';
import '../screens/artist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DeezerApiService _api = DeezerApiService();
  List<Artist> _featuredArtists = [];
  List<Album> _latestReleases = [];
  List<_TopArtistDisplay> _topArtistsDisplay = [];
  bool _isLoading = true;
  bool _releasesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
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

      _computeTopArtists();
    } catch (_) {
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
      } catch (_) {
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
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _latestReleases = albums;
        _releasesLoading = false;
      });
    }
  }

  Future<void> _loadLatestFromFeatured() async {
    setState(() => _releasesLoading = true);
    final albums = <Album>[];

    for (final artist in _featuredArtists.take(4)) {
      try {
        final artistAlbums = await _api.getArtistAlbums(artist.id);
        if (artistAlbums.isNotEmpty) {
          albums.add(artistAlbums.first);
        }
      } catch (_) {}
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
                      Row(
                        children: [
                          Text(
                            'INICIO',
                            style: GoogleFonts.orbitron(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBright,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            ' //',
                            style: GoogleFonts.orbitron(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentDim,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ONLINE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
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
                              'CANCIONES', '$listenedCount', 'ESCUCHADAS'),
                          _buildStatCard(
                              'ARTISTAS', '$artistsCount', 'EN SISTEMA'),
                          _buildStatCard(
                              'ÁLBUMES', '$albumsCount', 'EN SISTEMA'),
                          _buildStatCard(
                            'ARTISTA TOP',
                            topArtistName,
                            'AFINIDAD: $topArtistScore',
                            isTextValue: true,
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
                      'ARTISTAS MÁS FRECUENTES',
                      style: GoogleFonts.orbitron(
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
                          context, top.entry, top.artist, index + 1);
                    },
                    childCount: _topArtistsDisplay.length,
                  ),
                ),
              ] else if (_featuredArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Text(
                      'ARTISTAS MÁS FRECUENTES',
                      style: GoogleFonts.orbitron(
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
                      return _buildFeaturedArtistRow(context, artist, index + 1);
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
                    'ÚLTIMOS LANZAMIENTOS PARA TI',
                    style: GoogleFonts.orbitron(
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
                              'Marca canciones como escuchadas para ver lanzamientos personalizados',
                              style: GoogleFonts.spaceGrotesk(
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
                      'RECOMENDACIONES DEL SISTEMA',
                      style: GoogleFonts.orbitron(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (auth.user?.photoURL != null)
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(auth.user!.photoURL!),
              ),
            const SizedBox(height: 12),
            Text(
              auth.user?.displayName ?? '',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textBright,
              ),
            ),
            Text(
              auth.user?.email ?? '',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  auth.logout();
                },
                icon: const Icon(Icons.logout, color: AppColors.accent),
                label: Text(
                  'CERRAR SESIÓN',
                  style: GoogleFonts.orbitron(
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String meta,
      {bool isTextValue = false}) {
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
            style: GoogleFonts.jetBrainsMono(
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
                ? GoogleFonts.orbitron(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sakura,
                  )
                : GoogleFonts.orbitron(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sakura,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: GoogleFonts.jetBrainsMono(
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
      BuildContext context, TopArtistEntry entry, Artist? artist, int rank) {
    return InkWell(
      onTap: () {
        if (artist != null) {
          Navigator.of(context).push(
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
                style: GoogleFonts.orbitron(
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
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Afinidad: ${entry.score}',
                    style: GoogleFonts.jetBrainsMono(
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
      BuildContext context, Artist artist, int rank) {
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
                style: GoogleFonts.orbitron(
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
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'DESTACADO',
                    style: GoogleFonts.jetBrainsMono(
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
