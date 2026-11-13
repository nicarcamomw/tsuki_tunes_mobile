import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/lyrics_search_result.dart';
import '../../domain/logic/search_suggestions.dart';
import '../../domain/logic/voice_commands.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/search_provider.dart';
import '../state/use_cases.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/error_state.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/tap_scale.dart';
import '../widgets/track_tile.dart';
import '../widgets/voice_search_sheet.dart';
import 'main_navigation_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  Timer? _debounce;
  int _selectedTabIndex = 0;
  String _lastAnnouncedQuery = '';
  // The microphone is asked for on the first tap, not when the tab opens;
  // the voice sheet explains any problem (permission, no recognizer).
  static const bool _voiceSupported = !kIsWeb;

  List<Genre> _genres = const [];

  // The user's artists (most listened first) and song and album titles,
  // for suggestions and "did you mean"; rebuilt when the library changes.
  List<String> _libraryArtists = const [];
  List<String> _libraryTitles = const [];
  Object? _libraryNamesKey;
  static const int _maxLibraryTitles = 3000;

  @override
  void initState() {
    super.initState();
    NavigationEvents.onSearchFocus = focusSearchInput;
    NavigationEvents.onSearchClear = clearAndFocus;
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await ref.read(getGenresProvider)();
    if (mounted && genres.isNotEmpty) setState(() => _genres = genres);
  }

  /// Rebuilds the user's names when their library changed, and hands them
  /// to the search for "did you mean".
  void _refreshLibraryNames(SearchProvider search) {
    final library = ref.read(libraryProvider);
    final key = (library.listenedCount, library.followedArtists.length,
        library.favoriteArtists.length);
    if (key == _libraryNamesKey) return;
    _libraryNamesKey = key;

    final plays = <String, int>{};
    final spelled = <String, String>{};
    void count(String name, int weight) {
      final n = name.trim();
      if (n.isEmpty) return;
      final k = n.toLowerCase();
      spelled.putIfAbsent(k, () => n);
      plays[k] = (plays[k] ?? 0) + weight;
    }

    // Latest listened first, so the titles kept are the recent ones.
    final tracks = [...library.listenedTracks]..sort((a, b) {
        final at = a.listenedAt, bt = b.listenedAt;
        if (at == null || bt == null) return at == null ? (bt == null ? 0 : 1) : -1;
        return bt.compareTo(at);
      });
    final titles = <String>{};
    for (final t in tracks) {
      for (final a in t.artists) {
        count(a, 1);
      }
      if (t.title.isNotEmpty) titles.add(t.title);
      if (t.albumTitle.isNotEmpty) titles.add(t.albumTitle);
    }
    // Followed and favourite artists count as much as many songs.
    for (final a in [...library.followedArtists, ...library.favoriteArtists]) {
      count(a.name, 20);
    }
    final ranked = plays.keys.toList()
      ..sort((a, b) => plays[b]!.compareTo(plays[a]!));
    _libraryArtists = [for (final k in ranked) spelled[k]!];
    // Every artist, but a bounded number of titles: suggestions run on
    // each keystroke, and a big library has tens of thousands.
    _libraryTitles = titles.take(_maxLibraryTitles).toList();
    search.setLibraryNames([..._libraryArtists, ..._libraryTitles]);
  }

  /// Searches [query] at once, as if typed: from a suggestion, "did you
  /// mean" or the explore section.
  void _runQuery(String query) {
    Haptics.selection();
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusScope.of(context).unfocus();
    final search = ref.read(searchProvider);
    if (_selectedTabIndex == 4) {
      search.searchLyrics(query);
    } else {
      search.search(query);
    }
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
    ref.read(searchProvider).clear();
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
    Haptics.tap();
    FocusScope.of(context).unfocus();
    final locale = ref.read(localeProvider);
    final audio = ref.read(audioProvider);
    final search = ref.read(searchProvider);
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
        : VoiceCommands.parse(spokenText);
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
    final joined = VoiceCommands.withoutArtistJoiner(command.query);
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
    Haptics.confirm();
    await ref.read(playTracksProvider)(search.tracks);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    ref.watch(libraryProvider.select((l) => (l.listenedCount,
        l.followedArtists.length, l.favoriteArtists.length)));
    _refreshLibraryNames(search);
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
      // Only closes the keyboard: nothing for screen readers.
        excludeFromSemantics: true,
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
                    // Flavour, not information: screen readers skip it.
                    ExcludeSemantics(child: Text(
                      strings.searchTelemetry,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentText,
                        letterSpacing: 1.2,
                      ),
                    )),
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
                              onPressed: () { Haptics.selection();
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

              // Completions of what is being typed.
              ListenableBuilder(
                listenable: Listenable.merge([_controller, focusNode]),
                builder: (context, _) => _buildSuggestions(search, locale),
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
                      child: TapScale(
                      scaleDown: 0.93,
                      haptic: Haptics.selection,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        final prev = _selectedTabIndex;
                        setState(() => _selectedTabIndex = index);
                        if (index == 4 && prev != 4) {
                          final q = _controller.text.trim();
                          if (q.length >= 3) {
                            ref.read(searchProvider).searchLyrics(q);
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
                        ? _resultsSkeleton()
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
    final search = ref.read(searchProvider);
    final history = search.searchHistory;
    final topArtists = _libraryArtists.take(10).toList();

    if (history.isEmpty && topArtists.isEmpty && _genres.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Only closes the keyboard: nothing for screen readers.
        excludeFromSemantics: true,
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
      // Only closes the keyboard: nothing for screen readers.
        excludeFromSemantics: true,
        onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (history.isNotEmpty) ...[
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
                onTap: () { Haptics.tap();
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
                behavior: HitTestBehavior.opaque,
                // 48 dp to touch around the small word.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
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
              ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map((q) => Dismissible(
                key: ValueKey('history_$q'),
                direction: DismissDirection.endToStart,
                onUpdate: Haptics.swipe,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete_outline,
                      color: AppColors.accent, size: 18, semanticLabel: strings.a11yClearHistory),
                ),
                onDismissed: (_) {
                  Haptics.remove();
                  search.removeFromHistory(q);
                },
                child: InkWell(
                  onTap: () { Haptics.tap();
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
          if (topArtists.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel(strings.searchYourArtists, locale),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in topArtists)
                  _QueryChip(
                    label: name,
                    icon: Icons.person_outline,
                    semanticLabel: strings.a11ySearchSuggestion(name),
                    locale: locale,
                    onTap: () => _runQuery(name),
                  ),
              ],
            ),
          ],
          if (_genres.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel(strings.exploreGenres, locale),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final g in _genres) _GenreTile(genre: g, locale: locale),
              ],
            ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, LocaleProvider locale) => Semantics(
        header: true,
        child: Text(
          text,
          style: locale.getTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      );

  /// Completions of the text being typed: recent searches, the user's own
  /// artists and songs, then names from the results so far.
  Widget _buildSuggestions(SearchProvider search, LocaleProvider locale) {
    final text = _controller.text.trim();
    if (text.isEmpty || !focusNode.hasFocus || _selectedTabIndex == 4) {
      return const SizedBox.shrink();
    }
    final suggestions = SearchSuggestions.suggest(
      text,
      history: search.searchHistory,
      library: [..._libraryArtists, ..._libraryTitles],
      // Results are those of the query being typed, or a little behind it.
      catalog: search.resultNames,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final strings = locale.strings;
    return Semantics(
      container: true,
      label: strings.searchSuggestions,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          children: [
            for (final sug in suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _QueryChip(
                  label: sug.text,
                  icon: switch (sug.source) {
                    SuggestionSource.history => Icons.history,
                    SuggestionSource.library => Icons.library_music_outlined,
                    SuggestionSource.catalog => Icons.search,
                  },
                  semanticLabel: strings.a11ySearchSuggestion(sug.text),
                  locale: locale,
                  onTap: () => _runQuery(sug.text),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "Did you mean X?", tappable, when the search found a likely typo.
  Widget _buildDidYouMean(SearchProvider search, LocaleProvider locale) {
    final suggestion = search.didYouMean;
    if (suggestion == null) return const SizedBox.shrink();
    final strings = locale.strings;
    return Semantics(
      button: true,
      label: strings.a11yDidYouMean(suggestion),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _runQuery(suggestion),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.auto_fix_high, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: locale.getTextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    children: [
                      TextSpan(text: '${strings.didYouMeanPrefix} '),
                      TextSpan(
                        text: suggestion,
                        style: locale.getTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(SearchProvider search, AppStrings strings, LocaleProvider locale) =>
      ErrorState(message: strings.searchError, onRetry: search.retryLastSearch, padding: EdgeInsets.zero);

  /// What the open tab's results will look like: artists, albums or songs.
  Widget _resultsSkeleton() => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: switch (_selectedTabIndex) {
          1 => const SkeletonRowList(count: 7, leading: 48, round: true, padding: EdgeInsets.fromLTRB(16, 8, 16, 0)),
          2 => const Column(children: [SkeletonAlbumRow(), SkeletonAlbumRow()]),
          _ => const SkeletonTrackList(count: 8, padding: EdgeInsets.fromLTRB(16, 8, 16, 0)),
        },
      );

  Widget _buildLyricsTabContent(SearchProvider search, AppStrings strings, LocaleProvider locale) {
    if (search.isLyricsLoading) {
      return const SkeletonRowList(count: 5, padding: EdgeInsets.fromLTRB(16, 8, 16, 0));
    }

    if (search.hasLyricsError) {
      return ErrorState(
          message: strings.lyricsSearchError, onRetry: search.retryLyricsSearch, padding: EdgeInsets.zero);
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
        Haptics.tap();
        // One search: the song's results land in the Songs tab, which
        // opens only when the catalog has it.
        final query = '${result.trackName} ${result.artistName}';
        final search = ref.read(searchProvider);
        await search.search(query);
        if (!mounted || search.tracks.isEmpty) return;
        _controller.text = query;
        setState(() => _selectedTabIndex = 3);
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
        // Only closes the keyboard: nothing for screen readers.
        excludeFromSemantics: true,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.noResultsFor(search.query),
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(color: AppColors.textSecondary),
                ),
                _buildDidYouMean(search, locale),
              ],
            ),
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
        _buildDidYouMean(search, locale),

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

/// A query to search with one tap: a suggestion or one of the user's
/// artists.
class _QueryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String semanticLabel;
  final LocaleProvider locale;
  final VoidCallback onTap;

  const _QueryChip({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: TapScale(
        scaleDown: 0.93,
        haptic: null, // the query it runs gives the tick
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A genre to explore: its picture under a dark veil, and its name.
class _GenreTile extends StatelessWidget {
  final Genre genre;
  final LocaleProvider locale;

  const _GenreTile({required this.genre, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: genre.name,
      excludeSemantics: true,
      child: TapScale(
        scaleDown: 0.93,
        onTap: () {
          FocusScope.of(context).unfocus();
          GenreRoute(id: genre.id, name: genre.name).push(context);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.bgMid),
              if (genre.pictureUrl.isNotEmpty)
                LayoutBuilder(
                  builder: (context, box) => CachedNetworkImage(
                    imageUrl: genre.pictureUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: imageCacheSize(context, box.maxWidth),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.bgDeep.withValues(alpha: 0.9),
                      AppColors.bgDeep.withValues(alpha: 0.35),
                    ],
                  ),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    genre.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
