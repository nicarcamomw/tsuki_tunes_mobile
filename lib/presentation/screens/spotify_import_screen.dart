import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/logic/track_matcher.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/spotify_import_controller.dart';
import '../state/use_cases.dart';

final spotifyImportProvider = ChangeNotifierProvider.autoDispose<SpotifyImportController>((ref) {
  final spotify = ref.read(audioProvider).spotify;
  final catalog = ref.read(musicCatalogProvider);
  final playlists = ref.read(playlistProvider);
  final c = SpotifyImportController(
    loadPlaylists: spotify.getImportablePlaylists,
    loadTracks: spotify.getImportTracks,
    needsReconnect: () => spotify.importNeedsReconnect,
    matcher: TrackMatcher(
      byIsrc: catalog.findTrackByIsrc,
      search: (q) => catalog.searchTracksUnfiltered(q, limit: 10),
    ),
    createPlaylist: (name, tracks) => playlists.createPlaylist(name, tracks: tracks),
    likedName: ref.read(localeProvider).strings.importLiked,
  );
  if (spotify.isConnected) unawaited(c.load());
  return c;
});

/// Spotify's playlists to bring in, then the progress and how each went.
class SpotifyImportScreen extends ConsumerWidget {
  const SpotifyImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final c = ref.watch(spotifyImportProvider);
    final connected = ref.read(audioProvider).spotify.isConnected;
    TextStyle style(double size, {Color color = AppColors.textBright, FontWeight w = FontWeight.w600}) =>
        locale.getTextStyle(fontSize: size, color: color, fontWeight: w, height: 1.4);

    Widget body;
    if (!connected) {
      body = _Center(icon: Icons.link_off_rounded, text: strings.importNotConnected, style: style(13.5));
    } else if (c.loading || c.playlists == null) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.success, strokeWidth: 2.4));
    } else if (c.running || c.results.isNotEmpty) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          if (c.running) ...[
            Text(c.current ?? '', style: style(16, w: FontWeight.w900)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: c.total == 0 ? null : c.done / c.total,
                minHeight: 6,
                color: AppColors.success,
                backgroundColor: AppColors.border,
              ),
            ),
            const SizedBox(height: 8),
            Text(strings.importProgress(c.done, c.total), style: style(12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(strings.importKeepOpen, style: style(11.5, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
              onPressed: c.cancel,
              child: Text(strings.importCancel),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(strings.importDone, style: style(14, w: FontWeight.w800)),
            const SizedBox(height: 16),
          ],
          for (final r in c.results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(r.found > 0 ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: r.found > 0 ? AppColors.success : AppColors.textMuted),
              title: Text(r.name, style: style(13.5, w: FontWeight.w800)),
              subtitle: Text(strings.importFound(r.found, r.total), style: style(11.5, color: AppColors.textSecondary)),
              trailing: r.playlistId == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: r.playlistId == null ? null : () => PlaylistRoute(id: r.playlistId!).push<void>(context),
            ),
        ],
      );
    } else if (c.needsReconnect) {
      body = _Center(icon: Icons.lock_reset_rounded, text: strings.importReconnect, style: style(13.5));
    } else if (c.playlists!.isEmpty) {
      body = _Center(icon: Icons.queue_music_rounded, text: strings.importNone, style: style(13.5));
    } else {
      final list = c.playlists!;
      body = Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(strings.importHint, style: style(12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                for (final p in list)
                  CheckboxListTile(
                    value: c.isSelected(p.id),
                    onChanged: (_) {
                      HapticFeedback.selectionClick();
                      c.toggle(p.id);
                    },
                    activeColor: AppColors.success,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: p.liked
                            ? const ColoredBox(
                                color: Color(0xFF3B2A7A), child: Icon(Icons.favorite_rounded, color: Colors.white))
                            : p.imageUrl == null
                                ? const ColoredBox(
                                    color: AppColors.bgCard,
                                    child: Icon(Icons.queue_music_rounded, color: AppColors.textMuted))
                                : CachedNetworkImage(
                                    imageUrl: p.imageUrl!,
                                    memCacheWidth: imageCacheSize(context, 44),
                                    fit: BoxFit.cover,
                                  ),
                      ),
                    ),
                    title: Text(c.nameOf(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: style(13.5, w: FontWeight.w800)),
                    subtitle: Text(strings.importSongs(p.total), style: style(11.5, color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.black),
                  onPressed: c.selectedCount == 0
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          unawaited(c.run());
                        },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(strings.importButton(c.selectedCount), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      // Leaving mid-import would stop it: ask to stop first.
      canPop: !c.running,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          elevation: 0,
          centerTitle: true,
          title: Text(strings.importTitle.toUpperCase(),
              style: locale.getTextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 2)),
        ),
        body: body,
      ),
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.icon, required this.text, required this.style});
  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textMuted),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: style),
            ],
          ),
        ),
      );
}
