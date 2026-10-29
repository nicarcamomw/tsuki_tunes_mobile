import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../models/lyrics_search_result.dart';
import '../providers/audio_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/search_provider.dart';
import '../services/deezer_api_service.dart';
import '../services/voice_search_service.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/track_tile.dart';
import '../widgets/voice_search_sheet.dart';
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
  // The microphone is asked for on the first tap, not when the tab opens;
  // the voice sheet explains any problem (permission, no recognizer).
  static const bool _voiceSupported = !kIsWeb;

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
      if (_selectedTabIndex == 4) {
        provider.searchLyrics(query);
      } else {
        provider.search(query);
      }
    });
  }

  Future<void> _startVoiceSearch() async {
    unawaited(HapticFeedback.lightImpact());
    FocusScope.of(context).unfocus();
    final locale = context.read<LocaleProvider>();
    final audio = context.read<AudioProvider>();
    final search = context.read<SearchProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = locale.strings;

    // Music playing next to the mic drowns the voice out: pause it while
    // listening and pick it back up unless the command plays something.
    final resumeAfter = audio.isPlaying;
    if (resumeAfter) await audio.togglePlay();
    if (!mounted) return;

    final spokenText = await VoiceSearchSheet.show(
      context,
      langCode: locale.currentLanguage.code,
    );

    final command = spokenText == null
        ? null
        : VoiceSearchService.parseCommand(spokenText);
    if (command == null || command.query.isEmpty || !mounted) {
      if (resumeAfter && !audio.isPlaying) await audio.togglePlay();
      return;
    }

    _controller.text = command.query;

    if (command.action != VoiceAction.play) {
      if (resumeAfter && !audio.isPlaying) unawaited(audio.togglePlay());
      unawaited(search.search(command.query));
      return;
    }

    await search.search(command.query);
    // "pon Jefe de La Combo Tortuga": try again without the "de".
    final joined = VoiceSearchService.withoutArtistJoiner(command.query);
    if (search.tracks.isEmpty && joined != null) {
      _controller.text = joined;
      await search.search(joined);
    }
    if (!mounted) return;
    if (search.tracks.isEmpty) {
      if (resumeAfter && !audio.isPlaying) unawaited(audio.togglePlay());
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
        content: Text(
          '${strings.noResults}: "${command.query}"',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
      ));
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    await audio.playTrack(search.tracks.first, newQueue: search.tracks);
  }

  @override
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
    final hasLyricsResults = search.lyricsResults.isNotEmpty;
    final tabs = [
      strings.tabAll,
      hasResults ? '${strings.tabArtists} (${search.artists.length})' : strings.tabArtists,
      hasResults ? '${strings.tabAlbums} (${search.albums.length})' : strings.tabAlbums,
      hasResults ? '${strings.tabTracks} (${search.tracks.length})' : strings.tabTracks,
      hasLyricsResults ? '${strings.tabByLyrics} (${search.lyricsResults.length})' : strings.tabByLyrics,
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
                    Semantics(
                      header: true,
                      child: Row(
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
                          if (value.text.isNotEmpty) {
                            return IconButton(
                              icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yClearSearch),
                              tooltip: strings.a11yClearSearch,
                              onPressed: () {
                                _controller.clear();
                                search.clear();
                              },
                            );
                          }
                          if (!_voiceSupported) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.mic, color: AppColors.accent, size: 20),
                            tooltip: strings.a11yVoiceSearch,
                            onPressed: _startVoiceSearch,
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
                      child: _TapScale(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        FocusScope.of(context).unfocus();
                        final prev = _selectedTabIndex;
                        setState(() => _selectedTabIndex = index);
                        if (index == 4 && prev != 4) {
                          final q = _controller.text.trim();
                          if (q.length >= 3) {
                            context.read<SearchProvider>().searchLyrics(q);
                          }
                        }
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
                child: _selectedTabIndex == 4
                    ? _buildLyricsTabContent(search, strings, locale)
                    : search.isLoading
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
              Opacity(
                opacity: 0.3,
                child: Image.asset('assets/images/tengu.png', width: 54, height: 54, semanticLabel: strings.a11ySearchEmpty),
              ),
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

  Widget _buildLyricsTabContent(SearchProvider search, AppStrings strings, LocaleProvider locale) {
    if (search.isLyricsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (search.hasLyricsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
            const SizedBox(height: 12),
            Text(
              strings.lyricsSearchError,
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
                  search.retryLyricsSearch();
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

    final q = _controller.text.trim();
    if (q.length < 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 54, color: AppColors.borderGlow, semanticLabel: strings.a11yLyricsSearch),
            const SizedBox(height: 12),
            Text(
              strings.lyricsSearchEmpty,
              style: locale.getTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.lyricsSearchEmptySubtitle,
              style: locale.getTextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (search.lyricsResults.isEmpty) {
      return Center(
        child: Text(
          strings.lyricsSearchNoResults,
          style: locale.getTextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: search.lyricsResults.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              strings.lyricsSearchResults(search.lyricsResults.length).toUpperCase(),
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        return _buildLyricsResultTile(search.lyricsResults[index - 1], q, locale);
      },
    );
  }

  Widget _buildLyricsResultTile(LyricsSearchResult result, String query, LocaleProvider locale) {
    final snippet = result.lyricsSnippet;

    return InkWell(
      onTap: () async {
        unawaited(HapticFeedback.lightImpact());
        try {
          final deezerResults = await DeezerApiService().search(
            '${result.trackName} ${result.artistName}',
          );
          final tracks = deezerResults['tracks'];
          if (tracks != null && tracks.isNotEmpty) {
            if (!mounted) return;
            final provider = context.read<SearchProvider>();
            _controller.text = '${result.trackName} ${result.artistName}';
            unawaited(provider.search('${result.trackName} ${result.artistName}'));
            setState(() => _selectedTabIndex = 3);
          }
        } catch (_) {}
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lyrics_outlined, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.trackName,
                    style: locale.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.artistName}  ·  ${result.albumName}',
                    style: locale.getTextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildHighlightedSnippet(snippet, query, locale),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              result.durationFormatted,
              style: locale.getTextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedSnippet(String snippet, String query, LocaleProvider locale) {
    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerSnippet.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        snippet,
        style: locale
            .getTextStyle(fontSize: 11, color: AppColors.textMuted)
            .copyWith(fontStyle: FontStyle.italic),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final before = snippet.substring(0, matchIndex);
    final match = snippet.substring(matchIndex, matchIndex + query.length);
    final after = snippet.substring(matchIndex + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: locale
            .getTextStyle(fontSize: 11, color: AppColors.textMuted)
            .copyWith(fontStyle: FontStyle.italic),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: locale
                .getTextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                )
                .copyWith(fontStyle: FontStyle.italic),
          ),
          TextSpan(text: after),
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

class _TapScale extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _TapScale({required this.onTap, required this.child});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
