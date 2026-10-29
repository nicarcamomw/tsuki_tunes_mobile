import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_cache_size.dart';
import '../models/wrapped_data.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/wrapped_service.dart';

class WrappedScreen extends StatefulWidget {
  final int year;
  const WrappedScreen({super.key, required this.year});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  WrappedData? _data;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isSharing = false;
  final Map<int, GlobalKey> _slideKeys = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _generateWrapped();
  }

  Future<void> _generateWrapped() async {
    final library = context.read<LibraryProvider>();
    final days = await library.loadPlayDays(
      DateTime(widget.year, 1, 1),
      DateTime(widget.year, 12, 31),
    );
    if (!mounted) return;
    final data = WrappedService().generate(
      days: days,
      listened: library.listenedTracks,
      year: widget.year,
    );
    setState(() {
      _data = data;
      _totalPages = _computePageCount(data);
      for (int i = 0; i < _totalPages; i++) {
        _slideKeys[i] = GlobalKey();
      }
    });
    _startProgress();
  }

  int _computePageCount(WrappedData data) {
    if (data.isEmpty) return 1;
    int count = 1; // intro
    if (data.topTracks.isNotEmpty) count++;
    if (data.topArtists.isNotEmpty) count++;
    count++; // listening time
    count++; // favorite hour
    if (data.funFacts.isNotEmpty) count++;
    count++; // outro
    return count;
  }

  void _startProgress() {
    _progressController.forward(from: 0).then((_) {
      if (mounted && _currentPage < _totalPages - 1) {
        _goToPage(_currentPage + 1);
      }
    });
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentPage = page);
    _startProgress();
  }

  void _onTapLeft() {
    if (_currentPage > 0) _goToPage(_currentPage - 1);
  }

  void _onTapRight() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _shareSlide() async {
    final key = _slideKeys[_currentPage];
    if (key == null) return;

    setState(() => _isSharing = true);
    _progressController.stop();

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/tsuki_wrapped_${widget.year}_$_currentPage.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tsuki Wrapped ${widget.year}',
      );
    } catch (e) {
      debugPrint('[WrappedScreen] share error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
        _startProgress();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final data = _data;

    return Scaffold(
      backgroundColor: Colors.black,
      body: data == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : data.isEmpty
              ? _buildEmptyState(locale, strings)
              : _buildStoryView(locale, strings, data),
    );
  }

  Widget _buildEmptyState(LocaleProvider locale, dynamic strings) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.music_off_rounded,
                    color: AppColors.accent, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                strings.wrappedNoData,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.wrappedNoDataSubtitle,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.accent.withValues(alpha: 0.08),
                  ),
                  child: Text(
                    strings.a11yBack,
                    style: locale.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 1.5,
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

  Widget _buildStoryView(
      LocaleProvider locale, dynamic strings, WrappedData data) {
    final slides = _buildSlides(locale, strings, data);

    return Stack(
      children: [
        GestureDetector(
          onTapUp: (details) {
            final w = MediaQuery.sizeOf(context).width;
            if (details.globalPosition.dx < w / 3) {
              _onTapLeft();
            } else if (details.globalPosition.dx > w * 2 / 3) {
              _onTapRight();
            }
          },
          onLongPressStart: (_) => _progressController.stop(),
          onLongPressEnd: (_) => _progressController.forward(),
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: _slideKeys[index],
                child: slides[index],
              );
            },
          ),
        ),
        // Progress bars
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: List.generate(_totalPages, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: i < _currentPage
                            ? Container(color: AppColors.accent)
                            : i == _currentPage
                                ? AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (_, __) {
                                      return LinearProgressIndicator(
                                        value: _progressController.value,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.2),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                AppColors.accent),
                                        minHeight: 3,
                                      );
                                    },
                                  )
                                : Container(
                                    color:
                                        Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        // Top actions
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  tooltip: strings.a11yClose,
                ),
                IconButton(
                  onPressed: _isSharing ? null : _shareSlide,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_outlined,
                          color: Colors.white, size: 22),
                  tooltip: strings.wrappedShare,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSlides(
      LocaleProvider locale, dynamic strings, WrappedData data) {
    final slides = <Widget>[];

    final since = data.playsSince;
    final String? sourceNote = !data.basedOnPlays
        ? strings.wrappedBasedOnDiscoveries
        : (since != null && since.isAfter(DateTime(widget.year, 1, 15)))
            ? strings.wrappedPlaysSince(strings.longDate(since))
            : null;
    slides.add(_IntroSlide(
        year: widget.year,
        locale: locale,
        strings: strings,
        note: sourceNote));

    if (data.topTracks.isNotEmpty) {
      slides.add(_TopTracksSlide(
          tracks: data.topTracks,
          basedOnPlays: data.basedOnPlays,
          locale: locale,
          strings: strings));
    }

    if (data.topArtists.isNotEmpty) {
      slides.add(_TopArtistsSlide(
          artists: data.topArtists,
          basedOnPlays: data.basedOnPlays,
          locale: locale,
          strings: strings));
    }

    slides.add(_ListeningTimeSlide(data: data, locale: locale, strings: strings));

    slides.add(_FavoriteHourSlide(data: data, locale: locale, strings: strings));

    if (data.funFacts.isNotEmpty) {
      slides.add(
          _FunFactsSlide(data: data, locale: locale, strings: strings));
    }

    slides.add(
        _OutroSlide(year: widget.year, locale: locale, strings: strings));

    return slides;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: INTRO
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _IntroSlide extends StatelessWidget {
  final int year;
  final LocaleProvider locale;
  final dynamic strings;
  final String? note;
  const _IntroSlide(
      {required this.year,
      required this.locale,
      required this.strings,
      this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A0A), Color(0xFF0A0A1A), Colors.black],
        ),
      ),
      child: Stack(
        children: [
          // Decorative grid lines
          ..._buildGridLines(),
          // Diagonal accent line
          Positioned(
            top: -50,
            right: -50,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 300,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.accent.withValues(alpha: 0),
                    AppColors.accent.withValues(alpha: 0.8),
                    AppColors.accent.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 200.ms)
              .slideX(begin: 0.3, end: 0, duration: 1200.ms),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Title
                  Text(
                    '◈ TSUKI',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent.withValues(alpha: 0.8),
                      letterSpacing: 6,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 100.ms)
                      .slideY(begin: -0.3, end: 0),
                  const SizedBox(height: 16),
                  Text(
                    'WRAPPED',
                    style: locale.getTextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 8,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 300.ms)
                      .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '$year',
                      style: locale.getTextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 6,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 600.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 32),
                  Text(
                    strings.wrappedIntroSlide,
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 900.ms),
                  if (note != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      note!,
                      textAlign: TextAlign.center,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ).animate().fadeIn(duration: 800.ms, delay: 1100.ms),
                  ],
                  const SizedBox(height: 48),
                  // Telemetry decoration
                  Text(
                    '◈ 年間報告 // ANNUAL.REPORT.SYS',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent.withValues(alpha: 0.5),
                      letterSpacing: 2,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 1200.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGridLines() {
    return List.generate(5, (i) {
      final top = 100.0 + i * 160;
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Container(
          height: 0.5,
          color: AppColors.accent.withValues(alpha: 0.05 + i * 0.01),
        ),
      );
    });
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: TOP TRACKS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopTracksSlide extends StatelessWidget {
  final List<WrappedTrackEntry> tracks;
  final bool basedOnPlays;
  final LocaleProvider locale;
  final dynamic strings;
  const _TopTracksSlide(
      {required this.tracks,
      required this.basedOnPlays,
      required this.locale,
      required this.strings});

  // Without a play log every song was "played" once: show the album instead
  // of a meaningless "1 play".
  String _caption(WrappedTrackEntry t) =>
      basedOnPlays ? strings.wrappedPlays(t.playCount) : t.albumTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0505), Color(0xFF0A0A12), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                basedOnPlays
                    ? strings.wrappedTopTracks
                    : strings.wrappedTopDiscoveries,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 2,
                color: AppColors.accent,
              ).animate().scaleX(begin: 0, end: 1, duration: 600.ms, delay: 200.ms, alignment: Alignment.centerLeft),
              const SizedBox(height: 24),
              // #1 Track — featured large
              if (tracks.isNotEmpty)
                _buildFeaturedTrack(context, tracks.first)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms)
                    .slideY(begin: 0.15, end: 0),
              const SizedBox(height: 20),
              // #2-5 Tracks
              ...tracks.skip(1).take(4).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final track = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildTrackRow(context, track, i + 2),
                )
                    .animate()
                    .fadeIn(
                        duration: 500.ms,
                        delay: Duration(milliseconds: 500 + i * 120))
                    .slideX(begin: 0.1, end: 0);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedTrack(BuildContext context, WrappedTrackEntry track) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: track.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, 100),
                    imageUrl: track.coverUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: AppColors.bgCard,
                    child: const Icon(Icons.music_note,
                        color: AppColors.accent, size: 40),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#1',
                style: locale.getTextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                track.title,
                style: locale.getTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                track.artistName,
                style: locale.getTextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _caption(track),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackRow(BuildContext context, WrappedTrackEntry track, int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.accent.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: track.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, 40),
                    imageUrl: track.coverUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: AppColors.bgCard,
                    child: const Icon(Icons.music_note,
                        color: AppColors.accent, size: 18),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artistName,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (basedOnPlays)
            Text(
              strings.wrappedPlays(track.playCount),
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: TOP ARTISTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopArtistsSlide extends StatelessWidget {
  final List<WrappedArtistEntry> artists;
  final bool basedOnPlays;
  final LocaleProvider locale;
  final dynamic strings;
  const _TopArtistsSlide(
      {required this.artists,
      required this.basedOnPlays,
      required this.locale,
      required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0A0A1A), Color(0xFF1A050A), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.wrappedTopArtists,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonCyan,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 2,
                color: AppColors.neonCyan,
              ).animate().scaleX(begin: 0, end: 1, duration: 600.ms, delay: 200.ms, alignment: Alignment.centerLeft),
              const SizedBox(height: 28),
              ...artists.asMap().entries.map((entry) {
                final i = entry.key;
                final artist = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildArtistRow(context, artist, i + 1),
                )
                    .animate()
                    .fadeIn(
                        duration: 500.ms,
                        delay: Duration(milliseconds: 300 + i * 150))
                    .slideX(begin: 0.15, end: 0);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistRow(BuildContext context, WrappedArtistEntry artist, int rank) {
    final isFirst = rank == 1;
    final accentColor = isFirst ? AppColors.neonCyan : AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.all(isFirst ? 14 : 10),
      decoration: BoxDecoration(
        color: isFirst
            ? AppColors.neonCyan.withValues(alpha: 0.06)
            : AppColors.bgCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFirst
              ? AppColors.neonCyan.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: locale.getTextStyle(
                fontSize: isFirst ? 20 : 14,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: artist.coverUrl != null && artist.coverUrl!.isNotEmpty
                ? CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, (isFirst ? 56.0 : 40.0)),
                    imageUrl: artist.coverUrl!,
                    width: isFirst ? 56 : 40,
                    height: isFirst ? 56 : 40,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: isFirst ? 56 : 40,
                    height: isFirst ? 56 : 40,
                    color: AppColors.bgCard,
                    child: Icon(Icons.person,
                        color: accentColor, size: isFirst ? 28 : 20),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  style: locale.getTextStyle(
                    fontSize: isFirst ? 17 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  basedOnPlays
                      ? strings.wrappedPlays(artist.playCount)
                      : strings.wrappedDiscoveredSongs(artist.playCount),
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: LISTENING TIME
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ListeningTimeSlide extends StatelessWidget {
  final WrappedData data;
  final LocaleProvider locale;
  final dynamic strings;
  const _ListeningTimeSlide(
      {required this.data, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final hours = data.totalMinutesListened ~/ 60;
    final mins = data.totalMinutesListened % 60;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050A1A), Color(0xFF0A0510), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.basedOnPlays
                      ? strings.wrappedListeningTime
                      : strings.wrappedNewMusicTime,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neonPurple,
                    letterSpacing: 2,
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 2,
                  color: AppColors.neonPurple,
                ).animate().scaleX(begin: 0, end: 1, duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 40),
                if (hours > 0) ...[
                  Text(
                    '$hours',
                    style: locale.getTextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      height: 1,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 400.ms)
                      .scaleXY(begin: 0.5, end: 1, curve: Curves.easeOutBack),
                  Text(
                    strings.wrappedHours(hours),
                    style: locale.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonPurple,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                  if (mins > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+ ${strings.wrappedMinutes(mins)}',
                      style: locale.getTextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                  ],
                ] else ...[
                  Text(
                    '${data.totalMinutesListened}',
                    style: locale.getTextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      height: 1,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 400.ms)
                      .scaleXY(begin: 0.5, end: 1, curve: Curves.easeOutBack),
                  Text(
                    strings.wrappedMinutes(data.totalMinutesListened),
                    style: locale.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonPurple,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                ],
                const SizedBox(height: 32),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.neonPurple.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    data.basedOnPlays
                        ? strings.wrappedTotalTracks(data.totalTracksPlayed)
                        : strings.wrappedDiscoveredSongs(data.totalTracksPlayed),
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
                const SizedBox(height: 12),
                Text(
                  strings.wrappedUniqueCount(
                      data.uniqueTracksCount, data.uniqueArtistsCount),
                  style: locale.getTextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: FAVORITE HOUR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FavoriteHourSlide extends StatelessWidget {
  final WrappedData data;
  final LocaleProvider locale;
  final dynamic strings;
  const _FavoriteHourSlide(
      {required this.data, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        data.hourDistribution.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A0A), Color(0xFF0A0A14), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.wrappedFavoriteHour,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neonGreen,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 2,
                color: AppColors.neonGreen,
              ).animate().scaleX(begin: 0, end: 1, duration: 600.ms, delay: 200.ms, alignment: Alignment.centerLeft),
              const SizedBox(height: 32),
              // Big hour display
              Center(
                child: Text(
                  strings.wrappedHourLabel(data.favoriteHour),
                  style: locale.getTextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.neonGreen,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms, delay: 400.ms)
                  .scaleXY(begin: 0.7, end: 1, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              // Hour distribution chart
              Expanded(
                child: _buildHourChart(maxCount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourChart(int maxCount) {
    if (maxCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(24, (hour) {
                  final count = data.hourDistribution[hour] ?? 0;
                  final ratio = count / maxCount;
                  final isFav = hour == data.favoriteHour;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: ratio.clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isFav
                                      ? AppColors.neonGreen
                                      : AppColors.neonGreen
                                          .withValues(alpha: 0.15 + ratio * 0.35),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2)),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .scaleY(
                                  begin: 0,
                                  end: 1,
                                  duration: 600.ms,
                                  delay: Duration(
                                      milliseconds: 600 + hour * 30),
                                  alignment: Alignment.bottomCenter),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0h',
                    style: locale.getTextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('6h',
                    style: locale.getTextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('12h',
                    style: locale.getTextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('18h',
                    style: locale.getTextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
                Text('24h',
                    style: locale.getTextStyle(
                        fontSize: 9, color: AppColors.textMuted)),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: FUN FACTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FunFactsSlide extends StatelessWidget {
  final WrappedData data;
  final LocaleProvider locale;
  final dynamic strings;
  const _FunFactsSlide(
      {required this.data, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1A0A14), Color(0xFF0A0A1A), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.wrappedFunFacts,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sakura,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 4),
              Container(
                width: 40,
                height: 2,
                color: AppColors.sakura,
              ).animate().scaleX(begin: 0, end: 1, duration: 600.ms, delay: 200.ms, alignment: Alignment.centerLeft),
              const SizedBox(height: 24),
              ...data.funFacts.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final fact = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFactCard(fact, i),
                )
                    .animate()
                    .fadeIn(
                        duration: 500.ms,
                        delay: Duration(milliseconds: 400 + i * 200))
                    .slideY(begin: 0.1, end: 0);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactCard(WrappedFunFact fact, int index) {
    final text = _factToText(fact);
    final colors = [
      AppColors.sakura,
      AppColors.neonCyan,
      AppColors.neonPurple,
      AppColors.neonGreen,
      AppColors.accent,
    ];
    final color = colors[index % colors.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: locale.getTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _factToText(WrappedFunFact fact) {
    final d = fact.data;
    final count = (d['count'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse('${d['date'] ?? ''}');
    final dateLabel = date == null ? '${d['date'] ?? ''}' : strings.longDate(date);
    final plays = data.basedOnPlays;
    return switch (fact.key) {
      'late_night_song' => strings.wrappedFactLateNight(
          d['title'] ?? '', d['artistName'] ?? ''),
      'marathon_day' => plays
          ? strings.wrappedFactMarathon(dateLabel, count)
          : strings.wrappedFactMarathonDiscovery(dateLabel, count),
      'loyal_artist' => plays
          ? strings.wrappedFactLoyal(d['name'] ?? '', count)
          : strings.wrappedFactLoyalDiscovery(d['name'] ?? '', count),
      'dawn_listener' => strings.wrappedFactDawn(
          (d['count'] as num?)?.toInt() ?? 0),
      'one_hit_wonder' => strings.wrappedFactOneHit(
          d['title'] ?? '', d['artistName'] ?? '', (d['count'] as num?)?.toInt() ?? 0),
      'night_owl' => strings.wrappedFactNightOwl(
          (d['percentage'] as num?)?.toInt() ?? 0),
      'early_bird' => strings.wrappedFactEarlyBird(
          (d['percentage'] as num?)?.toInt() ?? 0),
      'weekend_warrior' => strings.wrappedFactWeekend(
          (d['weekendAvg'] as num?)?.toInt() ?? 0,
          (d['weekdayAvg'] as num?)?.toInt() ?? 0),
      _ => '',
    };
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLIDE: OUTRO
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _OutroSlide extends StatelessWidget {
  final int year;
  final LocaleProvider locale;
  final dynamic strings;
  const _OutroSlide(
      {required this.year, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0505), Color(0xFF0A0A14), Colors.black],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5), width: 2),
                ),
                child: Center(
                  child: Text(
                    '月',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scaleXY(begin: 0.5, end: 1, curve: Curves.easeOutBack),
              const SizedBox(height: 28),
              Text(
                strings.wrappedOutro,
                style: locale.getTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBright,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 400.ms),
              const SizedBox(height: 12),
              Text(
                strings.wrappedOutroSubtitle,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 700.ms),
              const SizedBox(height: 40),
              Text(
                '◈ TSUKI WRAPPED $year // END.TRANSMISSION',
                style: GoogleFonts.notoSansJp(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent.withValues(alpha: 0.4),
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}
