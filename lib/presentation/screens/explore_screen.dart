import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/artist.dart';
import '../navigation/main_tab.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/daily_guess.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/entry_cards.dart';
import '../widgets/feature_card.dart';
import '../widgets/haptics.dart';
import '../widgets/section_title.dart';
import '../widgets/streak_card.dart';
import '../widgets/weekly_challenges_card.dart';
import 'lore_screen.dart';
import 'main_navigation_screen.dart';
import 'mask_collection_screen.dart';
import 'run_mode_screen.dart';
import 'time_machine_screen.dart';

final _log = Log.named('ExploreScreen');

/// The third tab: everything there is to do besides playing music, in one
/// place. Discover (new music), Play (games and moods) and Your path
/// (progress, stats and lore).
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final ScrollController _scroll = ScrollController();

  /// Where the rabbit hole starts: the user's top artist, or a featured one.
  Artist? _seedArtist;

  @override
  void initState() {
    super.initState();
    NavigationEvents.onExploreScrollToTop = _scrollToTop;
    unawaited(DailyGuess.refresh());
    unawaited(_loadSeedArtist());
  }

  @override
  void dispose() {
    if (NavigationEvents.onExploreScrollToTop == _scrollToTop) {
      NavigationEvents.onExploreScrollToTop = null;
    }
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    unawaited(_scroll.animateTo(
      0,
      duration: AppMotion.slow,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadSeedArtist() async {
    try {
      final top = ref.read(libraryProvider).getTopArtists(limit: 1);
      Artist? seed;
      if (top.isNotEmpty) {
        seed = await ref.read(findArtistByNameProvider)(top.first.name);
      }
      if (seed == null) {
        final featured = await ref.read(musicCatalogProvider).getFeaturedArtists();
        if (featured.isNotEmpty) seed = featured.first;
      }
      if (mounted && seed != null) setState(() => _seedArtist = seed);
    } catch (e) {
      // Without a seed the rabbit hole card just isn't shown.
      _log.warning('seed artist: $e');
    }
  }

  Future<void> _openGuessGame() async {
    if (!ecoAllows(context, EcoFeature.guessSong)) return;
    Haptics.tap();
    await const GuessSongRoute().push<void>(context);
    await DailyGuess.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final isLoggedIn = ref.watch(authProvider.select((a) => a.isLoggedIn));
    final hasListened = ref.watch(libraryProvider.select((l) => l.listenedCount > 0));
    final radarSupported = ref.watch(releaseRadarSupportedProvider);
    final ambientCount =
        ref.watch(ambientProvider.select((a) => a.isPlaying ? a.activeSounds.length : 0));
    final run = ref.watch(runProvider.select(
        (r) => (r.active, r.active ? r.reading.spm?.round() : null, r.enabled)));
    final masks = ref.watch(maskProvider.select((m) => (m.unlockedCount, m.totalCount)));

    const cardGap = SizedBox(height: 10);
    const sidePadding = EdgeInsets.symmetric(horizontal: AppSpacing.page);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SafeArea(
            bottom: false,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _Header(locale: locale),

                // ── Discover: new music ──
                _SectionHeading(locale: locale, text: strings.exploreDiscover),
                if (isLoggedIn)
                  EcoLocked(
                    feature: EcoFeature.discovery,
                    child: DiscoveryEntryCard(locale: locale),
                  ),
                if (_seedArtist != null)
                  EcoLocked(
                    feature: EcoFeature.rabbitHole,
                    child: RabbitHoleEntryCard(
                      locale: locale,
                      strings: strings,
                      seedArtist: _seedArtist,
                    ),
                  ),
                if (isLoggedIn && radarSupported)
                  ReleaseRadarEntryCard(locale: locale, strings: strings),
                if (isLoggedIn && hasListened)
                  const EcoLocked(feature: EcoFeature.timeMachine, child: TimeMachineEntryCard()),

                // ── Play: games and moods ──
                _SectionHeading(locale: locale, text: strings.explorePlay),
                Padding(
                  padding: sidePadding,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: DailyGuess.done,
                              builder: (context, done, _) => FeatureCard(
                                locale: locale,
                                icon: Icons.music_note_rounded,
                                color: AppColors.accent,
                                title: strings.guessTitle,
                                subtitle: done ? strings.guessDailyDone : strings.guessModeDaily,
                                highlight: !done,
                                onTap: _openGuessGame,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FeatureCard(
                              locale: locale,
                              icon: Icons.water_drop_rounded,
                              color: AppColors.neonCyan,
                              title: strings.ambientTitle,
                              subtitle: ambientCount > 0
                                  ? strings.ambientPlayingCount(ambientCount)
                                  : strings.homeAmbientCardSubtitle,
                              highlight: ambientCount > 0,
                              onTap: () {
                                if (!ecoAllows(context, EcoFeature.ambient)) return;
                                Haptics.tap();
                                AmbientMixerSheet.show(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (run.$3) ...[
                        cardGap,
                        FeatureCard(
                          locale: locale,
                          icon: Icons.directions_run_rounded,
                          color: AppColors.neonGreen,
                          title: strings.runTitle,
                          subtitle: run.$1 ? strings.runCardActive(run.$2) : strings.runCardSubtitle,
                          highlight: run.$1,
                          onTap: () {
                            if (!ecoAllows(context, EcoFeature.running)) return;
                            Haptics.tap();
                            RunModeScreen.open(context);
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Your path: progress, stats and lore ──
                _SectionHeading(locale: locale, text: strings.explorePath),
                if (isLoggedIn) const EcoLevelCard(),
                if (isLoggedIn) const EcoLocked(feature: EcoFeature.streak, child: StreakCard()),
                const EcoLocked(
                  feature: EcoFeature.weekly,
                  child: WeeklyChallengesCard(compact: true),
                ),
                if (isLoggedIn && hasListened)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: EcoLocked(
                            feature: EcoFeature.wrapped,
                            child: WrappedEntryCard(locale: locale, strings: strings),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: EcoLocked(
                            feature: EcoFeature.listeningClock,
                            child: ListeningClockEntryCard(locale: locale, strings: strings),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 0),
                  child: Row(
                    children: [
                      if (isLoggedIn) ...[
                        Expanded(
                          child: FeatureCard(
                            locale: locale,
                            icon: Icons.theater_comedy_rounded,
                            color: AppColors.neonPurple,
                            title: strings.masksTitle,
                            subtitle: strings.masksCount(masks.$1, masks.$2),
                            highlight: false,
                            onTap: () {
                              Haptics.tap();
                              MaskCollectionScreen.open(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FeatureCard(
                          locale: locale,
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.sakura,
                          title: strings.loreTitle,
                          subtitle: strings.exploreLoreSubtitle,
                          highlight: false,
                          onTap: () {
                            Haptics.tap();
                            LoreScreen.open(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "EXPLORAR // 03" and its line of flavour, like the other tabs.
class _Header extends StatelessWidget {
  final LocaleProvider locale;
  const _Header({required this.locale});

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    strings.navExplore,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.display,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    ' // ${MainTab.explore.number}',
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.display,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Flavour, not information: screen readers skip it.
          ExcludeSemantics(
            child: Text(
              strings.exploreTelemetry,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansJp(
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w700,
                color: AppColors.accentText,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final LocaleProvider locale;
  final String text;
  const _SectionHeading({required this.locale, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 24, AppSpacing.page, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SectionTitle(locale: locale, text: text),
        ),
      );
}
