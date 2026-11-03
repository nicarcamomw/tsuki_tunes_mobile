import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firebase_emulators.dart';
import '../../core/logger.dart';
import 'crash_reporter.dart';


final _log = Log.named('FeatureFlags');

/// Switches that change what the app does without a new APK, from Firebase
/// Remote Config: a kill switch for a part that broke, or a feature turned
/// on for a share of users (a "user in random percentile" condition in the
/// console; each user always lands in the same group).
///
/// The defaults below are what runs with no network, before the first
/// fetch, against the emulators, or if Remote Config fails: the app as it
/// is. The parameters themselves live in remoteconfig.template.json.
class FeatureFlags extends ChangeNotifier {
  static final FeatureFlags _instance = FeatureFlags._();
  factory FeatureFlags() => _instance;
  FeatureFlags._();

  /// A separate instance holding only the defaults and what a test sets.
  @visibleForTesting
  FeatureFlags.forTesting();

  /// Kill switch for full songs through Spotify: off, everyone plays the
  /// Deezer previews, a song already playing in Spotify included.
  static const spotifyPlaybackKey = 'spotify_playback_enabled';

  /// Putting the next song in Spotify's queue near a song's end (crossfade,
  /// no autoplay). Off, Tsuki starts the next song itself.
  static const spotifyQueueNextKey = 'spotify_queue_next_enabled';

  static const Map<String, Object> defaults = {
    spotifyPlaybackKey: true,
    spotifyQueueNextKey: true,
  };

  FirebaseRemoteConfig? _config;
  final Map<String, bool> _overrides = {};
  StreamSubscription<RemoteConfigUpdate>? _updates;

  bool get spotifyPlayback => _bool(spotifyPlaybackKey);
  bool get spotifyQueueNext => _bool(spotifyQueueNextKey);

  bool _bool(String key) =>
      _overrides[key] ?? _config?.getBool(key) ?? defaults[key] as bool;

  /// Applies the values fetched last time right away (no waiting on the
  /// network at launch), then fetches new ones in the background and keeps
  /// listening, so a kill switch reaches open apps within seconds. Needs
  /// Firebase initialized.
  Future<void> start() async {
    _reportKeys();
    if (_config != null || useFirebaseEmulators) return;
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? const Duration(minutes: 1) : const Duration(hours: 1),
      ));
      await config.setDefaults(defaults);
      await config.activate();
      _config = config;
      notifyListeners();
      unawaited(_fetch(config));
      _updates = config.onConfigUpdated.listen((_) async {
        await config.activate();
        _log.fine('Updated: ${_describe()}');
        notifyListeners();
      }, onError: (Object e) {
        _log.severe('Live updates failed: $e');
      });
    } catch (e) {
      _log.fine('Remote Config unavailable, using defaults: $e');
    }
  }

  Future<void> _fetch(FirebaseRemoteConfig config) async {
    try {
      if (await config.fetchAndActivate()) notifyListeners();
      _log.fine(_describe());
    } catch (e) {
      _log.severe('Fetch failed, keeping the last values: $e');
    }
  }

  @override
  void notifyListeners() {
    _reportKeys();
    super.notifyListeners();
  }

  /// Each switch's value goes with crash reports (`flag_<key>`).
  void _reportKeys() {
    for (final key in defaults.keys) {
      CrashReporter.instance.setKey('flag_$key', _bool(key));
    }
  }

  String _describe() =>
      [for (final key in defaults.keys) '$key=${_bool(key)}'].join(' ');

  @visibleForTesting
  void setForTesting(String key, bool value) {
    _overrides[key] = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}
