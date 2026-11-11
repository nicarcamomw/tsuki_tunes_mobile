import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/notification_payloads.dart';
import 'firebase_service.dart';
import 'release_radar_service.dart';

final _log = Log.named('PushRadar');

/// Where Android delivers a push while the app isn't in front: its own
/// isolate, no Firebase needed (the radar keeps its state in preferences).
@pragma('vm:entry-point')
Future<void> radarPushHandler(RemoteMessage message) async {
  await ReleaseRadarService().handlePush(message.data);
}

/// New releases pushed by the server (functions/src/radar.ts): registers
/// this phone under the signed-in account (users/{uid}/devices/{deviceId},
/// with its Firebase Installation ID, platform, language and the radar's
/// switch) and hands
/// what arrives to [ReleaseRadarService.handlePush]. Guests aren't
/// registered: the server can't see whom they follow, so their own daily
/// check carries on alone, as it does for everyone as the fallback.
class PushRadarService {
  static final PushRadarService _instance = PushRadarService._();
  factory PushRadarService() => _instance;
  PushRadarService._();

  static const _deviceIdKey = 'tsuki_push_device_id';
  static const _registeredKey = 'tsuki_push_registered';
  static const _registeredAtKey = 'tsuki_push_registered_at';
  // Confirmed at least this often, so the server keeps the device
  // (it drops ones unconfirmed for 60 days).
  static const _confirmEvery = Duration(days: 1);
  static const _writeTimeout = Duration(seconds: 15);

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool _started = false;
  final List<StreamSubscription<dynamic>> _subs = [];
  AppLifecycleListener? _lifecycle;
  Future<void> _queue = Future.value();

  /// This install's FCM address, once FCM gave it (onRegistered).
  String? _fid;

  /// Once, before runApp: pushes arriving with the app in the background.
  static void registerBackgroundHandler() {
    if (!isSupported) return;
    try {
      FirebaseMessaging.onBackgroundMessage(radarPushHandler);
    } catch (e) {
      _log.warning('background pushes unavailable: $e');
    }
  }

  Future<void> init() async {
    if (!isSupported || _started) return;
    _started = true;
    try {
      await FirebaseService().initialize();
      final messaging = FirebaseMessaging.instance;
      _subs
        ..add(FirebaseMessaging.onMessage
            .listen((m) => ReleaseRadarService().handlePush(m.data)))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_opened))
        ..add(messaging.onRegistered.listen((fid) {
          _fid = fid;
          _sync();
        }))
        ..add(messaging.onUnregistered.listen((_) => _fid = null))
        ..add(FirebaseService().auth.authStateChanges().listen((_) => _sync()));
      ReleaseRadarService().notifyEnabled.addListener(_sync);
      _lifecycle ??= AppLifecycleListener(onResume: _sync);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _opened(initial);
      // Answers with onRegistered (also when the FID changes later).
      await messaging.register();
    } catch (e) {
      // No Google Play services, no APNs set up: the local check stays.
      _log.warning('push unavailable: $e');
    }
  }

  /// The system showed the notification itself (iOS) and it was tapped.
  void _opened(RemoteMessage message) {
    if (message.data['type'] != NotificationPayloads.releaseRadar) return;
    unawaited(ReleaseRadarService().handlePush(message.data, notify: false));
    ReleaseRadarService().openFromPush();
  }

  /// One at a time, in order.
  Future<void> _sync() {
    return _queue = _queue.then((_) => _register()).catchError((Object e) {
      _log.fine('push registration skipped: $e');
    });
  }

  Future<void> _register() async {
    final user = FirebaseService().currentUser;
    if (user == null) return;
    final fid = _fid;
    if (fid == null || fid.isEmpty) {
      // Signed in again after unregister(): onRegistered brings it back here.
      await FirebaseMessaging.instance.register();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final lang = ReleaseRadarService.languageFromPrefs(prefs).code;
    final notify = ReleaseRadarService.notifyFromPrefs(prefs);
    final platform = Platform.isIOS ? 'ios' : 'android';

    // Written only when something changed, or once a day to confirm it.
    final fingerprint = '${user.uid}|$fid|$lang|$notify|$platform';
    final at = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_registeredAtKey) ?? 0);
    if (prefs.getString(_registeredKey) == fingerprint &&
        DateTime.now().difference(at) < _confirmEvery) {
      return;
    }

    await _deviceDoc(user.uid, _deviceId(prefs)).set({
      'fid': fid,
      'platform': platform,
      'lang': lang,
      'notify': notify,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_writeTimeout);
    await prefs.setString(_registeredKey, fingerprint);
    await prefs.setInt(_registeredAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Before signing out or deleting the account (while still allowed to):
  /// this phone stops getting the account's pushes. It's unregistered from
  /// FCM too, so a removal that couldn't reach the server can't leave it
  /// getting them.
  Future<void> unregister() async {
    if (!isSupported) return;
    await _queue;
    final user = FirebaseService().currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registeredKey);
    await prefs.remove(_registeredAtKey);
    try {
      await _deviceDoc(user.uid, _deviceId(prefs)).delete().timeout(const Duration(seconds: 5));
    } catch (e) {
      _log.fine('device removal skipped: $e');
    }
    try {
      _fid = null;
      await FirebaseMessaging.instance.unregister().timeout(const Duration(seconds: 5));
    } catch (e) {
      _log.fine('FCM unregister skipped: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _deviceDoc(String uid, String deviceId) =>
      FirebaseService().db.collection('users').doc(uid).collection('devices').doc(deviceId);

  /// This install's id: random, kept in preferences (a reinstall is a new device).
  static String _deviceId(SharedPreferences prefs) {
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.length >= 8) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final id = List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
    unawaited(prefs.setString(_deviceIdKey, id));
    return id;
  }

  @visibleForTesting
  static String deviceIdForTesting(SharedPreferences prefs) => _deviceId(prefs);
}
