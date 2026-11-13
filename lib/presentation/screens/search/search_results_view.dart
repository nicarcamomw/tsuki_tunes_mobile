part of '../search_screen.dart';

/// The results: all, artists, albums, songs.
extension _SearchResultsView on _SearchScreenState {
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
            style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildDidYouMean(search, locale),

        // B-04: the best match, highlighted first on "All".
        if (showAll) _topResult(search, strings, locale),

        // Artists Section
        if (showArtists && hasArtists) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabArtists.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: search.artists.length,
              itemBuilder: (context, i) => ArtistCard(artist: search.artists[i]),
            ),
          ),
        ],

        // Albums Section
        if (showAlbums && hasAlbums) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabAlbums.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: search.albums.length,
              itemBuilder: (context, i) => AlbumCard(album: search.albums[i]),
            ),
          ),
        ],

        // Tracks Section
        if (showTracks && hasTracks) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 8),
            child: Semantics(
              header: true,
              child: Text(
                strings.tabTracks.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
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

  /// The artist when their name is what was typed (or starts with it),
  /// else the first song; nothing when there are neither.
  Widget _topResult(SearchProvider search, AppStrings strings, LocaleProvider locale) {
    String norm(String v) => v.toLowerCase().trim();
    final q = norm(search.query);
    final artist = search.artists.isEmpty ? null : search.artists.first;
    final artistWins = artist != null && q.isNotEmpty && norm(artist.name).startsWith(q);
    if (!artistWins && search.tracks.isEmpty) return const SizedBox.shrink();

    final Widget body;
    if (artistWins) {
      body = Semantics(
        button: true,
        label: '${strings.searchTopResult}: ${artist.name}, ${strings.searchTopArtistKind}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Haptics.tap();
            FocusScope.of(context).unfocus();
            ArtistRoute(id: artist.id, $extra: artist).push<void>(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: artist.pictureUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artist.pictureUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: imageCacheSize(context, 72),
                            errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.bgMid),
                          )
                        : const ColoredBox(
                            color: AppColors.bgMid,
                            child: Icon(Icons.person_rounded, color: AppColors.textMuted, size: 32),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                              fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                      const SizedBox(height: 2),
                      Text(strings.searchTopArtistKind,
                          style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      );
    } else {
      body = TrackTile(track: search.tracks.first, queue: search.tracks);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              strings.searchTopResult,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.bgCard,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.borderGlow),
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}
