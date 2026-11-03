import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/crash_reporter.dart';
import 'package:tsuki_tunes_mobile/data/datasources/device_integrity.dart';
import 'package:tsuki_tunes_mobile/data/datasources/product_analytics.dart';

class _Reports implements CrashReporterBackend {
  final keys = <String, Object>{};

  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> recordNonFatal(Object error, StackTrace stack, String reason) async {}
}

class _Analytics implements AnalyticsBackend {
  final events = <String, Map<String, Object>>{};

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async =>
      events[name] = parameters;

  @override
  Future<void> logScreen(String name) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tsuki.tsuki_tunes_mobile/device');
  late _Reports reports;
  late _Analytics analytics;
  Object? answer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    answer = {'rooted': true, 'emulator': false, 'signals': 'su,root_app'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'integrity');
      if (answer is Exception) throw answer!;
      return answer;
    });
    CrashReporter.instance.resetForTesting();
    reports = _Reports();
    CrashReporter.instance.attach(reports);
    ProductAnalytics.instance.resetForTesting();
    analytics = _Analytics();
    await ProductAnalytics.instance.attach(analytics, collect: true);
  });

  test('a rooted phone is noted in crash reports and counted once', () async {
    await DeviceIntegrity.report(android: true);
    await Future<void>.delayed(Duration.zero);

    expect(reports.keys['device_rooted'], true);
    expect(reports.keys['device_emulator'], false);
    expect(reports.keys['device_root_signals'], 'su,root_app');
    expect(analytics.events['device_integrity'], {'rooted': true, 'emulator': false});

    analytics.events.clear();
    await DeviceIntegrity.report(android: true);
    expect(analytics.events, isEmpty, reason: 'once per install');
    expect(reports.keys['device_rooted'], true, reason: 'crash keys every launch');
  });

  test('not on Android, or no answer: nothing is reported', () async {
    await DeviceIntegrity.report(android: false);
    answer = PlatformException(code: 'unavailable');
    await DeviceIntegrity.report(android: true);
    await Future<void>.delayed(Duration.zero);

    expect(reports.keys.keys.where((k) => k.startsWith('device_')), isEmpty);
    expect(analytics.events, isEmpty);
  });
}
