part of '../wrapped_screen.dart';

// One widget per story: intro, minutes, top song, artist, album, hour, aura, facts, summary.
class _IntroSlide extends StatelessWidget {
  final _SlideContext c;
  final String? note;
  final GlobalKey shareKey;
  const _IntroSlide({required this.c, required this.note, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final strings = c.strings;
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.accent,
      kanji: c.monthly ? '月' : '年',
      center: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('T S U K I', style: c.text(AppFontSize.titleLg, weight: FontWeight.w800, color: AppColors.accent, spacing: 6))
              .animateCalm(context)
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 14),
          // One line whatever the screen: it scales down instead of wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'WRAPPED',
              maxLines: 1,
              style: c.text(AppFontSize.mega, weight: FontWeight.w900, spacing: 4, height: 1).copyWith(
                shadows: [Shadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 30)],
              ),
            ),
          )
              .animateCalm(context)
              .fadeIn(duration: 700.ms, delay: 150.ms)
              .scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack, duration: 700.ms),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 1.4),
              color: AppColors.accent.withValues(alpha: 0.08),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 18)],
            ),
            child: Text(c.period,
                style: c.text(c.monthly ? 22 : 34, weight: FontWeight.w900, color: AppColors.accent, spacing: 5)),
          ).animateCalm(context).fadeIn(duration: 600.ms, delay: 450.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sheet),
            ),
            child: Text(c.monthly ? strings.wrappedMonthlyLabel : strings.wrappedYearlyLabel,
                style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
          ).animateCalm(context).fadeIn(delay: 600.ms),
          const SizedBox(height: 18),
          Text(strings.wrappedIntro(monthly: c.monthly),
                  textAlign: TextAlign.center, style: c.text(AppFontSize.headline, weight: FontWeight.w700))
              .animateCalm(context)
              .fadeIn(duration: 600.ms, delay: 750.ms),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note!,
                textAlign: TextAlign.center,
                style: c.text(AppFontSize.body, weight: FontWeight.w500, color: AppColors.textMuted, height: 1.45))
                .animateCalm(context)
                .fadeIn(delay: 950.ms),
          ],
          const SizedBox(height: 36),
          Text('◈ ${strings.wrappedReportTag(monthly: c.monthly)}',
              style: GoogleFonts.notoSansJp(
                  fontSize: AppFontSize.micro, fontWeight: FontWeight.w700, color: AppColors.accent.withValues(alpha: 0.55), letterSpacing: 2.5)),
        ],
      ),
    );
  }
}

