part of '../expanded_player_screen.dart';

/// The queue in place of the artwork: the editable [QueuePanel], with the
/// radio's banner and footer while a radio plays.
class _QueueView extends StatelessWidget {
  final AudioProvider audio;
  final LocaleProvider locale;

  /// A song in the list was picked: the artwork comes back.
  final VoidCallback onPlay;

  const _QueueView({
    required this.audio,
    required this.locale,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    // The panel follows the songs itself; this only follows the radio.
    return Expanded(
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(audioProvider.select((a) => (a.isRadioActive, a.radioStatus, a.radioMode)));
          return QueuePanel(
            banner: audio.isRadioActive ? _buildRadioBanner(context) : null,
            footer: audio.isRadioActive ? _buildRadioFooter() : null,
            onPlay: onPlay,
          );
        },
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
