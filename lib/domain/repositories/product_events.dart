/// What people do in the app, counted to see which features are used, where
/// they drop off and who comes back (product analytics). Events carry ids
/// and categories, never song titles, searches or names. The use cases
/// report the actions they perform through it; the data layer decides
/// where events go, and whether at all (the user can turn it off).
abstract class ProductEvents {
  void log(String name, [Map<String, Object> parameters = const {}]);
}