class _MinutesSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _MinutesSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final prev = d.previousMinutes;
    final pct = prev == null || prev == 0
        ? null
        : (((d.totalMinutesListened - prev) / prev) * 100).round();
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonCyan,
      kanji: '時',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, d.basedOnPlays ? strings.wrappedListeningTime : strings.wrappedNewMusicTime,
              color: AppColors.neonCyan),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _CountUp(
              value: d.totalMinutesListened,
              style: c.text(AppFontSize.mega, weight: FontWeight.w900, height: 1).copyWith(
                shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 30)],
              ),
            ),
          ),
          Text(strings.wrappedMinutesLabel,
              style: c.text(AppFontSize.titleLg, weight: FontWeight.w800, color: AppColors.neonCyan, spacing: 3)),
          const SizedBox(height: 10),
          Text(strings.wrappedHoursOfMusic(d.totalMinutesListened ~/ 60),
              style: c.text(AppFontSize.titleLg, weight: FontWeight.w500, color: AppColors.textSecondary)),
          if (pct != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (pct >= 0 ? AppColors.neonGreen : AppColors.sakura).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                border: Border.all(color: (pct >= 0 ? AppColors.neonGreen : AppColors.sakura).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16, color: pct >= 0 ? AppColors.neonGreen : AppColors.sakura),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(strings.wrappedVsPrevious(pct, c.previousLabel),
                        style: c.text(AppFontSize.body, weight: FontWeight.w700, color: pct >= 0 ? AppColors.neonGreen : AppColors.sakura)),
                  ),
                ],
              ),
            ).animateCalm(context).fadeIn(delay: 1400.ms).slideX(begin: -0.2, end: 0),
          ],
          const Spacer(),
          Row(
            children: [
              _Stat(c, d.totalTracksPlayed, d.basedOnPlays ? strings.wrappedPlaysLabel : strings.wrappedSongsLabel),
              _Stat(c, d.uniqueTracksCount, strings.wrappedSongsLabel),
              _Stat(c, d.uniqueArtistsCount, strings.wrappedArtistsLabel),
            ],
          ).animateCalm(context).fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
          if (d.periodDays > 0) ...[
            const SizedBox(height: 18),
            Text(strings.wrappedActiveDays(d.activeDays, d.periodDays),
                style: c.text(AppFontSize.body, weight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _DaysBar(active: d.activeDays, total: d.periodDays),
          ],
          if (d.longestStreak >= 2) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(strings.wrappedStreak(d.longestStreak, d.streakStart),
                      maxLines: 2,
                      style: c.text(AppFontSize.body, weight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ],
            ).animateCalm(context).fadeIn(delay: 1600.ms),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final _SlideContext c;
  final int value;
  final String label;
  const _Stat(this.c, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border(left: BorderSide(color: AppColors.accent.withValues(alpha: 0.8), width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _CountUp(value: value, style: c.text(AppFontSize.headline, weight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  maxLines: 1,
                  style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysBar extends StatelessWidget {
  final int active;
  final int total;
  const _DaysBar({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.08)),
            FractionallySizedBox(
              widthFactor: total == 0 ? 0 : (active / total).clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.sakura]),
                ),
              ),
            ).animateCalm(context).scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 1200.ms, delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

class _TopSongSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _TopSongSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final top = d.topTracks.first;
    final rest = d.topTracks.skip(1).take(4).toList();
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.accent,
      coverUrl: top.coverUrl,
      kanji: '歌',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, d.basedOnPlays ? strings.wrappedTopSongLabel : strings.wrappedTopDiscoveries),
          const SizedBox(height: 22),
          Center(
            child: LayoutBuilder(builder: (context, box) {
              final size = math.min(box.maxWidth * 0.62, 240.0);
              return _Cover(top.coverUrl, size: size, radius: AppRadius.chip, glow: true);
            }),
          ).animateCalm(context).fadeIn(duration: 600.ms).scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack, duration: 700.ms),
          const SizedBox(height: 20),
          Center(
            child: Text(top.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: c.text(AppFontSize.display, weight: FontWeight.w900, height: 1.15)),
          ).animateCalm(context).fadeIn(delay: 300.ms),
          const SizedBox(height: 4),
          Center(
            child: Text(top.artistName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.text(AppFontSize.titleLg, weight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          if (d.basedOnPlays) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sheet),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 14)],
                ),
                child: Text(strings.wrappedPlays(top.playCount),
                    style: c.text(AppFontSize.body, weight: FontWeight.w800, color: Colors.white)),
              ),
            ).animateCalm(context).fadeIn(delay: 500.ms),
          ],
          const Spacer(),
          if (rest.isNotEmpty) ...[
            Text(strings.wrappedRunnersUp,
                style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
            const SizedBox(height: 8),
            for (var i = 0; i < rest.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 2}', style: c.text(AppFontSize.titleLg, weight: FontWeight.w900, color: AppColors.accent)),
                    ),
                    _Cover(rest[i].coverUrl, size: 38, radius: AppRadius.chip),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(AppFontSize.bodyLg, weight: FontWeight.w700)),
                          Text(rest[i].artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(AppFontSize.caption, weight: FontWeight.w500, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (d.basedOnPlays)
                      Text('${rest[i].playCount}', style: c.text(AppFontSize.bodyLg, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ],
                ),
              ).animateCalm(context).fadeIn(delay: Duration(milliseconds: 700 + i * 120)).slideX(begin: 0.15, end: 0),
          ],
        ],
      ),
    );
  }
}

