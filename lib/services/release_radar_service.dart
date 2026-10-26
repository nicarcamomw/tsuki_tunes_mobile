import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color, DartPluginRegistrant, PlatformDispatcher;

import 'package:flutter/foundation.dart';
// `show`: widgets also exports a `Constraints` that clashes with workmanager's.
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants/api_endpoints.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_strings.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/radar_release.dart';

/// Also the iOS BGTask identifier: must match Info.plist and AppDelegate.
const String kReleaseRadarTask = 'com.tsuki.releaseRadar';

@pragma('vm:entry-point')
void releaseRadarDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      // iOS gives background refresh ~30s; stay well inside it.
      await ReleaseRadarService().runCheck(budget: const Duration(seconds: 22));
    } catch (e) {
      debugPrint('[ReleaseRadar] background check failed: $e');
    }
    // Never ask the OS to retry: tomorrow's run picks up where this one left.
    return true;
  });
}

class _ArtistState {
  final Set<String> ids;
  final int checkedAt;
  _ArtistState(this.ids, this.checkedAt);

  factory _ArtistState.fromJson(Map<String, dynamic> json) => _ArtistState(
        (json['ids'] as List? ?? const []).map((e) => e.toString()).toSet(),
        json['checkedAt'] is int ? json['checkedAt'] : 0,
      );

  Map<String, dynamic> toJson() => {'ids': ids.toList(), 'checkedAt': checkedAt};
}

/// Watches followed artists for new Deezer releases. The same check runs from
/// three places: a daily WorkManager/BGTask job, app open/resume, and the
/// radar screen's manual refresh. State lives in SharedPreferences so the
/// background isolate never needs Firebase or a signed-in session.
class ReleaseRadarService {
  static final ReleaseRadarService _instance = ReleaseRadarService._();
  factory ReleaseRadarService() => _instance;
  ReleaseRadarService._();

  static const String _watchedKey = 'tsuki_radar_watched';
  static const String _stateKey = 'tsuki_radar_state';
  static const String _releasesKey = 'tsuki_radar_releases';
  static const String _lastCheckKey = 'tsuki_radar_last_check';
  static const String _notifyKey = 'tsuki_radar_notify';
  static const String _askedKey = 'tsuki_radar_permission_asked';
  static const String _lockKey = 'tsuki_radar_lock';
  static const String _languageKey = 'tsuki_app_language';

  static const Duration timelineWindow = Duration(days: 60);
  // Older albums appearing for the first time are back-catalogue uploads,
  // not new drops, so they never notify.
  static const Duration _newWindow = Duration(days: 30);
  static const Duration _foregroundInterval = Duration(hours: 6);
  static const Duration _requestGap = Duration(milliseconds: 180);
  static const Duration _lockTtl = Duration(minutes: 3);
  static const int _maxIdsPerArtist = 120;
  static const int _maxTimeline = 80;

  static const String _channelId = 'tsuki_release_radar';
  static const int _notificationId = 7101;
  static const String _payload = 'release_radar';

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;
  bool _running = false;
  bool _pendingOpen = false;
  Set<String>? _watchedIds;
  AppLifecycleListener? _lifecycle;

  // UI state (foreground isolate only).
  final ValueNotifier<List<RadarRelease>> releases = ValueNotifier(const []);
  final ValueNotifier<bool> checking = ValueNotifier(false);
  final ValueNotifier<DateTime?> lastCheck = ValueNotifier(null);
  final ValueNotifier<int> watchedCount = ValueNotifier(0);
  final ValueNotifier<bool> notifyEnabled = ValueNotifier(true);

  /// Bumped when a radar notification is tapped while the app is running.
  final ValueNotifier<int> openRequests = ValueNotifier(0);

  // ---------------------------------------------------------------------------
  // Foreground lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initForeground() async {
    if (!isSupported) return;
    try {
      await Workmanager().initialize(releaseRadarDispatcher);
      await Workmanager().registerPeriodicTask(
        kReleaseRadarTask,
        kReleaseRadarTask,
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('[ReleaseRadar] background scheduling unavailable: $e');
    }

    try {
      await _initNotifications(foreground: true);
      // Cold start from a notification: Home may already be listening.
      if (_pendingOpen) openRequests.value++;
    } catch (e) {
      debugPrint('[ReleaseRadar] notifications init failed: $e');
    }

    await _reloadUiState();
    _lifecycle ??= AppLifecycleListener(
      onResume: () => _reloadUiState().then((_) => maybeCheck()),
    );
    // Let startup traffic settle before hitting Deezer.
    unawaited(Future.delayed(const Duration(seconds: 8), maybeCheck));
  }

