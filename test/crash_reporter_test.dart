import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/crash_reporter.dart';

class FakeBackend implements CrashReporterBackend {
  final keys = <String, Object>{};
  final logs = <String>[];
  final issues = <String>[];

  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> recordNonFatal(Object error, StackTrace stack, String reason) async =>
      issues.add(reason);
}

void main() {
  final reporter = CrashReporter.instance;
  late FakeBackend backend;

  setUp(() {
    reporter.resetForTesting();
    backend = FakeBackend();
  });
  tearDown(reporter.resetForTesting);

  group('redact', () {
    test('song titles, artists and searches are blanked', () {
      expect(
        CrashReporter.redact('Spotify: searching "Toxicity" by "System of a Down"'),
        'Spotify: searching "…" by "…"',
      );
    });

    test('Spotify device names are blanked', () {
      expect(
        CrashReporter.redact('Spotify device: Nico\'s phone (Smartphone) active=true'),
        'Spotify device: …(Smartphone) active=true',
      );
      expect(
        CrashReporter.redact('Spotify: using active smartphone HONOR Magic5'),
        'Spotify: using active smartphone …',
      );
    });

    test('ids and technical state stay', () {
      const line = '[SpotifyCheck] is_playing=false progress_ms=0 item=spotify:track:abc';
      expect(CrashReporter.redact(line), line);
    });
  });

  test('keys set before Crashlytics starts are sent when it does', () {
    reporter.setKey('env', 'dev');
    expect(backend.keys, isEmpty);
    reporter.attach(backend);
    expect(backend.keys, {'env': 'dev'});
  });

  test('a key set again to the same value sends nothing', () {
    reporter.attach(backend);
    reporter.setKey('playback_mode', 'preview');
    backend.keys.clear();
    reporter.setKey('playback_mode', 'preview');
    expect(backend.keys, isEmpty);
    reporter.setKey('playback_mode', 'spotify_app_remote');
    expect(backend.keys, {'playback_mode': 'spotify_app_remote'});
  });

  test('breadcrumbs go out redacted', () {
    reporter.attach(backend);
    reporter.breadcrumb('[AudioProvider] "Aerials" queued in Spotify after this song');
    expect(backend.logs, ['[AudioProvider] "…" queued in Spotify after this song']);
  });

  test('the same issue is reported once per interval', () {
    reporter.attach(backend);
    reporter.issue('spotify_did_not_start');
    reporter.issue('spotify_did_not_start');
    reporter.issue('spotify_queue_refused');
    expect(backend.issues, ['spotify_did_not_start', 'spotify_queue_refused']);
  });

  test('nothing is sent before Crashlytics starts', () {
    reporter.breadcrumb('Spotify: something');
    reporter.issue('spotify_did_not_start');
    reporter.attach(backend);
    expect(backend.logs, isEmpty);
    expect(backend.issues, isEmpty);
  });
}
