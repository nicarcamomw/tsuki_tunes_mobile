import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../data/datasources/storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.es;
  bool _isInitialized = false;

  AppLanguage get currentLanguage => _currentLanguage;
  AppStrings get strings => AppStrings.of(_currentLanguage);
  bool get isInitialized => _isInitialized;

  LocaleProvider({StorageService? storage}) {
    if (storage != null) {
      init(storage);
    }
  }

  Future<void> init(StorageService storage) async {
    if (_isInitialized) return;
    try {
      final code = await storage.getAppLanguage();
      if (code == 'es' && !(await storage.hasExplicitLanguage())) {
        _currentLanguage = _detectDeviceLanguage();
      } else {
        _currentLanguage = AppLanguage.fromCode(code);
      }
    } catch (_) {
      _currentLanguage = _detectDeviceLanguage();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  AppLanguage _detectDeviceLanguage() {
    final locale = PlatformDispatcher.instance.locale;
    final code = locale.languageCode.toLowerCase();
    if (code == 'en') return AppLanguage.en;
    if (code == 'ja') return AppLanguage.ja;
    return AppLanguage.es;
  }

  Future<void> setLanguage(AppLanguage language, StorageService storage) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();
    try {
      await storage.saveAppLanguage(language.code);
    } catch (_) {}
  }

  /// Retorna la tipografía adaptativa adecuada según el idioma activo:
  /// Noto Sans JP para japonés (`ja`) y Plus Jakarta Sans para español/inglés.
  TextStyle getTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
    List<Shadow>? shadows,
  }) {
    // Brand colours as text get their readable (AA) versions.
    if (color != null) color = AppColors.forText(color);
    if (_currentLanguage == AppLanguage.ja) {
      return GoogleFonts.notoSansJp(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationThickness: decorationThickness,
        shadows: shadows,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      shadows: shadows,
    );
  }
}
