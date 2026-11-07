import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import 'swipeable_sheet.dart';

/// Spotify Connect: the user's devices with Spotify open, to move the music
/// to one of them (a PC, a speaker, the TV, a console) or back here.
Future<void> showSpotifyDevicesSheet(BuildContext context) => SwipeableSheet.show(
      context,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => _DevicesSheet(controller: controller, host: context),
    );

class _DevicesSheet extends ConsumerStatefulWidget {
  final ScrollController controller;
  final BuildContext host;
  const _DevicesSheet({required this.controller, required this.host});

  @override
  ConsumerState<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends ConsumerState<_DevicesSheet> {
  List<Map<String, dynamic>>? _devices;
  String? _moving;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _devices = null);
    final devices = await ref.read(audioProvider).spotify.getDevices();
    if (mounted) setState(() => _devices = devices);
  }

  Future<void> _choose(Map<String, dynamic> d) async {
    final id = d['id'] as String?;
    final name = (d['name'] as String?) ?? '';
    if (id == null || _moving != null) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _moving = id);
    final audio = ref.read(audioProvider);
    final strings = ref.read(localeProvider).strings;
    final messenger = ScaffoldMessenger.maybeOf(widget.host);
    final ok = await audio.spotify.listenOn(id, name: name, isPhone: d['type'] == 'Smartphone');
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(ok ? strings.devicesMoved(name) : strings.devicesFailed)));
  }

  static IconData _icon(String? type) => switch (type) {
        'Smartphone' => Icons.smartphone_rounded,
        'Computer' => Icons.computer_rounded,
        'Tablet' => Icons.tablet_rounded,
        'Speaker' => Icons.speaker_rounded,
        'TV' => Icons.tv_rounded,
        'GameConsole' => Icons.sports_esports_rounded,
        'CastVideo' || 'CastAudio' => Icons.cast_rounded,
        'Automobile' => Icons.directions_car_rounded,
        _ => Icons.devices_other_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final devices = _devices;
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.devices_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(strings.devicesTitle.toUpperCase(),
                  style: locale.getTextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 2)),
            ),
            IconButton(
              tooltip: strings.devicesRefresh,
              onPressed: devices == null ? null : _load,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
        Text(strings.devicesHint,
            style: locale.getTextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 14),
        if (devices == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(color: AppColors.success, strokeWidth: 2.4)),
          )
        else if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(strings.devicesEmpty,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
          )
        else
          for (final d in devices) _tile(d, locale, strings),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> d, LocaleProvider locale, AppStrings strings) {
    final active = d['is_active'] == true;
    final restricted = d['is_restricted'] == true;
    final moving = _moving == d['id'];
    final color = active ? AppColors.success : AppColors.textSecondary;
    final name = (d['name'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: !restricted,
        selected: active,
        label: '$name${active ? '. ${strings.devicesPlayingHere}' : ''}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: restricted || active ? null : () => _choose(d),
          child: Opacity(
            opacity: restricted ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? AppColors.success : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(_icon(d['type'] as String?), color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: locale.getTextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textBright)),
                        if (active || restricted) ...[
                          const SizedBox(height: 2),
                          Text(active ? strings.devicesPlayingHere : strings.devicesRestricted,
                              style: locale.getTextStyle(fontSize: 10.5, color: color)),
                        ],
                      ],
                    ),
                  ),
                  if (moving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: AppColors.success, strokeWidth: 2),
                    )
                  else if (active)
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.success, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
