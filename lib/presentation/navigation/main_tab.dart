/// The tabs of the bottom bar, in the order they are shown.
enum MainTab {
  home,
  search,
  explore,
  library;

  /// The number shown after the tab's name ("// 03").
  String get number => '0${index + 1}';
}
