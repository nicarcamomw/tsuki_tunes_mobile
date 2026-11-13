import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/wrapped_data.dart';
import '../../domain/logic/wrapped_service.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/empty_state.dart';
import '../widgets/haptics.dart';
import '../widgets/motion.dart';
import '../widgets/skeleton_loader.dart';
import 'wrapped/story_image.dart';

part 'wrapped/wrapped_pieces.dart';
part 'wrapped/wrapped_slides.dart';


final _log = Log.named('Wrapped');

/// Tsuki Wrapped as stories: the recap of a [year], or of one [month] of
/// it. Tap the sides to move, hold to pause, swipe down to close.
class WrappedScreen extends ConsumerStatefulWidget {
  final int year;

  /// 1–12 for a monthly recap; null for the whole year.
  final int? month;

  /// Shown as is instead of reading the play log (tests and previews).
  @visibleForTesting
  final WrappedData? previewData;

  const WrappedScreen(
      {super.key, required this.year, this.month, this.previewData});

  /// Opens full screen, over the bottom bar and the mini player.
  static Future<void> open(BuildContext context, {required int year, int? month}) =>
      WrappedRoute(year: year, month: month).push(context);


  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

typedef _SlideBuilder = Widget Function(GlobalKey shareKey);

class _WrappedScreenState extends ConsumerState<WrappedScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progress;
  WrappedData? _data;
  List<_SlideBuilder> _slides = const [];
  int _page = 0;
  bool _sharing = false;
  double _dragDown = 0;
  final Map<int, GlobalKey> _shareKeys = {};

