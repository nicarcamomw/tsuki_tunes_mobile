import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_language.dart';
import '../models/synced_lyrics.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/locale_provider.dart';
import '../services/lyrics_service.dart';
import '../services/translation_service.dart';

/// Lyrics of the playing track, shared by the card under the player and the
/// full-screen view, so they load once and a translation carries over.
class LyricsController extends ChangeNotifier {
  String? _trackId;
  SyncedLyrics? _lyrics;
  bool _loading = false;
  List<String>? _translated;
  bool _showTranslation = false;
  bool _translating = false;
  bool _disposed = false;

  String? get trackId => _trackId;
  SyncedLyrics? get lyrics => _lyrics;
  bool get loading => _loading;
  bool get translating => _translating;

  /// Translated lines, when the translation is switched on.
  List<String>? get translation => _showTranslation ? _translated : null;

  bool get hasText =>
      _lyrics != null &&
      !_lyrics!.isInstrumental &&
      _lyrics!.plainLyrics.trim().isNotEmpty;

  /// One entry per displayed line, in order.
  List<String> get lineTexts => _lyrics == null
      ? const []
      : _lyrics!.isSynced
          ? [for (final l in _lyrics!.lines) l.text]
          : _lyrics!.plainLyrics.split('\n');

  /// Loads [track]'s lyrics unless they are the ones already loaded.
  void ensureFor(Track track) {
    if (_trackId != track.id) _load(track);
  }

  void retry(Track track) => _load(track);

  Future<void> _load(Track track) async {
    _trackId = track.id;
    _lyrics = null;
    _loading = true;
    _translated = null;
    _showTranslation = false;
    _translating = false;
    _notify();
    SyncedLyrics? result;
    try {
      result = await LyricsService().getLyrics(track.title, track.artistName);
    } catch (e) {
      debugPrint('[Lyrics] load failed: $e');
    }
    if (_disposed || _trackId != track.id) return;
    _lyrics = result;
    _loading = false;
    _notify();
  }

  /// Switches the translation on or off. [confirmDownload] is asked first
  /// when the translation models still have to be downloaded. Returns false
  /// when translating failed.
  Future<bool> toggleTranslation(
    AppLanguage target, {
    required Future<bool> Function(int models) confirmDownload,
  }) async {
    if (_showTranslation) {
      _showTranslation = false;
      _notify();
      return true;
    }
    if (_translated != null) {
      _showTranslation = true;
      _notify();
      return true;
    }
    final trackId = _trackId;
    if (trackId == null || !hasText) return true;

    final service = TranslationService();
    try {
      final needed = await service.requiredModels(targetLang: target);
      if (needed.isNotEmpty) {
        if (!await confirmDownload(needed.length)) return true;
        _translating = true;
        _notify();
        await service.downloadRequiredModels(targetLang: target);
      }
      _translating = true;
      _notify();
      final lines = await service.translateLines(
        lines: lineTexts,
        trackId: trackId,
        targetLang: target,
      );
      if (_disposed || _trackId != trackId) return true;
      _translated = lines;
      _showTranslation = true;
      return true;
    } catch (e) {
      debugPrint('[Lyrics] translation failed: $e');
      return false;
    } finally {
      if (!_disposed && _trackId == trackId) {
        _translating = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A deep color taken from the album cover, for lyrics backgrounds that
/// match the record (white text stays readable on it).
class AlbumTint {
  AlbumTint._();

  static const Color fallback = Color(0xFF4A0E16);
  static final Map<String, Color> _cache = {};

  static Color? cached(String url) => _cache[url];

  static Future<Color> of(String url) async {
    if (url.isEmpty) return fallback;
    final hit = _cache[url];
    if (hit != null) return hit;
    try {
      final image = await _decodeSmall(url);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      final color =
          data == null ? fallback : fromPixels(data.buffer.asUint8List());
      return _cache[url] = color;
    } catch (e) {
      debugPrint('[AlbumTint] $e');
      return fallback;
    }
  }

  static Future<ui.Image> _decodeSmall(String url) {
    final completer = Completer<ui.Image>();
    final stream = ResizeImage(
      CachedNetworkImageProvider(url),
      width: 24,
      height: 24,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.completeError(error);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(const Duration(seconds: 8));
  }

  /// The cover's most vivid color, darkened enough for white text. Grey or
  /// near-black covers fall back to Tsuki's crimson.
  @visibleForTesting
  static Color fromPixels(Uint8List rgba) {
    double r = 0, g = 0, b = 0, weight = 0;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      final hsv = HSVColor.fromColor(
          Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]));
      if (hsv.value < 0.12) continue;
      // Favour saturated, reasonably bright pixels: the cover's accent.
      final w = math.pow(hsv.saturation * hsv.value, 2).toDouble();
      r += rgba[i] * w;
      g += rgba[i + 1] * w;
      b += rgba[i + 2] * w;
      weight += w;
    }
    if (weight < 0.5) return fallback;
    final vivid =
        Color.fromARGB(255, r ~/ weight, g ~/ weight, b ~/ weight);
    final hsl = HSLColor.fromColor(vivid);
    if (hsl.saturation < 0.15) return fallback;
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.85))
        .withLightness(0.24)
        .toColor();
  }
}

