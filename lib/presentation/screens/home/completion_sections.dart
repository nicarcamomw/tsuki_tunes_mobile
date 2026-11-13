part of '../home_screen.dart';

/// "Almost complete": albums a few songs away from complete, each saying
/// how many are missing. Watches the library on its own, so marking a song
/// rebuilds only this row.
class _AlmostCompleteSection extends ConsumerWidget {
  final LocaleProvider locale;

  const _AlmostCompleteSection({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    // Song counts are only known for albums the user opened: ask for those
    // of the latest listened ones (once per album per session).
    ref.read(ensureAlbumTrackCountsProvider).recent();
    final albums = library.almostCompleteAlbums();
    if (albums.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: SectionTitle(
              locale: locale, text: locale.strings.almostCompleteTitle),
        ),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            itemBuilder: (context, index) =>
                _AlmostCompleteCard(locale: locale, progress: albums[index]),
          ),
        ),
      ],
    );
  }
}

class _AlmostCompleteCard extends StatelessWidget {
  final LocaleProvider locale;
  final AlbumProgress progress;

  static const double _width = 135;

  const _AlmostCompleteCard({required this.locale, required this.progress});

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final missing = strings.almostCompleteMissing(progress.missing);
    return TapScale(
      semanticLabel:
          strings.a11yAlmostComplete(progress.title, progress.artistName, missing),
      scaleDown: 0.95,
      onTap: () => AlbumRoute(
        id: progress.albumId,
        $extra: Album(
          id: progress.albumId,
          title: progress.title,
          coverUrl: progress.coverUrl,
          artistId: '',
          artistName: progress.artistName,
          tracksCount: progress.total,
        ),
      ).push(context),
      child: Container(
        width: _width,
        margin: const EdgeInsets.only(right: 14),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _width,
                height: _width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: progress.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          memCacheWidth: imageCacheSize(context, _width),
                          imageUrl: progress.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.bgMid),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgMid,
                            child: const Icon(Icons.album,
                                color: AppColors.accent),
                          ),
                        )
                      : Container(
                          color: AppColors.bgMid,
                          child:
                              const Icon(Icons.album, color: AppColors.accent),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.share,
                  minHeight: 3,
                  backgroundColor: AppColors.bgMid,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.bodyLg,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                missing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.label,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
