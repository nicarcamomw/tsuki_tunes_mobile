part of '../artist_detail_screen.dart';

/// The artist's popular tracks: five, or up to ten when expanded. Shows the
/// skeleton while loading and a retry when they couldn't be fetched.
class _TopTracksSliver extends StatelessWidget {
  final List<Track> tracks;
  final LocaleProvider locale;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final bool reduceMotion;

  const _TopTracksSliver({
    required this.tracks,
    required this.locale,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.showAll,
    required this.onToggleShowAll,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    if (isLoading) return const ArtistDetailSkeletonLoader();
    if (hasError && tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                  semanticLabel: strings.a11yOffline,
                ),
                const SizedBox(height: 10),
                Text(
                  strings.loadError,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Semantics(
                  button: true,
                  label: strings.retry,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onRetry();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
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
          ),
        ),
      );
    }
    if (tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            strings.noTracksFound,
            style: locale.getTextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          for (int i = 0; i < (tracks.length > 5 ? 5 : tracks.length); i++)
            TrackTile(track: tracks[i], index: i, queue: tracks),
          if (tracks.length > 5) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: showAll
                    ? [
                        for (int i = 5; i < tracks.take(10).length; i++)
                          TrackTile(track: tracks[i], index: i, queue: tracks),
                      ]
                    : const [],
              ),
            ),
            _ShowMoreTracksButton(
              locale: locale,
              showAll: showAll,
              onToggle: onToggleShowAll,
              reduceMotion: reduceMotion,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Aparece en": the artist's features on other artists' songs, kept apart
/// from their own popular tracks. Five, or all of them when expanded.
class _FeaturesSliver extends StatelessWidget {
  final List<Track> tracks;
  final LocaleProvider locale;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final bool reduceMotion;

  const _FeaturesSliver({
    required this.tracks,
    required this.locale,
    required this.showAll,
    required this.onToggleShowAll,
    required this.reduceMotion,
  });

  static const _collapsed = 5;

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      strings.tabAppearsOn,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${tracks.length}',
                  style: locale.getTextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < tracks.length && i < _collapsed; i++)
            TrackTile(track: tracks[i], index: i, queue: tracks),
          if (tracks.length > _collapsed) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: showAll
                    ? [
                        for (var i = _collapsed; i < tracks.length; i++)
                          TrackTile(track: tracks[i], index: i, queue: tracks),
                      ]
                    : const [],
              ),
            ),
            _ShowMoreTracksButton(
              locale: locale,
              showAll: showAll,
              onToggle: onToggleShowAll,
              reduceMotion: reduceMotion,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShowMoreTracksButton extends StatelessWidget {
  final LocaleProvider locale;
  final bool showAll;
  final VoidCallback onToggle;
  final bool reduceMotion;

  const _ShowMoreTracksButton({
    required this.locale,
    required this.showAll,
    required this.onToggle,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Semantics(
          button: true,
          label: showAll
              ? strings.a11yShowLessTracks
              : strings.a11yShowAllTracks,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onToggle();
            },
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textBright.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textBright.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showAll ? strings.showLessTracks : strings.showMoreTracks,
                    style: locale.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: showAll ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textSecondary,
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