  /// Called with every LibraryProvider change; only writes when the set of
  /// followed artists actually changed.
  Future<void> watchArtists(List<Artist> artists) async {
    final ids = artists.map((a) => a.id).toSet();
    if (_watchedIds != null && setEquals(ids, _watchedIds)) return;
    _watchedIds = ids;
    watchedCount.value = ids.length;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _watchedKey,
        json.encode([
          for (final a in artists) {'id': a.id, 'name': a.name},
        ]),
      );
    } catch (e) {
      debugPrint('[ReleaseRadar] watchArtists save failed: $e');
    }
  }

  Future<void> maybeCheck() async {
    final last = lastCheck.value;
    if (last != null && DateTime.now().difference(last) < _foregroundInterval) {
      return;
    }
    await checkNow();
  }

  /// Returns how many brand-new releases were found.
  Future<int> checkNow() async {
    if (!isSupported || checking.value) return 0;
    checking.value = true;
    try {
      return await runCheck(budget: const Duration(seconds: 45));
    } catch (e) {
      debugPrint('[ReleaseRadar] check failed: $e');
      return 0;
    } finally {
      await _reloadUiState();
      checking.value = false;
    }
  }

  Future<void> markAllRead() async {
    if (!releases.value.any((r) => r.isUnread)) return;
    final updated = [for (final r in releases.value) r.copyWith(read: true)];
    releases.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _releasesKey, json.encode(updated.map((r) => r.toJson()).toList()));
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('[ReleaseRadar] markAllRead failed: $e');
    }
  }

  Future<void> setNotifyEnabled(bool enabled) async {
    notifyEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyKey, enabled);
  }

  bool consumePendingOpen() {
    final pending = _pendingOpen;
    _pendingOpen = false;
    return pending;
  }

  // ---------------------------------------------------------------------------
  // Notification permission
  // ---------------------------------------------------------------------------

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      await _initNotifications(foreground: true);
      if (Platform.isAndroid) {
        return await _notifications
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      }
      final status = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return status?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      await _initNotifications(foreground: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
      if (Platform.isAndroid) {
        return await _notifications
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Asks once, at the moment the user shows intent (following an artist).
  Future<void> askPermissionOnceForFollow() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    if (await hasPermission()) {
      await prefs.setBool(_askedKey, true);
      return;
    }
    await requestPermission();
  }

  // ---------------------------------------------------------------------------
  // The check (runs in either isolate)
  // ---------------------------------------------------------------------------

  Future<int> runCheck({required Duration budget}) async {
    if (_running) return 0;
    _running = true;
    var lockHeld = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // The other isolate may have written since this one cached prefs.
      await prefs.reload();

      final now = DateTime.now();
      final lock = prefs.getInt(_lockKey);
      if (lock != null &&
          now.millisecondsSinceEpoch - lock < _lockTtl.inMilliseconds) {
        return 0;
      }
      await prefs.setInt(_lockKey, now.millisecondsSinceEpoch);
      lockHeld = true;

      final watched = _decodeWatched(prefs);
      if (watched.isEmpty) return 0;
      final watchedIds = watched.map((a) => a.id).toSet();

      final state = _decodeState(prefs);
      final timeline = {
        for (final r in _decodeReleases(prefs)) r.albumId: r,
      };
      final fresh = <RadarRelease>[];

      // Least recently checked first, so a tight budget still rotates
      // through everyone over successive runs.
      watched.sort((a, b) => (state[a.id]?.checkedAt ?? 0)
          .compareTo(state[b.id]?.checkedAt ?? 0));
      final deadline = now.add(budget);
      var checked = 0;

      for (final artist in watched) {
        if (DateTime.now().isAfter(deadline)) break;
        if (checked > 0) await Future.delayed(_requestGap);
        final albums = await _fetchAlbums(artist.id);
        if (albums == null) continue; // network trouble: keep old state

        final known = state[artist.id];
        for (final album in albums) {
          if (album.id.isEmpty || album.recordType == 'compile') continue;
          if (timeline.containsKey(album.id)) continue;
          final released = album.releaseDate.isEmpty
              ? null
              : DateTime.tryParse(album.releaseDate);
          if (released == null) continue;
          final age = now.difference(released);
          if (age > timelineWindow) continue;

          final isNew = known != null &&
              !known.ids.contains(album.id) &&
              age <= _newWindow;
          final release = RadarRelease.fromAlbum(
            album,
            artistId: artist.id,
            artistName: artist.name,
            detectedAt: now,
            isNew: isNew,
          );
          timeline[album.id] = release;
          if (isNew) fresh.add(release);
        }

        state[artist.id] = _ArtistState(
          {...albums.map((a) => a.id), ...?known?.ids}
              .take(_maxIdsPerArtist)
              .toSet(),
          now.millisecondsSinceEpoch,
        );
        checked++;
      }

      state.removeWhere((id, _) => !watchedIds.contains(id));
      final cutoff = now.subtract(timelineWindow);
      final kept = timeline.values.where((r) {
        final at = r.releasedAt;
        return watchedIds.contains(r.artistId) &&
            at != null &&
            at.isAfter(cutoff);
      }).toList()
        ..sort((a, b) {
          final byDate = b.releaseDate.compareTo(a.releaseDate);
          return byDate != 0 ? byDate : b.detectedAt.compareTo(a.detectedAt);
        });

      await prefs.setString(_stateKey,
          json.encode(state.map((k, v) => MapEntry(k, v.toJson()))));
      await prefs.setString(_releasesKey,
          json.encode(kept.take(_maxTimeline).map((r) => r.toJson()).toList()));
      if (checked > 0) {
        await prefs.setString(_lastCheckKey, now.toIso8601String());
      }

      if (fresh.isNotEmpty && (prefs.getBool(_notifyKey) ?? true)) {
        await _notify(fresh, prefs);
      }
      return fresh.length;
    } finally {
      _running = false;
      if (lockHeld) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_lockKey);
        } catch (_) {}
      }
    }
  }

  Future<List<Album>?> _fetchAlbums(String artistId) async {
    final uri = Uri.parse(ApiEndpoints.artistAlbums(artistId, limit: 50));
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode == 429) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        if (res.statusCode != 200) return null;
        final decoded = json.decode(res.body);
        if (decoded is! Map<String, dynamic>) return null;
        final error = decoded['error'];
        if (error != null) {
          // Deezer signals its quota with HTTP 200 + code 4 / 800.
          final code = error is Map ? error['code'] : null;
          if (code == 4 || code == 800) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return null;
        }
        final data = decoded['data'];
        if (data is! List) return null;
        return data
            .whereType<Map>()
            .map((m) => Album.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<void> _initNotifications({required bool foreground}) async {
    if (_notificationsReady) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: foreground ? _onNotificationTap : null,
    );
    if (foreground) {
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if ((launch?.didNotificationLaunchApp ?? false) &&
          launch?.notificationResponse?.payload == _payload) {
        _pendingOpen = true;
      }
    }
    _notificationsReady = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != _payload) return;
    _pendingOpen = true;
    openRequests.value++;
  }

  AppLanguage _language(SharedPreferences prefs) {
    final saved = prefs.getString(_languageKey);
    if (saved != null) return AppLanguage.fromCode(saved);
    try {
      return AppLanguage.fromCode(PlatformDispatcher.instance.locale.languageCode);
    } catch (_) {
      return AppLanguage.es;
    }
  }

  Future<void> _notify(List<RadarRelease> fresh, SharedPreferences prefs) async {
    try {
      await _initNotifications(foreground: false);
      final strings = AppStrings(_language(prefs));

      final String title;
      final String body;
      if (fresh.length == 1) {
        final r = fresh.first;
        title = strings.radarNotifSingle(r.artistName, r.recordType);
        body = r.title;
      } else {
        final artists = fresh.map((r) => r.artistName).toSet().toList();
        title = strings.radarNotifMany(fresh.length);
        body = strings.radarNotifManyBody(artists);
      }

      final cover = fresh.length == 1 && Platform.isAndroid
          ? await _downloadCover(fresh.first.coverUrl)
          : null;

      await _notifications.show(
        _notificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            strings.radarChannelName,
            channelDescription: strings.radarChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            color: const Color(0xFFFF1919),
            largeIcon: cover == null ? null : ByteArrayAndroidBitmap(cover),
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: _payload,
      );
    } catch (e) {
      debugPrint('[ReleaseRadar] notify failed: $e');
    }
  }

  Future<Uint8List?> _downloadCover(String url) async {
    if (url.isEmpty) return null;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<void> _reloadUiState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      releases.value = _decodeReleases(prefs);
      final last = prefs.getString(_lastCheckKey);
      lastCheck.value = last == null ? null : DateTime.tryParse(last);
      final watched = _decodeWatched(prefs);
      _watchedIds ??= watched.map((a) => a.id).toSet();
      watchedCount.value = _watchedIds!.length;
      notifyEnabled.value = prefs.getBool(_notifyKey) ?? true;
    } catch (e) {
      debugPrint('[ReleaseRadar] reload failed: $e');
    }
  }

  List<({String id, String name})> _decodeWatched(SharedPreferences prefs) {
    final raw = prefs.getString(_watchedKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in json.decode(raw) as List)
          if (e is Map && e['id'] != null)
            (id: e['id'].toString(), name: (e['name'] ?? '').toString()),
      ];
    } catch (_) {
      return [];
    }
  }

  Map<String, _ArtistState> _decodeState(SharedPreferences prefs) {
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, _ArtistState.fromJson(Map<String, dynamic>.from(v))));
    } catch (_) {
      return {};
    }
  }

  List<RadarRelease> _decodeReleases(SharedPreferences prefs) {
    final raw = prefs.getString(_releasesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final e in json.decode(raw) as List)
          if (e is Map) RadarRelease.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return [];
    }
  }
}
