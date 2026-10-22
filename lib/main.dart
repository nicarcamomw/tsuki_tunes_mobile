import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/cyber_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/media_session_handler.dart';
import 'services/storage_service.dart';

void main() async {
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

  runApp(TsukiTunesApp(mediaHandler: await _initMediaSession()));
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
      ),
    );
  } catch (e) {
    debugPrint('[main] AudioService init failed, no system media controls: $e');
    return null;
  }
}

class TsukiTunesApp extends StatelessWidget {
  final TsukiAudioHandler? mediaHandler;

  const TsukiTunesApp({super.key, this.mediaHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(storage: StorageService()),
        ),
        ChangeNotifierProxyProvider2<LibraryProvider, ConnectivityProvider, AudioProvider>(
          create: (_) => AudioProvider(mediaHandler: mediaHandler),
          update: (_, library, connectivity, audio) {
            audio ??= AudioProvider(mediaHandler: mediaHandler);
            audio.setConnectivityProvider(connectivity);
            audio.onTrackStarted = (track) {
              library.addRecentTrack(track);
            };
            audio.onListenedThreshold = (track) {
              if (!library.isTrackListened(track.id)) library.markTrack(track);
            };
            return audio;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Tsuki Tunes',
        debugShowCheckedModeBanner: false,
        theme: CyberTheme.darkTheme,
        scrollBehavior: const _SmoothScrollBehavior(),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final clampedScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 0.8,
            maxScaleFactor: 1.4,
          );
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: clampedScaler),
            child: child!,
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

