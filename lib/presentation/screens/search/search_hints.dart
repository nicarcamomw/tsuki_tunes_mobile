part of '../search_screen.dart';

/// While typing: completions, "did you mean", the error and the skeleton.
extension _SearchHints on _SearchScreenState {
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
              const Icon(Icons.auto_fix_high, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary),
                    children: [
                      TextSpan(text: '${strings.didYouMeanPrefix} '),
                      TextSpan(
                        text: suggestion,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.bodyLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.info,
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

}