class _TopArtistSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _TopArtistSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final top = d.topArtists.first;
    final rest = d.topArtists.skip(1).take(4).toList();
    final maxCount = d.topArtists.first.playCount.clamp(1, 1 << 30);
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonPurple,
      coverUrl: top.coverUrl,
      kanji: '星',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, strings.wrappedTopArtistLabel, color: AppColors.neonPurple),
          const SizedBox(height: 26),
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.neonPurple, width: 2),
                boxShadow: [BoxShadow(color: AppColors.neonPurple.withValues(alpha: 0.5), blurRadius: 36)],
              ),
              child: ClipOval(child: _Cover(top.coverUrl ?? '', size: 170, radius: 0)),
            ),
          ).animateCalm(context).fadeIn(duration: 600.ms).scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack, duration: 800.ms),
          const SizedBox(height: 22),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(top.name.toUpperCase(),
                  maxLines: 1,
                  style: c.text(AppFontSize.hero, weight: FontWeight.w900, spacing: 1.5).copyWith(
                    shadows: [Shadow(color: AppColors.neonPurple.withValues(alpha: 0.6), blurRadius: 24)],
                  )),
            ),
          ).animateCalm(context).fadeIn(delay: 300.ms),
          const SizedBox(height: 6),
          Center(
            child: Text(
              d.basedOnPlays
                  ? '${strings.wrappedPlays(top.playCount)} · ${strings.wrappedMinutes(top.totalSeconds ~/ 60)}'
                  : strings.wrappedDiscoveredSongs(top.playCount),
              style: c.text(AppFontSize.bodyLg, weight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          const Spacer(),
          if (rest.isNotEmpty) ...[
            Text(strings.wrappedRunnersUp,
                style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
            const SizedBox(height: 10),
            for (var i = 0; i < rest.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 2}',
                          style: c.text(AppFontSize.titleLg, weight: FontWeight.w900, color: AppColors.neonPurple)),
                    ),
                    ClipOval(child: _Cover(rest[i].coverUrl ?? '', size: 34, radius: 0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(AppFontSize.bodyLg, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            child: SizedBox(
                              height: 4,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (rest[i].playCount / maxCount).clamp(0.05, 1.0),
                                child: Container(color: AppColors.neonPurple.withValues(alpha: 0.8)),
                              ),
                            ),
                          ).animateCalm(context).scaleX(
                              begin: 0,
                              end: 1,
                              alignment: Alignment.centerLeft,
                              delay: Duration(milliseconds: 800 + i * 120),
                              duration: 700.ms),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${rest[i].playCount}',
                        style: c.text(AppFontSize.bodyLg, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ],
                ),
              ).animateCalm(context).fadeIn(delay: Duration(milliseconds: 700 + i * 120)),
          ],
        ],
      ),
    );
  }
}

