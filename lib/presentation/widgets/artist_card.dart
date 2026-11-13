import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/artist.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import 'tap_scale.dart';

class ArtistCard extends ConsumerWidget {
  final Artist artist;
  final double size;

  const ArtistCard({
    super.key,
    required this.artist,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);

    return TapScale(
      semanticLabel: '${artist.name}, ${locale.strings.tabArtists}',
      onTap: () {
        FocusScope.of(context).unfocus();
        ArtistRoute(id: artist.id, $extra: artist).push(context);
      },
      scaleDown: 0.95,
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
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.accentDim,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: ExcludeSemantics(
                  child: artist.pictureUrl.isNotEmpty
                      ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (size).toDouble()),
                          imageUrl: artist.pictureUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.bgMid),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgMid,
                            child: Icon(Icons.person, color: AppColors.accent, semanticLabel: locale.strings.a11yArtistAvatar),
                          ),
                        )
                      : Container(
                          color: AppColors.bgMid,
                          child: Icon(Icons.person, color: AppColors.accent, semanticLabel: locale.strings.a11yArtistAvatar),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: locale.getTextStyle(
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
                locale.strings.artistFansCompact(Formatters.formatNumber(artist.fansCount)),
                style: locale.getTextStyle(
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
