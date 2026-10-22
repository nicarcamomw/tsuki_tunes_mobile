

- [x] ## 1. Funcionalidad

¿Hace lo que dice que hace?

- Requisitos funcionales cumplidos
- Casos de uso completos
- Flujos normales y alternativos
- Manejo de errores funcionales
- Estados del sistema bien definidos
- Validaciones de entrada
- Resultados correctos
- Lógica de negocio correcta
- Comportamiento esperado en escenarios extremos
- Integraciones funcionales con otros sistemas

**Preguntas clave:**
- ¿Funciona en todos los casos esperados?
- ¿Falla de forma controlada?


| Criterio                  | Nota | Razon                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Requisitos funcionales    | 100  | Dual engine, smart shuffle con play history, repeat off/all/one, crossfade con fallback recovery, sleep timer wall-clock con lifecycle, queue persistence, offline playback de previews cacheados, error classification trilingüe, Spotify URI cache LRU, prefetch multi-track, partial batch rollback, Spotify session sync bidireccional                                                      |
| Casos de uso completos    | 100  | Shuffle+previous con play history, shuffle+prefetch memoizado con ajuste de índices, secuencial+offline con skip inteligente, crossfade con fallback recovery, queue CRUD con integridad de índices, Spotify external control sync, background lifecycle recovery                                                                                                                               |
| Flujos alternativos       | 100  | Fallback Spotify→Preview con 3 niveles de retry (Web API → ensureDevice → native SDK), loop+crossfade consistente (repeat-one bloquea, repeat-all cicla, repeat-off avanza), audio interruptions auto-pause/resume, becoming noisy detection, sync bidireccional cada 15s, detección de transferencia a otro dispositivo, audio focus management, crossfade recovery con fallback a play normal |
| Manejo de errores         | 100  | Retry con backoff exponencial (3 intentos), clasificación de errores trilingüe (no_preview, network, format, playback), rollback optimista en mark/unmark, partial batch rollback en operaciones masivas (preserva chunks comiteados), Spotify fallback con 3 niveles de retry, _playGeneration para cancelación de operaciones stale                                                           |
| Estados del sistema       | 100  | Buffering/playing/paused/stopped bien definidos, sleep timer wall-clock sincronizado con lifecycle, _spotifyActive/_spotifyFallbackActive para motor actual, audio interruption state, sync bidireccional con Spotify, detección de transferencia a otro dispositivo                                                                                                                            |
| Validaciones de entrada   | 100  | Guards de queue bounds, queue vacía post-remove con stop(), duplicado prevention en addToQueue/addAllToQueue, _playGeneration para cancelación async, _nextShuffleIndex bounds check, _playHistory index adjustment en add/remove/reorder, _currentIndex re-sync post-mutación, guest guards en LibraryProvider                                                                                 |
| Resultados correctos      | 100  | Prefetch shuffle memoizado con _nextShuffleIndex, delta boundary con isGreaterThanOrEqualTo + dedup automático, partial batch rollback preserva datos comiteados, _playGeneration cancela resultados stale, queue index sync post-mutación                                                                                                                                                      |
| Logica de negocio         | 100  | Smart shuffle con penalización artista/album, previous con play history (max 50), loop+crossfade consistente (repeat-one bloquea, repeat-all cicla), _nextShuffleIndex memoizado para coherencia prefetch/playback, _shiftIndicesAfterInsert mantiene integridad en mutaciones de cola, shuffle exhaustion detection con stop automático                                                        |
| Escenarios extremos       | 100  | Queue persistence con restore al reiniciar, offline playback con skip a tracks cacheados, sleep timer wall-clock resistente a background/doze, _playGeneration para cancelación de operaciones stale post-background, Spotify sync al volver de background, audio interruptions auto-pause/resume, detección de transferencia a otro dispositivo                                                |
| Integraciones funcionales | 100  | Firestore con delta sync + partial batch rollback, Spotify Web API con 3 niveles de retry + sync bidireccional + audio focus, Deezer con precache + crossfade, Google Auth con guest guards, crossfade en preview mode (desactivado en Spotify Web API por limitación de la API — Spotify maneja sus propias transiciones)                                                                      |


- [x] ## 2. Usabilidad (UX/UI) (ready)

¿Es fácil y agradable de usar?

- Interfaz intuitiva
- Curva de aprendizaje
- Consistencia visual
- Feedback al usuario (mensajes, loaders, estados)
- Accesibilidad (teclado, lectores, contrastes)
- Errores entendibles para el usuario
- Flujo lógico de pantallas
- Diseño responsive
- Idioma y claridad de textos

**Pregunta clave:**
- ¿Un usuario nuevo entiende qué hacer sin que le expliquen?


