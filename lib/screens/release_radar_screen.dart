import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/radar_release.dart';
import '../providers/locale_provider.dart';
import '../services/release_radar_service.dart';
import 'album_detail_screen.dart';

class ReleaseRadarScreen extends StatefulWidget {
  const ReleaseRadarScreen({super.key});

  @override
  State<ReleaseRadarScreen> createState() => _ReleaseRadarScreenState();
}

class _ReleaseRadarScreenState extends State<ReleaseRadarScreen>
    with WidgetsBindingObserver {
  final ReleaseRadarService _radar = ReleaseRadarService();
  bool? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
    if (_radar.lastCheck.value == null && _radar.watchedCount.value > 0) {
      unawaited(_radar.checkNow());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may come back from system settings with notifications enabled.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Badges stay visible while the user is looking at them.
    unawaited(_radar.markAllRead());
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    final granted = await _radar.hasPermission();
    if (mounted) setState(() => _permission = granted);
  }

  Future<void> _requestPermission() async {
    unawaited(HapticFeedback.selectionClick());
    final granted = await _radar.requestPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (!granted) {
      final strings = context.read<LocaleProvider>().strings;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
        content: Text(
          strings.radarPermissionSettingsHint,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        ),
      ));
    }
  }

  Future<void> _toggleNotify(bool enabled) async {
    unawaited(HapticFeedback.selectionClick());
    await _radar.setNotifyEnabled(enabled);
    if (enabled && _permission == false) await _requestPermission();
  }

  Future<void> _checkNow() async {
    unawaited(HapticFeedback.lightImpact());
    await _radar.checkNow();
  }

  void _openRelease(RadarRelease release) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: release.toAlbum()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textBright,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          strings.radarTitle,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 2,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _radar.releases,
          _radar.checking,
          _radar.lastCheck,
          _radar.watchedCount,
          _radar.notifyEnabled,
        ]),
        builder: (context, _) {
          final releases = _radar.releases.value;
          final unread = releases.where((r) => r.isUnread).toList();
          final recent = releases.where((r) => !r.isUnread).toList();
          final checking = _radar.checking.value;
          final watched = _radar.watchedCount.value;

          return RefreshIndicator(
            color: AppColors.neonCyan,
            backgroundColor: AppColors.bgCard,
            onRefresh: _radar.checkNow,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 300,
              slivers: [
                SliverToBoxAdapter(
                  child: _RadarHeader(
                    locale: locale,
                    watched: watched,
                    unread: unread.length,
                    lastCheck: _radar.lastCheck.value,
                    checking: checking,
                    onCheck: watched == 0 || checking ? null : _checkNow,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _NotifyRow(
                    locale: locale,
                    enabled: _radar.notifyEnabled.value,
                    permission: _permission,
                    onToggle: _toggleNotify,
                    onRequestPermission: _requestPermission,
                  ),
                ),
                if (watched == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.person_add_alt_1,
                      title: strings.radarEmptyNoArtistsTitle,
                      body: strings.radarEmptyNoArtists,
                      locale: locale,
                    ),
                  )
                else if (releases.isEmpty && checking)
                  SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (_, __) => const _SkeletonTile(),
                  )
                else if (releases.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.radar,
                      title: strings.radarEmptyNoReleasesTitle,
                      body: strings.radarEmptyNoReleases,
                      locale: locale,
                    ),
                  )
                else ...[
                  if (unread.isNotEmpty) ...[
                    _sectionHeader(strings.radarSectionNew, AppColors.accent,
                        locale, count: unread.length),
                    SliverList.builder(
                      itemCount: unread.length,
                      itemBuilder: (_, i) => _ReleaseTile(
                        release: unread[i],
                        locale: locale,
                        onTap: () => _openRelease(unread[i]),
                      ),
                    ),
                  ],
                  if (recent.isNotEmpty) ...[
                    _sectionHeader(
                        strings.radarSectionRecent, AppColors.neonCyan, locale),
                    SliverList.builder(
                      itemCount: recent.length,
                      itemBuilder: (_, i) => _ReleaseTile(
                        release: recent[i],
                        locale: locale,
                        onTap: () => _openRelease(recent[i]),
                      ),
                    ),
                  ],
                ],
                if (Platform.isIOS && watched > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Text(
                        strings.radarIosNote,
                        textAlign: TextAlign.center,
                        style: locale.getTextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: 32 + MediaQuery.paddingOf(context).bottom),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, Color color, LocaleProvider locale,
      {int? count}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Semantics(
          header: true,
          child: Row(
            children: [
              Container(width: 3, height: 12, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBright,
                  letterSpacing: 1.6,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: locale.getTextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header with animated radar sweep
// ---------------------------------------------------------------------------

class _RadarHeader extends StatelessWidget {
  final LocaleProvider locale;
  final int watched;
  final int unread;
  final DateTime? lastCheck;
  final bool checking;
  final VoidCallback? onCheck;

  const _RadarHeader({
    required this.locale,
    required this.watched,
    required this.unread,
    required this.lastCheck,
    required this.checking,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final last = lastCheck;
    final status = checking
        ? strings.radarChecking
        : strings.radarLastCheck(
            last == null ? null : DateTime.now().difference(last));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1418), Color(0xFF0A0A14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _RadarSweep(active: checking, blips: min(unread, 6)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread > 0
                      ? strings.radarNewCount(unread)
                      : strings.radarWatching(watched).toUpperCase(),
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: unread > 0 ? AppColors.accent : AppColors.textBright,
                    letterSpacing: 1,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    strings.radarWatching(watched),
                    style: locale.getTextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  status,
                  style: locale.getTextStyle(
                    fontSize: 10,
                    fontWeight: checking ? FontWeight.w700 : FontWeight.w500,
                    color: checking ? AppColors.neonCyan : AppColors.textMuted,
                    letterSpacing: checking ? 1.5 : 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: onCheck,
                    icon: checking
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.neonCyan,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 15),
                    label: Text(
                      strings.radarCheckNow,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neonCyan,
                      disabledForegroundColor:
                          AppColors.neonCyan.withValues(alpha: 0.4),
                      side: BorderSide(
                          color: AppColors.neonCyan.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarSweep extends StatefulWidget {
  final bool active;
  final int blips;
  const _RadarSweep({required this.active, required this.blips});

  @override
  State<_RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<_RadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _RadarSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (widget.active && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 72,
        child: CustomPaint(
          painter: _SweepPainter(
            spin: _spin,
            active: widget.active,
            blips: widget.blips,
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final Animation<double> spin;
  final bool active;
  final int blips;

  _SweepPainter({required this.spin, required this.active, required this.blips})
      : super(repaint: spin);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.neonCyan.withValues(alpha: 0.3);
    for (final f in [1.0, 0.66, 0.33]) {
      canvas.drawCircle(c, r * f - 0.5, ring);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);

    final angle = active ? spin.value * 2 * pi : -pi / 4;
    const sweep = pi / 2.2;
    // Rotate instead of offsetting the gradient: sweep gradients misrender
    // when their angle range is negative or wraps past 0.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle - sweep);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r - 1),
      0,
      sweep,
      true,
      Paint()
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [
            AppColors.neonCyan.withValues(alpha: 0),
            AppColors.neonCyan.withValues(alpha: active ? 0.45 : 0.2),
          ],
          const [0.0, 1.0],
          TileMode.clamp,
          0,
          sweep,
        ),
    );
    canvas.restore();
    canvas.drawLine(
      c,
      c + Offset(cos(angle), sin(angle)) * (r - 1),
      Paint()
        ..color = AppColors.neonCyan.withValues(alpha: active ? 0.9 : 0.5)
        ..strokeWidth = 1.2,
    );

    // Fixed, deterministic blip positions: one per unread release.
    final blip = Paint()..color = AppColors.accent;
    final glow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < blips; i++) {
      final a = i * 2.39996; // golden angle spreads them evenly
      final d = r * (0.3 + 0.55 * ((i * 0.37) % 1));
      final p = c + Offset(cos(a), sin(a)) * d;
      canvas.drawCircle(p, 4, glow);
      canvas.drawCircle(p, 2.2, blip);
    }

    canvas.drawCircle(c, 2, Paint()..color = AppColors.neonCyan);
  }

  @override
  bool shouldRepaint(covariant _SweepPainter old) =>
      old.active != active || old.blips != blips;
}

// ---------------------------------------------------------------------------
// Notification toggle + permission banner
// ---------------------------------------------------------------------------

class _NotifyRow extends StatelessWidget {
  final LocaleProvider locale;
  final bool enabled;
  final bool? permission;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRequestPermission;

  const _NotifyRow({
    required this.locale,
    required this.enabled,
    required this.permission,
    required this.onToggle,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final blocked = enabled && permission == false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: blocked
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.borderSub,
        ),
      ),
      child: Column(
        children: [
          MergeSemantics(
            child: SwitchListTile(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: AppColors.accent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              secondary: Icon(
                enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                color: enabled ? AppColors.accent : AppColors.textMuted,
                size: 20,
              ),
              title: Text(
                strings.radarNotifyToggle,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBright,
                ),
              ),
              subtitle: Text(
                strings.radarNotifyToggleSubtitle,
                style: locale.getTextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.radarPermissionDenied,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRequestPermission,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning),
                    child: Text(
                      strings.radarPermissionAction,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Release rows
// ---------------------------------------------------------------------------

class _ReleaseTile extends StatelessWidget {
  final RadarRelease release;
  final LocaleProvider locale;
  final VoidCallback onTap;

  const _ReleaseTile({
    required this.release,
    required this.locale,
    required this.onTap,
  });

  int? _daysAgo() {
    final at = release.releasedAt;
    if (at == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final unread = release.isUnread;
    final days = _daysAgo();
    final type = strings.radarType(release.recordType);
    final when = days == null ? '' : strings.radarReleasedAgo(days);

    return Semantics(
      button: true,
      label: '${release.title}, ${release.artistName}, $type, $when',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: unread
                ? AppColors.accent.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: unread
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: release.coverUrl.isEmpty
                    ? _coverPlaceholder()
                    : CachedNetworkImage(
                        imageUrl: release.coverUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (60 * MediaQuery.devicePixelRatioOf(context)).round(),
                        placeholder: (_, __) => _coverPlaceholder(),
                        errorWidget: (_, __, ___) => _coverPlaceholder(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      release.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(
                          label: type,
                          color: release.recordType == 'single'
                              ? AppColors.sakura
                              : release.recordType == 'ep'
                                  ? AppColors.neonPurple
                                  : AppColors.neonCyan,
                          locale: locale,
                        ),
                        if (when.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            when,
                            style: locale.getTextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: days != null && days <= 1
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 60,
        height: 60,
        color: AppColors.bgCard,
        child: const Icon(Icons.album, color: AppColors.textMuted, size: 24),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final LocaleProvider locale;

  const _Chip({required this.label, required this.color, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: locale.getTextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          bar(60, 60),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(150, 12),
              const SizedBox(height: 8),
              bar(90, 10),
              const SizedBox(height: 8),
              bar(50, 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final LocaleProvider locale;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.neonCyan.withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
