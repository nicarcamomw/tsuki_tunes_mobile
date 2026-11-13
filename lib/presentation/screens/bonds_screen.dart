import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/entities/social.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../widgets/eco_widgets.dart' show becomeBearer;
import '../widgets/haptics.dart';
import '../widgets/oni_mask_art.dart';
import '../widgets/skeleton_loader.dart';

/// Bonds (Lazos): what your Bonds' Echo did (Resonances), your Bonds and
/// requests, and finding Bearers by name.
class BondsScreen extends ConsumerStatefulWidget {
  const BondsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<BondsScreen> createState() => _BondsScreenState();
}

class _BondsScreenState extends ConsumerState<BondsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final social = ref.watch(socialProvider);
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        title: Text(
          strings.bondsTitle.toUpperCase(),
          style: locale.getTextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.textBright,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (social.available)
            Consumer(
              builder: (context, ref, _) {
                final invites = ref.watch(partyProvider.select((p) => p.invitations.length));
                final inParty = ref.watch(partyProvider.select((p) => p.inParty));
                return IconButton(
                  tooltip: strings.partyTitle,
                  onPressed: () { Haptics.tap(); const PartyRoute().push<void>(context); },
                  icon: Badge(
                    isLabelVisible: invites > 0,
                    backgroundColor: AppColors.accent,
                    label: Text('$invites', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                    child: Icon(Icons.headphones_rounded, color: inParty ? AppColors.success : AppColors.textBright),
                  ),
                );
              },
            ),
        ],
        bottom: social.available
            ? TabBar(
                controller: _tabs,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.textBright,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                tabs: [
                  Tab(text: strings.bondsTabResonances),
                  Tab(
                    child: Badge(
                      isLabelVisible: social.pending > 0,
                      backgroundColor: AppColors.accent,
                      offset: const Offset(12, -6),
                      label: Text(
                        '${social.pending}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      child: Text(strings.bondsTabBonds),
                    ),
                  ),
                  Tab(text: strings.bondsTabSearch),
                ],
              )
            : null,
      ),
      body: !social.available
          ? _ObserverPanel(locale: locale, strings: strings)
          : TabBarView(
              controller: _tabs,
              children: [
                _ResonancesTab(onFindBonds: () => _tabs.animateTo(2)),
                _BondsTab(onSearch: () => _tabs.animateTo(2)),
                const _SearchTab(),
              ],
            ),
    );
  }
}

class _ObserverPanel extends StatelessWidget {
  const _ObserverPanel({required this.locale, required this.strings});
  final LocaleProvider locale;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            strings.bondsObserver,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill),
            onPressed: () => becomeBearer(context),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text(strings.ecoObserverAction, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
}

// ── Resonances ──

class _ResonancesTab extends ConsumerStatefulWidget {
  const _ResonancesTab({required this.onFindBonds});
  final VoidCallback onFindBonds;

  @override
  ConsumerState<_ResonancesTab> createState() => _ResonancesTabState();
}

class _ResonancesTabState extends ConsumerState<_ResonancesTab> with AutomaticKeepAliveClientMixin {
  Future<List<Resonance>>? _feed;
  int _bonds = -1;

  @override
  bool get wantKeepAlive => true;

  void _load({bool refresh = false}) {
    _feed = ref.read(socialProvider).resonances(refresh: refresh);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final bonds = ref.watch(socialProvider.select((s) => s.bonds.length));
    if (_feed == null || bonds != _bonds) {
      _bonds = bonds;
      _load();
    }
    if (bonds == 0) {
      return _Empty(
        icon: Icons.graphic_eq_rounded,
        text: strings.bondsResonancesNoBonds,
        action: strings.bondsAsk,
        onAction: widget.onFindBonds,
        locale: locale,
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgCard,
      onRefresh: () async {
        Haptics.threshold();
        setState(() => _load(refresh: true));
        await _feed;
      },
      child: FutureBuilder<List<Resonance>>(
        future: _feed,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonRowList(count: 6, round: true, padding: EdgeInsets.fromLTRB(16, 12, 16, 0));
          }
          final feed = snap.data ?? const [];
          if (feed.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                _Empty(icon: Icons.hearing_rounded, text: strings.bondsResonancesNone, locale: locale),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: feed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => ResonanceTile(resonance: feed[i]),
          );
        },
      ),
    );
  }
}

/// One Resonance: who, what their Echo did, and when.
class ResonanceTile extends ConsumerWidget {
  const ResonanceTile({super.key, required this.resonance, this.showPerson = true});

  final Resonance resonance;
  final bool showPerson;

