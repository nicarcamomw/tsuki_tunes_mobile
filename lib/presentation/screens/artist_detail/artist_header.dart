part of '../artist_detail_screen.dart';

/// Photo hero with the distorted name, back button and the completion mask.
class _ArtistHeroAppBar extends StatelessWidget {
  final Artist artist;
  final LocaleProvider locale;
  final bool showTitle;
  final bool reduceMotion;
  final bool isComplete;
  final int completedReleases;
  final int totalReleases;

  const _ArtistHeroAppBar({
    required this.artist,
    required this.locale,
    required this.showTitle,
    required this.reduceMotion,
    required this.isComplete,
    required this.completedReleases,
    required this.totalReleases,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return SliverAppBar(
      expandedHeight: 270,
      pinned: true,
      backgroundColor: AppColors.bgDeep,
      title: AnimatedOpacity(
        opacity: showTitle ? 1.0 : 0.0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        child: Text(
          artist.name,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        tooltip: strings.a11yBack,
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Icon(Icons.chevron_left,
              color: AppColors.accent, size: 24, semanticLabel: strings.a11yBack),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: isComplete
                ? strings.artistCompleteTooltip
                : strings.artistDiscographyProgress(
                    completedReleases, totalReleases),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isComplete
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.4),
                  width: isComplete ? 1.5 : 1,
                ),
                boxShadow: isComplete
                    ? [
                        const BoxShadow(
                          color: AppColors.accentGlow,
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: OniMaskIcon(
                isActive: isComplete,
                size: 22,
                showContainer: false,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (artist.pictureUrl.isNotEmpty)
              ExcludeSemantics(
                child: CachedNetworkImage(
                  memCacheWidth: imageCacheSize(context, (420).toDouble()),
                  imageUrl: artist.getBestImage(size: 'xl'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 0.80, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x990B0D13),
                    AppColors.bgDeep,
                  ],
                ),
              ),
            ),
            // Name rendered directly on top of the photo with room for descenders
            Positioned(
              left: 16,
              right: 16,
              bottom: 22,
              child: Semantics(
                header: true,
                child: DistortedArtistName(
                  name: artist.name,
                  artistId: artist.id,
                  fontSize: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fans and releases, follow button, release breakdown, genre tags and the
/// popular tracks heading.
class _ArtistInfoSection extends StatelessWidget {
  final Artist artist;
  final LocaleProvider locale;
  final Map<String, List<Album>> categories;
  final List<String> tags;
  final bool showStats;
  final VoidCallback onToggleStats;

  /// Guests can't follow, so they get no button.
  final bool canFollow;
  final bool isFollowed;
  final VoidCallback onToggleFollow;
  final bool reduceMotion;

  /// Starts the artist's endless radio.
  final VoidCallback onStartRadio;

  const _ArtistInfoSection({
    required this.artist,
    required this.locale,
    required this.categories,
    required this.tags,
    required this.showStats,
    required this.onToggleStats,
    required this.canFollow,
    required this.isFollowed,
    required this.onToggleFollow,
    required this.reduceMotion,
    required this.onStartRadio,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(strings),
          const SizedBox(height: 14),
          Row(
            children: [
              if (canFollow) ...[
                _buildFollowButton(strings),
                const SizedBox(width: 10),
              ],
              _buildRadioButton(strings),
            ],
          ),
          _buildBreakdown(strings),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildTags(),
          ],
          const SizedBox(height: 20),
          // Top Tracks header
          Row(
            children: [
              AppCustomIcons.fuego(
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                strings.popularTracks,
                style: locale.getTextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AppStrings strings) {
    return Row(
      children: [
        if (artist.fansCount > 0) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCustomIcons.persona(
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                strings.artistFans(Formatters.formatNumber(artist.fansCount)),
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
        if (artist.albumsCount > 0)
          Semantics(
            button: true,
            label: showStats ? strings.a11yHideStats : strings.a11yShowStats,
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                onToggleStats();
              },
              behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppCustomIcons.cd(
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  strings.artistReleases(artist.albumsCount),
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    decoration: showStats
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: AppColors.accent,
                    decorationThickness: 2,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: showStats ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowButton(AppStrings strings) {
    return Semantics(
      button: true,
      label: isFollowed ? strings.a11yUnfollowArtist : strings.a11yFollowArtist,
      child: GestureDetector(
      onTap: () {
        Haptics.selection();
        onToggleFollow();
      },
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isFollowed
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isFollowed
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: isFollowed
              ? [
                  BoxShadow(
                    color: AppColors.accentGlow.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowed ? Icons.check : Icons.add,
              size: 14,
              color: AppColors.accent,
              semanticLabel: isFollowed ? strings.a11yUnfollowArtist : strings.a11yFollowArtist,
            ),
            const SizedBox(width: 6),
            Text(
              isFollowed
                  ? strings.unfollowArtist
                  : strings.followArtist,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// The artist's endless radio: their hits, then artists like them.
  Widget _buildRadioButton(AppStrings strings) {
    return Semantics(
      button: true,
      label: strings.a11yArtistRadio(artist.name),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onStartRadio,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: AppColors.accentGlow.withValues(alpha: 0.35), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sensors, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                strings.artistRadioButton,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Glass capsule counting albums, EPs, singles and appearances.
  Widget _buildBreakdown(AppStrings strings) {
    final cats = categories;
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity),
      secondChild: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x730C0C12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            if (cats['album']!.isNotEmpty)
              _buildBreakdownItem(
                AppCustomIcons.libreria(
                    size: 15, color: AppColors.accent),
                strings.albumCountLabel(cats['album']!.length),
              ),
            if (cats['ep']!.isNotEmpty)
              _buildBreakdownItem(
                AppCustomIcons.ep(
                    size: 15, color: AppColors.accent),
                strings.epCountLabel(cats['ep']!.length),
              ),
            if (cats['single']!.isNotEmpty)
              _buildBreakdownItem(
                AppCustomIcons.nota(
                    size: 15, color: AppColors.accent),
                strings.singleCountLabel(cats['single']!.length),
              ),
            if (cats['appears_on']!.isNotEmpty)
              _buildBreakdownItem(
                AppCustomIcons.grupo(
                    size: 15, color: AppColors.accent),
                strings.appearsOnCountLabel(cats['appears_on']!.length),
              ),
          ],
        ),
      ),
      crossFadeState: showStats
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildBreakdownItem(Widget icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: locale.getTextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            border:
                Border.all(color: AppColors.accent, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            tag.toUpperCase(),
            style: locale.getTextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