/// The most-played albums, and the ones heard whole.
class _TopAlbumSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _TopAlbumSlide({required this.c, required this.shareKey});

  static const _tint = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final top = d.topAlbums.first;
    final done = d.completedAlbums;
    final rest = d.topAlbums.skip(1).take(done.isEmpty ? 4 : 2).toList();
    String detail(WrappedAlbumEntry a) => d.basedOnPlays
        ? '${strings.wrappedPlays(a.playCount)} · ${strings.wrappedAlbumSongs(a.tracksHeard)}'
        : strings.wrappedDiscoveredSongs(a.tracksHeard);
    return _Backdrop(
      shareKey: shareKey,
      tint: _tint,
      coverUrl: top.coverUrl,
      kanji: '盤',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, strings.wrappedTopAlbumsLabel, color: _tint),
          const SizedBox(height: 22),
          Center(
            child: LayoutBuilder(builder: (context, box) {
              final size = math.min(box.maxWidth * 0.5, 190.0);
              return _Cover(top.coverUrl, size: size, radius: AppRadius.chip, glow: true);
            }),
          ).animateCalm(context).fadeIn(duration: 600.ms).scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack, duration: 700.ms),
          const SizedBox(height: 18),
          Center(
            child: Text(top.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: c.text(AppFontSize.headline, weight: FontWeight.w900, height: 1.15)),
          ).animateCalm(context).fadeIn(delay: 300.ms),
          const SizedBox(height: 4),
          Center(
            child: Text(top.artistName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.text(AppFontSize.titleLg, weight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(detail(top),
                textAlign: TextAlign.center,
                style: c.text(AppFontSize.body, weight: FontWeight.w700, color: _tint)),
          ).animateCalm(context).fadeIn(delay: 500.ms),
          const Spacer(),
          if (rest.isNotEmpty) ...[
            Text(strings.wrappedRunnersUp,
                style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
            const SizedBox(height: 8),
            for (var i = 0; i < rest.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 2}', style: c.text(AppFontSize.titleLg, weight: FontWeight.w900, color: _tint)),
                    ),
                    _Cover(rest[i].coverUrl, size: 38, radius: AppRadius.chip),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rest[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(AppFontSize.bodyLg, weight: FontWeight.w700)),
                          Text('${rest[i].artistName} · ${detail(rest[i])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.text(AppFontSize.caption, weight: FontWeight.w500, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animateCalm(context).fadeIn(delay: Duration(milliseconds: 700 + i * 120)).slideX(begin: 0.15, end: 0),
          ],
          if (done.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tint.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: _tint.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: _tint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(strings.wrappedCompletedAlbums,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: _tint, spacing: 1.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final a in done.take(5))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Cover(a.coverUrl, size: 44, radius: AppRadius.chip),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    done.length == 1
                        ? '${done.first.title} · ${strings.wrappedCompletedCount(1)}'
                        : strings.wrappedCompletedCount(done.length),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: c.text(AppFontSize.body, weight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ).animateCalm(context).fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }
}

class _HourSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _HourSlide({required this.c, required this.shareKey});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final parts = WrappedService.dayParts(d.hourDistribution);
    final maxCount = d.hourDistribution.values.fold<int>(1, math.max);
    const partColors = [AppColors.neonPurple, AppColors.warning, AppColors.accent, AppColors.neonCyan];
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.warning,
      kanji: '刻',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, strings.wrappedFavoriteHour, color: AppColors.warning),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(strings.wrappedHourLabel(d.favoriteHour),
                style: c.text(AppFontSize.mega, weight: FontWeight.w900, height: 1).copyWith(
                  shadows: [Shadow(color: AppColors.warning.withValues(alpha: 0.5), blurRadius: 30)],
                )),
          ).animateCalm(context).fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 26),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final count = d.hourDistribution[h] ?? 0;
                final fav = h == d.favoriteHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: FractionallySizedBox(
                      heightFactor: math.max(count / maxCount, 0.03),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fav ? AppColors.warning : partColors[_partOf(h)].withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.chip)),
                          boxShadow: fav
                              ? [BoxShadow(color: AppColors.warning.withValues(alpha: 0.7), blurRadius: 10)]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ).animateCalm(context).scaleY(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.bottomCenter,
                    delay: Duration(milliseconds: 300 + h * 25),
                    duration: 500.ms);
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shrink rather than overflow on narrow phones ("12:00 AM" ×5).
              for (final h in const [0, 6, 12, 18, 23])
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(strings.wrappedHourLabel(h), style: c.text(AppFontSize.micro, color: AppColors.textMuted)),
                  ),
                ),
            ],
          ),
          const Spacer(),
          for (var p = 0; p < 4; p++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: partColors[p], shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: Text(strings.wrappedDayPart(p), style: c.text(AppFontSize.bodyLg, weight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: 0.06)),
                            FractionallySizedBox(
                              widthFactor: parts[p],
                              child: Container(color: partColors[p]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text('${(parts[p] * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: c.text(AppFontSize.body, weight: FontWeight.w800, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ).animateCalm(context).fadeIn(delay: Duration(milliseconds: 900 + p * 120)),
        ],
      ),
    );
  }

  static int _partOf(int hour) => hour < 6 ? 0 : hour < 12 ? 1 : hour < 19 ? 2 : 3;
}

class _AuraSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _AuraSlide({required this.c, required this.shareKey});

  static const kanjiFor = {
    'night': '夜',
    'dawn': '朝',
    'loyal': '忠',
    'explorer': '探',
    'marathon': '走',
    'balance': '和',
  };

  @override
  Widget build(BuildContext context) {
    final strings = c.strings;
    final aura = WrappedService.auraOf(c.data);
    final (name, description) = strings.wrappedAura(aura);
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.sakura,
      center: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tag(c, strings.wrappedAuraTitle, color: AppColors.sakura),
          const SizedBox(height: 30),
          Container(
            width: 190,
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.sakura.withValues(alpha: 0.35),
                AppColors.accent.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
              border: Border.all(color: AppColors.sakura.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Text(kanjiFor[aura] ?? '和',
                style: c.kanji(AppFontSize.mega, Colors.white).copyWith(
                  shadows: [
                    Shadow(color: AppColors.sakura.withValues(alpha: 0.9), blurRadius: 24),
                  ],
                )),
          )
              .animateCalm(context, onPlay: (ctrl) => ctrl.repeat(reverse: true))
              .scaleXY(begin: 0.97, end: 1.03, duration: 2.seconds, curve: Curves.easeInOut),
          const SizedBox(height: 30),
          Text(name.toUpperCase(),
                  textAlign: TextAlign.center, style: c.text(AppFontSize.display, weight: FontWeight.w900, spacing: 2))
              .animateCalm(context)
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(description,
                  textAlign: TextAlign.center,
                  style: c.text(AppFontSize.titleLg, weight: FontWeight.w500, color: AppColors.textSecondary, height: 1.5))
              .animateCalm(context)
              .fadeIn(delay: 700.ms),
        ],
      ),
    );
  }
}

