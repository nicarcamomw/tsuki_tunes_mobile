import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/image_quality.dart';
import '../../data/datasources/storage_service.dart';

export '../../core/utils/image_quality.dart' show ImageQuality;

/// The chosen [ImageQuality], kept on the phone. Normal until it loads (and
/// for anyone who never changes it).
class ImageQualitySetting extends ChangeNotifier {
  ImageQualitySetting(this._storage) {
    unawaited(_load());
  }

  final StorageService _storage;
  ImageQuality _quality = ImageQuality.normal;

  ImageQuality get quality => _quality;

  /// [url] for a large image, at the chosen size.
  String large(String url) => _quality.large(url);

  Future<void> _load() async {
    final saved = ImageQuality.fromName(await _storage.getImageQuality());
    if (saved == _quality) return;
    _quality = saved;
    notifyListeners();
  }

  Future<void> set(ImageQuality quality) async {
    if (quality == _quality) return;
    _quality = quality;
    notifyListeners();
    await _storage.saveImageQuality(quality.name);
  }
}