/// Synced lyrics that follow the song: the line being sung is bright, sung
/// lines fade back, upcoming ones wait dimmed. [interactive] lets the user
/// scroll (auto-follow pauses a moment) and tap a line to jump there.
class LyricsLines extends StatefulWidget {
  final LyricsController controller;
  final bool compact;
  final bool interactive;

  const LyricsLines({
    super.key,
    required this.controller,
    this.compact = false,
    this.interactive = false,
  });

  @override
  State<LyricsLines> createState() => _LyricsLinesState();
}

class _LyricsLinesState extends State<LyricsLines> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = [];
  int _lastActive = -2;
  String? _lastTrackId;
  bool _userScrolling = false;
  Timer? _resume;

  double get _alignment => widget.compact ? 0.3 : 0.38;

  @override
  void dispose() {
    _resume?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int index, {bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      double target = 0;
      if (index >= 0 && index < _keys.length) {
        final box = _keys[index].currentContext?.findRenderObject();
        if (box == null) return;
        // Reveal within this list only: Scrollable.ensureVisible would also
        // scroll the player page the card sits in.
        target = RenderAbstractViewport.of(box)
            .getOffsetToReveal(box, _alignment)
            .offset;
      }
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _pauseFollow() {
    if (!widget.interactive) return;
    _resume?.cancel();
    if (!_userScrolling) setState(() => _userScrolling = true);
    _resume = Timer(const Duration(seconds: 4), _resumeFollow);
  }

  void _resumeFollow() {
    _resume?.cancel();
    if (!mounted) return;
    setState(() => _userScrolling = false);
    _follow(_lastActive);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final lyrics = widget.controller.lyrics;
        if (lyrics == null || !widget.controller.hasText) {
          return const SizedBox.shrink();
        }
        if (_lastTrackId != widget.controller.trackId) {
          _lastTrackId = widget.controller.trackId;
          _lastActive = -2;
          _userScrolling = false;
        }
        if (!lyrics.isSynced) return _buildLines(lyrics, -1, synced: false);
        return Selector<AudioProvider, int>(
          selector: (_, a) => lyrics.activeIndexAt(a.position),
          builder: (context, active, _) {
            if (active != _lastActive) {
              final first = _lastActive == -2;
              _lastActive = active;
              if (!_userScrolling) _follow(active, jump: first);
            }
            return _buildLines(lyrics, active, synced: true);
          },
        );
      },
    );
  }

  Widget _buildLines(SyncedLyrics lyrics, int active, {required bool synced}) {
    final locale = context.read<LocaleProvider>();
    final texts = widget.controller.lineTexts;
    final translation = widget.controller.translation;
    while (_keys.length < texts.length) {
      _keys.add(GlobalKey());
    }
    final fontSize = widget.compact ? 19.0 : 25.0;
    final base = locale.getTextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.28,
      letterSpacing: -0.2,
    );

    final list = SingleChildScrollView(
      controller: _scroll,
      physics: widget.interactive
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: widget.compact
          ? const EdgeInsets.fromLTRB(20, 6, 20, 160)
          : EdgeInsets.fromLTRB(
              26, 24, 26, MediaQuery.sizeOf(context).height * 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < texts.length; i++)
            _LyricLine(
              key: _keys[i],
              text: texts[i],
              translation: translation != null && i < translation.length
                  ? translation[i]
                  : null,
              state: !synced
                  ? _LineState.plain
                  : i == active
                      ? _LineState.current
                      : i < active
                          ? _LineState.sung
                          : _LineState.upcoming,
              base: base,
              compact: widget.compact,
              onTap: widget.interactive && synced
                  ? () {
                      HapticFeedback.selectionClick();
                      context.read<AudioProvider>().seek(lyrics.lines[i].time);
                      _resumeFollow();
                    }
                  : null,
            ),
        ],
      ),
    );

    if (!widget.interactive) return list;
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.direction != ScrollDirection.idle) _pauseFollow();
            return false;
          },
          child: list,
        ),
        if (_userScrolling && synced && active >= 0)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: _FollowPill(onTap: _resumeFollow)),
          ),
      ],
    );
  }
}

