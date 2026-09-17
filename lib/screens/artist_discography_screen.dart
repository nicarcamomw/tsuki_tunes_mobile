import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/oni_mask_icon.dart';
import 'album_detail_screen.dart';
import 'main_navigation_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtistDiscographyScreen extends StatefulWidget {
  final String artistName;
  final List<Album> albums;
  final String initialFilter;

  const ArtistDiscographyScreen({
    super.key,
    required this.artistName,
    required this.albums,
    this.initialFilter = 'all',
  });

  @override
  State<ArtistDiscographyScreen> createState() =>
      _ArtistDiscographyScreenState();
}

class _ArtistDiscographyScreenState extends State<ArtistDiscographyScreen> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  List<Album> get _filtered {
    if (_filter == 'all') return widget.albums;
    if (_filter == 'single_ep') {
      return widget.albums
          .where((a) => a.recordType == 'single' || a.recordType == 'ep')
          .toList();
    }
    return widget.albums.where((a) => a.recordType == _filter).toList();
  }

  Map<String, List<Album>> get _categories {
    final Map<String, List<Album>> cats = {};
    for (final a in widget.albums) {
      if (a.recordType == 'album') {
        cats.putIfAbsent('album', () => []).add(a);
      } else if (a.recordType == 'single') {
        cats.putIfAbsent('single', () => []).add(a);
      } else if (a.recordType == 'ep') {
        cats.putIfAbsent('ep', () => []).add(a);
      } else if (a.recordType == 'compile') {
        cats.putIfAbsent('compile', () => []).add(a);
      }
    }
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final cats = _categories;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        title: Text(
          widget.artistName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('all', strings.tabAll, locale),
                    if (cats.containsKey('album'))
                      _buildChip('album', strings.tabAlbums, locale),
                    if (cats.containsKey('single'))
                      _buildChip('single', strings.tabSingles, locale),
                    if (cats.containsKey('ep'))
                      _buildChip('ep', strings.tabEps, locale),
                    if (cats.containsKey('compile'))
                      _buildChip('compile', strings.tabAppearsOn, locale),
                  ],
                ),
              ),
            ),
          ),
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
                  final album = _filtered[index];
                  return _buildItem(context, album, library, locale, strings);
                },
                childCount: _filtered.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildChip(String value, String label, LocaleProvider locale) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
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
          style: locale.getTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.textBright : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, Album album, LibraryProvider library, LocaleProvider locale, dynamic strings) {
    final listenedCount = album.tracksCount > 0
        ? library.listenedTracks.where((t) => t.albumId == album.id).length
        : 0;
    final isCompleted =
        album.tracksCount > 0 && listenedCount >= album.tracksCount;

    return GestureDetector(
      onTap: () {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
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
                      ? AppColors.accent.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: isCompleted ? 1.5 : 1,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: _buildCover(album, isCompleted),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.title,
            style: locale.getTextStyle(
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
                  '${album.year}  ·  ${strings.albumTypeLabel(album.recordType)}',
                  style: locale.getTextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCompleted) const OniMaskIcon(isActive: true, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(Album album, bool isCompleted) {
    final image = album.coverUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: album.coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
          )
        : Container(
            color: AppColors.bgMid,
            child: const Icon(Icons.album, color: AppColors.accent, size: 40),
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
}
