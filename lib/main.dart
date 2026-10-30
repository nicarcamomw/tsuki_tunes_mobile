import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/cyber_theme.dart';
import 'providers/ambient_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/library_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/mask_provider.dart';
import 'providers/moon_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/run_provider.dart';
import 'providers/search_provider.dart';
import 'providers/shake_skip_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/mask_collection_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auto_media_library.dart';
import 'services/deezer_disk_cache.dart';
import 'services/firebase_service.dart';
import 'services/home_widget_service.dart';
import 'services/media_session_handler.dart';
import 'services/play_history.dart';
import 'services/release_radar_service.dart';
import 'services/storage_service.dart';
import 'services/tile_channel_service.dart';
import 'widgets/mask_unlock_banner.dart';
import 'widgets/moon_atmosphere.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // debugPrint also writes to the system log in release builds, where any
  // app with log access (or a bug report) could read songs, searches and
  // request URLs. Errors still reach Crashlytics.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

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
  // Built here, not in the widget tree: when Android Auto starts the app
  // there is no screen, so no widgets (and no providers) get built, yet the
  // car still needs the player.
  _audio;
  runApp(const TsukiTunesApp());
  _deferredInit();
}

/// The app's one player; the widget tree gets it through its provider.
final AudioProvider _audio = AudioProvider();

/// Minimal pre-frame Firebase init: just Firebase.initializeApp() so
/// AuthProvider (which calls FirebaseService().initialize()) can proceed.
Future<void> _initFirebaseCore() async {
  if (kIsWeb) return;
  try {
    await FirebaseService().initializeCore();
  } catch (e) {
    debugPrint('[main] Firebase core init failed: $e');
  }
}

/// Everything that doesn't need to block the first frame.
void _deferredInit() {
  var started = false;
  Future<void> start() async {
    if (started) return;
    started = true;
    final mediaFuture = _initMediaSession();
    await Future.wait([_initCrashReporting(), DeezerDiskCache().init(), mediaFuture]);
    final handler = await mediaFuture;
    if (handler != null) {
      _audio.attachDeferredMediaHandler(handler);
      handler.library = AutoMediaLibrary(
        play: (track, queue) => _audio.playTrack(track, newQueue: queue),
      );
    }
    unawaited(ReleaseRadarService().initForeground());
    unawaited(HomeWidgetService().initialize());
    unawaited(HomeWidgetService().registerInteractivityCallback());
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => start());
  // No frame ever comes when Android Auto starts the app without a screen.
  Timer(const Duration(seconds: 1), start);
}

/// Sends uncaught Flutter and async errors to Crashlytics. Collection is off
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
  } catch (e) {
    debugPrint('[main] Crashlytics init failed: $e');
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
    debugPrint('[main] AudioService init failed, no system media controls: $e');
    return null;
  }
}

class TsukiTunesApp extends StatelessWidget {
  const TsukiTunesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) {
          final library = LibraryProvider();
          library.addListener(() {
            ReleaseRadarService().watchArtists(library.followedArtists);
          });
          return library;
        }),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(storage: StorageService()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AmbientProvider(
            labelFor: (sound) => ctx.read<LocaleProvider>().strings.ambientName(sound),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MaskProvider>(
          create: (_) => MaskProvider(),
          update: (_, auth, masks) =>
              masks!..setUser(auth.isAuthenticated ? auth.uid : null),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MoonProvider()
            ..onEclipseSeen = () => ctx.read<MaskProvider>().onEclipseSeen(),
        ),
        ChangeNotifierProvider(create: (_) => PlayHistory()..load()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProxyProvider5<LibraryProvider, ConnectivityProvider, AmbientProvider,
            PlayHistory, MaskProvider, AudioProvider>(
          create: (_) => _audio,
          update: (_, library, connectivity, ambient, history, masks, audio) {
            final player = audio ?? AudioProvider();
            player.setConnectivityProvider(connectivity);
            player.onPlayCounted = (track) {
              history.record(track);
              masks.onPlayCounted(track);
              library.recordPlay(track);
            };
            player.onTrackCompleted = masks.onTrackCompleted;
            player.onSleepTimerFinished = ambient.onSleepTimerFinished;
            player.onAmbientPlay = ambient.resumeAll;
            player.onAmbientPause = ambient.pauseAll;
            player.onAmbientStop = ambient.stopAll;
            ambient.onMediaStateChanged = player.setAmbientMediaState;
            masks.isMusicPlaying = () => player.isPlaying;
            masks.isRainPlaying = () =>
                ambient.isPlaying &&
                (ambient.isOn(AmbientSound.rain) || ambient.isOn(AmbientSound.storm));
            if (library.listenedTracksLoaded && !masks.artistsSeeded) {
              masks.seedKnownArtists([
                ...library.listenedTracks.map((t) => t.artistName),
                ...library.favoriteArtists.map((a) => a.name),
              ]);
            }
            player.onTrackStarted = (track) {
              library.addRecentTrack(track);
              masks.onTrackStarted(track);
            };
            player.onListenedThreshold = (track) {
              if (!library.isTrackListened(track.id)) library.markTrack(track);
            };
            if (audio != null) TileChannelService.init(audio);
            return player;
          },
        ),
        ChangeNotifierProxyProvider2<AudioProvider, LibraryProvider, RunProvider>(
          create: (_) => RunProvider(),
          update: (_, audio, library, run) => run!..attach(audio, library),
        ),
        ChangeNotifierProxyProvider2<AudioProvider, RunProvider, ShakeSkipProvider>(
          // Not lazy: it has to listen from launch once switched on.
          lazy: false,
          create: (_) => ShakeSkipProvider(),
          update: (_, audio, run, shake) => shake!..attach(audio, run),
        ),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
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
              child: MoonAtmosphere(child: child!),
            ),
          );
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _connectedUid;
  bool? _hasCompletedOnboarding;
  bool _onboardingChecked = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const _CyberLoadingScreen();
    }

    if (auth.isLoggedIn) {
      final uid = auth.uid;
      if (uid != null && _connectedUid != uid) {
        _connectedUid = uid;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (!auth.isGuest) {
              context.read<LibraryProvider>().connectToFirestore(uid);
              final playlists = context.read<PlaylistProvider>();
              final guestUid = auth.takeGuestUidToMigrate();
              playlists.connectToFirestore(uid).then((_) {
                if (guestUid != null) playlists.importGuestPlaylists(guestUid);
              });
            } else {
              context.read<PlaylistProvider>().initLocalOnly(uid);
            }
          }
        });
      }

      if (!_onboardingChecked) {
        _onboardingChecked = true;
        StorageService().hasCompletedOnboarding().then((completed) {
          if (mounted) {
            setState(() => _hasCompletedOnboarding = completed);
          }
        });
        return const _CyberLoadingScreen();
      }

      if (_hasCompletedOnboarding == null) {
        return const _CyberLoadingScreen();
      }

      if (!_hasCompletedOnboarding!) {
        return const OnboardingScreen();
      }

      return const MainNavigationScreen();
    }

    if (_connectedUid != null) {
      _connectedUid = null;
      _onboardingChecked = false;
      _hasCompletedOnboarding = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<LibraryProvider>().disconnectFirestore();
          context.read<PlaylistProvider>().disconnectFirestore();
        }
      });
    }

    return const LoginScreen();
  }
}

class _CyberLoadingScreen extends StatelessWidget {
  const _CyberLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF181B22),
    );
  }
}

