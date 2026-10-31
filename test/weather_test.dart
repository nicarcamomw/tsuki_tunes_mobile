import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/ambient_provider.dart';
import 'package:tsuki_tunes_mobile/providers/app_providers.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/providers/moon_provider.dart';
import 'package:tsuki_tunes_mobile/providers/weather_provider.dart';
import 'package:tsuki_tunes_mobile/services/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/services/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/services/device_location.dart';
import 'package:tsuki_tunes_mobile/services/rain_mix.dart';
import 'package:tsuki_tunes_mobile/services/weather_service.dart';
import 'package:tsuki_tunes_mobile/widgets/sky_line.dart';
import 'package:tsuki_tunes_mobile/widgets/weather_sheet.dart';

import 'helpers/test_scope.dart';

String _forecast({int code = 61, double temp = 14.3, int isDay = 1, String time = '2026-10-26T17:15'}) =>
    jsonEncode({
      'latitude': -33.44,
      'longitude': -70.66,
      'current': {
        'time': time,
        'interval': 900,
        'temperature_2m': temp,
        'weather_code': code,
        'is_day': isDay,
        'precipitation': code >= 51 ? 0.6 : 0.0,
      },
    });

const _places = '''
{"results":[
  {"id":3871336,"name":"Santiago","latitude":-33.45694,"longitude":-70.64827,"country":"Chile","admin1":"Santiago Metropolitan"},
  {"id":3109642,"name":"Santiago de Compostela","latitude":42.88052,"longitude":-8.54569,"country":"España","admin1":"Galicia"}
]}
''';

class _FakeLocation implements LocationSource {
  LocationResult result;
  int asks = 0;
  _FakeLocation(this.result);

  @override
  Future<LocationResult> approximate({bool ask = false}) async {
    if (ask) asks++;
    return result;
  }

  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

class _Api {
  int code = 61;
  bool online = true;
  final List<Uri> calls = [];

