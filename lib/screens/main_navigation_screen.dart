import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/tap_scale.dart';
import '../widgets/cyber_nav_icon.dart';
import '../widgets/cyber_tab_indicator.dart';
import '../providers/locale_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Canales de eventos para atajos táctiles de la barra de navegación (Double-Tap / Long-Press)
class NavigationEvents {
  static VoidCallback? onHomeScrollToTop;
  static VoidCallback? onHomeOpenProfile;
  static VoidCallback? onHomeRefresh;
  static VoidCallback? onSearchFocus;
  static VoidCallback? onSearchClear;
  static VoidCallback? onLibraryScrollToTop;
  static final ValueNotifier<bool> isPlayerExpanded = ValueNotifier<bool>(false);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  String? _lastShownError;

  // Timestamps para detección de Double-Tap a 0 ms de latencia
  DateTime? _lastTapTime;
  int? _lastTapIndex;

  // Carga Perezosa (Lazy Loading): Tab 0 (Home) inicia montado; Search y Library se montan al visitarse
  final Set<int> _loadedTabs = {0};
  int? _lastSeenLibraryCount;

  // Manejo reactivo de Predictive Back para Android 13+ (inicializados inline para sobrevivir a hot-reloads)
  final ValueNotifier<bool> _canPopNotifier = ValueNotifier<bool>(true);
  late final _NestedNavigatorObserver _navigatorObserver =
      _NestedNavigatorObserver(onNavigationChanged: _updateCanPop);

  // Compatibility getter to prevent hot-reload lookup failure from previous state
  // ignore: unused_element
  List<Widget> get _screens => const [];

