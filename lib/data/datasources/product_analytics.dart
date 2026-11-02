import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/product_events.dart';

/// Where product events go: Firebase Analytics in the app, a fake in tests.
abstract class AnalyticsBackend {
  Future<void> logEvent(String name, Map<String, Object> parameters);
  Future<void> logScreen(String name);
  Future<void> setCollectionEnabled(bool enabled);
}

class FirebaseAnalyticsBackend implements AnalyticsBackend {
  FirebaseAnalyticsBackend(this._analytics);
  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) =>
      _analytics.logEvent(name: name, parameters: {
        // Analytics takes text and numbers only.
        for (final e in parameters.entries)
          e.key: e.value is bool ? (e.value as bool ? 'yes' : 'no') : e.value,
      });

  @override
  Future<void> logScreen(String name) => _analytics.logScreenView(screenName: name);

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}

/// Product analytics through Firebase Analytics: which features are used,
/// funnels and retention. Without the advertising id (AndroidManifest.xml),
/// with ids and categories only, nothing from debug builds, and only while
/// the user leaves it on (settings). Until Firebase Analytics is attached
/// (after Firebase starts; never in tests) events are dropped.
class ProductAnalytics implements ProductEvents {
  ProductAnalytics._();
  static final ProductAnalytics instance = ProductAnalytics._();

  static const _enabledKey = 'product_analytics_enabled';

  AnalyticsBackend? _backend;
  bool _collect = false;
  bool _enabled = true;

  /// Whether the user lets usage statistics be sent (on unless turned off).
  bool get enabled => _enabled;

  /// [collect] is false in debug builds: nothing is sent, whatever the
  /// user chose.
  Future<void> attach(AnalyticsBackend backend, {required bool collect}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}
    _collect = collect;
    _backend = backend;
    await _apply();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    await _apply();
  }

  Future<void> _apply() async {
    try {
      await _backend?.setCollectionEnabled(_collect && _enabled);
    } catch (_) {}
  }

  @override
  void log(String name, [Map<String, Object> parameters = const {}]) {
    final backend = _backend;
    if (backend == null || !_enabled) return;
    backend.logEvent(name, parameters).catchError((Object _) {});
  }

  /// A screen opened, by its route pattern (/album/:id), never its ids.
  void screen(String name) {
    final backend = _backend;
    if (backend == null || !_enabled) return;
    backend.logScreen(name).catchError((Object _) {});
  }

  @visibleForTesting
  void resetForTesting() {
    _backend = null;
    _collect = false;
    _enabled = true;
  }
}
