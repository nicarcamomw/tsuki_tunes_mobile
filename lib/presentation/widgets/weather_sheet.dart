import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/weather.dart';
import '../state/app_providers.dart';
import '../state/weather_provider.dart';
import 'haptics.dart';
import 'sky_line.dart';
import 'swipeable_sheet.dart';

/// Weather status and setup: where it comes from (approximate location or a
/// chosen city), with the privacy note right where the choice is made.
class WeatherSheet extends ConsumerStatefulWidget {
  const WeatherSheet({super.key});

  static Future<void> show(BuildContext context) => SwipeableSheet.show(
        context,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, controller) => const WeatherSheet(),
      );

  @override
  ConsumerState<WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends ConsumerState<WeatherSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Place>? _results;
  bool _searching = false;
  bool _searchFailed = false;
  int _gen = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final gen = ++_gen;
    setState(() => _searching = true);
    final lang = ref.read(localeProvider).currentLanguage.name;
    final found = await ref.read(weatherProvider).searchPlaces(q, language: lang);
    if (!mounted || gen != _gen) return;
    setState(() {
      _searching = false;
      _searchFailed = found == null;
      _results = found ?? const [];
    });
  }

  String? _problemText(LocationStatus? s, AppStrings strings) => switch (s) {
        LocationStatus.denied => strings.weatherDenied,
        LocationStatus.deniedForever => strings.weatherDeniedForever,
        LocationStatus.serviceOff => strings.weatherServiceOff,
        LocationStatus.failed => strings.weatherLocationFailed,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final now = weather.enabled ? weather.current : null;
    final problem = _problemText(weather.locationProblem, strings);
    final part = dayPartAt(DateTime.now());

    TextStyle label(double size, {FontWeight? weight, Color? color, double? spacing}) =>
        locale.getTextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color ?? AppColors.textPrimary,
          letterSpacing: spacing,
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGlow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(strings.weatherTitle,
                      style: label(14, weight: FontWeight.w900, color: AppColors.textBright, spacing: 2)),
                  const Spacer(),
                  if (weather.enabled)
                    IconButton(
                      tooltip: strings.weatherTurnOff,
                      icon: const Icon(Icons.power_settings_new_rounded, color: AppColors.textMuted),
                      onPressed: () {
                        Haptics.selection();
                        weather.disable();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (now != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(skyIcon(now.sky, isDay: now.isDay, part: part),
                          size: 34, color: skyColor(now.sky, isDay: now.isDay)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${now.temperature.round()}°  ${strings.skyName(now.sky)}',
                              style: label(18, weight: FontWeight.w900, color: AppColors.textBright),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${weather.source == WeatherSource.place ? weather.place?.name ?? '' : strings.weatherHere}'
                              '  ·  ${strings.weatherUpdated(DateTime.now().difference(now.fetchedAt).inMinutes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: label(11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (weather.loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                        )
                      else
                        IconButton(
  tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                          onPressed: () { Haptics.tap(); weather.refresh(force: true); },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Text(strings.weatherSettingSubtitle, style: label(12, color: AppColors.textMuted)),
                const SizedBox(height: 14),
              ],

              if (weather.enabled && weather.offline && now == null) ...[
                Text(strings.weatherOffline, style: label(11.5, color: AppColors.warning)),
                const SizedBox(height: 10),
              ],

              // Approximate location.
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neonCyan,
                  side: BorderSide(
                    color: weather.enabled && weather.source == WeatherSource.device
                        ? AppColors.neonCyan
                        : AppColors.borderGlow,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: weather.loading
                    ? null
                    : () {
                        Haptics.selection();
                        weather.useDeviceLocation();
                      },
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(strings.weatherUseLocation, style: label(12.5, weight: FontWeight.w700, color: AppColors.neonCyan)),
              ),
              if (problem != null) ...[
                const SizedBox(height: 8),
                Text(problem, style: label(11.5, color: AppColors.warning)),
                if (weather.locationProblem == LocationStatus.deniedForever ||
                    weather.locationProblem == LocationStatus.serviceOff)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Haptics.tap();
                        weather.locationProblem == LocationStatus.serviceOff
                            ? weather.openLocationSettings()
                            : weather.openAppSettings();
                      },
                      child: Text(strings.weatherOpenSettings,
                          style: label(12, weight: FontWeight.w700, color: AppColors.neonCyan)),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(strings.weatherPrivacy, style: label(10.5, color: AppColors.textMuted)),
              const SizedBox(height: 18),

              // A city by hand.
              Text(strings.weatherOrCity.toUpperCase(),
                  style: label(10, weight: FontWeight.w800, color: AppColors.textMuted, spacing: 1.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _query,
                onChanged: _onQuery,
                textInputAction: TextInputAction.search,
                style: label(13, color: AppColors.textBright),
                decoration: InputDecoration(
                  hintText: strings.weatherSearchHint,
                  hintStyle: label(13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.textMuted),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.bgDeep,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (_results != null) ...[
                const SizedBox(height: 6),
                if (_results!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _searchFailed ? strings.weatherOffline : strings.weatherNoResults,
                      style: label(11.5, color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final p in _results!)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.place_outlined, color: AppColors.textMuted, size: 20),
                      title: Text(p.name, style: label(13, weight: FontWeight.w700, color: AppColors.textBright)),
                      subtitle: p.detail.isEmpty
                          ? null
                          : Text(p.detail, style: label(11, color: AppColors.textMuted)),
                      trailing: weather.enabled &&
                              weather.source == WeatherSource.place &&
                              weather.place?.latitude == p.latitude &&
                              weather.place?.longitude == p.longitude
                          ? const Icon(Icons.check_rounded, color: AppColors.neonCyan)
                          : null,
                      onTap: () {
                        Haptics.selection();
                        FocusScope.of(context).unfocus();
                        weather.usePlace(p);
                        setState(() => _results = null);
                        _query.clear();
                      },
                    ),
              ] else if (weather.enabled &&
                  weather.source == WeatherSource.place &&
                  weather.place != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_rounded, color: AppColors.neonCyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [weather.place!.name, weather.place!.detail].where((s) => s.isNotEmpty).join(' · '),
                        style: label(12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
