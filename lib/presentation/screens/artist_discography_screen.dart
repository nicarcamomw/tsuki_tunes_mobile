import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/album_categorizer.dart';
import '../../core/utils/image_cache_size.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/album.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';

class ArtistDiscographyScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ArtistDiscographyScreen> createState() =>
      _ArtistDiscographyScreenState();
}

class _ArtistDiscographyScreenState extends ConsumerState<ArtistDiscographyScreen> {
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

  bool _isOwnRelease(Album a) => AlbumCategorizer.isOwnRelease(
        a, artistId: widget.artistId ?? '', artistName: widget.artistName);

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
    final library = ref.watch(libraryProvider);
    library.ensureAlbumTrackCounts(_allAlbums, _api.getAlbum);
    final locale = ref.watch(localeProvider);
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
                  ),
                if (_filtered.isNotEmpty && _filter == 'all')
                  ..._buildAllSections(cats, library, locale, strings),
                if (_filtered.isNotEmpty && _filter != 'all')
                  ..._buildFilteredGrid(_filtered, library, locale, strings,
                      isAppearsOn: _filter == 'appears_on'),
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

  List<Widget> _buildAllSections(Map<String, List<Album>> cats,
      LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings) {
    final sections = <Widget>[];
    final order = [
      ('album', strings.tabAlbums, Icons.album_rounded, false),
      ('ep', strings.tabEps, Icons.album_outlined, false),
      ('single', strings.tabSingles, Icons.music_note_rounded, false),
      ('appears_on', strings.tabAppearsOn, Icons.groups_rounded, true),
    ];
    for (final (key, label, icon, isAppearsOn) in order) {
      final items = cats[key];
      if (items == null || items.isEmpty) continue;
      sections.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent, semanticLabel: label),
              const SizedBox(width: 8),
              Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: locale.getTextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ));
      sections.addAll(_buildFilteredGrid(items, library, locale, strings,
          isAppearsOn: isAppearsOn));
    }
    return sections;
  }

  List<Widget> _buildFilteredGrid(List<Album> albums,
      LibraryRepositoryImpl library, LocaleProvider locale, AppStrings strings,
      {bool isAppearsOn = false}) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 4,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildItem(
                context, albums[index], library, locale, strings,
                isAppearsOn: isAppearsOn),
            childCount: albums.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildItem(BuildContext context, Album album, LibraryRepositoryImpl library,
      LocaleProvider locale, AppStrings strings,
      {bool isAppearsOn = false}) {
    final isCompleted =
        library.isAlbumCompleted(album.id, albumTracksCount: album.tracksCount);
    final subtitle = isAppearsOn
        ? '${album.year}  ·  ${album.artistName}'
        : '${album.year}  ·  ${strings.albumTypeLabel(album.recordType)}';

    return Semantics(
      button: true,
      label: '${album.title}, ${album.artistName}',
      child: GestureDetector(
        onTap: () async {
          await AlbumRoute(id: album.id, $extra: album).push(context);
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
            subtitle,
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
          memCacheWidth: imageCacheSize(context, (200).toDouble()),
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
