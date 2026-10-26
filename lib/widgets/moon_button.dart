import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../providers/moon_provider.dart';
import 'moon_glyph.dart';
import 'moon_sheet.dart';

/// Tonight's moon in the header. Tap: moon details and the full-moon mix.
/// Long press: a secret preview of the eclipse mode.
class MoonButton extends StatelessWidget {
  final double size;

  const MoonButton({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final moon = context.watch<MoonProvider>();
    final strings = context.watch<LocaleProvider>().strings;
    final s = moon.snapshot;

    return Semantics(
      button: true,
      label: '${strings.a11yMoon}: ${strings.moonPhaseName(s.name)}. ${MoonSheet.countdown(strings, s)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          MoonSheet.show(context);
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          moon.previewEclipse();
        },
        child: SizedBox(
          width: size + 16,
          height: size + 16,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              MoonGlyph(
                size: size,
                illumination: s.illumination,
                waxing: s.waxing,
                southernHemisphere: moon.southernHemisphere,
                eclipse: moon.eclipseActive,
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
