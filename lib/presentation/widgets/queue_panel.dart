import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../data/datasources/bpm_flow.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import 'eco_widgets.dart';
import 'flow_sheet.dart';
import 'playlist_selector_sheet.dart';
import 'radio_control_sheet.dart';
import 'shuffle_mode_icon.dart';
import 'track_tile.dart';

/// The play queue: what already played (folded away), the song playing now
/// and what comes next in the order it will really play, shuffle included.
/// Drag to reorder (hold anywhere, or the handle), swipe right to play a
/// song next, swipe left to remove it; every removal can be undone.
class QueuePanel extends ConsumerStatefulWidget {
  /// Shown under the header (the radio banner).
  final Widget? banner;

  /// Shown after the songs (the radio's "more" footer).
  final Widget? footer;

  /// A song was picked to play now.
  final VoidCallback? onPlay;

  const QueuePanel({super.key, this.banner, this.footer, this.onPlay});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  // Songs listed at once; with shuffle the rest are summed up below.
  static const _maxShown = 60;

  bool _showPlayed = false;

  AudioProvider get _audio => ref.read(audioProvider);
  LocaleProvider get _locale => ref.read(localeProvider);

  double get _snackBottom => MediaQuery.of(context).padding.bottom + 12;

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
        View.of(context), message, TextDirection.ltr);
  }

  /// Runs [edit] and offers to undo it.
  void _editWithUndo(String message, VoidCallback edit) {
    final before = _audio.queueSnapshot();
    edit();
    _announce(message);
    showTrackSnack(
      context,
      message,
      bottom: _snackBottom,
      action: SnackBarAction(
        label: _locale.strings.undo,
        textColor: AppColors.accent,
        onPressed: () => _audio.restoreQueue(before),
      ),
    );
  }

  void _remove(int queueIndex) {
    HapticFeedback.lightImpact();
    _editWithUndo(_locale.strings.removedFromQueue,
        () => _audio.removeFromQueue(queueIndex));
  }

  void _playNext(int queueIndex) {
    HapticFeedback.mediumImpact();
    _editWithUndo(_locale.strings.addedPlayNext,
        () => _audio.playNextFromQueue(queueIndex));
  }

  void _move(int from, int to) {
    HapticFeedback.selectionClick();
    _audio.moveUpcoming(from, to);
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    _editWithUndo(_locale.strings.queueClearLabel, _audio.clearQueue);
  }

  void _play(Track track) {
    HapticFeedback.selectionClick();
    ref.read(playTrackProvider)(track);
    widget.onPlay?.call();
  }

  void _showActions(Track track, int queueIndex, int position) {
    final strings = _locale.strings;
    showTrackActions(context, track, extra: [
      if (position > 0)
        TrackMenuAction(
          icon: Icons.vertical_align_top_rounded,
          label: strings.playNext,
          onTap: () => _playNext(queueIndex),
        ),
      TrackMenuAction(
        icon: Icons.remove_circle_outline,
        label: strings.queueRemoveLabel,
        onTap: () => _remove(queueIndex),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when what's listed changes: the songs, their order (shuffle
    // picks too), the current one and which ones you queued.
    ref.watch(audioProvider.select((a) {
      final upcoming = a.upcomingOrder(_maxShown);
      return Object.hash(
        Object.hashAll(a.queue.map((t) => t.id)),
        Object.hashAll(upcoming),
        Object.hashAll(upcoming.map((i) => a.isUserQueued(a.queue[i].id))),
        a.currentIndex,
        a.shuffleMode,
        a.currentTrack?.id,
      );
    }));
    return _buildPanel();
  }

  Widget _buildPanel() {
    final audio = _audio;
    final locale = _locale;
    final strings = locale.strings;
    final queue = audio.queue;
    final current = audio.currentTrack;
    final upcoming = audio.upcomingOrder(_maxShown);
    final played = audio.playedIndices;
    final upcomingCount = audio.upcomingCount;
    final hidden = upcomingCount - upcoming.length;

    // Remaining time: everything still to play.
    final remainingSeconds = audio.isShuffle
        ? queue.fold<int>(0, (s, t) => s + t.durationSeconds) -
            (current?.durationSeconds ?? 0)
        : [
            for (var i = audio.currentIndex + 1; i < queue.length; i++)
              queue[i].durationSeconds
          ].fold<int>(0, (s, d) => s + d);

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(upcomingCount, remainingSeconds, upcoming),
          const Divider(color: AppColors.border, height: 1),
          if (widget.banner != null) widget.banner!,
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: Text(
                strings.queueGesturesHint,
                style: locale.getTextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (played.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _buildPlayedToggle(played.length)),
                  if (_showPlayed)
                    SliverList.builder(
                      itemCount: played.length,
                      itemBuilder: (context, k) {
                        final t = queue[played[k]];
                        return Opacity(
                          opacity: 0.55,
                          child: _row(
                            t,
                            leading: _number(k + 1),
                            onTap: () => _play(t),
                          ),
                        );
                      },
                    ),
                ],
                if (current != null) ...[
                  SliverToBoxAdapter(
                      child: _sectionLabel(strings.queueNowPlaying)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _row(
                        current,
                        isCurrent: true,
                        leading: Icon(Icons.equalizer,
                            color: AppColors.accent,
                            size: 16,
                            semanticLabel: strings.a11yNowPlaying),
                        onTap: widget.onPlay,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: _sectionLabel(
                    strings.queueComingUp,
                    tag: switch (audio.shuffleMode) {
                      ShuffleMode.off => null,
                      ShuffleMode.on => strings.queueShuffledTag,
                      ShuffleMode.smart => strings.queueSmartShuffleTag,
                    },
                  ),
                ),
                if (upcoming.isEmpty)
                  SliverToBoxAdapter(child: _buildEmpty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverReorderableList(
                      itemCount: upcoming.length,
                      onReorderItem: (from, to) {
                        if (to != from) _move(from, to);
                      },
                      proxyDecorator: (child, _, __) => Material(
                        color: Colors.transparent,
                        elevation: 6,
                        shadowColor: AppColors.accent.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        child: child,
                      ),
                      itemBuilder: (context, k) =>
                          _upcomingRow(queue, upcoming, k),
                    ),
                  ),
                if (hidden > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Text(
                        strings.queueMoreShuffled(hidden),
                        style: locale.getTextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (widget.footer != null)
                  SliverToBoxAdapter(child: widget.footer),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count, int remainingSeconds, List<int> upcoming) {
    final audio = _audio;
    final locale = _locale;
    final strings = locale.strings;
    final minutes = (remainingSeconds / 60).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Icon(Icons.queue_music,
              color: AppColors.accent, size: 16, semanticLabel: strings.a11yQueue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.queueUpNext,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (count > 0)
                  Text(
                    strings.queueSummary(count, minutes),
                    style: locale.getTextStyle(
                      fontSize: 9.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (audio.upcomingTracks.length >= 3)
            _headerButton(
              icon: Icons.show_chart_rounded,
              label: strings.flowButton,
              semanticLabel: strings.flowTitle,
              color: AppColors.neonCyan,
              onTap: () {
                if (!ecoAllows(context, EcoFeature.bpmFlow)) return;
                HapticFeedback.selectionClick();
                FlowSheet.show(context);
              },
            ),
          if (count > 0)
            _headerButton(
              icon: Icons.playlist_add_rounded,
              semanticLabel: strings.queueSaveAsPlaylist,
              color: AppColors.textMuted,
              onTap: () {
                HapticFeedback.selectionClick();
                final queue = audio.queue;
                saveTracksAsPlaylist(context, [
                  if (audio.currentTrack != null) audio.currentTrack!,
                  for (final i in audio.upcomingOrder(audio.upcomingCount))
                    queue[i],
                ]);
              },
            ),
          if (count > 0)
            _headerButton(
              icon: Icons.delete_sweep_outlined,
              label: strings.queueClear,
              semanticLabel: strings.queueClearLabel,
              color: AppColors.textMuted,
              onTap: _clear,
            ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    String? label,
    required String semanticLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: _locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayedToggle(int count) {
    final locale = _locale;
    return Semantics(
      button: true,
      expanded: _showPlayed,
      child: InkWell(
        onTap: () => setState(() => _showPlayed = !_showPlayed),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
          child: Row(
            children: [
              Text(
                locale.strings.queuePlayedHeader(count),
                style: locale.getTextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showPlayed
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {String? tag}) {
    final locale = _locale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text(
            text,
            style: locale.getTextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.shuffle_rounded, size: 11, color: AppColors.neonCyan),
            const SizedBox(width: 3),
            Text(
              tag,
              style: locale.getTextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.neonCyan,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final locale = _locale;
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.queue_music_rounded,
              size: 40,
              color: AppColors.textMuted.withValues(alpha: 0.4),
              semanticLabel: strings.a11yEmptyQueue),
          const SizedBox(height: 8),
          Text(
            strings.queueNothingNext,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.queueEmptySubtitle,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingRow(List<Track> queue, List<int> upcoming, int k) {
    final strings = _locale.strings;
    final queueIndex = upcoming[k];
    final t = queue[queueIndex];
    final queuedByUser = _audio.isUserQueued(t.id);
    final recommended = !queuedByUser && _audio.isRecommended(t.id);
    // Keyed by the song (and which copy of it), not its position, so rows
    // keep their identity while being dragged around.
    var copy = 0;
    for (var j = 0; j < k; j++) {
      if (queue[upcoming[j]].id == t.id) copy++;
    }
    final key = '${t.id}#$copy';

    final row = _row(
      t,
      queuedByUser: queuedByUser,
      recommended: recommended,
      leading: queuedByUser
          ? Icon(Icons.queue_music,
              color: AppColors.neonCyan, size: 16, semanticLabel: strings.queuedByYou)
          : recommended
              ? SparkleIcon(
                  color: AppColors.accent,
                  size: 14,
                  semanticLabel: strings.recommendedTag)
              : _number(k + 1),
      onTap: () => _play(t),
      trailing: [
        _iconButton(
          icon: Icons.more_vert_rounded,
          semanticLabel: strings.a11yMoreOptions,
          onTap: () => _showActions(t, queueIndex, k),
        ),
        ReorderableDragStartListener(
          index: k,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.textMuted,
              size: 20,
              semanticLabel: strings.a11yReorder,
            ),
          ),
        ),
      ],
    );

    return KeyedSubtree(
      key: ValueKey('queue_$key'),
      child: Semantics(
        customSemanticsActions: {
          if (k > 0)
            CustomSemanticsAction(label: strings.playNext): () =>
                _playNext(queueIndex),
          if (k > 0)
            CustomSemanticsAction(label: strings.a11yMoveUp): () =>
                _move(k, k - 1),
          if (k < upcoming.length - 1)
            CustomSemanticsAction(label: strings.a11yMoveDown): () =>
                _move(k, k + 1),
          CustomSemanticsAction(label: strings.queueRemoveLabel): () =>
              _remove(queueIndex),
        },
        child: Dismissible(
          key: ValueKey('dismiss_$key'),
          // The first one already plays next.
          direction: k == 0
              ? DismissDirection.endToStart
              : DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.3,
            DismissDirection.endToStart: 0.4,
          },
          background: _swipeBackground(
            icon: Icons.vertical_align_top_rounded,
            label: strings.playNext,
            color: AppColors.neonCyan,
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: _swipeBackground(
            icon: Icons.delete_outline,
            label: strings.queueRemoveLabel,
            color: AppColors.accent,
            alignment: Alignment.centerRight,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Moves it up instead of taking it away: snap back.
              _playNext(queueIndex);
              return false;
            }
            return true;
          },
          onDismissed: (_) => _remove(queueIndex),
          // Hold anywhere on the row to drag it.
          child: ReorderableDelayedDragStartListener(index: k, child: row),
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required IconData icon,
    required String label,
    required Color color,
    required Alignment alignment,
  }) {
    final left = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!left) ...[
            Text(label, style: _swipeLabelStyle(color)),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color, size: 20),
          if (left) ...[
            const SizedBox(width: 8),
            Text(label, style: _swipeLabelStyle(color)),
          ],
        ],
      ),
    );
  }

  TextStyle _swipeLabelStyle(Color color) => _locale.getTextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      );

  Widget _number(int n) => Text(
        n.toString().padLeft(2, '0'),
        style: _locale.getTextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );

  Widget _iconButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(icon, color: AppColors.textMuted, size: 18),
        ),
      ),
    );
  }

  Widget _row(
    Track t, {
    required Widget leading,
    bool isCurrent = false,
    bool queuedByUser = false,
    bool recommended = false,
    VoidCallback? onTap,
    List<Widget> trailing = const [],
  }) {
    final locale = _locale;
    final strings = locale.strings;
    final why = radioReasonLabel(strings,
        _audio.radioReasonFor(t.id) ?? _audio.recommendationReasonFor(t.id));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.bgMid.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? AppColors.accent.withValues(alpha: 0.5)
              : queuedByUser
                  ? AppColors.neonCyan.withValues(alpha: 0.35)
                  : recommended
                      ? AppColors.accent.withValues(alpha: 0.35)
                      : AppColors.border.withValues(alpha: 0.4),
          width: isCurrent ? 1.2 : 0.8,
        ),
      ),
      child: Semantics(
        label: '${t.title}, ${t.fullArtistName}',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 6, trailing.isEmpty ? 10 : 0, 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Center(child: leading)),
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: t.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              memCacheWidth: imageCacheSize(context, 36),
                              imageUrl: t.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.bgHover),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppColors.bgHover),
                            )
                          : Container(color: AppColors.bgHover),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.title,
                        style: locale.getTextStyle(
                          color: isCurrent ? AppColors.accent : AppColors.textBright,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        queuedByUser
                            ? '${strings.queuedByYou} · ${t.fullArtistName}'
                            : recommended
                                ? '${strings.recommendedTag} · ${t.fullArtistName}'
                                : t.fullArtistName,
                        style: locale.getTextStyle(
                          color: queuedByUser
                              ? AppColors.neonCyan.withValues(alpha: 0.85)
                              : recommended
                                  ? AppColors.accent.withValues(alpha: 0.9)
                                  : AppColors.textSecondary,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (why != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            why,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: locale.getTextStyle(
                              color: AppColors.neonCyan.withValues(alpha: 0.75),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: BpmService.shared.revision,
                  builder: (_, __, ___) {
                    final bpm = BpmService.shared.cached(t.id);
                    if (bpm == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '${bpm.round()}',
                        style: locale.getTextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neonCyan.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  },
                ),
                if (t.durationSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      Formatters.formatSeconds(t.durationSeconds),
                      style: locale.getTextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ...trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
