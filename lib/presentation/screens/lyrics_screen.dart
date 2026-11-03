import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../widgets/audio_progress_selector.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/tap_scale.dart';

/// Full-screen synced lyrics over the album's color, with the song's
/// progress and play controls at the bottom.
class LyricsScreen extends ConsumerStatefulWidget {
  final LyricsController controller;

  const LyricsScreen({super.key, required this.controller});

  static Route<void> route({
    required LyricsController controller,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) =>
          LyricsScreen(controller: controller),
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {

  void _syncTrack(Track track) {
    if (widget.controller.trackId != track.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.ensureFor(track);
      });
    }
  }

  Future<bool> _confirmDownload(int models) async {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: AppColors.borderGlow.withValues(alpha: 0.5)),
            ),
            title: Text(
              strings.downloadModelTitle,
              style: locale.getTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1,
              ),
            ),
            content: Text(
              strings.downloadModelDesc('${models * 30}'),
              style: locale.getTextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.cancel,
                    style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(strings.downloadModelConfirm,
                    style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Lists the languages to translate into ("Original" first) and shows
  /// the lyrics in the one picked, under each line.
  Future<void> _chooseTranslation() async {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final messenger = ScaffoldMessenger.of(context);
    final controller = widget.controller;
    final current = controller.translatedTo;
    final suggested = current ?? await LyricsController.lastTarget() ?? locale.currentLanguage.code;
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  strings.lyricsTranslateTo,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              for (final entry in [
                MapEntry('', strings.lyricsOriginal),
                ...LyricsController.translationTargets.entries,
              ])
                ListTile(
                  dense: true,
                  title: Text(
                    entry.value,
                    style: locale.getTextStyle(fontSize: 14, color: Colors.white),
                  ),
                  trailing: (entry.key.isEmpty ? current == null : entry.key == current)
                      ? const Icon(Icons.check, color: AppColors.accent, size: 18)
                      : entry.key == suggested && current == null
                          ? const Icon(Icons.history, color: AppColors.textMuted, size: 16)
                          : null,
                  onTap: () => Navigator.pop(sheetCtx, entry.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.isEmpty) {
      controller.hideTranslation();
      return;
    }
    unawaited(LyricsController.rememberTarget(picked));
    final outcome = await controller.translateTo(picked, confirmDownload: _confirmDownload);
    final message = switch (outcome) {
      TranslationOutcome.failed => strings.translationError,
      TranslationOutcome.sameLanguage =>
        strings.lyricsSameLanguage(LyricsController.translationTargets[picked] ?? picked),
      TranslationOutcome.unknownLanguage => strings.lyricsUnknownLanguage,
      TranslationOutcome.shown || TranslationOutcome.cancelled => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.bgCard,
      ));
    }
  }

  void _share(Track track) {
    final lyrics = widget.controller.lyrics;
    final audio = ref.read(audioProvider);
    String? line;
    if (lyrics != null && lyrics.isSynced && audio.playsFullSong) {
      final i = lyrics.activeIndexAt(audio.position);
      if (i >= 0 && i < lyrics.lines.length) line = lyrics.lines[i].text;
    }
    line ??= widget.controller.lineTexts
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final quote = line.isEmpty ? '' : '"$line"\n\n';
    Share.share('$quote— ${track.title} · ${track.fullArtistName}\n🌙 Tsuki Tunes');
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final track = ref.watch(currentTrackProvider);
    if (track == null) {
      return const Scaffold(backgroundColor: AppColors.bgDeep);
    }
    _syncTrack(track);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: LyricsBackdrop(
        child: Stack(
          children: [
            // The cover, blurred into a faint glow behind the words.
            if (track.coverUrl.isNotEmpty)
              Positioned(
                top: -80,
                left: -80,
                right: -80,
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: 0.22,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  _Header(track: track, locale: locale),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.controller,
                      builder: (context, _) => _body(track, locale),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) {
                      if (!widget.controller.hasText) {
                        return const SizedBox(height: 8);
                      }
                      final translating = widget.controller.translating;
                      final translatedTo = widget.controller.translatedTo;
                      final translated = translatedTo != null;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Row(
                          children: [
                            _Chip(
                              icon: Icons.ios_share,
                              label: strings.lyricsShare,
                              onTap: () => _share(track),
                            ),
                            const SizedBox(width: 8),
                            _Chip(
                              icon: Icons.translate,
                              label: translated
                                  ? LyricsController.translationTargets[translatedTo] ??
                                      strings.lyricsTranslate
                                  : strings.lyricsTranslate,
                              active: translated,
                              loading: translating,
                              onTap: translating ? null : _chooseTranslation,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _Progress(locale: locale),
                  const _Controls(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Track track, LocaleProvider locale) {
    final strings = locale.strings;
    final c = widget.controller;
    if (c.loading) {
      return _Message(text: strings.lyricsLoading, loading: true);
    }
    if (c.lyrics == null) {
      return _Message(
        text: strings.noLyricsFound,
        icon: Icons.subtitles_off_outlined,
        actionLabel: strings.lyricsRetry,
        onAction: () => c.retry(track),
      );
    }
    if (!c.hasText) {
      return _Message(text: strings.instrumentalTrack, icon: Icons.graphic_eq);
    }
    return LyricsEdgeFade(
      top: 0.06,
      bottom: 0.16,
      child: LyricsLines(controller: c, interactive: true),
    );
  }
}

class _Header extends StatelessWidget {
  final Track track;
  final LocaleProvider locale;
  const _Header({required this.track, required this.locale});

  @override
  Widget build(BuildContext context) {
    // Swiping down on the header closes, like the player.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: locale.strings.a11yCollapsePlayer,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 30, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.fullArtistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '歌詞 // LIVE.SYNC',
                    style: locale.getTextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent.withValues(alpha: 0.9),
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _Chip extends ConsumerWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;

  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    return TapScale(
      semanticLabel: label,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      scaleDown: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white),
              )
            else
              Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  final LocaleProvider locale;
  const _Progress({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AudioProgressSelector<(Duration, Duration)>(
      selector: (a) => (a.position, a.duration),
      builder: (context, p) => _bar(context, p.$1, p.$2),
    );
  }

  Widget _bar(BuildContext context, Duration position, Duration duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ProgressBar(
        progress: position,
        total: duration,
        onSeek: context.readState(audioProvider).seek,
        barHeight: 4,
        progressBarColor: Colors.white,
        baseBarColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: Colors.white,
        thumbGlowColor: AppColors.accent.withValues(alpha: 0.5),
        thumbRadius: 6,
        timeLabelTextStyle: locale.getTextStyle(
          fontSize: 11,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.read(stringsProvider);
    final audio = ref.read(audioProvider);
    final (isPlaying, isBuffering) = ref.watch(audioProvider.select(
        (a) => (a.isPlaying, a.isBuffering)));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TapScale(
          semanticLabel: strings.a11yPrevious,
          onTap: audio.previous,
          scaleDown: 0.85,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.skip_previous, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(width: 18),
        TapScale(
          semanticLabel: isPlaying ? strings.a11yPause : strings.a11yPlay,
          onTap: isBuffering ? null : audio.togglePlay,
          scaleDown: 0.88,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: isBuffering
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36, color: Colors.white),
          ),
        ),
        const SizedBox(width: 18),
        TapScale(
          semanticLabel: strings.a11yNext,
          onTap: audio.next,
          scaleDown: 0.85,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.skip_next, size: 32, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Message extends ConsumerWidget {
  final String text;
  final bool loading;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            )
          else if (icon != null)
            Icon(icon, size: 38, color: Colors.white70),
          const SizedBox(height: 14),
          Text(
            text,
            style: locale.getTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                shape: const StadiumBorder(),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
