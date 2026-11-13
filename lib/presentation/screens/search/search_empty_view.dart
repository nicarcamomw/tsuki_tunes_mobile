part of '../search_screen.dart';

/// Before a search: recent searches, the library's artists, genres.
extension _SearchEmptyView on _SearchScreenState {
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
        child: EmptyState(
          image: 'assets/images/tengu.png',
          artLabel: strings.a11ySearchEmpty,
          title: strings.emptyStateTitle,
          message: strings.emptyStateSubtitle,
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
                  fontSize: AppFontSize.micro,
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
                          fontSize: AppFontSize.titleLg,
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
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
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
                              fontSize: AppFontSize.bodyLg,
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
            fontSize: AppFontSize.micro,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      );

  /// Completions of the text being typed: recent searches, the user's own
  /// artists and songs, then names from the results so far.
}

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
            borderRadius: BorderRadius.circular(AppRadius.sheet),
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
                    fontSize: AppFontSize.body,
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
          borderRadius: BorderRadius.circular(AppRadius.chip),
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
                  borderRadius: BorderRadius.circular(AppRadius.chip),
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
                      fontSize: AppFontSize.bodyLg,
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
