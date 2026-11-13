part of '../home_screen.dart';

/// Bonds (Lazos), with the count of requests waiting for an answer.
class _BondsButton extends ConsumerWidget {
  const _BondsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final pending = ref.watch(socialProvider.select((s) => s.pending)) +
        ref.watch(partyProvider.select((p) => p.invitations.length));
    return IconButton(
      tooltip: pending > 0 ? '${strings.bondsTitle}: ${strings.bondsRequests} $pending' : strings.bondsTitle,
      onPressed: () {
        Haptics.tap();
        BondsRoute(tab: pending > 0 ? 1 : 0).push<void>(context);
      },
      icon: Badge(
        isLabelVisible: pending > 0,
        backgroundColor: AppColors.accent,
        label: Text('$pending', style: const TextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w900)),
        child: const Icon(Icons.link_rounded, color: AppColors.textBright, size: 22),
      ),
    );
  }
}

/// Title, telemetry line, moon, source badge and profile gear over the sky.
class _HomeHeader extends StatelessWidget {
  final LocaleProvider locale;
  final bool isLoggedIn;

  const _HomeHeader({required this.locale, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return SkyBackdrop(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                          children: [
                            Text(
                              strings.homeHeader.replaceAll(' // 01', ''),
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.display,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textBright,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              ' // 01',
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.display,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Flavour, not information: screen readers skip it.
                      ExcludeSemantics(child: Text(
                        strings.homeTelemetry,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansJp(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentText,
                          letterSpacing: 1.2,
                        ),
                      )),
                    ],
                  ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const MoonButton(),
                      const SizedBox(width: 4),
                      _SourceBadge(locale: locale),
                      if (isLoggedIn) const _BondsButton(),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: isLoggedIn ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !isLoggedIn,
                          child: _GearProfileButton(
                            label: strings.profileTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: SkyLine(),
          ),
        ],
      ),
    );
  }
}

/// SPOTIFY or DEEZER: where full songs or previews come from.
class _SourceBadge extends StatelessWidget {
  final LocaleProvider locale;

  const _SourceBadge({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isSpotify = ref.watch(
            audioProvider.select((a) => a.useSpotify || a.spotify.isConnected));
        final badgeColor = AppColors.accent;
        final badgeBg = AppColors.accentDim;
        final badgeText = isSpotify ? 'SPOTIFY' : 'DEEZER';

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.5),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeColor,
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.7),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                badgeText,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-page notice (load error, empty library) with one action button.
class _HomeMessage extends StatelessWidget {
  final LocaleProvider locale;
  final Widget icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _HomeMessage({
    required this.locale,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: icon,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.bodyLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Haptics.tap();
                  onAction();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    color: AppColors.accent.withValues(alpha: 0.08),
                  ),
                  child: Text(
                    actionLabel,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.body,
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
}

/// Section heading fading from white into the accent color.
class _SectionTitle extends StatelessWidget {
  final LocaleProvider locale;
  final String text;

  /// Lines it may take before it is cut, for headings that share their
  /// row; unlimited when null.
  final int? maxLines;

  const _SectionTitle({
    required this.locale,
    required this.text,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.textBright, AppColors.accent],
          stops: [0.5, 1.0],
        ).createShader(bounds),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
          style: locale.getTextStyle(
            fontSize: AppFontSize.bodyLg,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final LocaleProvider locale;
  final String label;
  final String value;
  final String meta;
  final bool isTextValue;

  const _StatCard({
    required this.locale,
    required this.label,
    required this.value,
    required this.meta,
    this.isTextValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = isTextValue ? null : int.tryParse(value);
    return Semantics(
      label: '$label: $value, $meta',
      child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          // Same height for numbers and names, so the line under them sits
          // level across every card. Bottom-aligned so a name sits on the
          // same line as the numbers instead of floating above them.
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: numValue != null
                  ? TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: numValue),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) => Text(
                        '$val',
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.headline,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Text(
                      value,
                      style: isTextValue
                          ? locale.getTextStyle(
                              fontSize: AppFontSize.titleLg,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            )
                          : locale.getTextStyle(
                              fontSize: AppFontSize.headline,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final LocaleProvider locale;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.locale,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: GlassCard(
          color: color,
          highlightAlpha: highlight ? 0.18 : 0.08,
          dimAlpha: highlight ? 0.08 : 0.03,
          borderAlpha: highlight ? 0.6 : 0.3,
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.micro, color: color),
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

/// A numbered artist row: top artists by affinity, or featured ones.
class _ArtistRow extends StatelessWidget {
  final LocaleProvider locale;
  final int rank;
  final String name;
  final String subtitle;
  final String pictureUrl;
  final String semanticsLabel;

  /// Shows a person icon while there's no picture.
  final bool placeholderIcon;
  final VoidCallback onTap;

  const _ArtistRow({
    required this.locale,
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.pictureUrl,
    required this.semanticsLabel,
    required this.placeholderIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: locale.getTextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                      memCacheWidth: imageCacheSize(context, (40).toDouble()),
                        imageUrl: pictureUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.bgCard,
                        child: placeholderIcon
                            ? Icon(Icons.person,
                                color: AppColors.accent, size: 20, semanticLabel: locale.strings.a11yArtistAvatar)
                            : null,
                      ),
              ),
            )),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted, semanticLabel: locale.strings.a11ySeeAll),
          ],
        ),
      ),
    ),
    );
  }
}
