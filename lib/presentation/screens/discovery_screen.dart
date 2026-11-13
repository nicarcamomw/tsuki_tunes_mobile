import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants/app_colors.dart';
import '../../core/logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/track.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/discovery_controller.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';

final _log = Log.named('DiscoveryScreen');

/// A deck per visit to the screen.
final discoveryProvider = ChangeNotifierProvider.autoDispose<DiscoveryController>((ref) {
  final library = ref.read(libraryProvider);
  final c = DiscoveryController(
    catalog: ref.read(musicCatalogProvider),
    knownArtists: () => [...library.followedArtists, ...library.favoriteArtists],
    topArtistNames: () {
      final count = <String, int>{};
      for (final t in library.listenedTracks) {
        for (final a in t.artists.isEmpty ? [t.artistName] : t.artists) {
          if (a.trim().isEmpty) continue;
          count[a] = (count[a] ?? 0) + 1;
        }
      }
      return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
    },
    isListened: library.isTrackListened,
  );
  unawaited(c.start());
  return c;
});

/// Discovery mode: one new song at a time, its preview playing; swipe right
/// (or the heart) saves it to the Discoveries playlist, left passes.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  // Its own player: the main queue is left as it was.
  final AudioPlayer _preview = AudioPlayer();
  String? _playingId;
  bool _paused = false;
  double _drag = 0;
  bool _flying = false;

  @override
  void initState() {
    super.initState();
    // The main player pauses while songs are being discovered.
    final audio = ref.read(audioProvider);
    if (audio.isPlaying) unawaited(audio.togglePlay());
    unawaited(_preview.setLoopMode(LoopMode.one));
  }

  @override
  void dispose() {
    unawaited(_preview.dispose());
    super.dispose();
  }

  Future<void> _play(Track t) async {
    if (_playingId == t.id) return;
    _playingId = t.id;
    _paused = false;
    try {
      await _preview.setUrl(t.previewUrl);
      if (_playingId == t.id && !_paused) await _preview.play();
    } catch (e) {
      _log.warning('preview failed: $e');
    }
  }

  Future<void> _togglePause() async {
    Haptics.selection();
    setState(() => _paused = !_paused);
    if (_paused) {
      await _preview.pause();
    } else {
      await _preview.play();
    }
  }

  Future<void> _answer(DiscoveryCard card, {required bool liked}) async {
    if (_flying) return;
    liked ? Haptics.confirm() : Haptics.selection();
    setState(() {
      _flying = true;
      _drag = liked ? 600 : -600;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    final deck = ref.read(discoveryProvider);
    deck.answer(card, liked: liked);
    setState(() {
      _flying = false;
      _drag = 0;
    });
    if (liked) unawaited(_save(card.track));
  }

  /// Into the Discoveries playlist (made the first time).
  Future<void> _save(Track track) async {
    final playlists = ref.read(playlistProvider);
    final name = ref.read(localeProvider).strings.discoveryPlaylist;
    final existing = playlists.playlists.where((p) => p.name == name).firstOrNull;
    if (existing == null) {
      await playlists.createPlaylist(name, tracks: [track]);
    } else if (!existing.tracks.any((t) => t.id == track.id)) {
      await playlists.addTrackToPlaylist(existing.id, track);
    }
  }

  void _openSaved() {
    final name = ref.read(localeProvider).strings.discoveryPlaylist;
    final p = ref.read(playlistProvider).playlists.where((p) => p.name == name).firstOrNull;
    if (p != null) PlaylistRoute(id: p.id).push<void>(context);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final deck = ref.watch(discoveryProvider);
    final cards = deck.cards;
    final top = cards.isEmpty ? null : cards.first;
    if (top != null && top.track.id != _playingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_play(top.track));
      });
    }
    if (top == null && _playingId != null) {
      _playingId = null;
      unawaited(_preview.stop());
    }

    Widget body;
    if (top == null && (deck.loading || !deck.exhausted)) {
      body = _CardSkeleton(label: strings.discoveryLoading);
    } else if (top == null) {
      body = _Message(
        locale: locale,
        icon: Icons.wifi_off_rounded,
        text: strings.discoveryEmpty,
        action: strings.discoveryRetry,
        onAction: deck.retry,
      );
    } else {
      final next = cards.length > 1 ? cards[1] : null;
      final progress = (_drag / 120).clamp(-1.0, 1.0);
      body = Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (next != null)
                    Transform.scale(
                      scale: 0.92 + 0.06 * progress.abs(),
                      child: Opacity(opacity: 0.6, child: _SongCard(card: next, locale: locale)),
                    ),
                  GestureDetector(
                    onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx),
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (_drag > 110 || v > 900) {
                        unawaited(_answer(top, liked: true));
                      } else if (_drag < -110 || v < -900) {
                        unawaited(_answer(top, liked: false));
                      } else {
                        setState(() => _drag = 0);
                      }
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: _flying || _drag == 0 ? 220 : 0),
                      curve: Curves.easeOut,
                      transform: Matrix4.identity()
                        ..translateByDouble(_drag, 0, 0, 1)
                        ..rotateZ(_drag / 900 * math.pi / 6),
                      transformAlignment: Alignment.bottomCenter,
                      child: Stack(
                        children: [
                          _SongCard(card: top, locale: locale),
                          // What letting go does, as it's being dragged.
                          if (progress.abs() > 0.15)
                            Positioned(
                              top: 24,
                              left: progress > 0 ? 20 : null,
                              right: progress < 0 ? 20 : null,
                              child: Opacity(
                                opacity: progress.abs(),
                                child: _Stamp(
                                  text: progress > 0 ? strings.discoverySave : strings.discoveryPass,
                                  color: progress > 0 ? AppColors.success : AppColors.accent,
                                  locale: locale,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  icon: Icons.close_rounded,
                  color: AppColors.accent,
                  label: strings.discoveryPass,
                  onTap: () => _answer(top, liked: false),
                ),
                _RoundButton(
                  icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppColors.textSecondary,
                  label: _paused ? strings.discoveryPlay : strings.discoveryPause,
                  small: true,
                  onTap: _togglePause,
                ),
                _RoundButton(
                  icon: Icons.favorite_rounded,
                  color: AppColors.success,
                  label: strings.discoverySave,
                  onTap: () => _answer(top, liked: true),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        centerTitle: true,
        title: Text(strings.discoveryTitle.toUpperCase(),
            style: locale.getTextStyle(
                fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 3)),
        actions: [
          if (deck.liked > 0)
            TextButton.icon(
              onPressed: () { Haptics.tap(); _openSaved(); },
              icon: const Icon(Icons.queue_music_rounded, size: 18, color: AppColors.success),
              label: Text('${deck.liked}',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard({required this.card, required this.locale});

  final DiscoveryCard card;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = locale.strings;
    final t = card.track;
    return Semantics(
      label: '${t.title}, ${t.artistName}. ${strings.discoverySubtitle}',
      child: AspectRatio(
        aspectRatio: 0.72,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            color: AppColors.bgCard,
            border: Border.all(color: AppColors.border),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (t.coverUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ref.watch(imageQualityProvider).large(t.coverUrl.replaceAll('250x250', '500x500')),
                  memCacheWidth: imageCacheSize(context, 360),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.bgCard),
                )
              else
                const Icon(Icons.music_note_rounded, size: 80, color: AppColors.textMuted),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Colors.transparent, Color(0xEE07080C)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                            fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                    const SizedBox(height: 4),
                    Text(t.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w700, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(card.because == null ? Icons.public_rounded : Icons.auto_awesome_rounded,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            card.because == null ? strings.discoveryFromCharts : strings.discoveryBecause(card.because!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700, color: Colors.white60),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color, required this.locale});
  final String text;
  final Color color;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(AppRadius.card),
            color: Colors.black38,
          ),
          child: Text(text.toUpperCase(),
              style: locale.getTextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: color, letterSpacing: 2)),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.small = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 54.0 : 68.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 6,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCard,
            border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 16)],
          ),
          child: Icon(icon, color: color, size: size * 0.46),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.locale,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final LocaleProvider locale;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(text,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: AppFontSize.title, color: AppColors.textSecondary, height: 1.45)),
              if (action != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentText, side: const BorderSide(color: AppColors.accent)),
                  onPressed: onAction,
                  child: Text(action!),
                ),
              ],
            ],
          ),
        ),
      );
}

/// The next card being dealt: its shape, with the title's lines on it.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SkeletonScope(
        label: label,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 12),
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Stack(
                children: [
                  const Positioned.fill(child: SkeletonLoader(height: double.infinity, borderRadius: AppRadius.sheet)),
                  // Lighter lines where the title and artist will be.
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 22,
                    child: SkeletonScope(
                      label: label,
                      onImage: true,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(factor: 0.7, height: 22),
                          SizedBox(height: 8),
                          SkeletonLine(factor: 0.45, height: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
