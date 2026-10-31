part of '../home_screen.dart';

class _WrappedEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _WrappedEntryCard({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Semantics(
      button: true,
      label: strings.a11yWrapped,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            CyberPageRoute(builder: (_) => WrappedScreen(year: year)),
          );
        },
        child: GlassCard(
          color: AppColors.accent,
          highlightAlpha: 0.12,
          dimAlpha: 0.04,
          borderAlpha: 0.4,
          borderRadius: 6,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6)),
                ),
                child: Center(
                  child: Text(
                    '月',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'WRAPPED $year',
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                strings.wrappedViewYourWrapped,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningClockEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _ListeningClockEntryCard(
      {required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: strings.a11yClock,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            CyberPageRoute(builder: (_) => const ListeningClockScreen()),
          );
        },
        child: GlassCard(
          color: AppColors.neonCyan,
          highlightAlpha: 0.08,
          dimAlpha: 0.03,
          borderAlpha: 0.3,
          borderRadius: 6,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.radar,
                    color: AppColors.neonCyan, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                strings.clockTitle,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                strings.clockViewClock,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonCyan,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RabbitHoleEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  final Artist? seedArtist;
  const _RabbitHoleEntryCard({
    required this.locale,
    required this.strings,
    this.seedArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (seedArtist == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: strings.a11yRabbitHole,
      child: GestureDetector(
        onTap: () {
          appNavigatorKey.currentState?.push(
            CyberPageRoute(
              builder: (_) => RabbitHoleScreen(seedArtist: seedArtist!),
            ),
          );
        },
        child: GlassCard(
          color: AppColors.neonPurple,
          highlightAlpha: 0.10,
          dimAlpha: 0.04,
          borderAlpha: 0.3,
          borderRadius: 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.neonPurple.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(Icons.hub,
                    color: AppColors.neonPurple, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.rabbitHoleTitle,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.rabbitHoleSubtitle,
                      style: locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neonPurple.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (seedArtist != null)
                ClipOval(
                  child: CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, 30),
                    imageUrl: seedArtist!.getBestImage(size: 'small'),
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: AppColors.neonPurple.withValues(alpha: 0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseRadarEntryCard extends StatelessWidget {
  final LocaleProvider locale;
  final dynamic strings;
  const _ReleaseRadarEntryCard({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final radar = ReleaseRadarService();
    return ValueListenableBuilder<List<RadarRelease>>(
      valueListenable: radar.releases,
      builder: (context, releases, _) {
        final unread = releases.where((r) => r.isUnread).length;
        return ValueListenableBuilder<int>(
          valueListenable: radar.watchedCount,
          builder: (context, watched, _) {
            final hasNews = unread > 0;
            final accent = hasNews ? AppColors.accent : AppColors.neonCyan;
            return Semantics(
              button: true,
              label: hasNews
                  ? '${strings.a11yRadar}. ${strings.radarNewCount(unread)}'
                  : strings.a11yRadar,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  appNavigatorKey.currentState?.push(
                    CyberPageRoute(
                        builder: (_) => const ReleaseRadarScreen()),
                  );
                },
                child: GlassCard(
                  color: accent,
                  highlightAlpha: hasNews ? 0.12 : 0.08,
                  dimAlpha: hasNews ? 0.04 : 0.03,
                  borderAlpha: hasNews ? 0.55 : 0.3,
                  borderRadius: 6,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.5)),
                            ),
                            child: Icon(Icons.radar, color: accent, size: 20),
                          ),
                          if (hasNews)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 18, minHeight: 18),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: AppColors.bgDeep, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: locale.getTextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textBright,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.radarTitle,
                              style: locale.getTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasNews
                                  ? strings.radarNewCount(unread)
                                  : strings.radarWatching(watched),
                              style: locale.getTextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accent.withValues(alpha: 0.85),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: accent.withValues(alpha: 0.7), size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
