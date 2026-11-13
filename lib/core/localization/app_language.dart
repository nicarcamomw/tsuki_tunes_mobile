enum AppLanguage {
  es('es', 'Español', 'ES', 'Español (Latinoamérica)', 'INICIO', 'BUSCAR', 'EXPLORAR', 'BIBLIOTECA'),
  en('en', 'English', 'EN', 'English (International)', 'HOME', 'SEARCH', 'EXPLORE', 'LIBRARY'),
  ja('ja', '日本語', 'JA', '日本語 (Kanji & Katakana)', 'ホーム', '探索', '発見', '保管庫');

  final String code;
  final String label;
  final String tag;
  final String subtitle;
  final String navHome;
  final String navSearch;
  final String navExplore;
  final String navLibrary;

  const AppLanguage(
    this.code,
    this.label,
    this.tag,
    this.subtitle,
    this.navHome,
    this.navSearch,
    this.navExplore,
    this.navLibrary,
  );

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.es;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => AppLanguage.es,
    );
  }
}
