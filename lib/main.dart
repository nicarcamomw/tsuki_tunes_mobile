import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerState, ConsumerStatefulWidget, ProviderContainer, UncontrolledProviderScope;

import 'core/constants/app_colors.dart';
import 'core/theme/cyber_theme.dart';
import 'data/datasources/auto_media_library.dart';
import 'data/datasources/deezer_disk_cache.dart';
import 'data/datasources/firebase_service.dart';
import 'data/datasources/home_widget_service.dart';
import 'data/datasources/media_session_handler.dart';
import 'data/datasources/release_radar_service.dart';
import 'data/datasources/storage_service.dart';
import 'di/injection.dart';
import 'domain/usecases/playback/play_track.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/mask_collection_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/state/app_providers.dart';
import 'presentation/state/audio_provider.dart';
import 'presentation/widgets/mask_unlock_banner.dart';
import 'presentation/widgets/moon_atmosphere.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // debugPrint also writes to the system log in release builds, where any
  // app with log access (or a bug report) could read songs, searches and
  // request URLs. Errors still reach Crashlytics.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();
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
  // Built here, not in the widget tree: when Android Auto starts the app
  // there is no screen, so no widgets (and no providers) get built, yet the
  // car still needs the player.
  _audio;
  runApp(const TsukiTunesApp());
  _deferredInit();
}

/// The app's state (see providers/app_providers.dart). Created before
/// runApp so the player exists even when Android Auto starts the app with
/// no screen and no widget tree.
final appContainer = ProviderContainer();

/// The app's one player.
AudioProvider get _audio => appContainer.read(audioProvider);

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
        play: (track, queue) => getIt<PlayTrack>()(track, queue: queue),
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
    final c = appContainer;
    // Built at launch, not on first use: the player gets its links to the
    // rest of the app, and shake-to-skip listens from the start.
    c.read(playbackWiringProvider);
    c.read(shakeSkipProvider);
    return UncontrolledProviderScope(
      container: c,
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
    return const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast);
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  String? _connectedUid;
  bool? _hasCompletedOnboarding;
  bool _onboardingChecked = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

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
              ref.read(libraryProvider).connectToFirestore(uid);
              final playlists = ref.read(playlistProvider);
              final guestUid = auth.takeGuestUidToMigrate();
              playlists.connectToFirestore(uid).then((_) {
                if (guestUid != null) playlists.importGuestPlaylists(guestUid);
              });
            } else {
              ref.read(playlistProvider).initLocalOnly(uid);
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
          ref.read(libraryProvider).disconnectFirestore();
          ref.read(playlistProvider).disconnectFirestore();
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
    return const Scaffold(backgroundColor: Color(0xFF181B22));
  }
}
