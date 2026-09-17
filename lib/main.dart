import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/cyber_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/library_provider.dart';
import 'providers/search_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
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

  runApp(const TsukiTunesApp());
}

class TsukiTunesApp extends StatelessWidget {
  const TsukiTunesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(storage: StorageService()),
        ),
        ChangeNotifierProxyProvider<LibraryProvider, AudioProvider>(
          create: (_) => AudioProvider(),
          update: (_, library, audio) {
            audio ??= AudioProvider();
            audio.onTrackStarted = (track) {
              library.addRecentTrack(track);
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
  bool? _initialLoggedIn;
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await StorageService().hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading || _hasCompletedOnboarding == null) {
      return const _CyberLoadingScreen();
    }

    if (_hasCompletedOnboarding == false) {
      return OnboardingScreen(
        onComplete: () {
          if (mounted) {
            setState(() {
              _hasCompletedOnboarding = true;
            });
          }
        },
      );
    }

    _initialLoggedIn ??= auth.isLoggedIn;

    if (_initialLoggedIn == true) {
      if (auth.uid != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<LibraryProvider>().connectToFirestore(auth.uid!);
          }
        });
      }
      return const MainNavigationScreen();
    }

    return const LoginScreen();
  }
}

class _CyberLoadingScreen extends StatelessWidget {
  const _CyberLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Ambient neon glow in background
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cyber Oni Mecha Mask with breathing pulse animation
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/cyber_oni_clean.png',
                    fit: BoxFit.contain,
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.04, 1.04),
                      duration: 1400.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 32),

                // App Title with Cyberpunk Glow
                Text(
                  'TSUKI TUNES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBright,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.7),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  strings.loadingSubtitle,
                  style: locale.getTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 36),

                // Cyber Equalizer Bars
                const _CyberEqualizer(),
                const SizedBox(height: 22),

                // Status Terminal Text
                Text(
                  strings.loadingStatus,
                  style: locale.getTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.35, end: 1.0, duration: 800.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberEqualizer extends StatelessWidget {
  const _CyberEqualizer();

  @override
  Widget build(BuildContext context) {
    const delays = [0, 200, 450, 150, 320];
    const heights = [14.0, 24.0, 32.0, 20.0, 14.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.5),
          child: Container(
            width: 3.5,
            height: heights[index],
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.7),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
                delay: delays[index].ms,
              )
              .scaleY(
                begin: 0.25,
                end: 1.0,
                duration: 550.ms,
                curve: Curves.easeInOut,
                alignment: Alignment.bottomCenter,
              ),
        );
      }),
    );
  }
}

