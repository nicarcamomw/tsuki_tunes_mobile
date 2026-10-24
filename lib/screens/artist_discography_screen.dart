import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../models/album.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/deezer_api_service.dart';
import 'album_detail_screen.dart';
import 'main_navigation_screen.dart';

class ArtistDiscographyScreen extends StatefulWidget {
  final String? artistId;
  final String artistName;
  final List<Album> albums;
  final int totalAlbums;
  final String initialFilter;

  const ArtistDiscographyScreen({
    super.key,
    this.artistId,
    required this.artistName,
    required this.albums,
    this.totalAlbums = 0,
    this.initialFilter = 'all',
  });

  @override
  State<ArtistDiscographyScreen> createState() =>
      _ArtistDiscographyScreenState();
}

class _ArtistDiscographyScreenState extends State<ArtistDiscographyScreen> {
  final DeezerApiService _api = DeezerApiService();
  late String _filter;
  late final ScrollController _scrollController;
  late List<Album> _allAlbums;
  late int _totalAlbums;
  late bool _hasMore;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _allAlbums = List<Album>.from(widget.albums);
    _totalAlbums = widget.totalAlbums > 0
        ? widget.totalAlbums
        : (_allAlbums.length >= 250 ? 9999 : _allAlbums.length);
    _hasMore = (widget.artistId != null) &&
        (_totalAlbums > _allAlbums.length || _allAlbums.length >= 250);
    _scrollController = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoFill();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 400 && !_isLoadingMore && _hasMore) {
      _loadMoreAlbums();
    }
  }

  void _setFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoFill());
  }

  void _checkAutoFill() {
    if (!mounted || _isLoadingMore || !_hasMore || widget.artistId == null) {
      return;
    }
    // Proactively load next batch if current filter has very few visible items
    if (_filtered.length < 8) {
      _loadMoreAlbums();
    }
  }

  Future<void> _loadMoreAlbums() async {
    if (widget.artistId == null || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = false;
    });

    try {
      final nonCompileCount =
          _allAlbums.where((a) => a.recordType != 'compile').length;
      final page = await _api.getArtistAlbumsPage(
        widget.artistId!,
        limit: 100,
        index: nonCompileCount,
      );

      if (!mounted) return;

      if (page.items.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final existingIds = _allAlbums.map((a) => a.id).toSet();
      final newItems =
          page.items.where((a) => !existingIds.contains(a.id)).toList();

      setState(() {
        _allAlbums.addAll(newItems);
        _totalAlbums = page.total > 0 ? page.total : _allAlbums.length;
        _hasMore = page.hasMore && (_allAlbums.length < _totalAlbums);
        _isLoadingMore = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoFill());
    } catch (e) {
      debugPrint('[ArtistDiscography] _loadMoreAlbums error: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _loadMoreError = true;
        });
      }
    }
  }

  bool _isOwnRelease(Album a) {
    final id = widget.artistId;
    if (id != null && a.artistId.isNotEmpty) return a.artistId == id;
    return a.artistName.toLowerCase().trim() ==
        widget.artistName.toLowerCase().trim();
  }

  List<Album> get _filtered {
    if (_filter == 'all') return _allAlbums;
    if (_filter == 'appears_on') {
      return _allAlbums.where((a) => !_isOwnRelease(a)).toList();
    }
    if (_filter == 'single_ep') {
      return _allAlbums
          .where((a) =>
              _isOwnRelease(a) &&
              (a.recordType == 'single' || a.recordType == 'ep'))
          .toList();
    }
    return _allAlbums
        .where((a) => _isOwnRelease(a) && a.recordType == _filter)
        .toList();
  }

  Map<String, List<Album>> get _categories {
    final Map<String, List<Album>> cats = {};
    for (final a in _allAlbums) {
      if (!_isOwnRelease(a)) {
        cats.putIfAbsent('appears_on', () => []).add(a);
      } else if (a.recordType == 'album') {
        cats.putIfAbsent('album', () => []).add(a);
      } else if (a.recordType == 'single') {
        cats.putIfAbsent('single', () => []).add(a);
      } else if (a.recordType == 'ep' || a.recordType == 'compile') {
        cats.putIfAbsent('ep', () => []).add(a);
      } else {
        cats.putIfAbsent('album', () => []).add(a);
      }
    }
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    library.ensureAlbumTrackCounts(_allAlbums, _api.getAlbum);
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final cats = _categories;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_allAlbums);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          title: Text(
            widget.artistName,
            style: locale.getTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textBright,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            tooltip: strings.a11yBack,
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
              child: Icon(Icons.chevron_left,
                  color: AppColors.accent, size: 24, semanticLabel: strings.a11yBack),
            ),
            onPressed: () => Navigator.of(context).pop(_allAlbums),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              controller: _scrollController,
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
                          if (cats.containsKey('appears_on'))
                            _buildChip('appears_on', strings.tabAppearsOn, locale),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          strings.noResults,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = _filtered[index];
                          return _buildItem(
                              context, album, library, locale, strings);
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
                if (_isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              strings.loadingMoreAlbums,
                              style: locale.getTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_loadMoreError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: strings.retryLoading,
                          child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: _loadMoreAlbums,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgMid,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh,
                                    size: 14, color: AppColors.accent, semanticLabel: strings.a11yRetry),
                                const SizedBox(width: 8),
                                Text(
                                  strings.retryLoading,
                                  style: locale.getTextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textBright,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
                if (!_hasMore && _allAlbums.length > 20)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Center(
                        child: Text(
                          '${strings.allAlbumsLoaded} (${_filtered.length})',
                          style: locale.getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String value, String label, LocaleProvider locale) {
    final isSelected = _filter == value;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _setFilter(value);
        },
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
      ),
    );
  }

  Widget _buildItem(BuildContext context, Album album, LibraryProvider library,
      LocaleProvider locale, AppStrings strings) {
    final isCompleted =
        library.isAlbumCompleted(album.id, albumTracksCount: album.tracksCount);

    return Semantics(
      button: true,
      label: '${album.title}, ${strings.albumTypeLabel(album.recordType)}',
      child: GestureDetector(
        onTap: () async {
          await appNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
          );
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
                child: _buildCover(album, isCompleted, strings),
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
            '${album.year}  ·  ${strings.albumTypeLabel(album.recordType)}',
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

  Widget _buildCover(Album album, bool isCompleted, AppStrings strings) {
    final image = album.coverUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: album.coverUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : Container(
            color: AppColors.bgMid,
            child: Icon(Icons.album, color: AppColors.accent, size: 40, semanticLabel: strings.a11yAlbumCover),
          );

    if (isCompleted) return ExcludeSemantics(child: image);

    return ExcludeSemantics(
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: image,
      ),
    );
  }
}
