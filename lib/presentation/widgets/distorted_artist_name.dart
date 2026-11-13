import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../../core/utils/artist_fonts.dart';
import '../state/app_providers.dart';

class DistortedArtistName extends ConsumerWidget {
  final String name;
  final String artistId;
  final double fontSize;
  final TextAlign textAlign;
  final double? strokeWidth;

  const DistortedArtistName({
    super.key,
    required this.name,
    required this.artistId,
    this.fontSize = AppFontSize.display,
    this.textAlign = TextAlign.left,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final customFont = ArtistFonts.getFontFamily(artistId, name);

    if (customFont == null) {
      final displayName = name.toUpperCase();
      return Text(
        displayName,
        textAlign: textAlign,
        style: locale.getTextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: AppColors.textBright,
          letterSpacing: 1.5,
        ),
      );
    }

    final config = ArtistFonts.getConfig(customFont);
    final effectiveSize = fontSize * config.sizeMultiplier;
    final isMetallica = customFont == 'Metallica';

    final textStyle = TextStyle(
      fontFamily: customFont,
      fontSize: effectiveSize,
      fontWeight: isMetallica ? FontWeight.normal : FontWeight.bold,
      color: AppColors.textBright,
      letterSpacing: config.letterSpacing,
    );

    final isACDC = customFont == 'Squealer' || name.toUpperCase().contains('AC/DC');

    Widget resultWidget;

    // Iconic Metallica logo: "Metallic" (winged M + clean body) + flipped capital "A" (winged right)
    if (isMetallica) {
      resultWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Metallic', style: textStyle),
          Transform.scale(
            scaleX: -1.0,
            alignment: Alignment.center,
            child: Text('A', style: textStyle),
          ),
        ],
      );
    } else if (isACDC && (name.contains('/') || name.contains('DC'))) {
      // Iconic AC/DC with lightning bolt in the middle
      final parts = name.contains('/') ? name.split('/') : ['AC', 'DC'];
      final p1 = parts[0].trim().toUpperCase();
      final p2 = parts.length > 1 ? parts[1].trim().toUpperCase() : 'DC';

      resultWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(p1, style: textStyle),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: effectiveSize * 0.08),
            child: SizedBox(
              width: effectiveSize * 0.4,
              height: effectiveSize * 0.7,
              child: CustomPaint(
                painter: _AcDcLightningPainter(color: AppColors.textBright),
              ),
            ),
          ),
          Text(p2, style: textStyle),
        ],
      );
    } else {
      final clean = name.trim();
      final displayName = config.forceUppercase
          ? clean.toUpperCase()
          : (clean.length > 1
              ? clean[0].toUpperCase() + clean.substring(1).toLowerCase()
              : clean.toUpperCase());

      resultWidget = Text(
        displayName,
        textAlign: textAlign,
        style: textStyle,
      );
    }

    if (config.leftOffset != 0 || config.topOffset != 0) {
      return Transform.translate(
        offset: Offset(config.leftOffset, config.topOffset),
        child: resultWidget,
      );
    }

    return resultWidget;
  }
}

class _AcDcLightningPainter extends CustomPainter {
  final Color color;

  _AcDcLightningPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.65, 0)
      ..lineTo(w * 1.0, 0)
      ..lineTo(w * 0.55, h * 0.44)
      ..lineTo(w * 0.90, h * 0.44)
      ..lineTo(w * 0.15, h)
      ..lineTo(w * 0.45, h * 0.56)
      ..lineTo(w * 0.10, h * 0.56)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AcDcLightningPainter oldDelegate) =>
      oldDelegate.color != color;
}