  static IconData iconFor(MilestoneKind k) => switch (k) {
    MilestoneKind.album => Icons.album_rounded,
    MilestoneKind.mask => Icons.auto_awesome_rounded,
    MilestoneKind.rank => Icons.trending_up_rounded,
    MilestoneKind.streak => Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final m = resonance.milestone;
    final mask = m.kind == MilestoneKind.mask ? MaskCatalog.byId(m.a) : null;
    final what = strings.bondsMilestone(m, mask?.name(locale.currentLanguage) ?? m.a);
    final ago = strings.bondsAgo(DateTime.now().difference(m.at));
    return Semantics(
      button: showPerson,
      label: '${showPerson ? '${resonance.person.name} ' : ''}$what, $ago',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: showPerson ? () { Haptics.tap(); UserProfileRoute(uid: resonance.person.uid).push<void>(context); } : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (showPerson) ...[PersonAvatar(person: resonance.person, size: 42), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (showPerson)
                            TextSpan(
                              text: '${resonance.person.name} ',
                              style: locale.getTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textBright,
                              ),
                            ),
                          TextSpan(
                            text: what,
                            style: locale.getTextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ago, style: locale.getTextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (mask != null)
                OniMaskArt.image(mask, 40)
              else
                Icon(iconFor(m.kind), color: AppColors.accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bonds and requests ──

class _BondsTab extends ConsumerWidget {
  const _BondsTab({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final social = ref.watch(socialProvider);
    if (social.bonds.isEmpty && social.received.isEmpty && social.sent.isEmpty) {
      return _Empty(
        icon: Icons.people_outline_rounded,
        text: strings.bondsNone,
        action: strings.bondsTabSearch,
        onAction: onSearch,
        locale: locale,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (social.received.isNotEmpty) ...[
          _SectionLabel(text: strings.bondsRequests, count: social.received.length, locale: locale),
          for (final p in social.received)
            PersonRow(
              person: p,
              subtitle: strings.bondsWantsYou(p.name),
              below: _RequestButtons(person: p),
            ),
          const SizedBox(height: 18),
        ],
        if (social.bonds.isNotEmpty) ...[
          _SectionLabel(text: strings.bondsYours, count: social.bonds.length, locale: locale),
          for (final p in social.bonds)
            PersonRow(
              person: p,
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ),
          const SizedBox(height: 18),
        ],
        if (social.sent.isNotEmpty) ...[
          _SectionLabel(text: strings.bondsSent, count: social.sent.length, locale: locale),
          for (final p in social.sent)
            PersonRow(
              person: p,
              trailing: BondButton(person: p, compact: true),
            ),
        ],
      ],
    );
  }
}

class _RequestButtons extends ConsumerWidget {
  const _RequestButtons({required this.person});
  final SocialPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final social = ref.watch(socialProvider);
    if (social.isBusy(person.uid)) return const SizedBox(height: 40, child: Center(child: _Spinner()));
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 40),
            ),
            onPressed: () async {
              Haptics.remove();
              final ok = await social.decline(person.uid);
              if (!ok && context.mounted) _toast(context, strings.bondsFailed);
            },
            child: Text(strings.bondsDecline),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill, minimumSize: const Size(0, 40)),
            onPressed: () async {
              Haptics.confirm();
              final ok = await social.accept(person.uid);
              if (context.mounted) _toast(context, ok ? strings.bondsNowBonded(person.name) : strings.bondsFailed);
            },
            child: Text(strings.bondsAccept, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ── Search ──

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> with AutomaticKeepAliveClientMixin {
  final _field = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<PublicProfile>? _results;
  bool _failed = false;
  bool _searching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    _query = q;
    if (q.length < 2) {
      setState(() {
        _results = null;
        _failed = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await ref.read(socialProvider).search(q);
      if (!mounted || q != _query) return;
      setState(() {
        _results = found;
        _failed = false;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || q != _query) return;
      setState(() {
        _failed = true;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final results = _results;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        TextField(
          controller: _field,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (q) => _search(q.trim()),
          style: locale.getTextStyle(fontSize: 14, color: AppColors.textBright),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: strings.bondsSearchHint,
            hintStyle: locale.getTextStyle(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
            suffixIcon: _searching
                ? const Padding(padding: EdgeInsets.all(14), child: _Spinner())
                : _field.text.isEmpty
                ? null
                : IconButton(
  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () { Haptics.selection();
                      _field.clear();
                      _search('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        if (results == null && !_failed)
          Text(
            strings.bondsSearchHelp,
            style: locale.getTextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
          )
        else if (_failed)
          _Empty(icon: Icons.wifi_off_rounded, text: strings.bondsSearchFailed, locale: locale)
        else if (results!.isEmpty)
          _Empty(icon: Icons.search_off_rounded, text: strings.bondsSearchNone(_query), locale: locale)
        else
          for (final p in results)
            PersonRow(
              person: SocialPerson(uid: p.uid, name: p.displayName, photoUrl: p.photoUrl, maskId: p.maskId),
              subtitle: '${p.stats.tracks} · ${strings.profileSongs.toLowerCase()}',
              trailing: BondButton(
                person: SocialPerson(uid: p.uid, name: p.displayName, photoUrl: p.photoUrl, maskId: p.maskId),
                compact: true,
              ),
            ),
      ],
    );
  }
}

// ── Shared pieces ──

/// What I can do with [person]: ask, cancel, answer, or nothing (a Bond).
class BondButton extends ConsumerWidget {
  const BondButton({super.key, required this.person, this.compact = false});

  final SocialPerson person;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final social = ref.watch(socialProvider);
    if (!social.available || social.me == person.uid) return const SizedBox.shrink();
    if (social.isBusy(person.uid)) {
      return SizedBox(
        height: compact ? 36 : 48,
        child: const Center(child: _Spinner()),
      );
    }
    final state = social.stateWith(person.uid);
    final size = Size(compact ? 0 : double.infinity, compact ? 36 : 48);
    final pad = EdgeInsets.symmetric(horizontal: compact ? 12 : 16);
    switch (state) {
      case BondState.none:
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill, minimumSize: size, padding: pad),
          onPressed: () async {
            Haptics.confirm();
            final ok = await social.request(person);
            if (context.mounted) _toast(context, ok ? strings.bondsSentTo(person.name) : strings.bondsFailed);
          },
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: Text(
            compact ? strings.bondsAskShort : strings.bondsAsk,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      case BondState.sent:
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: size,
            padding: pad,
          ),
          onPressed: () async {
            Haptics.remove();
            final ok = await social.cancel(person.uid);
            if (!ok && context.mounted) _toast(context, strings.bondsFailed);
          },
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(compact ? strings.bondsAsked : strings.bondsCancel),
        );
      case BondState.received:
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentFill, minimumSize: size, padding: pad),
          onPressed: () async {
            Haptics.confirm();
            final ok = await social.accept(person.uid);
            if (context.mounted) _toast(context, ok ? strings.bondsNowBonded(person.name) : strings.bondsFailed);
          },
          icon: const Icon(Icons.how_to_reg_rounded, size: 18),
          label: Text(strings.bondsAccept, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      case BondState.bonded:
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentText,
            side: const BorderSide(color: AppColors.accent),
            minimumSize: size,
            padding: pad,
          ),
          onPressed: compact ? null : () { Haptics.tap(); _confirmUnbond(context, ref, person); },
          icon: const Icon(Icons.link_rounded, size: 18),
          label: Text(compact ? strings.bondsBonded : strings.bondsUnbond),
        );
    }
  }

  static Future<void> _confirmUnbond(BuildContext context, WidgetRef ref, SocialPerson person) async {
    final strings = ref.read(stringsProvider);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(strings.bondsUnbond),
        content: Text(strings.bondsUnbondBody(person.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.bondsUnbond, style: const TextStyle(color: AppColors.accentText)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await ref.read(socialProvider).unbond(person.uid);
    if (!ok && context.mounted) _toast(context, strings.bondsFailed);
  }
}

/// A person in a list: avatar, name, a line, and an action. Opens their
/// profile.
class PersonRow extends ConsumerWidget {
  const PersonRow({super.key, required this.person, this.subtitle, this.trailing, this.below});

  final SocialPerson person;
  final String? subtitle;
  final Widget? trailing;

  /// Actions under the name, across the whole row (a request's answers).
  final Widget? below;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () { Haptics.tap(); UserProfileRoute(uid: person.uid).push<void>(context); },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  PersonAvatar(person: person, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textBright,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    // Never wider than the name needs to stay readable: with
                    // big text sizes the button's words wrap. Scaling it down
                    // instead shrank it under a fingertip (to 23 dp).
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: trailing,
                    ),
                  ],
                ],
              ),
              if (below != null) ...[const SizedBox(height: 10), below!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Their equipped being, or their photo, or their initial.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 44});

  final SocialPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mask = MaskCatalog.byId(person.maskId);
    final Widget initial = Text(
      person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase(),
      style: TextStyle(color: AppColors.textBright, fontSize: size * 0.42, fontWeight: FontWeight.w800),
    );
    final Widget inner = mask != null
        ? OniMaskArt.image(mask, size * 0.82)
        : person.photoUrl != null
        ? ClipOval(
            child: Image.network(person.photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: imageCacheSize(context, size),
                // An expired or offline photo falls back to the initial.
                errorBuilder: (_, _, _) => Center(child: initial)),
          )
        : initial;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgDeep,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: inner,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.count, required this.locale});
  final String text;
  final int count;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      '${text.toUpperCase()} · $count',
      style: locale.getTextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 2,
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, required this.locale, this.action, this.onAction});
  final IconData icon;
  final String text;
  final LocaleProvider locale;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentText,
                side: const BorderSide(color: AppColors.accent),
              ),
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
