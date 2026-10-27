import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../providers/locale_provider.dart';
import '../screens/album_detail_screen.dart';
import '../screens/main_navigation_screen.dart';
import 'tap_scale.dart';

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
    final locale = context.read<LocaleProvider>();

    return TapScale(
      semanticLabel: '${album.title}, ${album.artistName}',
      onTap: () {
        FocusScope.of(context).unfocus();
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
          ),
        );
      },
      scaleDown: 0.95,
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
                child: ExcludeSemantics(
                  child: album.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (width).toDouble()),
                          imageUrl: album.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.bgMid),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgMid,
                            child: Icon(Icons.album, color: AppColors.accent, semanticLabel: locale.strings.a11yAlbumCover),
                          ),
                        )
                      : Container(
                          color: AppColors.bgMid,
                          child: Icon(Icons.album, color: AppColors.accent, semanticLabel: locale.strings.a11yAlbumCover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              style: locale.getTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artistName,
              style: locale.getTextStyle(
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
