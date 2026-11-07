import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'haptics.dart';
import 'moon_glyph.dart';
import 'moon_sheet.dart';

/// Tonight's moon in the header. Tap: moon details and the full-moon mix.
/// Long press: a secret preview of the eclipse mode.
class MoonButton extends ConsumerStatefulWidget {
  final double size;

  const MoonButton({super.key, this.size = 24});

  @override
  ConsumerState<MoonButton> createState() => _MoonButtonState();
}

class _MoonButtonState extends ConsumerState<MoonButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MoonSheet.prewarm(context, ref.read(moonProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final moon = ref.watch(moonProvider);
    final strings = ref.read(stringsProvider);
    final s = moon.snapshot;

    return Semantics(
      button: true,
      label: '${strings.a11yMoon}: ${strings.moonPhaseName(s.name)}. ${MoonSheet.countdown(strings, s)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          MoonSheet.show(context);
        },
        onLongPress: () {
          Haptics.longPress();
          moon.previewEclipse();
        },
        child: SizedBox(
          width: size + 16,
          height: size + 16,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              MoonBreathing(
                active: moon.eclipseActive,
                child: MoonGlyph(
                  size: size,
                  illumination: s.illumination,
                  waxing: s.waxing,
                  southernHemisphere: moon.southernHemisphere,
                  eclipse: moon.eclipseActive,
                ),
              ),
              if (s.isFullMoonWindow && !moon.eclipseActive)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8EEFC),
                      boxShadow: [BoxShadow(color: Color(0xAAD6E0F5), blurRadius: 6)],
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
