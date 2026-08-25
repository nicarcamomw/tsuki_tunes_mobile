import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/artist.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/main_navigation_screen.dart';

class ArtistCard extends StatelessWidget {
  final Artist artist;
  final double size;

  const ArtistCard({
    super.key,
    required this.artist,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.accentDim,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: artist.pictureUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artist.pictureUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.bgMid),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.bgMid,
                          child: const Icon(Icons.person, color: AppColors.accent),
                        ),
                      )
                    : Container(
                        color: AppColors.bgMid,
                        child: const Icon(Icons.person, color: AppColors.accent),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (artist.fansCount > 0)
              Text(
                '${Formatters.formatNumber(artist.fansCount)} fans',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
