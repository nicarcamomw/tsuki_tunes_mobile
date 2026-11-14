import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import '../state/app_providers.dart';
import 'oni_mask_art.dart';

/// The user's own face in the app: the profile mask when one is chosen
/// (what the Bonds see too), otherwise the account photo, otherwise a
/// silhouette.
class MyAvatar extends ConsumerWidget {
  const MyAvatar({super.key, required this.size, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mask = ref.watch(maskProvider.select((m) => m.profileMask));
    final photo = ref.watch(authProvider.select((a) => a.user?.photoURL));
    final Widget inner;
    if (mask != null) {
      inner = OniMaskArt.image(mask, size * 0.86, cacheWidth: imageCacheSize(context, size));
    } else if (photo != null) {
      inner = ClipOval(
        child: Image(
          image: ResizeImage(CachedNetworkImageProvider(photo), width: imageCacheSize(context, size)),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(Icons.person_rounded, size: size * 0.55, color: AppColors.textMuted),
        ),
      );
    } else {
      inner = Icon(Icons.person_rounded, size: size * 0.55, color: AppColors.textMuted);
    }
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: mask != null ? AppColors.bgDeep : AppColors.bgMid,
          border: mask != null ? Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.2) : null,
        ),
        child: inner,
      ),
    );
  }
}
