import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/track_tile.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final DeezerApiService _api = DeezerApiService();
  List<Track> _topTracks = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  bool _showAllTopTracks = false;
  String _discographyFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadArtistData();
    _trackVisit();
  }

  void _trackVisit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().trackArtistVisit(widget.artist.name);
    });
  }

  Future<void> _loadArtistData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getArtistTopTracks(widget.artist.id, limit: 10),
        _api.getArtistAlbums(widget.artist.id, limit: 250),
      ]);
      if (mounted) {
        setState(() {
          _topTracks = results[0] as List<Track>;
          _albums = results[1] as List<Album>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Album> get _filteredAlbums {
    if (_discographyFilter == 'all') return _albums;
    if (_discographyFilter == 'single_ep') {
      return _albums.where((a) =>
          a.recordType == 'single' || a.recordType == 'ep').toList();
    }
    return _albums.where((a) => a.recordType == _discographyFilter).toList();
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
    final library = context.watch<LibraryProvider>();
    final isFavArtist = library.isFavoriteArtist(widget.artist.id);
    final audio = context.read<AudioProvider>();

    final displayedTracks = _showAllTopTracks
        ? _topTracks
        : _topTracks.take(5).toList();

    final cats = _categorizedAlbums;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: CustomScrollView(
        slivers: [
          // Hero with parallax
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: AppColors.textBright, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavArtist ? Icons.favorite : Icons.favorite_border,
                    color: isFavArtist ? AppColors.accent : AppColors.textBright,
                    size: 20,
                  ),
                ),
                onPressed: () =>
                    library.toggleFavoriteArtist(widget.artist),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artist.name,
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  shadows: [
                    const Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.artist.pictureUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.artist.getBestImage(size: 'xl'),
                      fit: BoxFit.cover,
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0x8014171F),
                          AppColors.bgDeep,
                        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      if (widget.artist.fansCount > 0) ...[
                        Text(
                          '${Formatters.formatNumber(widget.artist.fansCount)} FANS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (widget.artist.albumsCount > 0)
                        Text(
                          '${widget.artist.albumsCount} LANZAMIENTOS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Play popular button
                  if (_topTracks.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          audio.playTrack(_topTracks.first,
                              newQueue: _topTracks);
                        },
                        icon: const Icon(Icons.play_arrow,
                            color: AppColors.accent),
                        label: Text(
                          'PLAY POPULAR',
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Top Tracks header with toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '// POPULAR TRACKS',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (_topTracks.length > 5)
                        GestureDetector(
                          onTap: () {
                            setState(() =>
                                _showAllTopTracks = !_showAllTopTracks);
                          },
                          child: Text(
                            _showAllTopTracks ? 'VER MENOS' : 'VER MÁS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
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
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            )
          else if (_topTracks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tracks found',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => TrackTile(
                  track: displayedTracks[index],
                  index: index,
                  queue: _topTracks,
                ),
                childCount: displayedTracks.length,
              ),
            ),

          // Discography
          if (!_isLoading && _albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '// DISCOGRAFÍA',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Todos'),
                          if (cats['album']!.isNotEmpty)
                            _buildFilterChip('album', 'Álbumes'),
                          if (cats['single_ep']!.isNotEmpty)
                            _buildFilterChip('single_ep', 'Singles/EPs'),
                          if (cats['compile']!.isNotEmpty)
                            _buildFilterChip('compile', 'Compilaciones'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Album grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = _filteredAlbums[index];
                    return _buildDiscographyItem(context, album, library);
                  },
                  childCount: _filteredAlbums.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _discographyFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _discographyFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.bgMid,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.textBright : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscographyItem(
      BuildContext context, Album album, LibraryProvider library) {
    final listenedCount = album.tracksCount > 0
        ? library.listenedTracks
            .where((t) => t.albumId == album.id)
            .length
        : 0;
    final isCompleted =
        album.tracksCount > 0 && listenedCount >= album.tracksCount;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: isCompleted ? 1.5 : 1,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: album.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: AppColors.bgMid,
                        child: const Icon(Icons.album,
                            color: AppColors.accent, size: 40),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${album.year}  ·  ${Album.getAlbumTypeLabel(album.recordType)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
