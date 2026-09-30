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
import 'providers/connectivity_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
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
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(storage: StorageService()),
        ),
        ChangeNotifierProxyProvider2<LibraryProvider, ConnectivityProvider, AudioProvider>(
          create: (_) => AudioProvider(),
          update: (_, library, connectivity, audio) {
            audio ??= AudioProvider();
            audio.setConnectivityProvider(connectivity);
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
  String? _connectedUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const _CyberLoadingScreen();
    }

    if (auth.isLoggedIn) {
      final uid = auth.uid;
      if (uid != null && !auth.isGuest && _connectedUid != uid) {
        _connectedUid = uid;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<LibraryProvider>().connectToFirestore(uid);
          }
        });
      }
      return const MainNavigationScreen();
    }

    if (_connectedUid != null) {
      _connectedUid = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<LibraryProvider>().disconnectFirestore();
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
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Cyber grid background
          Positioned.fill(
            child: CustomPaint(painter: const _LoadingGridPainter()),
          ),

          // Ambient neon glow in background
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.22),
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.65, 1.0],
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
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 50,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        blurRadius: 80,
                        spreadRadius: 20,
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
                      end: const Offset(1.05, 1.05),
                      duration: 1400.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 36),

                // App Title — TSUKI white, TUNES crimson (matching login)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TSUKI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textBright,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TUNES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color: AppColors.accent.withValues(alpha: 0.65),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Subtitle with decorative lines
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 1.2,
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.loadingSubtitle,
                      style: locale.getTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 1.2,
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Cyber Equalizer Bars
                const _CyberEqualizer(),
                const SizedBox(height: 24),

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

class _LoadingGridPainter extends CustomPainter {
  const _LoadingGridPainter();

  static final Paint _linePaint = Paint()
    ..color = const Color(0x08FFFFFF)
    ..strokeWidth = 0.5;

  static final Paint _crossPaint = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.1)
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);
    }
    const crossSize = 3.0;
    for (double x = spacing; x < size.width; x += spacing * 2) {
      for (double y = spacing; y < size.height; y += spacing * 2) {
        canvas.drawLine(Offset(x - crossSize, y), Offset(x + crossSize, y), _crossPaint);
        canvas.drawLine(Offset(x, y - crossSize), Offset(x, y + crossSize), _crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingGridPainter oldDelegate) => false;
}

