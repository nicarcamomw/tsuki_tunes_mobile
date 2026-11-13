import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, UncontrolledProviderScope;
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_environment.dart';
import 'core/logger.dart';
import 'core/theme/cyber_theme.dart';
import 'data/datasources/audio_precache_service.dart';
import 'data/datasources/auto_media_library.dart';
import 'data/datasources/crash_reporter.dart';
import 'data/datasources/deezer_disk_cache.dart';
import 'data/datasources/device_integrity.dart';
import 'data/datasources/feature_flags.dart';
import 'data/datasources/firebase_service.dart';
import 'data/datasources/home_widget_service.dart';
import 'data/datasources/media_session_handler.dart';
import 'data/datasources/perf_tracker.dart';
import 'data/datasources/playback_log.dart';
import 'data/datasources/product_analytics.dart';
import 'data/datasources/push_radar_service.dart';
import 'data/datasources/release_radar_service.dart';
import 'data/datasources/storage_service.dart';
import 'di/injection.dart';
import 'domain/usecases/playback/play_track.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/screens/ascension_screen.dart';
import 'presentation/screens/mask_collection_screen.dart';
import 'presentation/state/app_providers.dart';
import 'presentation/state/audio_provider.dart';
import 'presentation/widgets/haptics.dart';
import 'presentation/widgets/mask_unlock_banner.dart';
import 'presentation/widgets/moon_atmosphere.dart';


final _log = Log.named('main');

void main() async {
  // debugPrint also writes to the system log in release builds, where any
  // app with log access (or a bug report) could read songs, searches and
  // request URLs. Errors still reach Crashlytics.
  // Playback events are also kept in memory (PlaybackLog) so the user can
  // copy them from settings when something goes wrong.
  final systemPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    PlaybackLog.instance.capture(message);
    if (!kReleaseMode) systemPrint(message, wrapWidth: wrapWidth);
  };
  WidgetsFlutterBinding.ensureInitialized();
  Log.init();
  // Data sources, repositories and use cases (see di/injection.dart).
  configureDependencies();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgDeep,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: AppColors.border,
    ),
  );

  // Only Firebase.initializeApp() before first frame — AuthProvider needs it
  // but Crashlytics, AppCheck, disk cache and media session can wait.
  await _initFirebaseCore();
  // Before runApp: where release pushes go while the app is in the background.
  PushRadarService.registerBackgroundHandler();
  // Built here, not in the widget tree: when Android Auto starts the app
  // there is no screen, so no widgets (and no providers) get built, yet the
  // car still needs the player.
  _audio;
  // The user's vibration choice; until it's read the app vibrates.
  unawaited(Haptics.load());
  runApp(const TsukiTunesApp());
  _deferredInit();
}

/// The app's state (see providers/app_providers.dart). Created before
/// runApp so the player exists even when Android Auto starts the app with
/// no screen and no widget tree.
final appContainer = ProviderContainer();

/// The routes; the session decides the first screen (see app_router.dart).
final GoRouter appRouter = createAppRouter(appContainer.read(sessionGateProvider));

/// The app's one player.
AudioProvider get _audio => appContainer.read(audioProvider);

/// Minimal pre-frame Firebase init: just Firebase.initializeApp() so
/// AuthProvider (which calls FirebaseService().initialize()) can proceed.
Future<void> _initFirebaseCore() async {
  if (kIsWeb) return;
  try {
    await FirebaseService().initializeCore();
    // Not awaited: the last fetched values apply in a moment, new ones
    // whenever they arrive; the player follows them (FeatureFlags).
    unawaited(FeatureFlags().start());
  } catch (e) {
    _log.severe('Firebase core init failed: $e');
  }
}

