import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';

class AlbumCard extends StatelessWidget {
  final Album album;
  final double width;

  const AlbumCard({
    super.key,
    required this.album,
    this.width = 135,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.accentDim,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: album.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.bgMid),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.bgMid,
                          child: const Icon(Icons.album, color: AppColors.accent),
                        ),
                      )
                    : Container(
                        color: AppColors.bgMid,
                        child: const Icon(Icons.album, color: AppColors.accent),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artistName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
