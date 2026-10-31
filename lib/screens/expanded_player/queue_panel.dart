part of '../expanded_player_screen.dart';

/// The queue in place of the artwork: header with Flow and clear, the radio
/// banner, and the reorderable list of songs.
class _QueueView extends StatelessWidget {
  final AudioProvider audio;
  final LocaleProvider locale;

  /// A song in the list was tapped: it plays and the artwork comes back.
  final ValueChanged<Track> onPlay;

  const _QueueView({
    required this.audio,
    required this.locale,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    // The queue list is mutated in place (radio refills, reorders), so
    // rebuild on a fingerprint of it rather than on identity.
    return Expanded(
      child: Selector<AudioProvider, (int, int, bool, RadioStatus, RadioMode)>(
        selector: (_, a) => (
          Object.hashAll(a.queue.map((t) => t.id)),
          a.currentIndex,
          a.isRadioActive,
          a.radioStatus,
          a.radioMode,
        ),
        builder: (context, _, __) => _buildPanel(context),
      ),
    );
  }

  void _showSnack(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  SnackBar _snack(BuildContext context, String message, Duration duration,
      {SnackBarAction? action}) {
    final navPad = MediaQuery.of(context).padding.bottom;
    return SnackBar(
      content: Text(
        message,
        style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
      ),
      backgroundColor: AppColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      margin: EdgeInsets.only(bottom: navPad + 12, left: 16, right: 16),
      duration: duration,
      action: action,
    );
  }

  void _clearQueue(BuildContext context) {
    final strings = locale.strings;
    HapticFeedback.mediumImpact();
    final savedQueue = List<Track>.from(audio.queue);
    audio.clearQueue();
    SemanticsService.sendAnnouncement(View.of(context),strings.queueClearLabel, TextDirection.ltr);
    _showSnack(
      context,
      _snack(
        context,
        strings.queueClearLabel,
        const Duration(seconds: 4),
        action: SnackBarAction(
          label: strings.undo,
          textColor: AppColors.accent,
          onPressed: () {
            for (final t in savedQueue) {
              audio.addToQueue(t);
            }
          },
        ),
      ),
    );
  }

  void _remove(BuildContext context, int index) {
    final strings = locale.strings;
    audio.removeFromQueue(index);
    HapticFeedback.lightImpact();
    SemanticsService.sendAnnouncement(View.of(context),strings.removedFromQueue, TextDirection.ltr);
    _showSnack(
      context,
      _snack(context, strings.removedFromQueue, const Duration(seconds: 2)),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final queue = audio.queue;
    final strings = locale.strings;
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
            _buildHeader(context, queue.length),
            const Divider(color: AppColors.border, height: 1),
            if (audio.isRadioActive) _buildRadioBanner(context),
            if (queue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  strings.swipeToRemoveHint,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: queue.isEmpty
                  ? _buildEmpty()
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      footer: audio.isRadioActive
                          ? _buildRadioFooter()
                          : null,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      itemCount: queue.length,
                      // onReorderItem already adjusts newIndex for the
                      // removed item, unlike the deprecated onReorder.
                      onReorderItem: (oldIndex, newIndex) {
                        audio.reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, i) => _buildItem(context, queue, i),
                    ),
            ),
          ],
        ),
      );
  }

  Widget _buildHeader(BuildContext context, int queueLength) {
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.queue_music,
                    color: AppColors.accent, size: 16, semanticLabel: strings.a11yQueue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
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
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '$queueLength',
                    style: locale.getTextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (audio.upcomingTracks.length >= 3) ...[
            Semantics(
              button: true,
              label: strings.flowTitle,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  FlowSheet.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.show_chart_rounded, size: 13, color: AppColors.neonCyan),
                      const SizedBox(width: 4),
                      Text(
                        strings.flowButton,
                        style: locale.getTextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neonCyan,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (queueLength > 1)
            Semantics(
              button: true,
              label: strings.queueClearLabel,
              child: GestureDetector(
                onTap: () => _clearQueue(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep_outlined,
                          size: 13, color: AppColors.textMuted, semanticLabel: strings.a11yClearQueue),
                      const SizedBox(width: 4),
                      Text(
                        strings.queueClear,
                        style: locale.getTextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
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

  Widget _buildEmpty() {
    final strings = locale.strings;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music_rounded,
              size: 44,
              color: AppColors.textMuted.withValues(alpha: 0.4),
              semanticLabel: strings.a11yEmptyQueue),
          const SizedBox(height: 10),
          Text(
            strings.queueEmpty,
            style: locale.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.queueEmptySubtitle,
            style: locale.getTextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, List<Track> queue, int i) {
    final strings = locale.strings;
    final t = queue[i];
    final isCur = audio.currentTrack?.id == t.id;
    final queuedByUser = !isCur && audio.isUserQueued(t.id);
    return Dismissible(
      key: ValueKey('queue_${t.id}_$i'),
      direction: isCur ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.accent, size: 20, semanticLabel: strings.a11yRemoveFromQueue),
      ),
      onDismissed: (_) => _remove(context, i),
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isCur
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.bgMid.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCur
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.4),
          width: isCur ? 1.2 : 0.8,
        ),
      ),
      child: Semantics(
        label: '${t.title}, ${t.fullArtistName}',
        child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onPlay(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: isCur
                    ? Icon(Icons.equalizer,
                        color: AppColors.accent, size: 16, semanticLabel: strings.a11yNowPlaying)
                    : queuedByUser
                    ? Icon(Icons.queue_music,
                        color: AppColors.neonCyan, size: 16, semanticLabel: strings.queuedByYou)
                    : Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: locale.getTextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: t.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (36).toDouble()),
                          imageUrl: t.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.bgHover,
                          ),
                          errorWidget: (_, __, ___) =>
                              Container(
                            color: AppColors.bgHover,
                          ),
                        )
                      : Container(
                          color: AppColors.bgHover,
                        ),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      style: locale.getTextStyle(
                        color: isCur
                            ? AppColors.accent
                            : AppColors.textBright,
                        fontWeight: isCur
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      queuedByUser
                          ? '${strings.queuedByYou} · ${t.fullArtistName}'
                          : t.fullArtistName,
                      style: locale.getTextStyle(
                        color: queuedByUser
                            ? AppColors.neonCyan.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (radioReasonLabel(strings,
                            audio.radioReasonFor(t.id))
                        case final why?)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 2),
                        child: Text(
                          why,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            color: AppColors.neonCyan
                                .withValues(alpha: 0.75),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (BpmService.shared.cached(t.id) case final bpm?)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${bpm.round()}',
                    style: locale.getTextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neonCyan.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Semantics(
                button: true,
                label: strings.queueRemoveLabel,
                child: GestureDetector(
                  onTap: () => _remove(context, i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        Icons.close,
                        color: AppColors.textMuted,
                        size: 16,
                        semanticLabel: strings.a11yRemoveFromQueue,
                      ),
                    ),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                    semanticLabel: strings.a11yReorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildRadioBanner(BuildContext context) {
    final strings = locale.strings;
    final seed = audio.radioSeed;
    if (seed == null) return const SizedBox.shrink();
    final modeLabel = switch (audio.radioMode) {
      RadioMode.familiar => strings.radioModeFamiliar,
      RadioMode.balanced => strings.radioModeBalanced,
      RadioMode.adventurous => strings.radioModeAdventurous,
    };
    return Semantics(
      button: true,
      label: '${strings.a11yRadio}. ${strings.radioBasedOn(seed.title)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showRadioControlSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accent.withValues(alpha: 0.14),
              AppColors.neonPurple.withValues(alpha: 0.06),
            ]),
          ),
          child: Row(
            children: [
              const Icon(Icons.all_inclusive, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.radioLabel} · ${modeLabel.toUpperCase()}',
                      style: locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      strings.radioBasedOn(seed.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  strings.radioTune,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioFooter() {
    final status = audio.radioStatus;
    final warn =
        status == RadioStatus.offline || status == RadioStatus.exhausted;
    final color = warn ? AppColors.warning : AppColors.textMuted;
    return Padding(
      key: const ValueKey('radio_footer'),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == RadioStatus.loading)
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.accent),
              )
            else
              Icon(warn ? Icons.info_outline : Icons.all_inclusive,
                  size: 14, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                radioStatusLabel(locale.strings, status),
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