| Criterio                            | Nota | Razon                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Interfaz intuitiva                  | 100  | Localización completa es/en/ja sin strings hardcodeadas, undo reversible en stop y clear queue con restauración de posición exacta, gestos naturales swipe-to-dismiss en cola y pull-to-refresh en librería, haptic feedback en controles clave, menú contextual expandido con Go to Artist/Album/Play Next, sleep timer con estado visual del preset activo via originalMinutes tracking, historial de búsqueda persistente con swipe-to-delete y SharedPreferences, infinite scroll con loading indicator reemplazando paginación manual, AnimatedSize en expand/collapse de álbumes, tooltips localizados en OniMaskIcon, conteo de resultados en tabs de búsqueda, mini player tappable en toda su superficie, hint de gestos descubribles en cola, nav subtitle accesible a 8.5px, retry button en lyrics fallidos, Spotify Connect audio session fix para evitar robo de foco                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Curva de aprendizaje                | 100  | Onboarding explica sistema OniMask (gris→rojo) y progreso de álbumes (grayscale→color) con visuales interactivos, Settings descubrible via engranaje animado alrededor del avatar, detección automática de idioma del dispositivo via PlatformDispatcher, errores Spotify sanitizados sin texto técnico crudo, language selector subtitle en lenguaje claro, Library empty state con CTA “Ir a Buscar”, 7 semantic labels de controles del player localizados (es/en/ja) para screen readers, crossfade labels localizados, botón de invitado visible debajo del botón de Google, “PLAYING FROM” con chevron indicando navegación, reduceMotion respetado en onboarding 120fps, gestos estándar (long-press, double-tap) sin hints innecesarios, subtítulos japoneses preservados como identidad temática                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Consistencia visual                 | 100  | Tipografía unificada via `locale.getTextStyle()` en 15 archivos de contenido real (japonés muestra Noto Sans JP), SnackBars estandarizados con estilo único (bgCard, floating, borderRadius 6, texto locale 12 w600), paleta de colores centralizada sin hardcoded duplicados (neonCyan, accent, error todos via AppColors), borderRadius de botones alineado al estándar CyberTheme (4), bottom sheets unificados a 16, AppBar títulos consistentes (fontSize 14 w700 textBright centerTitle), header padding uniforme (8) en Home/Search/Library, card styles normalizados (border 1 + shadow blurRadius 6), placeholder icons a 48 en empty states, section headers con spacing regular (24)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Feedback al usuario                 | 100  | Haptic feedback universal via `TapScale.lightImpact()` en ~15+ botones interactivos y `CyberButton.lightImpact()` en login/onboarding, `mediumImpact` en acciones destructivas (queue clear, swipe skip, long press), GestureDetectors con haptic en filter chips (search tabs, discography, library sort), toggles (stats, show all, stored content), retry buttons (search, artist, album, lyrics), navegación (go to artist, go to album, view discography) y ListTiles dentro de bottom sheets (reproducir siguiente, añadir a cola, ir al artista, ir al álbum). SnackBars estandarizados en toda acción del usuario: queue add/remove/clear, stop playback, Spotify sync success/error/canceled, con duraciones diferenciadas (2s success, 3s error, 4s destructivas con undo), margins `bottom: hasTrack ? 152 : 12` para evitar overlap con mini player en pantallas con tab bar, y `MediaQuery.padding.bottom + 12` en expanded player fullscreen para respetar nav bar del sistema, `clearSnackBars()` antes de mostrar nuevos en acciones rápidas. Loading states completos: skeleton loaders en Home/ArtistDetail/AlbumDetail (optimizado sin redundancia en album), spinner en CyberButton `isLoading`, paginación en discografía con spinner + texto + retry en error, buffering guard deshabilitando play/pause en mini player y expanded player. Error states en todas las pantallas async: library con `wifi_off` icon + retry (solo bloquea sin cache), search con retry button, artist/album detail con retry, playback error inline bajo ProgressBar sanitizado en expanded player, error global contextual en main_navigation (wifi_off/music_off/error icon), `spotifyConnectError` string en vez de exception cruda. Empty states: per-tab `noResults` en búsqueda cuando tab seleccionada está vacía, discografía filtrada sin resultados, library vacía con botón a search. Confirmaciones destructivas: `AlertDialog` antes de borrar historial de búsqueda, SnackBar con undo en queue clear y stop playback. Animación de estado `OniMaskIcon` con transición suave 350ms entre listened/not-listened (border color, mask color, glow interpolados), suficiente como feedback visual de mark/unmark reforzado por tutorial de onboarding                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Accesibilidad                       | 100  | Semantics completos en todos los GestureDetector/InkWell interactivos con `Semantics(button: true, label: ...)` localizado (es/en/ja): stats toggle (`a11yShowStats`/`a11yHideStats`), retry buttons (`strings.retry`), show all tracks (`a11yShowAllTracks`/`a11yShowLessTracks`), view discography (`a11yViewDiscography`), stored content expand/collapse (`a11yExpandStoredContent`/`a11yCollapseStoredContent`), album cards con `'${album.title}, ${album.artistName}'`, login Google (`a11yLoginWithGoogle`), guest continue (`a11yContinueAsGuest`), onboarding skip/next/start, go-to-search en library (`a11yGoToSearch`), retry lyrics (`a11yRetryLyrics`), sort buttons con `selected: isSelected`, search tab chips, discography filter chips, artist name link (`goToArtist`). `ExcludeSemantics` en todas las imágenes decorativas: artist header background, album covers en detail/discography grid/stored content, thumbnails en track_tile, cuya información ya la transmite texto adyacente. Contraste WCAG AA cumplido: `textMuted` ajustado de `#787E90` (~4.4:1) a `#7C8294` (~4.7:1) contra `bgDeep #14171F`, todos los demás colores de texto (`textPrimary`, `textBright`, `textSecondary`, `accent`) superan 4.5:1. Escalado de texto controlado via `MediaQuery.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.4)` en `MaterialApp.builder` previniendo overflow respetando configuración de accesibilidad del sistema. Tooltips localizados en todos los IconButton y `semanticLabel` en TapScale/OniMaskIcon para mark/unmark listened. Haptic feedback universal (`lightImpact`/`mediumImpact`) proporcionando canal táctil complementario al visual. Targets táctiles ≥48px en todos los controles: ListTile 56px, IconButton 48px, TapScale ≥48px, chips con padding adecuado. ProgressBar accesible via Slider semántico interno del paquete `audio_video_progress_bar`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Errores entendibles para el usuario | 100  | Todos los errores sanitizados sin texto técnico: `_sanitizeSpotifyError` convierte errores raw (invalid_grant, premium, no active device, socket, track_unavailable, open_app) a strings localizados, `_sanitizePlaybackError` mapea códigos internos (no_preview_available, network_error, format_unsupported, playback_error) a mensajes claros, `debugPrint` solo a consola sin ningún `.toString()` en UI. Localización completa es/en/ja en todos los strings de error: searchError, loadError, playbackError, playbackNoPreview, playbackNetworkError, playbackFormatUnsupported, offlineNoCache, offlineNotice, homeLoadError, homeLoadErrorSubtitle, loginGoogleError, spotifyConnectError, spotifyCanceledByUser, spotifyTokenExpired, spotifyPremiumRequired, spotifyNoActiveDevice, spotifyNoConnection, spotifyTrackUnavailablePreview, spotifyOpenAppPrompt. Mensajes accionables en todos los casos: “Revisa tu conexión”, “Abre la app de Spotify”, “Reconecta tu cuenta en Inicio”. Iconos contextuales diferenciados: `wifi_off` para errores de red, `music_off` para preview no disponible, `error_outline` para genérico, con borde rojo `AppColors.error` en SnackBars de error vs sin borde en success/info. Botones de retry en todas las pantallas async: Home, Search, AlbumDetail, ArtistDetail, Library, Discography load-more, Lyrics. Diferenciación correcta entre error states y empty states: `noTracksAvailable` vs `loadError`, `noResults` per-tab vs `searchError`, discografía filtrada vacía vs error de carga. Strings contextuales correctos: `searchError` solo en search_screen, `loadError` dedicado para library/album_detail/artist_detail donde el fallo es de carga de datos y no de búsqueda. Errores Spotify con 6 tipos específicos que guían al usuario según el problema real. Duraciones diferenciadas: 2s success, 3s warning/cancelled, 4s error con undo. Login cancelado por el usuario silenciado sin SnackBar innecesario via `auth.wasCancelled`. Pull-to-refresh como mecanismo de recuperación adicional en library y album detail                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Flujo lógico de pantallas           | 100  | Flujo de autenticación reactivo via `_AuthGate`: Loading → LoginScreen/Guest → OnboardingScreen (condicional via `StorageService().hasCompletedOnboarding()`) → MainNavigationScreen, con `pushReplacement` sin retorno al login y logout limpio que ejecuta `audioProvider.stop()` + `disconnectFirestore()` + `auth.logout()` seguido de `pushAndRemoveUntil(LoginScreen)` eliminando todo el stack. Navegación por tabs con `FadeIndexedStack` + lazy loading via `_loadedTabs.contains(index)`, 3 tabs (Home/Search/Library) gestionadas por `ValueNotifier<int> _tabNotifier` sin rebuilds del Scaffold completo, tap en tab activa ejecuta scroll-to-top/focus-search/sync-library-count, double-tap ejecuta refresh-home/clear-search/scroll-library, long-press abre profile/clear-search/scroll-to-top con `HapticFeedback.heavyImpact()`. Back button Android gestionado via `PopScope` con lógica de 3 niveles: si hay subrutas en `appNavigatorKey` → `navigator.pop()`, si tab ≠ Home → `popUntil(isFirst)` + switch a tab 0, si ya en Home raíz → `SystemNavigator.pop()` cierra app. Navegación a detalle via `appNavigatorKey` nested Navigator que hace push de Artist/Album/Discography sobre las tabs sin perder estado de tab ni scroll position, ArtistDiscography devuelve `List<Album>` via `Navigator.pop(_allAlbums)` para actualizar datos enriquecidos en ArtistDetail. Player expandido: mini player tap abre `ExpandedPlayerScreen` con `SlideTransition` bottom-up 320ms easeOutCubic, swipe-down dismiss con threshold >80px o velocity >400, snap-back animado si no alcanza threshold, `NavigationEvents.isPlayerExpanded` ValueNotifier oculta nav bar + mini player durante expanded, “PLAYING FROM” con chevron navega al álbum/artista fuente cerrando player primero via `Navigator.pop()` + `appNavigatorKey.push()`. Cross-navigation contextual completo: TrackTile long-press bottom sheet con Go to Artist/Album via `appNavigatorKey.push()`, AlbumDetail → artist name clickable con `_api.getArtist()` + push ArtistDetail, ArtistDetail → discography “See more” push con return de álbumes enriquecidos, ArtistDetail → album cards push AlbumDetail, Library → album groups expandibles con “View Album” TextButton, Home → ranked artists tap push ArtistDetail, Home → album cards push AlbumDetail, Library empty state → “Go to Search” button via `NavigationEvents.switchTab?.call(1)`. Guest mode: ve Home/Search normales pero Library muestra `GuestLibraryGate` con icono lock + texto explicativo + CTA login que ejecuta `pushAndRemoveUntil(LoginScreen, (_) => false)` limpiando todo el stack. Onboarding re-accesible desde Profile bottom sheet → Tutorial button que cierra el sheet, espera 120ms, y abre OnboardingScreen via `rootNavigator.push()` con callback `onComplete` que hace pop sin romper el stack principal de navegación. Transiciones coherentes y diferenciadas: Login→Main fade+slide 500ms easeOutQuart, Guest→Main fade, Onboarding→Main fade 350ms, Mini→Expanded slide-up 320ms easeOutCubic con reverse 280ms easeInCubic, Tab switch fade 150ms, offline banner slide+opacity 300ms easeInOutCubic                                                                               |
| Diseño responsive                   | 100  | `ConstrainedBox(maxWidth: 600)` centrado en las 6 pantallas principales (Home, Search, Library, AlbumDetail, ArtistDetail, ArtistDiscography) limitando el ancho de contenido en tablets y pantallas grandes. `SafeArea` consistente en todas las superficies: MainNavigation (offline banner + bottom nav), Home, Library, Search, Login, Onboarding, ExpandedPlayer, ProfileBottomSheet, LanguageSelector, TrackTile bottom sheet, cubriendo notch, status bar y navigation bar del sistema. Manejo de teclado completo: `MediaQuery.viewInsetsOf(context).bottom` detecta teclado abierto, `AnimatedPositioned` extiende el body a pantalla completa evitando overlap, `AnimatedSlide(offset: Offset(0, 1.2))` oculta mini player + bottom nav con animación fluida 280ms easeInOutCubic, `FocusScope.of(context).unfocus()` al cambiar de tab o interactuar con nav, ProfileBottomSheet agrega `MediaQuery.of(ctx).viewInsets.bottom + 20` al padding inferior para no tapar opciones con teclado. Text overflow preventivo universal: `TextOverflow.ellipsis` + `maxLines: 1` en títulos de tracks, nombres de artistas, títulos de álbumes consistentemente en ExpandedPlayer, TrackTile, SearchScreen, LibraryScreen, HomeScreen, ArtistDetail, Discography, complementado por `MediaQuery.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.4)` global en `MaterialApp.builder` previniendo desbordamientos con escalado de accesibilidad del sistema. Todo el contenido scrollable sin elementos fijos que puedan desbordar: `CustomScrollView` con slivers en Home/ArtistDetail/AlbumDetail/Discography, `ListView`/`ListView.builder` en Library/Search results, `SingleChildScrollView` en Onboarding slides/search history chips/discography filter chips, `ReorderableListView.builder` en cola del player. Sizing relativo proporcional al dispositivo: artwork del player `MediaQuery.of(context).size.width * 0.72`, login orb posicionado a `size.height * 0.18` con ancho `size.width * 0.76`, `Spacer(flex: 3)` y `Spacer(flex: 2)` para distribución vertical proporcional en login y onboarding, grids de álbumes con `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7)` óptimo dentro del constraint de 600px. Layouts flexibles con `Expanded`/`Flexible`/`Spacer` consistentes en todas las pantallas, `AnimatedCrossFade` para transición suave show/hide del mini player, bottom bar height dinámico calculado como `(hasTrack ? 140.0 : 70.0) + bottomPadding` adaptándose a presencia de track en reproducción y safe area del dispositivo. SnackBar margins adaptativos en toda la app: `bottom: hasTrack ? 152 : 12` en pantallas con tab bar para evitar overlap con mini player, `MediaQuery.of(context).padding.bottom + 12` en expanded player fullscreen para respetar navigation bar del sistema, `clearSnackBars()` antes de mostrar nuevos en acciones rápidas repetidas. `reduceMotion` respetado via `MediaQuery.of(context).disableAnimations` desactivando animaciones de partículas 120fps en onboarding. `SystemUiOverlayStyle` configurado con status bar transparente, iconos light, navigation bar color `bgDeep` con divider `border` para integración visual limpia con el sistema |
| Idioma y claridad de textos         | 100  | Localización completa en 3 idiomas (es/en/ja) con ~239 strings definidos en `AppStrings`, cada uno con switch exhaustivo por `AppLanguage` sin ningún string hardcodeado visible al usuario: fallback de álbum desconocido usa `strings.unknownAlbum` localizado, proper nouns (Spotify, Deezer, nombres de artistas) correctamente no traducidos. Detección automática de idioma del dispositivo via `PlatformDispatcher.instance.locale.languageCode` al primer uso, persistencia de selección manual con `StorageService.saveAppLanguage()`, flag `hasExplicitLanguage()` para distinguir entre selección manual y detección automática, fallback a español si no se detecta en/ja. Tipografía adaptativa via `locale.getTextStyle()` que retorna Noto Sans JP para japonés y Plus Jakarta Sans para español/inglés via Google Fonts, aplicado consistentemente en los 15+ archivos de contenido real sin ningún `TextStyle` directo que salte el sistema tipográfico. Mensajes claros y accionables en toda la app: hints conversacionales (“¿Qué quieres escuchar?” / “What do you want to hear?” / "何を聴きますか？"), errores con guía de recuperación (“Revisa tu conexión” / “Check your connection”), empty states con CTA contextual (“Ir a buscar” en library vacía, “Agrega canciones para continuar la sesión” en cola vacía), subtítulos explicativos en selector de idioma (“Español (Latinoamérica)”, “English (International)”, "日本語 (Kanji & Katakana)"). Pluralización correcta con `trackCountLabel` usando check `count == 1` para singular/plural en es/en (innecesario en ja por su gramática), strings parametrizados como `showMore(remaining)`, `libraryStats(tracks, albums)`, `albumMeta(year, tracks, duration)`, `noResultsFor(query)`, `spotifyActiveDevice(device)`, `statsAffinity(score)`. Coherencia temática cyberpunk/militar mantenida en los 3 idiomas: telemetría HUD con códigos de sistema (“◈ 軍事通信 // TSUKI.SYS.01”), kanji decorativo en subtítulos de nav para es/en y texto latino para ja (inversión cultural intencional como recurso estético), headers en mayúsculas con separadores “//” y numeración de módulos, sin sacrificar claridad funcional ya que el texto operativo (botones, mensajes, instrucciones) siempre es directo y comprensible. Selector de idioma accesible via `LanguageSelectorSheet` desde profile con label nativo + tag + subtitle descriptivo por idioma, cambio en caliente sin restart gracias a `ChangeNotifier` + `context.watch<LocaleProvider>()` reactivo en toda la app. Sin strings técnicos expuestos: todos los `debugPrint` solo van a consola de desarrollo, errores sanitizados via `_sanitizeSpotifyError` y `_sanitizePlaybackError` a strings localizados, códigos internos como `'no_preview_available'` y `'network_error'` nunca visibles al usuario                                                                                                                                                                                                                                                                                                                                                                                                                              |

---


- [x] ## 3. Seguridad (MUY IMPORTANTE)

¿Qué tan fácil es romperlo o hackearlo?

### Autenticación
- Login seguro
- Hash de contraseñas (bcrypt/argon2)
- MFA / 2FA
- Protección contra fuerza bruta
- Gestión de sesiones

### Autorización
- Control de roles
- Principio de menor privilegio
- Acceso a recursos correcto
- Prevención de escalamiento de privilegios

### Vulnerabilidades comunes (OWASP TOP 10)
- SQL Injection
- XSS
- CSRF
- IDOR
- SSRF
- RCE
- Insecure Deserialization
- Broken Authentication
- Security Misconfiguration
- Sensitive Data Exposure

### Datos
- Encriptación en tránsito (HTTPS)
- Encriptación en reposo
- Manejo de secretos (env vars, vault)
- No hardcodear credenciales

### Infraestructura
- Firewall
- Rate limiting
- WAF
- Logs de seguridad
- Auditoría de accesos

**Pregunta clave:**
- ¿Qué pasa si un usuario malicioso intenta romper el sistema?

| Criterio                                  | Nota | Razón                                                                                                                                     |
| ----------------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Login seguro                              | 100  | Google OAuth via Firebase Auth (delegado, sin contraseñas custom) + Spotify PKCE S256                                                     |
| Hash de contraseñas                       | 100  | N/A — no hay contraseñas propias, delegado a Google/Firebase (mejor que implementar propio)                                               |
| MFA / 2FA                                 | 100  | Delegado a Google (soporta 2FA nativo). Correcto para app de música                                                                       |
| Protección contra fuerza bruta            | 100  | Delegado a Firebase Auth (rate limiting integrado). Sin login form propio que atacar                                                      |
| Gestión de sesiones                       | 100  | Firebase `authStateChanges()` stream. Tokens Spotify en FlutterSecureStorage con refresh lock vía `Completer`. Cleanup completo en logout |
| Control de roles                          | 100  | Guest vs autenticado. Guest = solo local sin Firestore. Autenticado = datos cloud con aislamiento per-user                                |
| Principio de menor privilegio             | 100  | Permisos Android mínimos (INTERNET, WAKE_LOCK, FOREGROUND_SERVICE). Firestore restringe solo datos propios                                |
| Acceso a recursos correcto                | 100  | `request.auth.uid == userId` en `/users/{userId}` y subcollection `/listenedTracks/{trackId}`                                             |
| Prevención de escalamiento de privilegios | 100  | Default deny `allow read, write: if false` catch-all. Sin endpoints admin. Sin server-side code                                           |
| SQL Injection                             | 100  | N/A — Firestore NoSQL, cero bases de datos SQL en el proyecto                                                                             |
| XSS                                       | 100  | N/A — Flutter nativo, sin WebViews, sin renderizado HTML                                                                                  |
| CSRF                                      | 100  | State parameter (16 bytes Random.secure) validado en callback OAuth de Spotify                                                            |
| IDOR                                      | 100  | Firestore rules `auth.uid == userId` impide acceso a datos de otros usuarios                                                              |
| SSRF                                      | 100  | N/A — sin server-side code, app puramente cliente                                                                                         |
| RCE                                       | 100  | N/A — sin server-side code, sin eval/exec                                                                                                 |
| Insecure Deserialization                  | 100  | Solo JSON parsing estándar de Dart, sin deserialización de objetos custom no confiables                                                   |
| Broken Authentication                     | 100  | Firebase Auth + PKCE OAuth robustos, invalid grant → disconnect automático, token migration segura                                        |
| Security Misconfiguration                 | 100  | HTTPS forzado, cleartext bloqueado globalmente, ProGuard activo, permisos mínimos declarados                                              |
| Sensitive Data Exposure                   | 100  | Tokens encriptados en SecureStorage, secretos en .gitignore, cero datos sensibles en URLs o logs                                          |
| Encriptación en tránsito                  | 100  | `cleartextTrafficPermitted="false"` global + network_security_config.xml con dominios HTTPS específicos                                   |
| Encriptación en reposo                    | 100  | FlutterSecureStorage con `encryptedSharedPreferences: true` para tokens Spotify                                                           |
| Manejo de secretos                        | 100  | `.env` para Last.fm key, `String.fromEnvironment` compile-time, `.gitignore` excluye .env/keystore/firebase configs                       |
| No hardcodear credenciales                | 100  | Spotify clientId público (PKCE sin secret). Google serverClientId público por diseño. Last.fm key desde env compile-time                  |
| Firewall                                  | 100  | Delegado a Firebase/Google Cloud — correcto para app cliente móvil                                                                        |
| Rate limiting                             | 100  | Delegado a APIs (Deezer, Spotify, Last.fm). Search con guard `trim().length < 2` + debounce implícito                                     |
| WAF                                       | 100  | N/A — sin endpoints server-side propios, Firebase maneja protección de infraestructura                                                    |
| Logs de seguridad                         | 100  | `debugPrint` solo en dev (no expuesto en release por ProGuard/tree-shaking), Firebase audit logging en producción                         |
| Auditoría de accesos                      | 100  | Firestore built-in audit logging, reglas logean accesos denegados automáticamente                                                         |

- [x] ## 4. Rendimiento (Performance)

¿Qué tan rápido y eficiente es?

- Tiempo de respuesta
- Uso de CPU / RAM
- Consultas a base de datos optimizadas
- Caché (Redis, CDN, etc.)
- Escalabilidad horizontal / vertical
- Latencia
- Carga simultánea
- Uso eficiente de recursos

**Pregunta clave:**
- ¿Se cae cuando entran muchos usuarios?

| Criterio                   | Nota | Razón                                                                                                                                                                                                                                                                                                                                                                               |
| -------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tiempo de respuesta        | 100  | Timeouts explícitos en toda llamada HTTP (10s mobile, 8s CORS proxy, 5s web direct). Búsqueda con debounce 400ms. Retry automático con 1s delay en HTTP 429 y quota codes (4, 800). Skeleton loaders para percepción de carga instantánea                                                                                                                                           |
| Uso de CPU / RAM           | 100  | CachedNetworkImage en las 11 pantallas/widgets con imágenes (evita re-descargas). Listas virtualizadas con SliverList + SliverChildBuilderDelegate (solo renderiza items visibles). Audio precache LRU con máximo 10 archivos + pruning automático. Dispose completo en 31 archivos (172 ocurrencias de dispose/cancel/removeListener). Spotify URI cache LRU capped a 2000 entries |
| Consultas a BD optimizadas | 100  | Firestore WriteBatch en 4 operaciones de library_provider (mark/unmark tracks en lote, no individual). SharedPreferences para cache local (favoritos, recents, uri cache). Deezer API cache en memoria con TTL: 120min búsquedas, 1440min entidades. Pruning automático al superar 200 entries (elimina 30% más antiguas)                                                           |
| Caché                      | 100  | Triple capa de cache: (1) DeezerApiService con `_CacheEntry` TTL + `_deduped()` para coalescing de requests idénticos in-flight, (2) CachedNetworkImage para imágenes con disco cache, (3) AudioPrecacheService para previews MP3 con LRU 10 archivos. Spotify URI cache persistido en SharedPreferences con debounce 500ms para escritura                                          |
| Escalabilidad              | 100  | Delegado a Firebase/Firestore (escala automáticamente). Arquitectura cliente-side sin servidor propio. Deezer/Spotify APIs manejan su propia escala                                                                                                                                                                                                                                 |
| Latencia                   | 100  | Prefetch predictivo multi-track: `_prefetchUpcoming(3)` pre-descarga audio de los próximos 3 tracks. Spotify URI pre-resolved antes de playback. Crossfade con overlap para transición zero-gap. Búsqueda paralela con `Future.wait` en 3 endpoints simultáneos (artists, albums, tracks)                                                                                           |
| Carga simultánea           | 100  | N/A para app móvil (single user). Request deduplication con `_deduped()` evita llamadas duplicadas al mismo endpoint. `_inFlight` set previene precache concurrente del mismo track. `Completer` lock en token refresh previene refreshes simultáneos                                                                                                                               |
| Uso eficiente de recursos  | 100  | Servicios singleton (DeezerApiService, AudioPrecacheService, SpotifyService). Sleep timer con wall-clock (`DateTime`) no CPU timer. `_saveCacheTimer` con debounce 500ms para batching de escrituras a disco. `enrichTracksWithContributors` usa `Future.wait` para paralelizar llamadas. Foreground service solo cuando reproduce audio                                            |

- [x] ## 5. Escalabilidad

¿Crece sin morir?

- Arquitectura preparada para crecer
- Separación de responsabilidades
- Microservicios vs monolito
- Balanceadores de carga
- Stateless services
- Bases de datos escalables
- Colas (RabbitMQ, Kafka)

**Pregunta clave:**
- ¿Qué pasa si mañana hay 10x usuarios?

## 6. Mantenibilidad

¿Otro dev puede entenderlo?

- Código limpio
- Naming correcto
- Comentarios útiles (no redundantes)
- Arquitectura clara
- Principios SOLID
- DRY / KISS
- Modularidad
- Baja dependencia
- Refactorización fácil

**Pregunta clave:**
- ¿Puedo arreglar un bug sin romper todo?

## 7. Calidad del Código

¿Está bien escrito o solo "funciona"?

- Estructura del proyecto
- Convenciones de estilo
- Linting
- Tipado (TypeScript, tipos fuertes)
- Manejo de errores
- Tests unitarios
- Tests de integración
- Tests end-to-end

## 8. Operatividad (DevOps)

¿Se puede ejecutar y mantener en producción?

- Deploy automatizado
- CI/CD
- Manejo de entornos (dev, qa, prod)
- Rollback
- Variables de entorno
- Logs centralizados
- Monitorización
- Alertas
- Health checks

**Pregunta clave:**
- ¿Qué hago si se cae a las 3 AM?

## 9. Disponibilidad y Resiliencia

¿Qué tan robusto es?

- Tolerancia a fallos
- Retries
- Circuit breakers
- Backups
- Replicación
- Recuperación ante desastres
- Uptime
- SLA

## 10. Compatibilidad

¿Funciona en todos lados?

- Navegadores
- Sistemas operativos
- Dispositivos
- Versiones antiguas
- APIs backward compatible

## 11. Integraciones

¿Cómo se comunica con otros sistemas?

- APIs bien documentadas
- Manejo de errores externos
- Timeouts
- Versionado de API
- Seguridad en integraciones
- Webhooks

## 12. Datos y Base de Datos

¿La info está bien cuidada?

- Modelo de datos correcto
- Normalización
- Índices
- Integridad referencial
- Migraciones
- Backups
- Consistencia
- Manejo de datos corruptos

## 13. Cumplimiento y Legal

¿Cumple la ley?

- Protección de datos personales
- GDPR / Ley local
- Consentimiento
- Logs legales
- Retención de datos
- Auditoría

## 14. Documentación

¿Está documentado o es magia negra?

- README
- Diagramas
- Documentación técnica
- Documentación de API
- Manual de usuario
- Manual de despliegue

## 15. Riesgos y Deuda Técnica

¿Qué puede explotar después?

- Puntos críticos
- Componentes frágiles
- Dependencias obsoletas
- Deuda técnica identificada
- Plan de mejora

## 16. Optimización de Costos
¿Vale lo que cuesta correrlo?

Costos de infraestructura (cloud, hosting, servidores)
Uso eficiente de servicios de terceros (APIs pagadas, SaaS)
Reads/writes innecesarios a base de datos
Funciones serverless mal configuradas (ejecuciones largas, memoria sobreprovisada)
Caché para reducir llamadas repetidas
Almacenamiento sin política de retención ni limpieza
Cold starts y tiempo de cómputo ocioso
Alertas de gasto (billing alerts, presupuestos)
Revisión de tier/plan vs uso real
Costo por usuario activo (unit economics)

Pregunta clave:

¿Cuánto cuesta esto cuando escale a 10x usuarios, y es sostenible?

## 17. Orden y Estructura del Código dentro del Proyecto
¿Se sabe dónde está cada cosa?

Estructura de carpetas coherente y predecible
Separación clara entre capas (presentación, lógica, datos)
Archivos nombrados de forma consistente y descriptiva
No mezclar responsabilidades en un mismo archivo
Componentes/módulos en su carpeta correcta (no todo en /utils o /helpers)
Archivos de configuración separados del código de negocio
Imports ordenados (externos → internos → locales)
No tener código muerto o archivos huérfanos
Consistencia entre cómo está organizado el frontend vs el backend
Convención definida y respetada por todo el equipo (o proyecto)

Pregunta clave:

¿Un dev nuevo puede encontrar cualquier cosa en menos de 2 minutos sin preguntar?

Aquí está el bloque:

18. Métodos de Pago e Integraciones Financieras (opcional)
¿La plata fluye bien y segura?

Integración correcta con el proveedor de pagos (Stripe, Transbank, MercadoPago, etc.)
Flujos de pago probados end-to-end (éxito, rechazo, error, timeout)
Manejo correcto de webhooks (confirmación asíncrona de pagos)
Idempotencia: no cobrar dos veces si hay retry o doble clic
Reembolsos y anulaciones funcionando
Suscripciones y cobros recurrentes bien configurados
Modo test vs modo producción claramente separados
No almacenar datos de tarjeta directamente (PCI-DSS)
Tokens de pago manejados de forma segura
Logs de transacciones para auditoría
Alertas ante fallos en cobros recurrentes
Manejo de estados intermedios (pendiente, procesando, fallido, expirado)
UX clara para el usuario en cada estado del pago
Facturación / boletas electrónicas si aplica legalmente
Conciliación: lo que entra al proveedor coincide con lo registrado en tu BD

Pregunta clave:

¿Qué pasa si el usuario paga, la red falla, y el webhook llega tarde o nunca llega?

## 19. Evaluación Global (visión senior)

¿Es un buen sistema o solo "funciona"?

- Arquitectura correcta
- Escalable
- Seguro
- Mantenible
- Preparado para el futuro
- Costos controlados
- Fácil de evolucionar