import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/synced_lyrics.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/lyrics_controller.dart';
import 'audio_progress_selector.dart';

export '../state/lyrics_controller.dart';

/// Synced lyrics that follow the song: the line being sung is bright, sung
/// lines fade back, upcoming ones wait dimmed. [interactive] lets the user
/// scroll (auto-follow pauses a moment) and tap a line to jump there.
class LyricsLines extends ConsumerStatefulWidget {
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
  ConsumerState<LyricsLines> createState() => _LyricsLinesState();
}

class _LyricsLinesState extends ConsumerState<LyricsLines> {
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
        // A preview's position isn't the song's: show the words unsynced.
        final fullSong = ref.watch(audioProvider.select((a) => a.playsFullSong));
        if (!fullSong) {
          return _buildLines(lyrics, -1, synced: false, previewNote: true);
        }
        return AudioProgressSelector<(int, bool)>(
          selector: (a) => (lyrics.activeIndexAt(a.position), lyrics.inBreakAt(a.position)),
          builder: (context, at) {
            final (active, inBreak) = at;
            if (active != _lastActive) {
              final first = _lastActive == -2;
              _lastActive = active;
              if (!_userScrolling) _follow(active, jump: first);
            }
            return _buildLines(lyrics, active, synced: true, inBreak: inBreak);
          },
        );
      },
    );
  }

  /// [inBreak]: an instrumental break, so no line is the current one.
  /// [previewNote]: synced lyrics shown unsynced under a preview, said so
  /// at the top.
  Widget _buildLines(SyncedLyrics lyrics, int active,
      {required bool synced, bool inBreak = false, bool previewNote = false}) {
    final locale = ref.read(localeProvider);
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
          if (previewNote)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                locale.strings.lyricsPreviewNote,
                style: locale
                    .getTextStyle(
                      fontSize: widget.compact ? 10 : 12,
                      color: AppColors.textMuted,
                    )
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          for (var i = 0; i < texts.length; i++)
            _LyricLine(
              key: _keys[i],
              text: texts[i],
              translation: translation != null && i < translation.length
                  ? translation[i]
                  : null,
              state: !synced
                  ? _LineState.plain
                  : i == active && !inBreak
                      ? _LineState.current
                      : i <= active
                          ? _LineState.sung
                          : _LineState.upcoming,
              base: base,
              compact: widget.compact,
              onTap: widget.interactive && synced
                  ? () {
                      HapticFeedback.selectionClick();
                      ref.read(audioProvider).seek(lyrics.lines[i].time);
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
    // Neon red: the line being sung glows, the rest stay dimmer.
    final color = switch (state) {
      _LineState.current => const Color(0xFFFF4D4D),
      _LineState.sung => AppColors.accent.withValues(alpha: 0.55),
      _LineState.upcoming => AppColors.accent.withValues(alpha: 0.32),
      _LineState.plain => const Color(0xFFFF4D4D).withValues(alpha: 0.9),
    };
    final style = base.copyWith(
      color: color,
      shadows: [
        Shadow(
          color: AppColors.accent.withValues(alpha: current ? 0.9 : 0.35),
          blurRadius: current ? 16 : 8,
        ),
        if (current)
          Shadow(
            color: AppColors.accent.withValues(alpha: 0.5),
            blurRadius: 32,
          ),
      ],
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

class _FollowPill extends ConsumerWidget {
  final VoidCallback onTap;
  const _FollowPill({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
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

/// Background shared by the card and the full view: lead grey fading into
/// the app's night, with faint scanlines, under neon red words.
class LyricsBackdrop extends StatelessWidget {
  final BorderRadius? borderRadius;
  final Widget child;

  const LyricsBackdrop({
    super.key,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF353A47), Color(0xFF2A2E39), AppColors.bgMid],
          stops: [0, 0.45, 1],
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
class LyricsCard extends ConsumerWidget {
  final LyricsController controller;
  final Track track;
  final VoidCallback onOpen;

  const LyricsCard({
    super.key,
    required this.controller,
    required this.track,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
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
                  color: AppColors.accent.withValues(alpha: 0.85),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LyricsBackdrop(
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
                                    lyrics?.isSynced == true &&
                                            ref.watch(audioProvider
                                                .select((a) => a.playsFullSong))
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

class _CardMessage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
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
