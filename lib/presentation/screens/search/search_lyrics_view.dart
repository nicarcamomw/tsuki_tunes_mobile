part of '../search_screen.dart';

/// The "by lyrics" tab: songs found by a line, with the line highlighted.
extension _SearchLyricsView on _SearchScreenState {
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
                fontSize: AppFontSize.bodyLg,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.lyricsSearchEmptySubtitle,
              style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textMuted),
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
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
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
        _selectTab(3);
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
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.lyrics_outlined, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.trackName,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.title,
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
                      fontSize: AppFontSize.caption,
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
                fontSize: AppFontSize.micro,
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
            .getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)
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
            .getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)
            .copyWith(fontStyle: FontStyle.italic),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: locale
                .getTextStyle(
                  fontSize: AppFontSize.caption,
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

}
