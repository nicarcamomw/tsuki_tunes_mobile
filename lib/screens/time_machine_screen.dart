import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../core/utils/cyber_page_route.dart';
import '../models/track.dart';
import '../providers/app_providers.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/deezer_api_service.dart';
import '../services/release_radar_service.dart';
import '../services/time_machine_service.dart';
import '../widgets/glass_card.dart';
import 'main_navigation_screen.dart';

enum _Period { year, sixMonths, month, week, random }

class TimeMachineScreen extends ConsumerStatefulWidget {
  const TimeMachineScreen({super.key});

  @override
  ConsumerState<TimeMachineScreen> createState() => _TimeMachineScreenState();
}

class _TimeMachineScreenState extends ConsumerState<TimeMachineScreen> {
  final TimeMachineService _service = TimeMachineService();
  final Random _rng = Random();

  _Period _period = _Period.year;
  late DateTime _anchor;
  TimeMachineMoment? _moment;
  bool _loading = true;
  bool _starting = false;
  bool _notify = true;
  DateTime? _firstPlayDay;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _anchor = TimeMachineService.yearsAgo(DateTime.now(), 1);
    _load();
    _service.notificationsEnabled().then((v) {
      if (mounted) setState(() => _notify = v);
    });
    context.read<LibraryProvider>().firstRecordedPlayDay().then((d) {
      if (mounted) setState(() => _firstPlayDay = d);
    });
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() => _loading = true);
    final moment = await _service.load(context.read<LibraryProvider>(), _anchor);
    if (!mounted || id != _request) return;
    setState(() {
      _moment = moment;
      _loading = false;
    });
  }

  void _select(_Period period) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    DateTime? anchor;
    switch (period) {
      case _Period.year:
        anchor = TimeMachineService.yearsAgo(now, 1);
      case _Period.sixMonths:
        anchor = TimeMachineService.monthsAgo(now, 6);
      case _Period.month:
        anchor = TimeMachineService.monthsAgo(now, 1);
      case _Period.week:
        anchor = now.subtract(const Duration(days: 7));
      case _Period.random:
        final dates = TimeMachineService.datesWithHistory(
          context.read<LibraryProvider>().listenedTracks,
          now.subtract(const Duration(days: 7)),
        );
        if (dates.isEmpty) {
          _snack(ref.read(stringsProvider).timeMachineNoHistory);
          return;
        }
        anchor = dates[_rng.nextInt(dates.length)];
    }
    setState(() {
      _period = period;
      _anchor = anchor!;
    });
    _load();
  }

  Future<void> _play() async {
    final moment = _moment;
    if (moment == null || _starting) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _starting = true);
    final strings = ref.read(stringsProvider);
    final audio = context.read<AudioProvider>();

    // History may lack a preview URL (older entries): fetch those fresh.
    final api = DeezerApiService();
    final resolved = await Future.wait(moment.tracks.map((t) async {
      if (t.track.previewUrl.isNotEmpty) return t.track;
      final fresh = await api.getTrack(t.track.id);
      return fresh;
    }));
    final playable =
        resolved.whereType<Track>().where((t) => t.previewUrl.isNotEmpty).toList();
    if (!mounted) return;
    setState(() => _starting = false);
    if (playable.isEmpty) {
      _snack(strings.timeMachinePlayFailed);
      return;
    }
    unawaited(audio.playTrack(playable.first, newQueue: playable));
    _snack(strings.timeMachinePlaying);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
        duration: const Duration(seconds: 2),
        content: Text(text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      ));
  }

  String _periodLabel(AppStrings s, _Period p) => switch (p) {
        _Period.year => s.timeMachineYearAgo,
        _Period.sixMonths => s.timeMachineSixMonthsAgo,
        _Period.month => s.timeMachineMonthAgo,
        _Period.week => s.timeMachineWeekAgo,
        _Period.random => s.timeMachineRandom,
      };

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final moment = _moment;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textBright,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          strings.timeMachineTitle,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 2,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            0, 4, 0, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in _Period.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_periodLabel(strings, p)),
                      avatar: p == _Period.random
                          ? const Icon(Icons.casino_outlined, size: 16)
                          : null,
                      selected: _period == p,
                      onSelected: (_) => _select(p),
                      showCheckmark: false,
                      labelStyle: locale.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _period == p
                            ? AppColors.textBright
                            : AppColors.textSecondary,
                      ),
                      selectedColor: AppColors.neonPurple.withValues(alpha: 0.3),
                      backgroundColor: AppColors.bgCard,
                      side: BorderSide(
                        color: _period == p
                            ? AppColors.neonPurple
                            : AppColors.border,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _DateHeader(anchor: _anchor, loading: _loading, locale: locale),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? const SizedBox(key: ValueKey('loading'), height: 220)
                : moment == null
                    ? _Nothing(
                        key: const ValueKey('nothing'),
                        locale: locale,
                        onRandom: () => _select(_Period.random),
                      )
                    : _MomentView(
                        key: ValueKey('${moment.anchor}-${moment.kind}'),
                        moment: moment,
                        locale: locale,
                        starting: _starting,
                        onPlay: _play,
                      ),
          ),
          if (!_loading &&
              (moment == null || moment.kind == TimeMachineKind.discoveries))
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                _firstPlayDay != null
                    ? strings.timeMachineCountingSince(
                        strings.longDate(_firstPlayDay!))
                    : strings.timeMachineCountingStarts,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          if (ReleaseRadarService.isSupported)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderSub),
              ),
              child: MergeSemantics(
                child: SwitchListTile(
                  value: _notify,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _notify = v);
                    _service.setNotificationsEnabled(v);
                  },
                  activeThumbColor: AppColors.neonPurple,
                  secondary: Icon(
                    _notify
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: _notify ? AppColors.neonPurple : AppColors.textMuted,
                    size: 20,
                  ),
                  title: Text(
                    strings.timeMachineNotifyToggle,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                  subtitle: Text(
                    strings.timeMachineNotifyToggleSubtitle,
                    style: locale.getTextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date header with a rewinding clock
// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  final DateTime anchor;
  final bool loading;
  final LocaleProvider locale;
  const _DateHeader(
      {required this.anchor, required this.loading, required this.locale});

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$anchor-$loading'),
              tween: Tween(begin: 0, end: loading && !reduce ? -2.0 : 0.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, turns, child) =>
                  Transform.rotate(angle: turns * 2 * pi, child: child),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withValues(alpha: 0.25),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(Icons.history,
                    color: AppColors.neonPurple, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.longDate(anchor).toUpperCase(),
                    style: locale.getTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading
                        ? strings.timeMachineRewinding
                        : strings.weekdayName(anchor.weekday),
                    style: locale.getTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: loading ? AppColors.neonPurple : AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Moment
// ---------------------------------------------------------------------------

class _MomentView extends StatelessWidget {
  final TimeMachineMoment moment;
  final LocaleProvider locale;
  final bool starting;
  final VoidCallback onPlay;

  const _MomentView({
    super.key,
    required this.moment,
    required this.locale,
    required this.starting,
    required this.onPlay,
  });

  String _caption(AppStrings s, TimeMachineTrack t) {
    if (moment.kind == TimeMachineKind.plays) {
      return s.timeMachineTimes(t.count, moment.exactDay);
    }
    final at = t.discoveredAt;
    if (at == null) return '';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return moment.exactDay
        ? s.timeMachineDiscoveredAt('$hh:$mm')
        : s.timeMachineDiscoveredOn(s.weekdayName(at.weekday));
  }

  @override
  Widget build(BuildContext context) {
    final s = locale.strings;
    final hero = moment.hero;
    final isPlays = moment.kind == TimeMachineKind.plays;
    final accent = isPlays ? AppColors.accent : AppColors.neonCyan;
    final headline = moment.onRepeat
        ? s.timeMachineHeadlineRepeat
        : isPlays
            ? s.timeMachineHeadlinePlayed
            : s.timeMachineHeadlineDiscovered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Wrap(
            spacing: 8,
            children: [
              _Badge(
                label: isPlays
                    ? s.timeMachineKindPlays
                    : s.timeMachineKindDiscoveries,
                color: accent,
                locale: locale,
              ),
              _Badge(
                label: moment.exactDay
                    ? s.timeMachineExactDay
                    : s.timeMachineThatWeek,
                color: AppColors.textMuted,
                locale: locale,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(
            headline,
            style: locale.getTextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.12), AppColors.bgCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _Cover(url: hero.track.coverUrl, size: 104),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hero.track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _caption(s, hero),
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: starting ? null : onPlay,
              icon: starting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textBright),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                s.timeMachinePlay,
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.85),
                foregroundColor: AppColors.textBright,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ),
        for (final t in moment.tracks.skip(1))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Semantics(
              label: '${t.track.title}, ${t.track.artistName}. ${_caption(s, t)}',
              excludeSemantics: true,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _Cover(url: t.track.coverUrl, size: 44),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBright,
                          ),
                        ),
                        Text(
                          t.track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPlays ? '×${t.count}' : _caption(s, t),
                    style: locale.getTextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
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

class _Cover extends StatelessWidget {
  final String url;
  final double size;
  const _Cover({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.bgMid,
      child: Icon(Icons.music_note, color: AppColors.textMuted, size: size * 0.35),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final LocaleProvider locale;
  const _Badge({required this.label, required this.color, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: locale.getTextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  final LocaleProvider locale;
  final VoidCallback onRandom;
  const _Nothing({super.key, required this.locale, required this.onRandom});

  @override
  Widget build(BuildContext context) {
    final s = locale.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 10),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty,
              size: 40, color: AppColors.neonPurple.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            s.timeMachineNothingTitle,
            style: locale.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.timeMachineNothing,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRandom,
            icon: const Icon(Icons.casino_outlined, size: 16),
            label: Text(s.timeMachineRandom),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.neonPurple,
              side: BorderSide(
                  color: AppColors.neonPurple.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home entry card: teases today's anniversary and refreshes the schedule
// ---------------------------------------------------------------------------

class TimeMachineEntryCard extends ConsumerStatefulWidget {
  const TimeMachineEntryCard({super.key});

  @override
  ConsumerState<TimeMachineEntryCard> createState() => _TimeMachineEntryCardState();
}

class _TimeMachineEntryCardState extends ConsumerState<TimeMachineEntryCard> {
  TimeMachineMoment? _moment;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-runs when the library notifies, until the history has loaded.
    final library = Provider.of<LibraryProvider>(context);
    if (_requested || !library.listenedTracksLoaded) return;
    _requested = true;
    final service = TimeMachineService();
    service
        .load(library, TimeMachineService.yearsAgo(DateTime.now(), 1))
        .then((m) {
      if (mounted) setState(() => _moment = m);
    });
    unawaited(service.refreshSchedule(library));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = locale.strings;
    final m = _moment;
    final teaser = m == null
        ? s.timeMachineCardEmpty
        : m.onRepeat
            ? s.timeMachineCardTeaserRepeat(m.hero.track.title)
            : s.timeMachineCardTeaser(m.hero.track.title);

    return Semantics(
      button: true,
      label: '${s.a11yTimeMachine}. $teaser',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          appNavigatorKey.currentState?.push(
            CyberPageRoute(builder: (_) => const TimeMachineScreen()),
          );
        },
        child: GlassCard(
          color: AppColors.neonPurple,
          highlightAlpha: 0.10,
          dimAlpha: 0.04,
          borderAlpha: 0.35,
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
                      color: AppColors.neonPurple.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.history,
                    color: AppColors.neonPurple, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.timeMachineTitle,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      teaser,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neonPurple.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (m != null && m.hero.track.coverUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _Cover(url: m.hero.track.coverUrl, size: 34),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right,
                  color: AppColors.neonPurple.withValues(alpha: 0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