  @override
  void initState() {
    super.initState();
    _tabNotifier.addListener(_updateCanPop);
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
      final canPop = _tabNotifier.value == 0 &&
          !(appNavigatorKey.currentState?.canPop() ?? false);
      if (_canPopNotifier.value != canPop) {
        _canPopNotifier.value = canPop;
      }
    });
  }

  @override
  void dispose() {
    _tabNotifier.removeListener(_updateCanPop);
    _tabNotifier.dispose();
    _canPopNotifier.dispose();
    super.dispose();
  }

  String _sanitizeSpotifyError(String raw, dynamic strings) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid_grant') || lower.contains('refresh') || lower.contains('token')) {
      return strings.spotifyTokenExpired;
    }
    if (lower.contains('premium')) {
      return strings.spotifyPremiumRequired;
    }
    if (lower.contains('no active device') || lower.contains('device not found')) {
      return strings.spotifyNoActiveDevice;
    }
    if (lower.contains('socket') || lower.contains('network') || lower.contains('connection')) {
      return strings.spotifyNoConnection;
    }
    if (lower.contains('track_unavailable') || lower.contains('pista no disponible')) {
      return strings.spotifyTrackUnavailablePreview;
    }
    if (lower.contains('open_app') || lower.contains('abre la app')) {
      return strings.spotifyOpenAppPrompt;
    }
    if (raw.length > 80) {
      return '${strings.audioStatusPrefix} ${raw.substring(0, 77)}...';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final hasTrack = audio.currentTrack != null;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final bottomBarHeight = (hasTrack ? 140.0 : 70.0) + bottomPadding;

    // Fix Bug 3 & Vulnerabilidad 3: SnackBar con margen flotante sobre la barra y mensaje desinfectado
    final spotifyError = audio.lastSpotifyError;
    if (spotifyError != null && spotifyError != _lastShownError) {
      _lastShownError = spotifyError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sanitizeSpotifyError(spotifyError, strings),
                      style: locale.getTextStyle(
                        fontSize: 12,
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
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.8),
                  width: 1.2,
                ),
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
            } else if (_tabNotifier.value != 0) {
              navigator?.popUntil((route) => route.isFirst);
              _loadedTabs.add(0);
              _tabNotifier.value = 0;
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
              child: Navigator(
                key: appNavigatorKey,
                observers: [_navigatorObserver],
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => ValueListenableBuilder<int>(
                    valueListenable: _tabNotifier,
                    builder: (context, activeIndex, _) {
                      _loadedTabs.add(activeIndex);

                      return _FadeIndexedStack(
                        index: activeIndex,
                        duration: const Duration(milliseconds: 150),
                        children: [
                          const RepaintBoundary(child: HomeScreen()),
                          RepaintBoundary(
                            child: _loadedTabs.contains(1)
                                ? const SearchScreen()
                                : const SizedBox.shrink(),
                          ),
                          RepaintBoundary(
                            child: _loadedTabs.contains(2)
                                ? const LibraryScreen()
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Mini Player animado + Bottom Nav
            // Ocultar limpiamente hacia abajo cuando el teclado está activo o el reproductor está expandido
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
    return ValueListenableBuilder<int>(
      valueListenable: _tabNotifier,
      builder: (context, selectedIndex, _) {
        final library = context.watch<LibraryProvider>();
        final locale = context.watch<LocaleProvider>();
        final strings = locale.strings;
        final currentLibraryCount = library.listenedTrackIds.length;
        _lastSeenLibraryCount ??= currentLibraryCount;

        // Si el usuario entra o está en la pestaña LIBRARY (2), sincronizamos inmediatamente
        if (selectedIndex == 2) {
          _lastSeenLibraryCount = currentLibraryCount;
        }

        // El badge SOLO se muestra si el usuario NO está en la biblioteca y hay temas nuevos
        final hasNewLibraryTracks = selectedIndex != 2 && currentLibraryCount > _lastSeenLibraryCount!;

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
                    label: strings.navHome,
                    selectedIndex: selectedIndex,
                    locale: locale,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: strings.navSearch,
                    selectedIndex: selectedIndex,
                    locale: locale,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: strings.navLibrary,
                    selectedIndex: selectedIndex,
                    showBadge: hasNewLibraryTracks,
                    locale: locale,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onNavItemTap(int index) {
    // Cerrar teclado virtual si el usuario estaba escribiendo
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final isDoubleTap = _lastTapIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 320);

    _lastTapTime = now;
    _lastTapIndex = index;

    if (isDoubleTap) {
      _onNavItemDoubleTap(index);
      return;
    }

    HapticFeedback.selectionClick();
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (_tabNotifier.value != index) {
      _loadedTabs.add(index);
      _tabNotifier.value = index;
      if (index == 2) {
        final lib = context.read<LibraryProvider>();
        _lastSeenLibraryCount = lib.listenedTrackIds.length;
      }
    } else {
      // Tap adicional en la pestaña ya activa: Acción inteligente instantánea
      if (index == 0) {
        NavigationEvents.onHomeScrollToTop?.call();
      } else if (index == 1) {
        NavigationEvents.onSearchFocus?.call();
      } else if (index == 2) {
        final lib = context.read<LibraryProvider>();
        if (_lastSeenLibraryCount != lib.listenedTrackIds.length) {
          _lastSeenLibraryCount = lib.listenedTrackIds.length;
        }
        NavigationEvents.onLibraryScrollToTop?.call();
      }
    }
  }

  void _onNavItemDoubleTap(int index) {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    if (index == 0) {
      NavigationEvents.onHomeScrollToTop?.call();
      NavigationEvents.onHomeRefresh?.call();
    } else if (index == 1) {
      NavigationEvents.onSearchClear?.call();
    } else if (index == 2) {
      NavigationEvents.onLibraryScrollToTop?.call();
    }
  }

  void _onNavItemLongPress(int index) {
    FocusScope.of(context).unfocus();
    HapticFeedback.heavyImpact();
    if (index == 0) {
      // Long-press en HOME: Abre el modal de perfil y configuración de Spotify
      if (_tabNotifier.value != 0) {
        _tabNotifier.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationEvents.onHomeOpenProfile?.call();
        });
      } else {
        NavigationEvents.onHomeOpenProfile?.call();
      }
    } else if (index == 1) {
      // Long-press en SEARCH: Limpia el texto de búsqueda y enfoca el teclado
      if (_tabNotifier.value != 1) {
        _loadedTabs.add(1);
        _tabNotifier.value = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationEvents.onSearchClear?.call();
        });
      } else {
        NavigationEvents.onSearchClear?.call();
      }
    } else if (index == 2) {
      // Long-press en LIBRARY: Scroll to top suave y feedback táctil
      if (_tabNotifier.value != 2) {
        _loadedTabs.add(2);
        _tabNotifier.value = 2;
        final lib = context.read<LibraryProvider>();
        _lastSeenLibraryCount = lib.listenedTrackIds.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationEvents.onLibraryScrollToTop?.call();
        });
      } else {
        NavigationEvents.onLibraryScrollToTop?.call();
      }
    }
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required int selectedIndex,
    required LocaleProvider locale,
    bool showBadge = false,
  }) {
    final isSelected = selectedIndex == index;

    return TapScale(
      onTap: () => _onNavItemTap(index),
      onLongPress: () => _onNavItemLongPress(index),
      scaleDown: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Ícono temático Cyberpunk con micro-shake, glow y morfología vectorial
                CyberNavIcon(
                  index: index,
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
            Text(
              label,
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              locale.strings.navHudSubtitle(index),
              style: GoogleFonts.notoSansJp(
                fontSize: 7.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.9)
                    : AppColors.textMuted.withValues(alpha: 0.6),
                letterSpacing: 0.6,
              ),
            ),
            CyberTabIndicator(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}

/// _FadeIndexedStack: Preserva el estado y scroll de IndexedStack con una
/// micro-transición de fade cinematográfico de 150 ms entre pestañas a 120 FPS Zero-GC.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _targetIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.index;
    _previousIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _targetIndex) {
      if (_controller.isAnimating) {
        // Caso 1: Si el usuario vuelve a la pestaña anterior a mitad de transición,
        // encadenamos el progreso simétricamente sin ningún salto ni parpadeo visual
        if (widget.index == _previousIndex) {
          final currentProgress = _controller.value;
          _previousIndex = _targetIndex;
          _targetIndex = widget.index;
          _controller.forward(from: (1.0 - currentProgress).clamp(0.0, 1.0));
          return;
        }

        // Caso 2: Si salta a una tercera pestaña cuando la entrante aún tenía < 50% de opacidad,
        // conservamos la pestaña de origen dominante como base de salida para evitar un destello abrupto
        if (_controller.value < 0.5) {
          _targetIndex = widget.index;
          _controller.forward(from: 0.0);
          return;
        }
      }

      _previousIndex = _targetIndex;
      _targetIndex = widget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Fix Bug 1: Zero-GC transform sin instanciar CurvedAnimation en cada frame
        final progress = Curves.easeInOut.transform(_controller.value);
        final isAnimating = _controller.isAnimating;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final isTarget = i == _targetIndex;
            final isPrevious = i == _previousIndex && isAnimating;
            final isOffstage = !isTarget && !isPrevious;

            double opacity;
            if (isAnimating) {
              if (isTarget) {
                opacity = progress;
              } else if (isPrevious) {
                opacity = 1.0 - progress;
              } else {
                opacity = 0.0;
              }
            } else {
              opacity = isTarget ? 1.0 : 0.0;
            }

            return Offstage(
              offstage: isOffstage,
              child: ExcludeFocus(
                excluding: !isTarget,
                child: IgnorePointer(
                  ignoring: !isTarget,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: widget.children[i],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Observer para sincronizar el estado de Predictive Back cuando se apilan o desapilan
/// pantallas de detalle (artistas, álbumes, discografía) dentro de appNavigatorKey.
class _NestedNavigatorObserver extends NavigatorObserver {
  final VoidCallback onNavigationChanged;
  _NestedNavigatorObserver({required this.onNavigationChanged});

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onNavigationChanged();
  }
}