  http.Client get client => MockClient((req) async {
        calls.add(req.url);
        if (!online) throw const SocketExceptionLike();
        if (req.url.host.startsWith('geocoding')) return http.Response(_places, 200);
        return http.Response(_forecast(code: code), 200);
      });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

Track _t(String id, {String artist = 'A'}) => Track(
      id: id,
      title: 'Song $id',
      artistId: artist,
      artistName: artist,
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: 'https://example.com/$id.mp3',
      durationSeconds: 30,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async {
        if (call.method == 'init') {
          final id = call.arguments['id'];
          for (final kind in ['methods', 'events', 'data']) {
            messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.$kind.$id'),
              (_) async => kind == 'methods' ? {} : null,
            );
          }
        }
        return {};
      },
    );
  });

  group('Open-Meteo', () {
    test('reads the current weather', () {
      final w = WeatherService.parseCurrent(_forecast(), now: DateTime(2026, 10, 26, 17, 20))!;
      expect(w.sky, Sky.rain);
      expect(w.isRaining, isTrue);
      expect(w.temperature, 14.3);
      expect(w.isDay, isTrue);
      expect(w.localTime, DateTime(2026, 10, 26, 17, 15));
      expect(WeatherNow.fromJson(jsonDecode(jsonEncode(w.toJson())))!.sky, Sky.rain);
      expect(WeatherService.parseCurrent('{"error":true}', now: DateTime(2026)), isNull);
    });

    test('maps WMO codes to skies', () {
      expect(WeatherService.skyFor(0), Sky.clear);
      expect(WeatherService.skyFor(2), Sky.cloudy);
      expect(WeatherService.skyFor(45), Sky.fog);
      expect(WeatherService.skyFor(53), Sky.drizzle);
      expect(WeatherService.skyFor(81), Sky.rain);
      expect(WeatherService.skyFor(75), Sky.snow);
      expect(WeatherService.skyFor(95), Sky.storm);
      expect(WeatherService.skyFor(12345), Sky.cloudy);
    });

    test('only rounded coordinates leave the phone', () {
      final uri = WeatherService.forecastUri(-33.456941234, -70.648271234);
      expect(uri.queryParameters['latitude'], '-33.46');
      expect(uri.queryParameters['longitude'], '-70.65');
      expect(uri.queryParameters['timezone'], 'auto');
      expect(uri.queryParameters['current'], contains('weather_code'));
    });

    test('finds cities with region and country', () {
      final p = WeatherService.parsePlaces(_places);
      expect(p.first.name, 'Santiago');
      expect(p.first.detail, 'Santiago Metropolitan, Chile');
      expect(p[1].detail, 'Galicia, España');
      expect(WeatherService.parsePlaces('{}'), isEmpty);
    });

    test('day parts', () {
      expect(WeatherService.dayPart(DateTime(2026, 1, 1, 3)), DayPart.lateNight);
      expect(WeatherService.dayPart(DateTime(2026, 1, 1, 6)), DayPart.morning);
      expect(WeatherService.dayPart(DateTime(2026, 1, 1, 12)), DayPart.afternoon);
      expect(WeatherService.dayPart(DateTime(2026, 1, 1, 20)), DayPart.night);
    });

    test('phrases read naturally in every language', () {
      const es = AppStrings(AppLanguage.es);
      expect(es.skyPhrase(DayPart.afternoon, Sky.rain, isDay: true), 'Tarde lluviosa');
      expect(es.skyPhrase(DayPart.afternoon, Sky.clear, isDay: true), 'Tarde soleada');
      expect(es.skyPhrase(DayPart.night, Sky.clear, isDay: false), 'Noche despejada');
      expect(es.skyPhrase(DayPart.night, Sky.storm, isDay: false), 'Noche de tormenta');
      const en = AppStrings(AppLanguage.en);
      expect(en.skyPhrase(DayPart.afternoon, Sky.rain, isDay: true), 'Rainy afternoon');
      expect(en.skyPhrase(DayPart.lateNight, Sky.clear, isDay: false), 'Clear night');
      const ja = AppStrings(AppLanguage.ja);
      expect(ja.skyPhrase(DayPart.night, Sky.rain, isDay: false), '雨の夜');
    });
  });

  group('weather provider', () {
    late _Api api;
    late _FakeLocation location;
    late DateTime now;

    WeatherProvider make() => WeatherProvider(
          service: WeatherService(client: api.client),
          location: location,
          clock: () => now,
          observeLifecycle: false,
        );

    setUp(() {
      api = _Api();
      location = _FakeLocation(const LocationResult(LocationStatus.ok, -33.4569, -70.6482));
      now = DateTime(2026, 10, 26, 17, 0);
    });

    test('is off until turned on, and asks nothing before that', () async {
      final w = make();
      await w.ready;
      expect(w.enabled, isFalse);
      await w.refresh(force: true);
      expect(api.calls, isEmpty);
      expect(location.asks, 0);
      w.dispose();
    });

    test('a denied permission keeps it off and says why', () async {
      location.result = const LocationResult(LocationStatus.denied);
      final w = make();
      await w.ready;
      expect(await w.useDeviceLocation(), LocationStatus.denied);
      expect(w.enabled, isFalse);
      expect(w.locationProblem, LocationStatus.denied);
      expect(api.calls, isEmpty);
      w.dispose();
    });

    test('approximate location: fetches, remembers and refreshes every half hour', () async {
      final w = make();
      await w.ready;
      expect(await w.useDeviceLocation(), LocationStatus.ok);
      expect(w.enabled, isTrue);
      expect(w.current?.sky, Sky.rain);
      expect(api.calls.single.queryParameters['latitude'], '-33.46');

      await w.refresh();
      expect(api.calls.length, 1, reason: 'fresh enough');
      now = now.add(const Duration(minutes: 31));
      await w.refresh();
      expect(api.calls.length, 2);
      w.dispose();

      final again = make();
      await again.ready;
      expect(again.enabled, isTrue, reason: 'remembered');
      expect(again.current?.sky, Sky.rain, reason: 'last reading kept for the next launch');
      again.dispose();
    });

    test('a chosen city needs no permission at all', () async {
      final w = make();
      await w.ready;
      final places = await w.searchPlaces('Santiago');
      await w.usePlace(places!.first);
      expect(location.asks, 0);
      expect(w.source, WeatherSource.place);
      expect(api.calls.last.queryParameters['latitude'], '-33.46');
      w.dispose();

      final again = make();
      await again.ready;
      expect(again.place?.name, 'Santiago');
      again.dispose();
    });

    test('offers music once per rain, then again only after a dry spell and a gap', () async {
      final w = make();
      await w.ready;
      await w.useDeviceLocation();
      expect(w.rainOffer, isTrue);

      await w.dismissRainOffer();
      expect(w.rainOffer, isFalse);
      now = now.add(const Duration(minutes: 40));
      await w.refresh();
      expect(w.rainOffer, isFalse, reason: 'same rain');

      api.code = 3; // dry
      now = now.add(const Duration(minutes: 40));
      await w.refresh();
      expect(w.rainOffer, isFalse);

      api.code = 63; // rain again, but too soon
      now = now.add(const Duration(minutes: 40));
      await w.refresh();
      expect(w.rainOffer, isFalse, reason: 'within the 3 h gap');

      now = now.add(const Duration(hours: 2));
      await w.refresh();
      expect(w.rainOffer, isTrue);
      w.dispose();
    });

    test('offline keeps the last reading and says so', () async {
      final w = make();
      await w.ready;
      await w.useDeviceLocation();
      api.online = false;
      now = now.add(const Duration(minutes: 31));
      await w.refresh();
      expect(w.offline, isTrue);
      expect(w.current?.sky, Sky.rain);
      now = now.add(const Duration(hours: 4));
      expect(w.current, isNull, reason: 'too old to show');
      w.dispose();
    });
  });

  group('rain mix', () {
    test("uses the listener's calm songs, winding down", () async {
      final lib = [for (var i = 0; i < 16; i++) _t('t$i', artist: 'A${i % 4}')];
      final tempos = {for (var i = 0; i < 16; i++) 't$i': 60.0 + i * 5}; // 60..135
      final mix = await RainMix.build(
        library: lib,
        artistNames: const [],
        bpm: BpmService(fetch: (id) async => TrackAudioInfo(bpm: tempos[id]!), gap: Duration.zero),
        search: (_) async => throw StateError('enough own songs'),
      );
      final bpms = [for (final t in mix) tempos[t.id]!];
      expect(bpms.every((b) => b <= RainMix.maxBpm), isTrue);
      expect(mix.length, 9);
      for (var i = 1; i < bpms.length; i++) {
        expect(bpms[i], lessThanOrEqualTo(bpms[i - 1]));
      }
    });

    test('tops up with calm songs by their own artists when there are few', () async {
      final queries = <String>[];
      final mix = await RainMix.build(
        library: [_t('own', artist: 'Ado')],
        artistNames: RainMix.artistsFrom([_t('own', artist: 'Ado')], ['Aimer']),
        bpm: BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 80), gap: Duration.zero),
        search: (q) async {
          queries.add(q);
          return [for (var i = 0; i < 3; i++) _t('${q.hashCode}-$i')];
        },
      );
      expect(queries, ['artist:"Aimer" bpm_min:"55" bpm_max:"100"', 'artist:"Ado" bpm_min:"55" bpm_max:"100"']);
      expect(mix.first.id, 'own');
      expect(mix.length, 7);
    });
  });

  group('widgets', () {
    late _Api api;
    late WeatherProvider weather;
    late MoonProvider moon;

    Future<void> pumpHome(WidgetTester tester, Widget child, {AudioProvider? audio}) async {
      tester.view.physicalSize = const Size(360 * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final app = MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryProvider()),
          weatherProvider.overrideWith((ref) => weather, disposeNotifier: false),
          moonProvider.overrideWith((ref) => moon, disposeNotifier: false),
          ambientProvider.overrideWith((ref) => AmbientProvider()),
          if (audio != null) audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
        ],
        child: app,
      ));
    }

    setUp(() {
      api = _Api();
    });

    testWidgets('the sky line reads time, weather and moon; off it offers to turn on',
        (tester) async {
      weather = WeatherProvider(
        service: WeatherService(client: api.client),
        location: _FakeLocation(const LocationResult(LocationStatus.ok, 1, 2)),
        clock: () => DateTime.now(),
        observeLifecycle: false,
      );
      moon = MoonProvider();
      await tester.runAsync(() => weather.ready);
      final at = DateTime(2026, 10, 26, 17, 30);
      await pumpHome(tester, SkyLine(clock: () => at));
      expect(find.textContaining('Tarde  ·  '), findsOneWidget);
      expect(find.text('CLIMA'), findsOneWidget);

      await tester.runAsync(() => weather.useDeviceLocation());
      await tester.pump();
      expect(find.textContaining('Tarde lluviosa  ·  14°  ·  '), findsOneWidget);
      expect(find.text('CLIMA'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      moon.dispose();
      weather.dispose();
    });

    testWidgets('rain falls behind the header only while it rains', (tester) async {
      weather = WeatherProvider(
        service: WeatherService(client: api.client),
        location: _FakeLocation(const LocationResult(LocationStatus.ok, 1, 2)),
        observeLifecycle: false,
      );
      moon = MoonProvider();
      await tester.runAsync(() => weather.ready);
      const header = SkyBackdrop(child: SizedBox(height: 120, width: double.infinity));
      await pumpHome(tester, header);
      expect(find.descendant(of: find.byType(SkyBackdrop), matching: find.byType(CustomPaint)),
          findsNothing);

      await tester.runAsync(() => weather.useDeviceLocation());
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.descendant(of: find.byType(SkyBackdrop), matching: find.byType(CustomPaint)),
          findsOneWidget);

      await tester.runAsync(() => weather.disable());
      await tester.pump();
      expect(find.descendant(of: find.byType(SkyBackdrop), matching: find.byType(CustomPaint)),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      moon.dispose();
      weather.dispose();
    });

    testWidgets('saying yes to the rain offer plays calm songs and answers the offer',
        (tester) async {
      weather = WeatherProvider(
        service: WeatherService(client: api.client),
        location: _FakeLocation(const LocationResult(LocationStatus.ok, 1, 2)),
        observeLifecycle: false,
      );
      moon = MoonProvider();
      final audio = (await tester.runAsync(() async {
        await weather.ready;
        await weather.useDeviceLocation();
        return AudioProvider();
      }))!;
      final calm = [for (var i = 0; i < 5; i++) _t('c$i', artist: 'X$i')];
      await pumpHome(
        tester,
        RainOfferCard(
          tempo: BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 70), gap: Duration.zero),
          search: (_) async => calm,
          library: [_t('own', artist: 'Mine')],
        ),
        audio: audio,
      );
      expect(find.text('Está lloviendo donde estás'), findsOneWidget);
      expect(find.text('¿Pongo algo para la lluvia?'), findsOneWidget);

      await tester.tap(find.text('Sí, ponlo'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(audio.queue.map((t) => t.id).toSet(), {'own', ...calm.map((t) => t.id)});
      expect(weather.rainOffer, isFalse);
      expect(find.text('Sonando: 6 canciones para la lluvia'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      moon.dispose();
      weather.dispose();
    });

    testWidgets('the sheet explains a denied permission and lets you pick a city',
        (tester) async {
      final location = _FakeLocation(const LocationResult(LocationStatus.denied));
      weather = WeatherProvider(
        service: WeatherService(client: api.client),
        location: location,
        observeLifecycle: false,
      );
      moon = MoonProvider();
      await tester.runAsync(() => weather.ready);
      await pumpHome(tester, const WeatherSheet());

      await tester.tap(find.text('Usar mi ubicación aproximada'));
      for (var k = 0; k < 5; k++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      expect(find.textContaining('Sin permiso de ubicación'), findsOneWidget);
      expect(weather.enabled, isFalse);

      await tester.enterText(find.byType(TextField), 'Santiago');
      await tester.pump(const Duration(milliseconds: 400));
      for (var k = 0; k < 5; k++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      expect(find.text('Santiago de Compostela'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Santiago'));
      for (var k = 0; k < 5; k++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      expect(weather.enabled, isTrue);
      expect(weather.source, WeatherSource.place);
      expect(find.textContaining('14°'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      moon.dispose();
      weather.dispose();
    });
  });
}
