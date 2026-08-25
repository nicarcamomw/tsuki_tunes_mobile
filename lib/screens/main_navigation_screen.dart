import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _lastShownError;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final hasTrack = audio.currentTrack != null;

    final spotifyError = audio.lastSpotifyError;
    if (spotifyError != null && spotifyError != _lastShownError) {
      _lastShownError = spotifyError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(spotifyError, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Navigator for detail screens that sit below the mini player
          Positioned.fill(
            child: Navigator(
              key: appNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => IndexedStack(
                  index: _currentIndex,
                  children: _screens
                      .map((s) => RepaintBoundary(child: s))
                      .toList(),
                ),
              ),
            ),
          ),

          // Mini Player + Bottom Nav always on top
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTrack) const MiniPlayer(),
                _buildCyberBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_filled,
                label: 'HOME',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.search,
                label: 'SEARCH',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.library_music,
                label: 'LIBRARY',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) {
          // Pop to root if tapping same tab
          appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        } else {
          setState(() => _currentIndex = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 14,
                height: 2,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGlow,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
