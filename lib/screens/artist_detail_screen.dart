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
import '../widgets/oni_mask_icon.dart';
import '../widgets/distorted_artist_name.dart';
import '../widgets/app_custom_icons.dart';
import '../services/lastfm_service.dart';
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
  List<String> _artistTags = [];
  bool _isLoading = true;
  String _discographyFilter = 'all';

  bool _showStats = false;

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
        LastFmService.getArtistTags(widget.artist.name),
      ]);
      if (mounted) {
        setState(() {
          _topTracks = results[0] as List<Track>;
          _albums = results[1] as List<Album>;
          _artistTags = results[2] as List<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ArtistDetail] loadArtistData error: $e');
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

    // Check if ALL albums have ALL tracks listened
    final bool isArtistComplete = _albums.isNotEmpty &&
        _albums.every((album) {
          if (album.tracksCount <= 0) return false;
          final listenedInAlbum = library.listenedTracks
              .where((t) => t.albumId == album.id)
              .length;
          return listenedInAlbum >= album.tracksCount;
        });

    final displayedTracks = _topTracks.take(5).toList();

    final cats = _categorizedAlbums;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: CustomScrollView(
        slivers: [
          // Hero with parallax
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: AppColors.bgDeep,
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
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isArtistComplete
                          ? AppColors.accent.withValues(alpha: 0.6)
                          : AppColors.textMuted.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: OniMaskIcon(
                    isActive: isArtistComplete,
                    size: 22,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.artist.pictureUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.artist.getBestImage(size: 'xl'),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
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
                              '${Formatters.formatNumber(widget.artist.fansCount)} fanáticos',
                              style: GoogleFonts.plusJakartaSans(
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
                        GestureDetector(
                          onTap: () {
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
                                '${widget.artist.albumsCount} lanzamientos',
                                style: GoogleFonts.plusJakartaSans(
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
                    ],
                  ),

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
                              '${cats['album']!.length} ${cats['album']!.length == 1 ? 'álbum' : 'álbumes'}',
                            ),
                          if (_albums
                              .where((a) => a.recordType == 'ep')
                              .isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.ep(
                                  size: 15, color: AppColors.accent),
                              '${_albums.where((a) => a.recordType == 'ep').length} ${_albums.where((a) => a.recordType == 'ep').length == 1 ? 'EP' : 'EPs'}',
                            ),
                          if (_albums
                              .where((a) => a.recordType == 'single')
                              .isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.nota(
                                  size: 15, color: AppColors.accent),
                              '${_albums.where((a) => a.recordType == 'single').length} ${_albums.where((a) => a.recordType == 'single').length == 1 ? 'sencillo' : 'sencillos'}',
                            ),
                          if (cats['compile']!.isNotEmpty)
                            _buildBreakdownItem(
                              AppCustomIcons.grupo(
                                  size: 15, color: AppColors.accent),
                              '${cats['compile']!.length} aparece en',
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
                            style: GoogleFonts.plusJakartaSans(
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
                        'POPULARES',
                        style: GoogleFonts.plusJakartaSans(
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
                      style: GoogleFonts.plusJakartaSans(
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
          style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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

  Widget _buildBreakdownItem(Widget icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
