import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../providers/locale_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/track_tile.dart';
import 'main_navigation_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  Timer? _debounce;
  int _selectedTabIndex = 0;
  String _lastAnnouncedQuery = '';

  @override
  void initState() {
    super.initState();
    NavigationEvents.onSearchFocus = focusSearchInput;
    NavigationEvents.onSearchClear = clearAndFocus;
  }

  @override
  void dispose() {
    if (NavigationEvents.onSearchFocus == focusSearchInput) {
      NavigationEvents.onSearchFocus = null;
    }
    if (NavigationEvents.onSearchClear == clearAndFocus) {
      NavigationEvents.onSearchClear = null;
    }
    _debounce?.cancel();
    _controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  /// Enfoca el campo de texto y despliega el teclado (Double-Tap o Tap activo)
  void focusSearchInput() {
    focusNode.requestFocus();
  }

  /// Limpia la búsqueda actual y re-enfoca el teclado (Long-Press en Search)
  void clearAndFocus() {
    _controller.clear();
    context.read<SearchProvider>().clear();
    focusNode.requestFocus();
  }

  void _onSearchChanged(String query, SearchProvider provider) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      provider.search(query);
    });
  }  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final hasResults = search.artists.isNotEmpty || search.albums.isNotEmpty || search.tracks.isNotEmpty;
    if (!search.isLoading && search.query.isNotEmpty && !search.hasError && _lastAnnouncedQuery != search.query) {
      _lastAnnouncedQuery = search.query;
      final total = search.artists.length + search.albums.length + search.tracks.length;
      final view = View.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (total > 0) {
          SemanticsService.sendAnnouncement(view, '$total ${strings.tabAll}', TextDirection.ltr);
        } else {
          SemanticsService.sendAnnouncement(view, strings.noResults, TextDirection.ltr);
        }
      });
    }
    final tabs = [
      strings.tabAll,
      hasResults ? '${strings.tabArtists} (${search.artists.length})' : strings.tabArtists,
      hasResults ? '${strings.tabAlbums} (${search.albums.length})' : strings.tabAlbums,
      hasResults ? '${strings.tabTracks} (${search.tracks.length})' : strings.tabTracks,
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          strings.searchTitle.toUpperCase(),
                          style: locale.getTextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textBright,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          ' // 02',
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
                      strings.searchTelemetry,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.searchSubtitle,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgMid,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: focusNode,
                    maxLength: 100,
                    style: locale.getTextStyle(color: AppColors.textBright, fontSize: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: strings.searchHint,
                      hintStyle: locale.getTextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const ExcludeSemantics(child: Icon(Icons.search, color: AppColors.textSecondary, size: 20)),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) return const SizedBox.shrink();
                          return IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yClearSearch),
                            tooltip: strings.a11yClearSearch,
                            onPressed: () {
                              _controller.clear();
                              search.clear();
                            },
                          );
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) => _onSearchChanged(val, search),
                  ),
                ),
              ),

              // Tabs: ['Todo', 'Artistas', 'Álbumes', 'Canciones'] (localizadas)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: List.generate(tabs.length, (index) {
                    final isSelected = _selectedTabIndex == index;
                    return Semantics(
                      button: true,
                      label: tabs[index],
                      child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        FocusScope.of(context).unfocus();
                        setState(() => _selectedTabIndex = index);
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
                          tabs[index],
                          style: locale.getTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.textBright : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 6),

              // Content
              Expanded(
                child: search.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      )
                    : search.hasError
                        ? _buildErrorState(search, strings, locale)
                        : search.query.isEmpty
                            ? _buildEmptyState(strings, locale)
                            : _buildResults(search, strings, locale),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppStrings strings, LocaleProvider locale) {
    final search = context.read<SearchProvider>();
    final history = search.searchHistory;

    if (history.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 54, color: AppColors.borderGlow, semanticLabel: strings.a11ySearchEmpty),
              const SizedBox(height: 12),
              Text(
                strings.emptyStateTitle,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.emptyStateSubtitle,
                style: locale.getTextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.recentSearches,
                style: locale.getTextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              Semantics(
                button: true,
                label: strings.clearHistory,
                child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.bgCard,
                      title: Text(
                        strings.clearHistory,
                        style: locale.getTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            strings.cancel,
                            style: locale.getTextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            search.clearHistory();
                          },
                          child: Text(
                            strings.confirm,
                            style: locale.getTextStyle(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  strings.clearHistory,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map((q) => Dismissible(
                key: ValueKey('history_$q'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete_outline,
                      color: AppColors.accent, size: 18, semanticLabel: strings.a11yClearHistory),
                ),
                onDismissed: (_) => search.removeFromHistory(q),
                child: InkWell(
                  onTap: () {
                    _controller.text = q;
                    search.search(q);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.history,
                            size: 18, color: AppColors.textMuted, semanticLabel: strings.a11ySearchHistory),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q,
                            style: locale.getTextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(Icons.north_west,
                                size: 14, color: AppColors.textMuted, semanticLabel: strings.a11yFillSearch),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildErrorState(SearchProvider search, AppStrings strings, LocaleProvider locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
          const SizedBox(height: 12),
          Text(
            strings.searchError,
            style: locale.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: strings.retry,
            child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              search.retryLastSearch();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
              child: Text(
                strings.retry,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SearchProvider search, AppStrings strings, LocaleProvider locale) {
    final showAll = _selectedTabIndex == 0;
    final showArtists = showAll || _selectedTabIndex == 1;
    final showAlbums = showAll || _selectedTabIndex == 2;
    final showTracks = showAll || _selectedTabIndex == 3;

    final hasArtists = search.artists.isNotEmpty;
    final hasAlbums = search.albums.isNotEmpty;
    final hasTracks = search.tracks.isNotEmpty;

    if (!hasArtists && !hasAlbums && !hasTracks) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Text(
            strings.noResultsFor(search.query),
            style: locale.getTextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Check if the selected tab's specific results are empty
    final tabHasResults = showAll ||
        (_selectedTabIndex == 1 && hasArtists) ||
        (_selectedTabIndex == 2 && hasAlbums) ||
        (_selectedTabIndex == 3 && hasTracks);

    if (!tabHasResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            strings.noResults,
            style: locale.getTextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // Artists Section
        if (showArtists && hasArtists) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabArtists.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 155,
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: search.artists.length,
              itemBuilder: (context, i) => ArtistCard(artist: search.artists[i]),
            ),
          ),
        ],

        // Albums Section
        if (showAlbums && hasAlbums) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabAlbums.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 185,
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: search.albums.length,
              itemBuilder: (context, i) => AlbumCard(album: search.albums[i]),
            ),
          ),
        ],

        // Tracks Section
        if (showTracks && hasTracks) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabTracks.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          ...search.tracks.asMap().entries.map(
                (entry) => TrackTile(
                  track: entry.value,
                  index: entry.key,
                  queue: search.tracks,
                ),
              ),
        ],
      ],
    );
  }
}
