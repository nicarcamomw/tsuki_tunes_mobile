import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';
import '../navigation/app_router.dart';
import '../navigation/main_tab.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/locale_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/battery_guide_sheet.dart';
import '../widgets/cyber_nav_icon.dart';
import '../widgets/cyber_tab_indicator.dart';
import '../widgets/fade_indexed_stack.dart';
import '../widgets/haptics.dart';
import '../widgets/mini_player.dart';
import '../widgets/permission_primer.dart';
import '../widgets/playback_error_text.dart';
import '../widgets/tap_scale.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Canales de eventos para atajos táctiles de la barra de navegación (Double-Tap / Long-Press)
class NavigationEvents {
  static VoidCallback? onHomeScrollToTop;
  static VoidCallback? onHomeOpenProfile;
  static VoidCallback? onHomeRefresh;
  static VoidCallback? onSearchFocus;
  static VoidCallback? onSearchClear;
  static VoidCallback? onExploreScrollToTop;
  static VoidCallback? onLibraryScrollToTop;
  static void Function(MainTab)? switchTab;
  static final ValueNotifier<bool> isPlayerExpanded = ValueNotifier<bool>(false);
}

/// The main shell: the bottom bar, the mini player and the expanded
/// player around [child], the shell navigator go_router builds (the tabs
/// first, detail pages pushed over them).
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  // Running in the background is offered once 20 s of music have played,
  // with Tsuki on screen: by then the user cares about the music going on,
  // and a song isn't interrupted as it starts. Once a session at most.
  static const _backgroundOfferAfter = Duration(seconds: 20);
  Timer? _backgroundOfferTimer;
  bool _backgroundOffered = false;

  void _onPlayingChanged(bool playing) {
    if (_backgroundOffered) return;
    if (!playing) {
      _backgroundOfferTimer?.cancel();
      _backgroundOfferTimer = null;
      return;
    }
    _backgroundOfferTimer ??= Timer(_backgroundOfferAfter, () async {
      _backgroundOfferTimer = null;
      if (!mounted || _backgroundOffered || !ref.read(audioProvider).isPlaying) return;
      // Away (the car, a pocket): tried again the next time music plays.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      _backgroundOffered = true;
      await PermissionPrimer.offerBackgroundIfNeeded(context);
    });
  }

  final ValueNotifier<MainTab> _tabNotifier = ValueNotifier<MainTab>(MainTab.home);
  SpotifyFallbackReason? _lastShownError;
  PlaybackError? _lastShownPlaybackError;
  String? _lastShownSyncError;

  // Timestamps para detección de Double-Tap a 0 ms de latencia
  DateTime? _lastTapTime;
  MainTab? _lastTapTab;

  // Carga Perezosa (Lazy Loading): Tab 0 (Home) inicia montado; Search y Library se montan al visitarse
  final Set<MainTab> _loadedTabs = {MainTab.home};
  int? _lastSeenLibraryCount;

  // Manejo reactivo de Predictive Back para Android 13+ (inicializados inline para sobrevivir a hot-reloads)
  final ValueNotifier<bool> _canPopNotifier = ValueNotifier<bool>(true);

  // Compatibility getter to prevent hot-reload lookup failure from previous state
  // ignore: unused_element
  List<Widget> get _screens => const [];

  @override
  void initState() {
    super.initState();
    _tabNotifier.addListener(_updateCanPop);
    shellNavigatorObserver.onNavigationChanged = _updateCanPop;
    NavigationEvents.switchTab = _switchToTab;
    unawaited(ref.read(batteryGuideProvider).load());
  }

  void _switchToTab(MainTab tab) {
    _loadedTabs.add(tab);
    _tabNotifier.value = tab;
  }

  @override
  void reassemble() {
    super.reassemble();
    _tabNotifier.removeListener(_updateCanPop);
    _tabNotifier.addListener(_updateCanPop);
    _updateCanPop();
  }

  void _updateCanPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final canPop = _tabNotifier.value == MainTab.home &&
          !(appNavigatorKey.currentState?.canPop() ?? false);
      if (_canPopNotifier.value != canPop) {
        _canPopNotifier.value = canPop;
      }
    });
  }

  @override
  void dispose() {
    if (NavigationEvents.switchTab == _switchToTab) {
      NavigationEvents.switchTab = null;
    }
    if (shellNavigatorObserver.onNavigationChanged == _updateCanPop) {
      shellNavigatorObserver.onNavigationChanged = null;
    }
    _backgroundOfferTimer?.cancel();
    _tabNotifier.removeListener(_updateCanPop);
    _tabNotifier.dispose();
    _canPopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(audioProvider.select((a) => a.isPlaying), (_, playing) => _onPlayingChanged(playing));
    final (hasTrack, spotifyError, playbackError) =
        ref.watch(audioProvider.select(
            (a) => (a.currentTrack != null, a.lastSpotifyError, a.lastPlaybackError)));
    final syncError =
        ref.watch(libraryProvider.select((l) => l.lastSyncError));
    final isOnline = ref.watch(isOnlineProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final bottomBarHeight = (hasTrack ? 140.0 : 70.0) + bottomPadding;
    if (spotifyError == null) {
      _lastShownError = null;
    } else if (spotifyError != _lastShownError) {
      _lastShownError = spotifyError;
      // On phones known to freeze Spotify, a failed start comes with a guide
      // to let it run in the background.
      final offerBatteryGuide = ref.read(batteryGuideProvider).offerFor(spotifyError);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              action: offerBatteryGuide
                  ? SnackBarAction(
                      label: strings.batteryGuideAction,
                      textColor: AppColors.accent,
                      onPressed: () { Haptics.tap(); BatteryGuideSheet.show(context); },
                    )
                  : null,
              content: Row(
                children: [
                  Icon(offerBatteryGuide ? Icons.battery_alert_rounded : Icons.info_outline,
                      color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yPlaybackError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offerBatteryGuide
                          ? strings.batteryGuideSnack
                          : spotifyError.message(strings),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: bottomBarHeight + 12,
                left: 16,
                right: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              duration: Duration(seconds: offerBatteryGuide ? 8 : 4),
            ),
          );
        }
      });
    }

    if (playbackError == null) {
      _lastShownPlaybackError = null;
    } else if (playbackError != _lastShownPlaybackError) {
      _lastShownPlaybackError = playbackError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    playbackError == PlaybackError.network
                        ? Icons.wifi_off_rounded
                        : (playbackError == PlaybackError.noPreview
                            ? Icons.music_off_rounded
                            : Icons.error_outline),
                    color: AppColors.error,
                    size: 18,
                    semanticLabel: strings.a11yPlaybackError,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      playbackError.message(strings, isOnline: isOnline),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: bottomBarHeight + 12,
                left: 16,
                right: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(
                  color: AppColors.error,
                  width: 1.2,
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    // Sync error feedback — the user sees a toast when a mark/unmark failed.
    if (syncError == null) {
      _lastShownSyncError = null;
    } else if (syncError != _lastShownSyncError) {
      _lastShownSyncError = syncError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.sync_problem, color: AppColors.accent, size: 18, semanticLabel: strings.a11ySyncError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.syncError,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: bottomBarHeight + 12,
                left: 16,
                right: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _canPopNotifier,
      builder: (context, canPop, scaffoldChild) {
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final navigator = appNavigatorKey.currentState;
            if (navigator != null && navigator.canPop()) {
              navigator.pop();
            } else if (_tabNotifier.value != MainTab.home) {
              navigator?.popUntil((route) => route.isFirst);
              _loadedTabs.add(MainTab.home);
              _tabNotifier.value = MainTab.home;
            } else {
              SystemNavigator.pop();
            }
          },
          child: scaffoldChild!,
        );
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.bgDeep,
        body: Stack(
          children: [
            // Navigator with tab screens (reactivo con Lazy Loading)
            // Fix Bug 4: En caso de teclado abierto, el body toma la pantalla completa y SearchScreen gestiona su scroll
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              left: 0,
              right: 0,
              top: 0,
              bottom: isKeyboardOpen ? 0 : bottomBarHeight,
              child: MainTabsScope(
                tab: _tabNotifier,
                loadedTabs: _loadedTabs,
                child: widget.child,
              ),
            ),
            // Mini Player animado + Bottom Nav
            // Ocultar limpiamente hacia abajo cuando el teclado está activo o el reproductor está expandido
            // Offline banner
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Builder(
                builder: (context) {
                  final isOnline = ref.watch(isOnlineProvider);
                  return AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    offset: isOnline ? const Offset(0, -1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: isOnline ? 0.0 : 1.0,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          color: AppColors.error.withValues(alpha: 0.9),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off, size: 14, color: Colors.white, semanticLabel: strings.a11yOffline),
                              const SizedBox(width: 6),
                              Text(
                                strings.offline,
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.label,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: NavigationEvents.isPlayerExpanded,
                builder: (context, isExpanded, _) {
                  final shouldHide = isKeyboardOpen || isExpanded;
                  return AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    offset: shouldHide ? const Offset(0, 1.2) : Offset.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Deslizamiento fluido hacia abajo al pausar/cerrar (AnimatedSlide + AnimatedCrossFade)
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                          offset: hasTrack ? Offset.zero : const Offset(0, 0.4),
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            firstCurve: Curves.easeInOutCubic,
                            secondCurve: Curves.easeInOutCubic,
                            crossFadeState: hasTrack
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: const MiniPlayer(),
                            secondChild: const SizedBox(
                              width: double.infinity,
                              height: 0,
                            ),
                          ),
                        ),
                        _buildCyberBottomNav(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Desacoplado con ValueListenableBuilder para evitar rebuilds globales de Scaffold
  Widget _buildCyberBottomNav() {
    return ValueListenableBuilder<MainTab>(
      valueListenable: _tabNotifier,
      builder: (context, selected, _) {
        final currentLibraryCount =
            ref.watch(libraryProvider.select((l) => l.listenedCount));
        final locale = ref.read(localeProvider);
        _lastSeenLibraryCount ??= currentLibraryCount;

        // Si el usuario entra o está en la biblioteca, sincronizamos inmediatamente
        if (selected == MainTab.library) {
          _lastSeenLibraryCount = currentLibraryCount;
        }

        // El badge SOLO se muestra si el usuario NO está en la biblioteca y hay temas nuevos
        final hasNewLibraryTracks =
            selected != MainTab.library && currentLibraryCount > _lastSeenLibraryCount!;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgDeep,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1.2),
            ),
            boxShadow: [
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
                children: [
                  for (final tab in MainTab.values)
                    Expanded(
                      child: _buildNavItem(
                        tab: tab,
                        selected: selected,
                        showBadge: tab == MainTab.library && hasNewLibraryTracks,
                        locale: locale,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _navLabel(MainTab tab, LocaleProvider locale) {
    final strings = locale.strings;
    return switch (tab) {
      MainTab.home => strings.navHome,
      MainTab.search => strings.navSearch,
      MainTab.explore => strings.navExplore,
      MainTab.library => strings.navLibrary,
    };
  }

  void _markLibrarySeen() =>
      _lastSeenLibraryCount = ref.read(libraryProvider).listenedCount;

  /// The shortcut a tab runs when it's tapped again or long-pressed.
  VoidCallback? _shortcutOf(MainTab tab, {required bool longPress}) => switch (tab) {
        MainTab.home =>
          longPress ? NavigationEvents.onHomeOpenProfile : NavigationEvents.onHomeScrollToTop,
        MainTab.search => longPress ? NavigationEvents.onSearchClear : NavigationEvents.onSearchFocus,
        MainTab.explore => NavigationEvents.onExploreScrollToTop,
        MainTab.library => NavigationEvents.onLibraryScrollToTop,
      };

  void _onNavItemTap(MainTab tab) {
    // Cerrar teclado virtual si el usuario estaba escribiendo
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final isDoubleTap = _lastTapTab == tab &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 320);

    _lastTapTime = now;
    _lastTapTab = tab;

    if (isDoubleTap) {
      _onNavItemDoubleTap(tab);
      return;
    }

    Haptics.selection();
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (_tabNotifier.value != tab) {
      _loadedTabs.add(tab);
      _tabNotifier.value = tab;
      if (tab == MainTab.library) _markLibrarySeen();
    } else {
      // Tap adicional en la pestaña ya activa: Acción inteligente instantánea
      if (tab == MainTab.library) _markLibrarySeen();
      _shortcutOf(tab, longPress: false)?.call();
    }
  }

  void _onNavItemDoubleTap(MainTab tab) {
    FocusScope.of(context).unfocus();
    Haptics.tap();
    switch (tab) {
      case MainTab.home:
        NavigationEvents.onHomeScrollToTop?.call();
        NavigationEvents.onHomeRefresh?.call();
      case MainTab.search:
        NavigationEvents.onSearchClear?.call();
      case MainTab.explore:
        NavigationEvents.onExploreScrollToTop?.call();
      case MainTab.library:
        NavigationEvents.onLibraryScrollToTop?.call();
    }
  }

  /// Long-press: opens the tab and runs its shortcut (Home: the profile;
  /// Search: a clean, focused field; Explore and Library: back to the top).
  void _onNavItemLongPress(MainTab tab) {
    FocusScope.of(context).unfocus();
    Haptics.longPress();
    if (_tabNotifier.value == tab) {
      _shortcutOf(tab, longPress: true)?.call();
      return;
    }
    _loadedTabs.add(tab);
    _tabNotifier.value = tab;
    if (tab == MainTab.library) _markLibrarySeen();
    // The tab may be built for the first time now: its shortcut is read
    // after the frame, once the tab has registered it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shortcutOf(tab, longPress: true)?.call();
    });
  }

  Widget _buildNavItem({
    required MainTab tab,
    required MainTab selected,
    required LocaleProvider locale,
    bool showBadge = false,
  }) {
    final isSelected = selected == tab;
    final label = _navLabel(tab, locale);

    return Semantics(
      selected: isSelected,
      child: TapScale(
      semanticLabel: label,
      onTap: () => _onNavItemTap(tab),
      onLongPress: () => _onNavItemLongPress(tab),
      scaleDown: 0.85,
      child: Container(
        // Four tabs share the width: each fills its quarter, so the whole
        // column is the touch target, and a long name shrinks to fit.
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Ícono temático Cyberpunk con micro-shake, glow y morfología vectorial
                CyberNavIcon(
                  tab: tab,
                  isSelected: isSelected,
                  size: 24,
                ),

                // Micro-punto rojo neón para canciones nuevas en la sesión
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bgDeep,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.95),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                locale.strings.navHudSubtitle(tab.name),
                maxLines: 1,
                style: GoogleFonts.notoSansJp(
                  fontSize: AppFontSize.micro,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.9)
                      : AppColors.textMuted.withValues(alpha: 0.6),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            CyberTabIndicator(isSelected: isSelected),
          ],
        ),
      ),
    ),
    );
  }
}

/// Hands the tab state to [MainTabsView], which go_router builds inside the
/// shell navigator, below the main screen that owns it.
class MainTabsScope extends InheritedWidget {
  const MainTabsScope({
    super.key,
    required this.tab,
    required this.loadedTabs,
    required super.child,
  });

  final ValueNotifier<MainTab> tab;

  /// Every tab but Home is built the first time it's shown.
  final Set<MainTab> loadedTabs;

  static MainTabsScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabsScope>()!;

  @override
  bool updateShouldNotify(MainTabsScope oldWidget) =>
      tab != oldWidget.tab || loadedTabs != oldWidget.loadedTabs;
}

/// The four tabs (Home, Search, Explore, Library), the first page of the
/// shell navigator; detail pages are pushed over them.
class MainTabsView extends StatelessWidget {
  const MainTabsView({super.key});

  Widget _screen(MainTab tab) => switch (tab) {
        MainTab.home => const HomeScreen(),
        MainTab.search => const SearchScreen(),
        MainTab.explore => const ExploreScreen(),
        MainTab.library => const AuthGuard(child: LibraryScreen()),
      };

  @override
  Widget build(BuildContext context) {
    final scope = MainTabsScope.of(context);
    return ValueListenableBuilder<MainTab>(
      valueListenable: scope.tab,
      builder: (context, active, _) {
        scope.loadedTabs.add(active);
        return FocusTraversalGroup(
          child: FadeIndexedStack(
            index: active.index,
            duration: const Duration(milliseconds: 150),
            children: [
              for (final tab in MainTab.values)
                RepaintBoundary(
                  child: scope.loadedTabs.contains(tab) ? _screen(tab) : const SizedBox.shrink(),
                ),
            ],
          ),
        );
      },
    );
  }
}