/// Everything that doesn't need to block the first frame.
void _deferredInit() {
  var started = false;
  Future<void> start() async {
    if (started) return;
    started = true;
    final mediaFuture = _initMediaSession();
    await Future.wait([
      _initCrashReporting(),
      DeezerDiskCache().init(),
      AudioPrecacheService().init(),
      mediaFuture,
    ]);
    final handler = await mediaFuture;
    if (handler != null) {
      // Album art for Android Auto's lists, served by ArtworkProvider.
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final info = await PackageInfo.fromPlatform();
          AutoArtwork.authority = '${info.packageName}.artwork';
        } catch (_) {}
      }
      _audio.attachDeferredMediaHandler(handler);
      handler.library = AutoMediaLibrary(
        // The app's storage: the library lives in its database.
        storage: getIt<StorageService>(),
        play: (track, queue) => getIt<PlayTrack>()(track, queue: queue),
      );
    }
    // Rooted phone or emulator: only reported (Crashlytics, analytics).
    unawaited(DeviceIntegrity.report());
    unawaited(ReleaseRadarService().initForeground());
    unawaited(PushRadarService().init());
    unawaited(HomeWidgetService().initialize());
    unawaited(HomeWidgetService().registerInteractivityCallback());
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => start());
  // No frame ever comes when Android Auto starts the app without a screen.
  Timer(const Duration(seconds: 1), start);
}

/// Sends uncaught Flutter and async errors to Crashlytics, with the state of
/// playback and the events before them (CrashReporter). Collection is off
/// in debug builds so development crashes don't pollute the dashboard.
Future<void> _initCrashReporting() async {
  if (kIsWeb) return;
  try {
    await FirebaseService().initialize();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    CrashReporter.instance
      ..setKey('env', isDevEnvironment ? 'dev' : 'prod')
      ..attach(CrashlyticsBackend(crashlytics));
    // Timings of what users wait on (PerfTracker), off in debug like crashes.
    final performance = FirebasePerformance.instance;
    await performance.setPerformanceCollectionEnabled(!kDebugMode);
    PerfTracker.instance.attach(FirebasePerfBackend(performance));
    // Product events (ProductAnalytics): nothing from debug builds, and
    // only while the user leaves usage statistics on in the settings.
    await ProductAnalytics.instance.attach(
        FirebaseAnalyticsBackend(FirebaseAnalytics.instance),
        collect: !kDebugMode);
  } catch (e) {
    _log.severe('Crashlytics init failed: $e');
  }
}

/// Lock screen / notification / headset controls. If the platform side is
/// misconfigured the app still runs, just without system media controls.
Future<TsukiAudioHandler?> _initMediaSession() async {
  try {
    return await AudioService.init(
      builder: () => TsukiAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tsuki.tsuki_tunes_mobile.playback',
        androidNotificationChannelName: 'Tsuki Tunes',
        // F-02: the mask's silhouette in the status bar (the colour launcher
        // icon, the default, is drawn as a white blob there).
        androidNotificationIcon: 'mipmap/ic_launcher_monochrome',
        // Keeping the service in the foreground while paused avoids
        // ForegroundServiceStartNotAllowedException when resuming from the
        // background on Android 12+.
        androidStopForegroundOnPause: false,
        // Android Auto: songs as a list, folders as a grid, voice search.
        androidBrowsableRootExtras: {
          'android.media.browse.SEARCH_SUPPORTED': true,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
        },
      ),
    );
  } catch (e) {
    _log.severe('AudioService init failed, no system media controls: $e');
    return null;
  }
}

class TsukiTunesApp extends StatelessWidget {
  const TsukiTunesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appContainer;
    // Built at launch, not on first use: the player gets its links to the
    // rest of the app, and shake-to-skip listens from the start.
    c.read(playbackWiringProvider);
    c.read(shakeSkipProvider);
    c.read(profileControllerProvider);
    return UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: appRouter,
        title: 'Tsuki Tunes',
        debugShowCheckedModeBanner: false,
        theme: CyberTheme.darkTheme,
        scrollBehavior: const _SmoothScrollBehavior(),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final clampedScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 0.8,
            maxScaleFactor: 2.0,
          );
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: clampedScaler),
            child: MaskUnlockLayer(
              onOpenCollection: () {
                final nav = rootNavigatorKey.currentContext;
                if (nav != null) MaskCollectionScreen.open(nav);
              },
              child: AscensionPrompt(child: MoonAtmosphere(child: child!)),
            ),
          );
        },
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast);
  }
}
