/// Phone makers whose battery manager freezes apps in the background, each
/// with its own settings to undo it. Sister brands share their system.
enum BatteryFamily {
  /// Honor (MagicOS) and Huawei (EMUI).
  honor,

  /// Xiaomi, Redmi and POCO (MIUI / HyperOS).
  xiaomi,

  /// OPPO, realme and OnePlus (ColorOS and its forks).
  oppo,

  /// vivo and iQOO (Funtouch OS / OriginOS).
  vivo,
}

/// The maker's family for [manufacturer] / [brand] (Android's
/// Build.MANUFACTURER and Build.BRAND), or null when it doesn't freeze apps.
BatteryFamily? batteryFamilyFor(String manufacturer, String brand) {
  final names = '${manufacturer.toLowerCase()} ${brand.toLowerCase()}';
  bool has(String name) => names.contains(name);
  if (has('honor') || has('huawei')) return BatteryFamily.honor;
  if (has('xiaomi') || has('redmi') || has('poco')) return BatteryFamily.xiaomi;
  if (has('oppo') || has('realme') || has('oneplus')) return BatteryFamily.oppo;
  if (has('vivo') || has('iqoo')) return BatteryFamily.vivo;
  return null;
}