  bool get _monthly => widget.month != null;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _generate();
  }

  Future<void> _generate() async {
    final preview = widget.previewData;
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final slides = _buildSlides(preview);
        setState(() {
          _data = preview;
          _slides = slides;
          for (var i = 0; i < slides.length; i++) {
            _shareKeys[i] = GlobalKey();
          }
        });
      });
      return;
    }
    final library = ref.read(libraryProvider);
    final y = widget.year;
    final m = widget.month;
    // The period and the one before it, to compare.
    final from = m == null ? DateTime(y - 1, 1, 1) : DateTime(y, m - 1, 1);
    final to = m == null ? DateTime(y, 12, 31) : DateTime(y, m + 1, 0);
    final days = await library.loadPlayDays(from, to);
    if (!mounted) return;
    final service = WrappedService();
    var data = service.generate(
      days: days,
      listened: library.listenedTracks,
      year: y,
      month: m,
    );
    if (data.basedOnPlays) {
      final prev = m == null
          ? service.minutesIn(days, y - 1)
          : service.minutesIn(days, from.year, month: from.month);
      data = data.withPreviousMinutes(prev > 0 ? prev : null);
    }
    final slides = _buildSlides(data);
    setState(() {
      _data = data;
      _slides = slides;
      for (var i = 0; i < slides.length; i++) {
        _shareKeys[i] = GlobalKey();
      }
    });
    if (!data.isEmpty) _startProgress();
    unawaited(_findCompletedAlbums(data));
  }

  /// Which albums were heard whole needs the catalog (how many songs each
  /// has): looked up after the recap shows, then the albums slide updates.
  Future<void> _findCompletedAlbums(WrappedData data) async {
    if (!data.topAlbums.any((a) => a.tracksHeard >= 5)) return;
    final getAlbum = ref.read(getAlbumProvider);
    final done = await WrappedService().withCompletedAlbums(data, getAlbum.call);
    if (!mounted || done.completedAlbums.isEmpty) return;
    setState(() {
      _data = done;
      _slides = _buildSlides(done);
    });
  }

  void _startProgress() {
    _progress.forward(from: 0).then((_) {
      if (mounted && _page < _slides.length - 1) _goTo(_page + 1);
    });
  }

  void _goTo(int page) {
    if (page < 0 || page >= _slides.length) return;
    _pageController.animateToPage(page,
        duration: AppMotion.slow, curve: Curves.easeInOutCubic);
    setState(() => _page = page);
    if (page == _slides.length - 1) {
      // The last slide (the recap to share) stays until closed.
      _progress.value = 1;
    } else {
      _startProgress();
    }
  }

  Future<void> _share() async {
    final key = _shareKeys[_page];
    final boundary = key?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    Haptics.tap();
    setState(() => _sharing = true);
    _progress.stop();
    try {
      // Sharp at 1080 px wide whatever the screen, then laid out as a
      // 1080×1920 story (what Instagram and WhatsApp stories expect).
      final pixelRatio = (1080 / boundary.size.width).clamp(2.0, 4.0);
      final slide = await boundary.toImage(pixelRatio: pixelRatio);
      final story = await composeStory(slide, footer: 'TSUKI TUNES  ·  ${ref.read(stringsProvider).wrappedPeriod(widget.year, widget.month)}');
      slide.dispose();
      final bytes = await story.toByteData(format: ui.ImageByteFormat.png);
      story.dispose();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final tag = _monthly ? '${widget.year}_${widget.month}' : '${widget.year}';
      final file = File('${dir.path}/tsuki_wrapped_${tag}_$_page.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      final strings = ref.read(stringsProvider);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Tsuki Wrapped · ${strings.wrappedPeriod(widget.year, widget.month)}',
      ));
    } catch (e) {
      _log.severe('share error: $e');
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        if (_page < _slides.length - 1) _progress.forward();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  List<_SlideBuilder> _buildSlides(WrappedData d) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final since = d.playsSince;
    final start = DateTime(widget.year, widget.month ?? 1, 1);
    final note = !d.basedOnPlays
        ? strings.wrappedBasedOnDiscoveries
        : (since != null && since.difference(start).inDays > (_monthly ? 3 : 14))
            ? strings.wrappedPlaysSince(strings.longDate(since))
            : null;
    final ctx = _SlideContext(
      data: d,
      locale: locale,
      strings: strings,
      period: strings.wrappedPeriod(widget.year, widget.month),
      monthly: _monthly,
      previousLabel: _monthly
          ? strings.monthName(widget.month == 1 ? 12 : widget.month! - 1)
          : '${widget.year - 1}',
    );
    return [
      (k) => _IntroSlide(c: ctx, note: note, shareKey: k),
      (k) => _MinutesSlide(c: ctx, shareKey: k),
      if (d.topTracks.isNotEmpty) (k) => _TopSongSlide(c: ctx, shareKey: k),
      if (d.topArtists.isNotEmpty) (k) => _TopArtistSlide(c: ctx, shareKey: k),
      if (d.topAlbums.isNotEmpty) (k) => _TopAlbumSlide(c: ctx, shareKey: k),
      if (d.hourDistribution.isNotEmpty) (k) => _HourSlide(c: ctx, shareKey: k),
      (k) => _AuraSlide(c: ctx, shareKey: k),
      if (d.funFacts.isNotEmpty) (k) => _FactsSlide(c: ctx, shareKey: k),
      (k) => _SummarySlide(c: ctx, shareKey: k, onShare: _share),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final data = _data;
    return Scaffold(
      backgroundColor: Colors.black,
      body: data == null
          ? const SkeletonStory()
          : data.isEmpty
              ? _Empty(locale: locale, strings: strings, monthly: _monthly)
              : _buildStories(strings),
    );
  }

  Widget _buildStories(AppStrings strings) {
    final size = MediaQuery.sizeOf(context);
    // Screen readers move through the story with actions instead of taps on
    // the screen's sides: a tap goes on, "previous" goes back.
    return Semantics(
      label: strings.a11yNext,
      onTap: () => _goTo(_page + 1),
      customSemanticsActions: {
        CustomSemanticsAction(label: strings.a11yPrevious): () => _goTo(_page - 1),
      },
      child: GestureDetector(
      excludeFromSemantics: true,
      onTapUp: (d) {
        final x = d.globalPosition.dx;
        if (x < size.width / 3) {
          _goTo(_page - 1);
        } else if (x > size.width * 2 / 3) {
          _goTo(_page + 1);
        }
      },
      onLongPressStart: (_) => _progress.stop(),
      onLongPressEnd: (_) {
        if (_page < _slides.length - 1) _progress.forward();
      },
      onVerticalDragUpdate: (d) => setState(() => _dragDown = math.max(0, _dragDown + d.delta.dy)),
      onVerticalDragEnd: (d) {
        if (_dragDown > 120 || (d.primaryVelocity ?? 0) > 900) {
          Navigator.of(context).pop();
        } else {
          setState(() => _dragDown = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragDown),
        child: Transform.scale(
          scale: 1 - math.min(_dragDown / size.height, 0.1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_dragDown > 0 ? AppRadius.sheet : 0),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _slides[i](_shareKeys[i]!),
                ),
                _buildTopBar(strings),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTopBar(AppStrings strings) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: List.generate(_slides.length, (i) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: i < _page
                        ? const _BarFill(value: 1)
                        : i == _page
                            ? AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) => _BarFill(value: _progress.value),
                              )
                            : null,
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  tooltip: strings.a11yClose,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                  tooltip: strings.wrappedShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