enum _LineState { upcoming, current, sung, plain }

class _LyricLine extends StatelessWidget {
  final String text;
  final String? translation;
  final _LineState state;
  final TextStyle base;
  final bool compact;
  final VoidCallback? onTap;

  const _LyricLine({
    super.key,
    required this.text,
    required this.translation,
    required this.state,
    required this.base,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = state == _LineState.current;
    final color = switch (state) {
      _LineState.current => Colors.white,
      _LineState.sung => Colors.white.withValues(alpha: 0.6),
      _LineState.upcoming => Colors.white.withValues(alpha: 0.3),
      _LineState.plain => Colors.white.withValues(alpha: 0.88),
    };
    final style = base.copyWith(
      color: color,
      shadows: current
          ? [
              Shadow(
                color: AppColors.accent.withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ]
          : const [],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 5 : 9),
        child: AnimatedScale(
          scale: current ? 1.03 : 1.0,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                style: style,
                child: Text(text),
              ),
              if (translation != null && translation!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    translation!,
                    style: base.copyWith(
                      fontSize: (base.fontSize ?? 20) * 0.62,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: color.withValues(alpha: color.a * 0.75),
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

class _FollowPill extends StatelessWidget {
  final VoidCallback onTap;
  const _FollowPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 13, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              locale.strings.lyricsFollowing,
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Background shared by the card and the full view: the album's color
/// fading into the app's night, with faint scanlines.
class LyricsBackdrop extends StatelessWidget {
  final Color tint;
  final BorderRadius? borderRadius;
  final Widget child;

  const LyricsBackdrop({
    super.key,
    required this.tint,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tint, Colors.white, 0.04)!,
            tint,
            Color.lerp(tint, AppColors.bgDeep, 0.55)!,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CustomPaint(
          foregroundPainter: const _ScanlinePainter(),
          child: child,
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}

/// Fades the top and bottom edges of a scrolling list.
class LyricsEdgeFade extends StatelessWidget {
  final Widget child;
  final double top;
  final double bottom;

  const LyricsEdgeFade({
    super.key,
    required this.child,
    this.top = 0.08,
    this.bottom = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, top, 1 - bottom, 1],
      ).createShader(rect),
      child: child,
    );
  }
}

/// The lyrics card under the player: a live preview of the synced lyrics
/// that opens the full view.
class LyricsCard extends StatelessWidget {
  final LyricsController controller;
  final Track track;
  final Color tint;
  final VoidCallback onOpen;

  const LyricsCard({
    super.key,
    required this.controller,
    required this.track,
    required this.tint,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lyrics = controller.lyrics;
        final hasText = controller.hasText;
        final radius = BorderRadius.circular(18);

        Widget body;
        if (controller.loading) {
          body = _CardMessage(text: strings.lyricsLoading, loading: true);
        } else if (lyrics == null) {
          body = _CardMessage(
            text: strings.noLyricsFound,
            actionLabel: strings.lyricsRetry,
            onAction: () => controller.retry(track),
          );
        } else if (!hasText) {
          body = _CardMessage(text: strings.instrumentalTrack, icon: Icons.graphic_eq);
        } else {
          body = LyricsEdgeFade(
            top: 0.04,
            bottom: 0.3,
            child: AbsorbPointer(
              child: LyricsLines(controller: controller, compact: true),
            ),
          );
        }

        return Semantics(
          button: hasText,
          label: strings.a11yLyrics,
          child: GestureDetector(
            onTap: hasText ? onOpen : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LyricsBackdrop(
                tint: tint,
                borderRadius: radius,
                child: SizedBox(
                  height: hasText ? 360 : 150,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.lyricsCardTitle,
                                    style: locale.getTextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lyrics?.isSynced == true
                                        ? '歌詞 // LIVE.SYNC'
                                        : '歌詞 // LYRICS',
                                    style: locale.getTextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent
                                          .withValues(alpha: 0.9),
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasText)
                              _RoundIcon(
                                icon: Icons.open_in_full,
                                tooltip: strings.a11yLyrics,
                                onTap: onOpen,
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardMessage extends StatelessWidget {
  final String text;
  final bool loading;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CardMessage({
    required this.text,
    this.loading = false,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>();
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6, color: Colors.white70),
            )
          else if (icon != null)
            Icon(icon, size: 18, color: Colors.white70),
          if (loading || icon != null) const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: locale.getTextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  actionLabel!,
                  style: locale.getTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
