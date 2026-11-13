import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/design_tokens.dart';
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
import '../widgets/app_snack.dart';
import '../widgets/artist_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/tap_scale.dart';
import '../widgets/track_tile.dart';
import '../widgets/voice_search_sheet.dart';
import 'main_navigation_screen.dart';

part 'search/search_empty_view.dart';
part 'search/search_hints.dart';
part 'search/search_lyrics_view.dart';
part 'search/search_results_view.dart';

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

  /// Shows tab [index] (for the views in search/, which can't setState).
  void _selectTab(int index) => setState(() => _selectedTabIndex = index);

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
    final messenger = AppSnack.of(context);
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
      messenger.info('${strings.noResults}: "${command.query}"');
      return;
    }
    Haptics.confirm();
    await ref.read(playTracksProvider)(search.tracks);
  }

  @override
  Widget build(BuildContext context) {
    // B-01: the screen rebuilds only when what it draws itself changes
    // (the tab counts, which view shows); each view listens on its own.
    final search = ref.read(searchProvider);
    ref.watch(searchProvider.select((s) => (s.query, s.isLoading, s.hasError, s.artists.length,
        s.albums.length, s.tracks.length, s.lyricsResults.length)));
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
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBright,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            ' // 02',
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.display,
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
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentText,
                        letterSpacing: 1.2,
                      ),
                    )),
                    const SizedBox(height: 4),
                    Text(
                      strings.searchSubtitle,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
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
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: focusNode,
                    maxLength: 100,
                    style: locale.getTextStyle(color: AppColors.textBright, fontSize: AppFontSize.title),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: strings.searchHint,
                      hintStyle: locale.getTextStyle(color: AppColors.textMuted, fontSize: AppFontSize.title),
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
                            icon: const Icon(Icons.mic, color: AppColors.textSecondary, size: 20),
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
                listenable: Listenable.merge([_controller, focusNode, search]),
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
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.border,
                          ),
                        ),
                        child: Text(
                          tabs[index],
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.caption,
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
                child: ListenableBuilder(
                  listenable: search,
                  builder: (context, _) => _selectedTabIndex == 4
                      ? _buildLyricsTabContent(search, strings, locale)
                      : search.isLoading
                          ? _resultsSkeleton()
                          : search.hasError
                              ? _buildErrorState(search, strings, locale)
                              : search.query.isEmpty
                                  ? _buildEmptyState(strings, locale)
                                  : _buildResults(search, strings, locale),
                ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

}

/// A query to search with one tap: a suggestion or one of the user's
/// artists.
