import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/app_router.dart';
import '../navigation/main_tab.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/cover_colors.dart';
import '../widgets/app_snack.dart';
import '../widgets/auth_guard.dart';
import '../widgets/battery_guide_sheet.dart';
import '../widgets/fade_indexed_stack.dart';
import '../widgets/frosted_glass.dart';
import '../widgets/haptics.dart';
import '../widgets/mini_player.dart';
import '../widgets/permission_primer.dart';
import '../widgets/playback_error_text.dart';
import '../widgets/player_tint.dart';
import '../widgets/tsuki_nav_bar.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// What the bar's shortcuts reach in each tab (tapping the active tab
/// again, double-tapping it, the menu on a long press); each tab sets its
/// own while it's built.
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

  /// The dock's glass (the song playing and the tabs).
  static const Key dockKey = ValueKey('dock');

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

  // The last tap on the tab that was already active, for the double tap.
  DateTime? _lastTapTime;
  MainTab? _lastTapTab;

  // Home is built at once; the other tabs the first time they're shown.
  final Set<MainTab> _loadedTabs = {MainTab.home};
  int? _lastSeenLibraryCount;

  // Back leaves the app only from Home with nothing pushed (predictive back).
  final ValueNotifier<bool> _canPopNotifier = ValueNotifier<bool>(true);

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

  static const _gesturesHintKey = 'nav_gestures_hint_shown';
  int _tabSwitches = 0;

  /// E-02: the bar's double tap and long press are taught once, on the
  /// third tab change (the user knows the bar by then).
  Future<void> _maybeTeachGestures() async {
    if (++_tabSwitches != 3) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_gesturesHintKey) ?? false) return;
    await prefs.setBool(_gesturesHintKey, true);
    if (!mounted) return;
    AppSnack.of(context, bottom: _snackBottom).info(
      ref.read(localeProvider).strings.navGesturesHint,
      icon: Icons.touch_app_rounded,
      duration: const Duration(seconds: 6),
    );
  }

  /// The shell's own snack bars (playback, Spotify, sync) clear its dock.
  double get _snackBottom => (MediaQuery.viewInsetsOf(context).bottom > 0 ? 0 : SnackDock.shellHeight) + 12;

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
    final bottomBarHeight = (hasTrack ? 146.0 : 76.0) + bottomPadding;
    if (spotifyError == null) {
      _lastShownError = null;
    } else if (spotifyError != _lastShownError) {
      _lastShownError = spotifyError;
      // On phones known to freeze Spotify, a failed start comes with a guide
      // to let it run in the background.
      final offerBatteryGuide = ref.read(batteryGuideProvider).offerFor(spotifyError);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // E-03: the app's snack bar, over the dock.
          AppSnack.of(context, bottom: _snackBottom).show(
            offerBatteryGuide ? strings.batteryGuideSnack : spotifyError.message(strings),
            icon: offerBatteryGuide ? Icons.battery_alert_rounded : Icons.info_outline_rounded,
            actionLabel: offerBatteryGuide ? strings.batteryGuideAction : null,
            onAction: offerBatteryGuide ? () => BatteryGuideSheet.show(context) : null,
            duration: Duration(seconds: offerBatteryGuide ? 8 : 4),
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
          AppSnack.of(context, bottom: _snackBottom).error(
            playbackError.message(strings, isOnline: isOnline),
            icon: playbackError == PlaybackError.network
                ? Icons.wifi_off_rounded
                : (playbackError == PlaybackError.noPreview ? Icons.music_off_rounded : Icons.error_outline_rounded),
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
          AppSnack.of(context, bottom: _snackBottom).error(strings.syncError, icon: Icons.sync_problem_rounded);
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
            // The pages run under the glass dock, which floats over them;
            // they get its height as their bottom padding, so their last
            // rows clear it (dockBottom).
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(context).copyWith(bottom: isKeyboardOpen ? bottomPadding : bottomBarHeight),
                  viewPadding: MediaQuery.viewPaddingOf(context).copyWith(bottom: isKeyboardOpen ? bottomPadding : bottomBarHeight),
                ),
                child: SnackDock(
                  child: MainTabsScope(
                    tab: _tabNotifier,
                    loadedTabs: _loadedTabs,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            // Offline: a strip at the top.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Builder(
                builder: (context) {
                  final isOnline = ref.watch(isOnlineProvider);
                  return AnimatedSlide(
                    duration: AppMotion.normal,
                    curve: Curves.easeInOutCubic,
                    offset: isOnline ? const Offset(0, -1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: AppMotion.normal,
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
                              Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white, semanticLabel: strings.a11yOffline),
                              const SizedBox(width: 6),
                              Text(
                                strings.offline,
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.caption,
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
                    duration: AppMotion.normal,
                    curve: Curves.easeInOutCubic,
                    offset: shouldHide ? const Offset(0, 1.2) : Offset.zero,
                    // R-04: slid away (keyboard up, player open) the dock's
                    // animations stop: the breathing cover, the marquee, the
                    // nav icons.
                    child: TickerMode(
                      enabled: !shouldHide,
                      child: DockSizeReporter(
                        // E-05: one dock. The song playing and the tabs
                        // share a single glass; the song's progress is the
                        // dock's lit top edge, its colour the dock's glow.
                        child: AnimatedPlayerTint(
                          color: ref.watch(playerTintColorProvider),
                          child: Builder(
                            builder: (context) => FrostedGlass(
                              key: MainNavigationScreen.dockKey,
                              color: AppColors.surface,
                              fill: AppGlass.barFill,
                              sheen: false,
                              shadow: hasTrack,
                              shadowColor: hasTrack ? PlayerTint.glowOf(context) : null,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                              border: FrostedGlass.showsThrough(context) ? null : Border.all(color: AppColors.border),
                              child: RepaintBoundary(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSize(
                                      duration: AppMotion.normal,
                                      curve: AppMotion.move,
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedSwitcher(
                                        duration: AppMotion.normal,
                                        child: hasTrack
                                            ? const MiniPlayer(key: ValueKey('mini'))
                                            : const SizedBox(key: ValueKey('none'), width: double.infinity),
                                      ),
                                    ),
                                    if (hasTrack)
                                      Container(
                                        height: 0.8,
                                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                                        color: Colors.white.withValues(alpha: 0.06),
                                      ),
                                    _buildBottomNav(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  // Only the bar rebuilds on a tab change, not the whole shell.
  Widget _buildBottomNav() {
    return ValueListenableBuilder<MainTab>(
      valueListenable: _tabNotifier,
      builder: (context, selected, _) {
        final listened = ref.watch(libraryProvider.select((l) => l.listenedCount));
        _lastSeenLibraryCount ??= listened;
        // Library open: everything in it is seen.
        if (selected == MainTab.library) _lastSeenLibraryCount = listened;
        final fresh = selected == MainTab.library ? 0 : (listened - _lastSeenLibraryCount!).clamp(0, 999);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: TsukiNavBar(
              selected: selected,
              locale: ref.watch(localeProvider),
              newInLibrary: fresh,
              onTap: _onNavItemTap,
              onLongPress: _onNavItemLongPress,
            ),
          ),
        );
      },
    );
  }

  void _markLibrarySeen() => _lastSeenLibraryCount = ref.read(libraryProvider).listenedCount;

  /// The shortcut a tab runs when it's tapped again while active.
  VoidCallback? _tapAgainShortcut(MainTab tab) => switch (tab) {
        MainTab.home => NavigationEvents.onHomeScrollToTop,
        MainTab.search => NavigationEvents.onSearchFocus,
        MainTab.explore => NavigationEvents.onExploreScrollToTop,
        MainTab.library => NavigationEvents.onLibraryScrollToTop,
      };

  void _onNavItemTap(MainTab tab) {
    FocusScope.of(context).unfocus();
    final wasActive = _tabNotifier.value == tab;
    final now = DateTime.now();
    // A double tap only on the tab already open: tapping a new tab twice
    // quickly opens it, then runs its tap-again shortcut, nothing more.
    final isDoubleTap = wasActive &&
        _lastTapTab == tab &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 320);
    _lastTapTime = wasActive ? now : null;
    _lastTapTab = wasActive ? tab : null;

    if (isDoubleTap) {
      _lastTapTime = null;
      _onNavItemDoubleTap(tab);
      return;
    }

    Haptics.selection();
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (tab == MainTab.library) _markLibrarySeen();
    if (!wasActive) {
      _loadedTabs.add(tab);
      _tabNotifier.value = tab;
      unawaited(_maybeTeachGestures());
    } else {
      _tapAgainShortcut(tab)?.call();
    }
  }

  void _onNavItemDoubleTap(MainTab tab) {
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

  /// A tab's shortcuts, for the menu a long press opens. Each is read when
  /// chosen: the tab may only be built once it's opened.
  List<(IconData, String, VoidCallback? Function())> _shortcuts(MainTab tab) {
    final s = ref.read(localeProvider).strings;
    return switch (tab) {
      MainTab.home => [
          (Icons.person_rounded, s.navMenuProfile, () => NavigationEvents.onHomeOpenProfile),
          (Icons.vertical_align_top_rounded, s.navMenuTop, () => NavigationEvents.onHomeScrollToTop),
          (Icons.refresh_rounded, s.navMenuRefresh, () => NavigationEvents.onHomeRefresh),
        ],
      MainTab.search => [
          (Icons.add_rounded, s.navMenuNewSearch, () => NavigationEvents.onSearchClear),
          (Icons.keyboard_rounded, s.navMenuTypeSearch, () => NavigationEvents.onSearchFocus),
        ],
      MainTab.explore => [(Icons.vertical_align_top_rounded, s.navMenuTop, () => NavigationEvents.onExploreScrollToTop)],
      MainTab.library => [(Icons.vertical_align_top_rounded, s.navMenuTop, () => NavigationEvents.onLibraryScrollToTop)],
    };
  }

  /// E-02: holding a tab shows what it can do, above it; choosing opens the
  /// tab and runs the shortcut.
  Future<void> _onNavItemLongPress(MainTab tab, Rect anchor) async {
    FocusScope.of(context).unfocus();
    Haptics.longPress();
    final locale = ref.read(localeProvider);
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final size = overlay.size;
    final chosen = await showMenu<VoidCallback? Function()>(
      context: context,
      useRootNavigator: true,
      color: AppColors.surfaceRaised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(anchor.left, anchor.top - 8, size.width - anchor.right, size.height - anchor.top + 8),
      items: [
        for (final (icon, label, action) in _shortcuts(tab))
          PopupMenuItem(
            value: action,
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accentText),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    Haptics.selection();
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (tab == MainTab.library) _markLibrarySeen();
    if (_tabNotifier.value == tab) {
      chosen()?.call();
      return;
    }
    _loadedTabs.add(tab);
    _tabNotifier.value = tab;
    // The tab may be built for the first time now: its shortcut is read
    // after the frame, once the tab has registered it.
    WidgetsBinding.instance.addPostFrameCallback((_) => chosen()?.call());
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
            duration: AppMotion.fast,
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