class _FactsSlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  const _FactsSlide({required this.c, required this.shareKey});

  static const _icons = {
    'late_night_song': Icons.nightlight_round,
    'marathon_day': Icons.local_fire_department_rounded,
    'loyal_artist': Icons.favorite_rounded,
    'dawn_listener': Icons.wb_twilight_rounded,
    'one_hit_wonder': Icons.repeat_one_rounded,
    'night_owl': Icons.dark_mode_rounded,
    'early_bird': Icons.wb_sunny_rounded,
    'weekend_warrior': Icons.celebration_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final facts = c.data.funFacts.take(4).toList();
    const colors = [AppColors.sakura, AppColors.neonCyan, AppColors.warning, AppColors.neonGreen];
    return _Backdrop(
      shareKey: shareKey,
      tint: AppColors.neonGreen,
      kanji: '話',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(c, c.strings.wrappedFunFacts, color: AppColors.neonGreen),
          const Spacer(),
          for (var i = 0; i < facts.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors[i % colors.length].withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors[i % colors.length].withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i % colors.length].withValues(alpha: 0.15),
                    ),
                    child: Icon(_icons[facts[i].key] ?? Icons.auto_awesome,
                        color: colors[i % colors.length], size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(_factText(facts[i]), style: c.text(AppFontSize.title, weight: FontWeight.w600, height: 1.45)),
                  ),
                ],
              ),
            ).animateCalm(context).fadeIn(delay: Duration(milliseconds: 300 + i * 180)).slideX(begin: 0.12, end: 0),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  String _factText(WrappedFunFact fact) {
    final strings = c.strings;
    final d = fact.data;
    final count = (d['count'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse('${d['date'] ?? ''}');
    final dateLabel = date == null ? '${d['date'] ?? ''}' : strings.longDate(date);
    final plays = c.data.basedOnPlays;
    return switch (fact.key) {
      'late_night_song' => strings.wrappedFactLateNight('${d['title'] ?? ''}', '${d['artistName'] ?? ''}'),
      'marathon_day' => plays
          ? strings.wrappedFactMarathon(dateLabel, count)
          : strings.wrappedFactMarathonDiscovery(dateLabel, count),
      'loyal_artist' => plays
          ? strings.wrappedFactLoyal('${d['name'] ?? ''}', count)
          : strings.wrappedFactLoyalDiscovery('${d['name'] ?? ''}', count),
      'dawn_listener' => strings.wrappedFactDawn(count),
      'one_hit_wonder' => strings.wrappedFactOneHit('${d['title'] ?? ''}', '${d['artistName'] ?? ''}', count),
      'night_owl' => strings.wrappedFactNightOwl((d['percentage'] as num?)?.toInt() ?? 0),
      'early_bird' => strings.wrappedFactEarlyBird((d['percentage'] as num?)?.toInt() ?? 0),
      'weekend_warrior' => strings.wrappedFactWeekend(
          (d['weekendAvg'] as num?)?.toInt() ?? 0, (d['weekdayAvg'] as num?)?.toInt() ?? 0),
      _ => '',
    };
  }
}

/// The last slide: a card with the whole recap, made to be shared.
class _SummarySlide extends StatelessWidget {
  final _SlideContext c;
  final GlobalKey shareKey;
  final VoidCallback onShare;
  const _SummarySlide({required this.c, required this.shareKey, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final d = c.data;
    final strings = c.strings;
    final aura = WrappedService.auraOf(d);
    final (auraName, _) = strings.wrappedAura(aura);
    final topCover = d.topTracks.isNotEmpty ? d.topTracks.first.coverUrl : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 70, 18, 18),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: RepaintBoundary(
                    key: shareKey,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sheet),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.8), width: 1.4),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A0A0F), Color(0xFF12141C), Color(0xFF0A0B10)],
                        ),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 30)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -30,
                            child: Text(c.monthly ? '月' : '年',
                                style: c.kanji(AppFontSize.mega, AppColors.accent.withValues(alpha: 0.08))),
                          ),
                          const Positioned.fill(child: CustomPaint(painter: _Scanlines())),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (topCover != null) _Cover(topCover, size: 64, radius: AppRadius.chip, glow: true),
                                    if (topCover != null) const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('TSUKI WRAPPED',
                                              style: c.text(AppFontSize.caption, weight: FontWeight.w800, color: AppColors.accent, spacing: 3)),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(c.period,
                                                maxLines: 1, style: c.text(AppFontSize.display, weight: FontWeight.w900, spacing: 1)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _SummaryList(
                                        c: c,
                                        title: strings.wrappedTopArtistsShort,
                                        items: [for (final a in d.topArtists.take(5)) a.name],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _SummaryList(
                                        c: c,
                                        title: strings.wrappedTopSongsShort,
                                        items: [for (final t in d.topTracks.take(5)) t.title],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: AppColors.border, height: 26),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c, label: strings.wrappedMinutesLabel, value: _thousands(d.totalMinutesListened)),
                                    ),
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c,
                                          label: d.basedOnPlays ? strings.wrappedPlaysLabel : strings.wrappedSongsLabel,
                                          value: _thousands(d.totalTracksPlayed)),
                                    ),
                                    Expanded(
                                      child: _SummaryNumber(
                                          c: c,
                                          label: strings.wrappedFavoriteHour,
                                          value: strings.wrappedHourLabel(d.favoriteHour)),
                                    ),
                                    if (d.longestStreak >= 2)
                                      Expanded(
                                        child: _SummaryNumber(
                                            c: c,
                                            label: strings.wrappedStreakLabel,
                                            value: strings.wrappedStreakValue(d.longestStreak)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.sakura.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.card),
                                    border: Border.all(color: AppColors.sakura.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_AuraSlide.kanjiFor[aura] ?? '和',
                                          style: c.kanji(AppFontSize.display, Colors.white).copyWith(shadows: [
                                            Shadow(color: AppColors.sakura.withValues(alpha: 0.9), blurRadius: 12),
                                          ])),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(strings.wrappedAuraTitle,
                                                style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
                                            Text(auraName, style: c.text(AppFontSize.titleLg, weight: FontWeight.w900)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text('◈ ${strings.wrappedReportTag(monthly: c.monthly)}',
                                    style: GoogleFonts.notoSansJp(
                                        fontSize: AppFontSize.micro,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent.withValues(alpha: 0.6),
                                        letterSpacing: 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animateCalm(context).fadeIn(duration: 600.ms).scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(strings.wrappedOutroFor(monthly: c.monthly),
                    style: c.text(AppFontSize.body, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 2)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onShare,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentFill,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
                    label: Text(strings.wrappedShareCta,
                        style: c.text(AppFontSize.bodyLg, weight: FontWeight.w900, color: Colors.white, spacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryList extends StatelessWidget {
  final _SlideContext c;
  final String title;
  final List<String> items;
  const _SummaryList({required this.c, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.6)),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text('${i + 1}', style: c.text(AppFontSize.body, weight: FontWeight.w900, color: AppColors.accent)),
                ),
                Expanded(
                  child: Text(items[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: c.text(AppFontSize.body, weight: i == 0 ? FontWeight.w800 : FontWeight.w600, height: 1.25)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  final _SlideContext c;
  final String label;
  final String value;
  const _SummaryNumber({required this.c, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label,
              maxLines: 1,
              style: c.text(AppFontSize.micro, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.2)),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: c.text(AppFontSize.headline, weight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  final bool monthly;
  const _Empty({required this.locale, required this.strings, required this.monthly});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EmptyState(
        art: Text(monthly ? '月' : '年',
            style: GoogleFonts.notoSansJp(
                fontSize: AppFontSize.mega, fontWeight: FontWeight.w900, color: AppColors.accent.withValues(alpha: 0.35))),
        title: strings.wrappedNoDataFor(monthly: monthly),
        message: strings.wrappedNoDataSubtitle,
        actionLabel: strings.a11yBack,
        onAction: () => Navigator.of(context).pop(),
      ),
    );
  }
}
