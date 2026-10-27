import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/synced_lyrics.dart';
import '../../models/track.dart';
import '../../providers/audio_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/lyrics_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/tap_scale.dart';

class PlayerLyricsView extends StatefulWidget {
  final Track track;

  const PlayerLyricsView({super.key, required this.track});

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  SyncedLyrics? _lyrics;
  bool _isLoadingLyrics = false;
  String? _lastLoadedTrackId;
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastActiveLyricIndex = -1;
  bool _userInteracting = false;
  Timer? _resumeAutoScrollTimer;
  final Map<int, GlobalKey> _lineKeys = {};

  bool _showTranslation = false;
  bool _isTranslating = false;
  bool _isDownloadingModel = false;
  List<String>? _translatedLines;
  String? _lastTranslatedTrackId;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _resumeAutoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final audio = context.read<AudioProvider>();
    final track = widget.track;

    if (_lastLoadedTrackId != track.id && !_isLoadingLyrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLyricsForTrack(track);
      });
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgMid.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderGlow.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lyrics,
                            color: AppColors.accent, size: 16, semanticLabel: locale.strings.a11yLyrics),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            locale.strings.lyrics,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_lyrics?.isSynced == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            locale.strings.syncedTapToSeek,
                            style: locale.getTextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      if (_lyrics != null && !_lyrics!.isInstrumental && _lyrics!.plainLyrics.isNotEmpty)
                        _buildTranslateButton(locale, track),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            if (_showTranslation && _translatedLines != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                color: AppColors.accent.withValues(alpha: 0.08),
                child: Text(
                  locale.strings.translatedTag,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent.withValues(alpha: 0.7),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            Expanded(
              child: Consumer<AudioProvider>(
                builder: (context, liveAudio, _) {
                  return _buildLyricsContent(liveAudio, locale, track);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(LocaleProvider locale, Track track) {
    final strings = locale.strings;
    final isActive = _showTranslation && _translatedLines != null;
    final isLoading = _isTranslating || _isDownloadingModel;

    return TapScale(
      semanticLabel: isActive ? strings.a11yHideTranslation : strings.a11yTranslate,
      onTap: isLoading ? null : () => _onTranslateTap(locale, track),
      scaleDown: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.bgHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.border,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.accent,
                ),
              )
            : Text(
                strings.translateButton,
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
      ),
    );
  }

  Future<void> _onTranslateTap(LocaleProvider locale, Track track) async {
    if (_showTranslation && _translatedLines != null) {
      setState(() => _showTranslation = false);
      return;
    }

    if (_lastTranslatedTrackId == track.id && _translatedLines != null) {
      setState(() => _showTranslation = true);
      return;
    }

    final service = TranslationService();
    final targetLang = locale.currentLanguage;

    final needed = await service.requiredModels(targetLang: targetLang);
    if (needed.isNotEmpty && mounted) {
      final confirmed = await _showDownloadDialog(locale, needed.length);
      if (!confirmed || !mounted) return;

      setState(() => _isDownloadingModel = true);
      try {
        await service.downloadRequiredModels(targetLang: targetLang);
      } catch (e) {
        debugPrint('[Translation] Model download failed: $e');
        if (mounted) {
          setState(() => _isDownloadingModel = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.strings.translationError),
              backgroundColor: AppColors.bgCard,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _isDownloadingModel = false);
    }

    setState(() => _isTranslating = true);

    try {
      final lines = _lyrics!.isSynced
          ? _lyrics!.lines.map((l) => l.text).toList()
          : _lyrics!.plainLyrics.split('\n');

      final translated = await service.translateLines(
        lines: lines,
        trackId: track.id,
        targetLang: targetLang,
      );

      if (mounted && _lastLoadedTrackId == track.id) {
        setState(() {
          _translatedLines = translated;
          _lastTranslatedTrackId = track.id;
          _showTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('[Translation] Error: $e');
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.strings.translationError),
            backgroundColor: AppColors.bgCard,
          ),
        );
      }
    }
  }

  Future<bool> _showDownloadDialog(LocaleProvider locale, int modelCount) async {
    final strings = locale.strings;
    final size = (modelCount * 30).toString();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderGlow.withValues(alpha: 0.5)),
            ),
            title: Row(
              children: [
                const Icon(Icons.download_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.downloadModelTitle,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              strings.downloadModelDesc(size),
              style: locale.getTextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  strings.cancel,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  strings.downloadModelConfirm,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadLyricsForTrack(Track track) async {
    if (_lastLoadedTrackId == track.id && _lyrics != null) return;
    _lastLoadedTrackId = track.id;
    _lineKeys.clear();
    _lastActiveLyricIndex = -1;
    _userInteracting = false;
    _resumeAutoScrollTimer?.cancel();

    setState(() {
      _isLoadingLyrics = true;
      _lyrics = null;
      _showTranslation = false;
      _translatedLines = null;
      _isTranslating = false;
      _isDownloadingModel = false;
    });

    try {
      final lyrics =
          await LyricsService().getLyrics(track.title, track.artistName);
      if (!mounted || _lastLoadedTrackId != track.id) return;
      setState(() {
        _lyrics = lyrics;
        _isLoadingLyrics = false;
        _lastActiveLyricIndex = -1;
        _lineKeys.clear();
      });
    } catch (e) {
      if (mounted && _lastLoadedTrackId == track.id) {
        setState(() {
          _lyrics = null;
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Widget _buildLyricsContent(AudioProvider audio, LocaleProvider locale, Track track) {
    final strings = locale.strings;
    if (_isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              locale.strings.lyricsLoading,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subtitles_off_outlined,
                color: AppColors.textMuted, size: 36, semanticLabel: strings.a11yNoLyrics),
            const SizedBox(height: 10),
            Text(
              locale.strings.noLyricsFound,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: locale.strings.a11yRetryLyrics,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _lastLoadedTrackId = null;
                _loadLyricsForTrack(track);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.bgHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14, color: AppColors.accent, semanticLabel: strings.a11yRetryLyrics),
                    const SizedBox(width: 6),
                    Text(
                      strings.lyricsRetry,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      );
    }

    if (_lyrics!.isInstrumental) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: AppColors.accent, size: 40, semanticLabel: strings.a11yVisualizer),
            const SizedBox(height: 12),
            Text(
              locale.strings.instrumentalTrack,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics!.isSynced && _lyrics!.lines.isNotEmpty) {
      return _buildSyncedLyrics(audio, locale, strings);
    }

    if (_showTranslation && _translatedLines != null) {
      return _buildPlainTranslatedLyrics(locale);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        _lyrics!.plainLyrics,
        textAlign: TextAlign.center,
        style: locale.getTextStyle(
          fontSize: 13,
          height: 1.8,
          color: AppColors.textPrimary.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildSyncedLyrics(AudioProvider audio, LocaleProvider locale, dynamic strings) {
    final position = audio.position;
    final activeIndex = _lyrics!.activeIndexAt(position);

    final bool isFirstScroll = _lastActiveLyricIndex == -1;
    if (activeIndex != _lastActiveLyricIndex && activeIndex >= 0) {
      _lastActiveLyricIndex = activeIndex;
      if (!_userInteracting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToActiveLine(activeIndex, immediate: isFirstScroll);
          }
        });
      }
    }

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              _userInteracting = true;
              _resumeAutoScrollTimer?.cancel();
              _resumeAutoScrollTimer =
                  Timer(const Duration(milliseconds: 3000), () {
                if (mounted) {
                  setState(() => _userInteracting = false);
                  _scrollToActiveLine(_lastActiveLyricIndex);
                }
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _lyricsScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: _lyrics!.lines.length,
            itemBuilder: (context, i) {
              final line = _lyrics!.lines[i];
              final isActive = i == activeIndex;
              final key = _lineKeys.putIfAbsent(i, () => GlobalKey());

              return GestureDetector(
                key: key,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  audio.seek(line.time);
                  _userInteracting = false;
                  _resumeAutoScrollTimer?.cancel();
                  _scrollToActiveLine(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: locale.getTextStyle(
                          fontSize: isActive ? 17 : 13,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive
                              ? AppColors.accent
                              : AppColors.textPrimary.withValues(alpha: 0.4),
                          shadows: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.7),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (_showTranslation &&
                          _translatedLines != null &&
                          i < _translatedLines!.length &&
                          _translatedLines![i].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _translatedLines![i],
                            textAlign: TextAlign.center,
                            style: locale.getTextStyle(
                              fontSize: isActive ? 13 : 11,
                              fontWeight: FontWeight.w400,
                              color: isActive
                                  ? AppColors.textPrimary.withValues(alpha: 0.7)
                                  : AppColors.textMuted.withValues(alpha: 0.5),
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_userInteracting && activeIndex >= 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _userInteracting = false);
                  _resumeAutoScrollTimer?.cancel();
                  _scrollToActiveLine(activeIndex);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync,
                          size: 13, color: AppColors.accent, semanticLabel: strings.a11ySyncingLyrics),
                      const SizedBox(width: 6),
                      Text(
                        strings.lyricsFollowing,
                        style: locale.getTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlainTranslatedLyrics(LocaleProvider locale) {
    final plainLines = _lyrics!.plainLyrics.split('\n');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          for (int i = 0; i < plainLines.length; i++) ...[
            Text(
              plainLines[i],
              textAlign: TextAlign.center,
              style: locale.getTextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.textPrimary.withValues(alpha: 0.8),
              ),
            ),
            if (i < _translatedLines!.length && _translatedLines![i].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _translatedLines![i],
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _scrollToActiveLine(int index, {bool immediate = false}) {
    if (index < 0 || _lyrics == null || index >= _lyrics!.lines.length) return;
    if (!_lyricsScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lyricsScrollController.hasClients) {
          _scrollToActiveLine(index, immediate: immediate);
        }
      });
      return;
    }

    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: immediate ? Duration.zero : const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.35,
      );
      return;
    }

    final double viewport = _lyricsScrollController.position.hasViewportDimension
        ? _lyricsScrollController.position.viewportDimension
        : 300.0;
    final double estimatedOffset = (index * 54.0 - (viewport * 0.35)).clamp(
      0.0,
      _lyricsScrollController.position.maxScrollExtent > 0
          ? _lyricsScrollController.position.maxScrollExtent
          : (index * 54.0),
    );

    if (immediate) {
      _lyricsScrollController.jumpTo(estimatedOffset);
    } else {
      _lyricsScrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final retryKey = _lineKeys[index];
      if (retryKey?.currentContext != null) {
        Scrollable.ensureVisible(
          retryKey!.currentContext!,
          duration: immediate ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: 0.35,
        );
      }
    });
  }
}
