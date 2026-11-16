# Tsuki Tunes Mobile — Plan de pulido de front y diseño

Documento de trabajo para ir apartado por apartado. Cada tarea tiene un código (por ejemplo `D-03`) para poder pedirla por su nombre.

## 1. Contexto

- App Flutter de música. Código en `lib/`, interfaz en `lib/presentation/` (pantallas en `screens/`, piezas compartidas en `widgets/`, estado en `state/`).
- Tema y colores: `lib/core/theme/cyber_theme.dart` y `lib/core/constants/app_colors.dart`.
- Tokens de diseño: `lib/core/theme/design_tokens.dart` (`AppFontSize`, `AppRadius`, `AppMotion`, `AppSpacing`); `test/design_tokens_test.dart` falla si aparece un valor suelto. Tras fusionar código con valores sueltos: `python3 tool/design_tokens/migrate.py fonts radii durations margins`.
- Textos: `lib/l10n/app_es.arb` (plantilla), `app_en.arb`, `app_ja.arb`, expuestos por `lib/core/localization/app_strings.dart`. El código de traducciones se regenera solo en cada `flutter pub get` y en cada build (no se commitea); `test/l10n_test.dart` falla si un texto falta en alguno de los tres idiomas.
- Identidad visual: cyberpunk japonés. Fondo oscuro, acento rojo puro (`AppColors.accent`, `#FF1919`), neones cian/púrpura/verde, luna, máscaras (Oni, Tengu y Hannya como ilustraciones base, más unas 130 coleccionables en `lib/domain/entities/oni_mask.dart`: Namahage, Raijin, Kitsune…), tarjetas de "tinta" (`GlassCard`), subtítulos en japonés tipo HUD.

## 2. Reglas (no negociables)

1. **Pulir, no rediseñar.** Se refina lo que hay; la identidad visual no se reemplaza.
2. **Solo Android.** iOS no es objetivo.
3. **Dónde se trabaja.**
   - **En local:** en `main`, sin ramas ni worktrees. Commit sí; `push` solo si se pide.
   - **En una sesión en la nube:** en la rama de la sesión, con `push` al terminar cada tarea (el contenedor se borra al cerrar y lo no subido se pierde). A `main` solo se pasa cuando se pide ("pasa a main").
4. **Una tarea por vez**, y "en verde" quiere decir lo mismo que exige el CI (`.github/workflows/build-apk.yml`), antes de dar algo por hecho:
   - `flutter analyze` sin avisos.
   - `flutter test --exclude-tags golden --coverage`, con la cobertura mínima del 60 % en providers, servicios, repositorios y casos de uso.
   - `flutter test --tags golden`.
5. **Todo cambio visual se muestra** con captura de antes y después.
   - Cuenta como visual cualquier cambio de color, espaciado, tamaño, texto visible o ícono.
   - Se sacan con `TSUKI_SHOTS=<carpeta> TSUKI_SHOT_FONTS=<carpeta con fuentes> flutter test --tags shots test/screenshots` (`test/screenshots/design_shots_test.dart`), una vez antes de tocar nada y otra al terminar.
   - Si el color depende del contenido (portada, paleta, máscara equipada), la captura muestra el peor caso: por ejemplo, una portada azul o violeta, no solo el rojo base.
6. **Accesibilidad ya ganada, no se pierde:** contraste AA, objetivos táctiles de 48 dp, etiquetas para TalkBack y respeto a "reducir movimiento" (`lib/presentation/widgets/motion.dart`).
   - Contraste medido: 4.5:1 para texto normal; 3:1 para texto grande y para íconos y bordes que informan.
   - Un color dinámico (el de la portada, el de la paleta, el aura de una máscara) usado como texto pasa por `readableTint` (`lib/presentation/widgets/player_tint.dart`), que lo aclara hasta cumplir.
   - Excepción aceptada: las líneas atenuadas de las letras (ya cantadas o por venir) quedan por debajo de AA a propósito, como estado inactivo; la línea actual sí cumple.
7. **Texto nuevo siempre en los tres idiomas** (es, en, ja), y con el mismo significado en los tres, no solo presente.
   - Va en los `.arb` (`test/l10n_test.dart` los revisa) o en `lib/core/localization/app_strings.dart` con `_es(es, en, ja)` o un `switch` por idioma, que el compilador obliga a completar.
8. **Tokens de diseño, nunca valores sueltos:** tamaños, radios, duraciones y márgenes salen de `AppFontSize`, `AppRadius`, `AppMotion` y `AppSpacing` (`lib/core/theme/design_tokens.dart`). `test/design_tokens_test.dart` falla si aparece uno suelto.
9. **Un solo vocabulario por cosa:** vibración solo por `Haptics` (`haptics.dart`), animaciones respetando `motion.dart`, superficies con `GlassCard` y cargas con los esqueletos de `skeleton_loader.dart`. Un pulido no inventa su propia variante.
10. **Arreglos de lógica: primero la prueba.** Se escribe una prueba que reproduzca el fallo y se ve fallar; después el arreglo, y la misma prueba pasa.
11. **Sin sorpresas de alcance.**
    - Sin dependencias nuevas sin preguntar.
    - Una tarea visual no cambia comportamiento. Si aparece un bug en el camino, se anota y se hace como tarea aparte.
12. **Cierre de cada tarea:** un mensaje corto con qué cambió, la captura de antes y después (si es visual), el resultado de las pruebas y lo que quedó pendiente.

## 3. Mapa completo de apartados

Inventario hecho contra el código el 13-11-2026: las 26 rutas, todos los archivos de `screens/` y `widgets/`, y lo que vive fuera de la app en `android/`. Si algo no está aquí, no existe en el código.

Rutas base: pantallas en `lib/presentation/screens/`, piezas en `lib/presentation/widgets/`.

### 0. Sistema de diseño (transversal)

- **Tema y colores:** `core/theme/cyber_theme.dart`, `core/constants/app_colors.dart`.
- **Tipografía:** Plus Jakarta Sans y Noto Sans JP (google_fonts); tipografías propias por artista (`core/utils/artist_fonts.dart`, 26 fuentes en `assets/fonts/`).
- **Superficies:** tres niveles (`AppColors.surface`, `surfaceCard`, `surfaceRaised`), `GlassCard` (tarjeta de tinta) y `FrostedGlass` (liquid glass al estilo de Apple, `AppGlass`: desenfoque, borde de luz, brillo interior, sombra solo por fuera). Solo sobre contenido que se mueve (la barra inferior y el mini reproductor, que flotan sobre las páginas con un solo desenfoque compartido; los botones y el título flotante de las páginas de detalle; los avisos) y solo con texto o íconos blancos encima; con alto contraste es sólido. Las hojas siguen sólidas: su texto gris no aguantaría AA sobre vidrio.
- **Botones y toques:** tres tipos (`FilledButton` primario, `OutlinedButton` secundario, `TextButton` de texto, desde el tema), `TapScale`, `MoonButton`, vibración (`haptics.dart`).
- **Texto con efecto:** `GlitchText`, `CyberGlitchText`, `DistortedArtistName`, `LoreText`.
- **Estados:** carga (`skeleton_loader.dart`, 20 esqueletos), error (`ErrorState`), vacío (`EmptyState`, uno solo), sin conexión (franja superior).
- **Hojas inferiores:** `SwipeableSheet` y unas 25 hojas (listadas en su apartado).
- **Títulos de sección:** `SectionTitle` (secciones de contenido) y `SectionLabel` (etiquetas de grupo), ambos anunciados como título.
- **Fin de página:** las páginas del shell pasan bajo la barra de vidrio y terminan con `dockBottom(context)` (el alto de la barra llega como padding inferior).
- **Movimiento:** `motion.dart` (reducir movimiento), tokens `AppMotion` (de `micro` a `ceremony`), transiciones `cyberPage` y `fadePage`.
- **Íconos:** `CyberNavIcon` (barra), `AppCustomIcons`, `ShuffleModeIcon`, `OniMaskIcon`; el resto, Material en su variante redondeada.

### 1. Acceso

- **Carga inicial** (`LoadingRoute`) y control de sesión (`navigation/session_gate.dart`).
- **Login** (`login/login_screen.dart`): el cielo de la entrada (`widgets/tsuki_sky.dart`), botón de Google (`login/google_button.dart`), entrar como observador (invitado), avisos de error.
- **Onboarding** (`onboarding/`): cuatro pasos (biblioteca, descubrir, escuchar, tu camino), cada uno con una demo en vivo sobre vidrio (`onboarding_steps.dart`), bajo el cielo de la entrada; indicador de paso en fases lunares y un botón que cambia en el último paso.
- **Tutorial** (`TutorialRoute`): el mismo onboarding abierto desde ajustes, con fundido, botón de cerrar y "Listo" al final.
- **Permisos explicados** (`permission_primer.dart`): notificaciones y segundo plano, cada uno con su escena animada y tres líneas.

### 2. Estructura

- **Barra inferior** (`widgets/tsuki_nav_bar.dart`, en `main_navigation_screen.dart`): 4 pestañas, ícono animado, subtítulo japonés, lente de vidrio que se desliza, contador de novedades en Biblioteca, gestos (tocar de nuevo, doble toque, mantener para ver atajos). Comparte un solo muelle de vidrio con el mini player.
- **Mini player** (`mini_player.dart`): portada que respira (en su propia capa), título en marquesina con bordes que se desvanecen, artista con "…", progreso como borde iluminado del muelle, marcar escuchada, play/pausa que gira, anillo de carga, tinte por portada aclarado donde no se leería, gestos (deslizar a los lados mostrando la canción a la que va, subir para abrir, bajar para detener), detener con "Deshacer", y mantener para ir al álbum, al artista o a la cola.
- **Avisos globales:** error de Spotify (con guía de batería), error de reproducción y error de sincronización (snacks sobre el muelle), y el aviso de conexión (`connection_notice.dart`), una píldora arriba.
- **Capas sobre toda la app:** aviso de máscara desbloqueada (`mask_unlock_banner.dart`: cápsula de vidrio, o la pantalla entera para UL, divinas y la de otro universo), aviso de subida de nivel (`EcoLevelUpBanner`), ambos sobre `celebration.dart`; hora bruja (`witching_hour_overlay.dart`), cumpleaños (`sakura_overlay.dart`), atmósfera lunar (`moon_atmosphere.dart`).
- **Transiciones y retroceso:** `navigation/routes.dart`, gesto predictivo de Android.
- **Enlaces profundos:** abrir álbum, artista, playlist, canción o perfil por enlace (`load_by_id.dart`, `TrackRoute`).
- **Bloqueos:** invitado sin biblioteca (`guest_library_gate.dart`, `auth_guard.dart`), función bloqueada por nivel (`EcoLocked` y su hoja).

### 3. Inicio (`home_screen.dart`, `home/`)

- **Cabecera:** título, línea de telemetría, botón de luna, insignia de fuente (Spotify/Deezer) y su hoja, botón de Bonds, engranaje de perfil.
- **Línea del cielo** (`sky_line.dart`): momento del día, fase lunar, clima; oferta de mezcla de lluvia (`RainOfferCard`).
- **Hojas que abre:** luna (`moon_sheet.dart`: ciclo, fases, mezcla de luna llena), clima (`weather_sheet.dart`), afinidad (`home/affinity_sheet.dart`).
- **Stats:** canciones, artistas, álbumes, artista top.
- **Tarjeta de hoy** y enlace a Explorar.
- **Top artistas** (o destacados si no hay historial) con botón de ayuda de afinidad.
- **Casi completos** (`home/completion_sections.dart`).
- **Últimos lanzamientos**, **"porque completaste…"** y **recomendados**.
- **Estados:** esqueleto, error de red, biblioteca vacía.

### 4. Buscar (`search_screen.dart`, `genre_screen.dart`)

- **Barra de búsqueda**, botón de voz y hoja de voz (`voice_search_sheet.dart`).
- **Estado inicial:** búsquedas recientes, sugerencias, mosaico de géneros.
- **Sugerencias mientras se escribe** y **"¿quisiste decir?"**.
- **Pestañas de resultados:** todo, artistas, álbumes, canciones, letras (con fragmento resaltado).
- **Pantalla de género.**
- **Estados:** esqueletos por pestaña, error, sin resultados.

### 5. Explorar (`explore_screen.dart`)

- **Música nueva:** Discovery, Rabbit Hole, Radar, Máquina del tiempo.
- **Jugar:** Adivina, Ambiente, Correr.
- **Tu camino:** nivel Eco, racha, retos semanales, Wrapped, Reloj, Máscaras, Lore.

### 6. Biblioteca (`library_screen.dart`)

- **Cabecera** con totales.
- **Pestaña Álbumes:** filtro, orden (recientes, alfabético, por artista), grupos desplegables con sus canciones, barra de progreso de álbum, deshacer al desmarcar.
- **Pestaña Playlists:** lista, crear, playlists compartidas, artistas seguidos.
- **Bloqueo de invitado.**
- **Estados:** esqueleto, error, vacíos.

### 7. Detalle

- **Artista** (`artist_detail_screen.dart`, `artist_detail/`): cabecera con tipografía propia, seguir, radio, compartir, canciones top, álbumes, relacionados, acceso a Rabbit Hole.
- **Discografía** (`artist_discography_screen.dart`): por tipo, paginada.
- **Álbum** (`album_detail_screen.dart`): cabecera, progreso, descargar, marcar todo, lista de canciones.
- **Playlist** (`playlist_detail_screen.dart`): cabecera, editar, reordenar, borrar.
- **Playlist compartida** (`shared_playlist_screen.dart`): colaborativa con Bonds.
- **Fila de canción** (`track_tile.dart`): indicador de reproducción, marca de escuchada, menú de acciones.
- **Hoja "añadir a playlist"** (`playlist_selector_sheet.dart`).
- **Tarjetas** de álbum y artista (`album_card.dart`, `artist_card.dart`).

### 8. Reproductor

- **Expandido** (`expanded_player_screen.dart`, `expanded_player/`): fondo por portada, portada que viaja desde el mini player, visualizador (`rinnegan_visualizer.dart`, `spectrum_wave_visualizer.dart`, `audio_visualizer.dart`, `cyber_orb.dart`), título en marquesina, barra de progreso, controles (aleatorio, anterior, play, siguiente, repetir), aviso de vista previa de 30 s.
- **Cola** (`queue_panel.dart`): en curso, siguientes, reordenar.
- **Letras** (`lyrics_screen.dart`, `lyrics_view.dart`): sincronizadas, traducción, botón de seguir.
- **Hojas:** ambiente (`ambient_mixer_sheet.dart`), ecualizador (`equalizer_sheet.dart`), temporizador de sueño, radio (`radio_control_sheet.dart`), aleatorio inteligente (`smart_shuffle_sheet.dart`), flow por BPM (`flow_sheet.dart`), dispositivos Spotify (`spotify_devices_sheet.dart`), fuente de reproducción (`playback_source_badge.dart`), guía de batería (`battery_guide_sheet.dart`).

### 9. Perfil y ajustes (`profile_bottom_sheet.dart`, `profile/`)

- **Cabecera:** avatar con máscara equipada, nombre, correo, acceso a máscaras.
- **Tarjeta de Spotify:** vincular, desvincular, estado.
- **Reproducción:** crossfade, marcar automático, normalizar, ecualizador, agitar para saltar, modo correr.
- **Almacenamiento:** precarga solo con Wi-Fi, reproducción automática, aleatorio inteligente, copiar registro, borrar caché.
- **General:** atmósfera lunar, clima, vibración, analítica, cumpleaños, calidad de imagen (y su hoja), idioma (`language_selector_sheet.dart`), tutorial, privacidad, términos, versión.
- **Cuenta:** cerrar sesión (`profile/logout.dart`), borrar cuenta (`profile/delete_account.dart`).

### 10. Social

- **Bonds** (`bonds_screen.dart`): pestañas Resonancias, Bonds y Buscar; solicitudes; panel de observador.
- **Perfil de usuario** (`user_profile_screen.dart`): avatar, stats, tarjeta de sintonía, controles propios.
- **Party** (`party_screen.dart`): escuchar en sincronía.

### 11. Descubrimiento

- **Discovery** (`discovery_screen.dart`): tarjetas para deslizar, sellos de guardar/pasar.
- **Rabbit Hole** (`rabbit_hole_screen.dart`): grafo de artistas, migas, tarjeta de foco, panel inferior.
- **Radar de lanzamientos** (`release_radar_screen.dart`): barrido, fila de notificaciones, lista.
- **Máquina del tiempo** (`time_machine_screen.dart`): fecha, momento, portada.
- **Importar de Spotify** (`spotify_import_screen.dart`).

### 12. Stats y juegos

- **Wrapped** (`wrapped_screen.dart`, selector en `wrapped_picker_sheet.dart`): historias de intro, minutos, canción, artista y álbum top, hora, aura, datos, resumen; imagen para compartir (`wrapped/story_image.dart`).
- **Reloj de escucha** (`listening_clock_screen.dart`): radar de 24 horas, barras por día.
- **Adivina la canción** (`guess_song_screen.dart`): modos diario, por artista, top mundial y biblioteca; ronda y resultado.
- **Modo correr** (`run_mode_screen.dart`): medidor de cadencia, panel de música, ritmo, estadísticas de sesión.

### 13. Progresión, lore y ambiente

- **Niveles Eco** (`eco_levels_screen.dart`, `eco_widgets.dart`): cabecera, cómo ganar Eco, selector de color, lista de niveles, leyenda; tarjeta de nivel, barra, insignia.
- **Racha** (`streak_screen.dart`, `streak_card.dart`): cabecera, stats, calendario, metas, escudo, recordatorio.
- **Retos semanales** (`weekly_challenges_card.dart`): retos y premio.
- **Máscaras / Seres etéreos** (`mask_collection_screen.dart`, `oni_mask_art.dart`): rejilla, barra de progreso, detalle, susurro, botón a Lore.
- **Ascensión** (`ascension_screen.dart`): aviso, elección, revelación.
- **Lore** (`lore_screen.dart`, contenido en `domain/lore/tsuki_lore.dart`):
  - Portada: título, subtítulo, capítulos abiertos de total.
  - Tomos y lista de capítulos, cada uno abierto o bloqueado por nivel.
  - "Próximamente" para lo que aún no se publica.
  - Pantalla de capítulo: texto, facciones (líder, rival, miembros, secreto, recompensa), vínculos entre máscaras y rostros (velados hasta desbloquear).
- **Ambiente:** luna (`moon_glyph.dart`, `moon_button.dart`), clima, hora bruja, sakura.

### 14. Fuera de la app (Android)

- **Widgets de pantalla de inicio:** luna y reproductor (`android/app/src/main/res/layout/widget_luna.xml`, `widget_player.xml`).
- **Atajo de ajustes rápidos:** mezcla de lluvia (`RainMixTileService.kt`).
- **Notificaciones:** reproducción, nuevos lanzamientos, racha, máquina del tiempo.
- **Android Auto** (`data/datasources/auto_media_library.dart`).
- **Ícono de la app** (con capa monocroma) y pantalla de arranque.
- **Compartir:** enlaces de álbum, artista y playlist; imagen de Wrapped.

## 4. Ya hecho: barra inferior de 4 pestañas

Orden: **Inicio · Buscar · Explorar · Biblioteca**.

- `navigation/main_tab.dart`: enum `MainTab` (home, search, explore, library). Reemplaza los índices escritos a mano. Para cambiar de pestaña desde cualquier pantalla: `NavigationEvents.switchTab?.call(MainTab.search)`.
- `widgets/cyber_nav_icon.dart`: recibe `tab:` en vez de `index:`; ícono nuevo de brújula para Explorar.
- `screens/explore_screen.dart`: pantalla nueva con tres secciones.
  - **Música nueva:** Discovery, Rabbit Hole, Radar, Máquina del tiempo.
  - **Jugar:** Adivina, Ambiente, Correr.
  - **Tu camino:** nivel Eco, racha, retos semanales, Wrapped, Reloj, Máscaras, Lore.
- Inicio ya no apila esas tarjetas. Conserva stats, **una tarjeta de hoy** (por prioridad: novedades del radar → juego diario pendiente → racha → nivel Eco) con un enlace a Explorar, y luego la música.
- Prueba: `test/explore_tab_test.dart`. Con la variable `TSUKI_SHOTS=<carpeta>` guarda además capturas de cada pantalla (útil para el antes y después).
- Pendiente: verlo en un teléfono real (ver X-01).
- Piezas que antes eran privadas de Inicio y ahora son compartidas: `widgets/section_title.dart` (`SectionTitle`), `widgets/feature_card.dart` (`FeatureCard`), `widgets/entry_cards.dart` (tarjetas de entrada), `state/daily_guess.dart` (si el juego diario ya se jugó).

## 5. Tareas por apartado

Lo que ya está hecho en `main` (D-01 a D-12 salvo D-07, y muchas tareas de los demás apartados) lo resume `Documentos/Informe de la noche - pulido front.md`.

Prioridad: **A** = primero, **B** = después, **C** = cuando haya tiempo.

### 0. Sistema de diseño (hacer primero: abarata todo lo demás)

| Código | Tarea | Hecho cuando… | Prio |
|---|---|---|---|
| D-01 | ~~Escala tipográfica: 33 tamaños, con medios puntos. Definir 7 u 8 tokens y migrar.~~ **Hecho** en `design_tokens.dart`: 10, 11, 12, 13, 14, 16, 22 y 28, más 40 y 64 para cifras y adornos. Detalle en `Documentos/Informe de la noche - pulido front.md`. | No queda ningún `fontSize:` suelto fuera de los tokens en `presentation/`. | A |
| D-02 | ~~Texto diminuto: mínimo 10 en todo lo que informe.~~ **Hecho:** el paso más bajo de la escala (`AppFontSize.micro`) ya es 10. | Ningún texto informativo bajo el mínimo; solo adornos pueden ir por debajo. | A |
| D-03 | ~~Radios: 21 valores distintos. Dejar 4 tokens (chip, tarjeta, sheet, píldora).~~ **Hecho:** `AppRadius` (chip, card, sheet, pill). Quedan 4 radios calculados en el momento (el disco que se transforma, la máscara a escala), que es lo correcto. | Todos los `BorderRadius.circular` usan un token. | A |
| D-04 | ~~Animaciones: unas 25 duraciones sueltas.~~ **Hecho:** `AppMotion` de `micro` a `slow` para transiciones, más `reveal`, `revealLong`, `cycle`, `breath` y `ceremony` para los bucles y revelaciones largas. `design_tokens_test` no deja ninguna duración escrita a mano. | Las duraciones salen de los tokens. | B |
| D-05 | ~~Margen lateral: alterna 16 y 20 según pantalla.~~ **Hecho:** `AppSpacing.page` (16). | Un solo valor de margen de página. | B |
| D-06 | ~~Un `EmptyState` compartido.~~ **Hecho:** todos los vacíos lo usan, también los avisos de error y de biblioteca vacía del inicio. | Las 7 pantallas usan el mismo widget. | A |
| D-07 | ~~Un solo título de sección.~~ **Hecho:** `SectionTitle` para secciones de contenido y `SectionLabel` para etiquetas de grupo (ajustes, historial de búsqueda, Lazos, radar, cola, resultados), las dos anunciadas como título. | Solo existe un título de sección. | B |
| D-08 | ~~Un helper de snackbar.~~ **Hecho:** `AppSnack`; ningún `SnackBar(` a mano. | Ningún `SnackBar(` construido a mano. | A |
| D-09 | ~~Una sola flecha de volver.~~ **Hecho:** `arrow_back_rounded`. | Un único ícono en toda la app. | C |
| D-10 | ~~Botones: primario, secundario y de texto.~~ **Hecho:** desde el tema, con esquina de chip y 48 dp; sin `ElevatedButton` ni `CyberButton` (`test/button_types_test.dart`). | Cada botón es uno de los tres tipos. | B |
| D-11 | ~~Colores fuera de paleta a `AppColors`.~~ **Hecho:** el santuario (Eco, racha, Lore, Ascensión) y las ilustraciones (login, onboarding, Wrapped, cielos) tienen nombre. Solo el dibujo sobre lienzo de `story_image.dart` conserva sus degradados. | Ningún `Color(0x…)` en pantallas. | C |
| D-12 | ~~**Rojo con significado.**~~ **Hecho:** la guía está en `app_colors.dart` (rojo para lo que suena, la acción principal y lo activo; cian información, púrpura social, verde Spotify) y aplicada en las cuatro pestañas: insignia de fuente verde o neutra, portadas faltantes en gris, primario para "Crear playlist". | Guía escrita y aplicada en las pestañas principales. | A |
| D-13 | **Tipografía de titulares:** sumar una display técnica y condensada para títulos (`INICIO // 01`) y cifras monoespaciadas para stats y tiempos. El cuerpo sigue en Plus Jakarta. **Hecha la mitad sin fuente nueva:** cifras de ancho fijo (`getTextStyle(tabular: true)`) en tiempos, duraciones y contadores. **Pendiente de decisión:** la fuente display cambia la identidad (regla 1). | Títulos y números usan las nuevas familias. | B |
| D-14 | ~~**Profundidad con luz.**~~ **Hecho:** `surface`, `surfaceCard` y `surfaceRaised` (hojas, diálogos y menús); `borderGlow` solo para lo activo (`test/surfaces_test.dart`). | Tokens de superficie aplicados a las tarjetas. | B |
| D-15 | ~~Un solo juego de íconos.~~ **Hecho:** todos los íconos Material en su variante redondeada (los delineados quedan donde significan "apagado"); `design_tokens_test` lo vigila. Redibujar a mano los más usados al estilo de la barra queda como idea, no como deuda. | Íconos principales redibujados o sustituidos. | C |

### 1. Acceso

| Código | Tarea | Prio |
|---|---|---|
| A-01 | ~~Login tiene 7 `CustomPaint` animados.~~ **Hecho:** el login comparte el cielo de la entrada (`widgets/tsuki_sky.dart`: la nebulosa en un shader y las brasas), con un solo ticker y pintores que se redibujan sin reconstruir; la máscara de la entrada sube a su lugar con su anillo (que es el indicador de carga), el nombre aparece con un glitch, y las entradas van en un panel de *liquid glass*: el botón oficial de Google, el observador, una línea que dice qué pasa (sin conexión, cuenta regresiva por intentos, error con "Reintentar") y los Términos (`test/login_screen_test.dart`). | B |
| A-02 | ~~Onboarding: es donde más texto diminuto y sombras hay. Subir tamaños y aligerar.~~ **Hecho:** rehecho sobre el cielo de la entrada (nebulosa y brasas, un solo ticker). Son cuatro pasos y cada uno muestra la app de verdad en una demo en vivo sobre *liquid glass*: canciones que se marcan con la máscara mientras el álbum gana color (y se pueden tocar), una búsqueda que se escribe sola con sus resultados y la radio del artista, el disco girando con la vista previa y la letra karaoke, y el nivel Eco llenándose mientras despiertan tres máscaras del catálogo (R, SR, SSR). Tiene parallax al deslizar, indicador en fases lunares, títulos anunciados como encabezado y "Paso n de 4" para TalkBack. Solo anima el paso visible (`TickerMode`) y, con menos movimiento, cada demo muestra su estado final quieta. Los textos van con tokens en es/en/ja y se borraron 27 claves viejas (`test/onboarding_screen_test.dart`). | B |
| A-04 | ~~Tutorial desde ajustes.~~ **Hecho:** abre el mismo recorrido con fundido, tiene botón de cerrar en vez de "Saltar" y termina en "Listo". El botón atrás de Android retrocede un paso antes de salir (también en el primer arranque). | B |
| A-05 | ~~Permisos explicados.~~ **Hecho:** la hoja actúa una vez lo que da el permiso. En notificaciones, la campana suena y cae el aviso del Radar tal como lo mostraría Android ("Daft Punk sacó un álbum nuevo"). En segundo plano, el teléfono se bloquea y la canción sigue sonando. Debajo van la pregunta como encabezado, tres líneas cortas que suben una tras otra y los botones en píldora. Se acomoda sin bucles y queda quieta con menos movimiento; el diálogo de Android sigue llegando solo después de un sí (`test/permission_primer_test.dart`). | B |
| A-03 | ~~Que la pantalla de carga enlace con el login sin salto visual; entrada animada desde el ícono.~~ **Hecho:** `LoadingScreen` sigue al splash de Android sin costura (misma noche `AppColors.splash`, la misma máscara en el mismo lugar), respira con un brillo rojo y, si tarda, dice "Despertando la luna…". El splash de Android 7 a 11 ya no dibuja el logo gigante y recortado. Nunca queda trabada: almacenamiento que falla o Firebase que no responde (8 s) siguen de largo (`test/startup_test.dart`). | C |

### 2. Estructura

| Código | Tarea | Prio |
|---|---|---|
| E-01 | ~~Subtítulo japonés de la barra (8.5 px): subirlo o dejarlo solo en la pestaña activa.~~ **Hecho:** va en el piso de la escala y solo en la pestaña activa, como adorno (TalkBack no lo lee). Todas las pestañas miden lo mismo: antes el indicador hacía más alta la activa y las etiquetas saltaban 14 px al cambiar. La etiqueta activa usa `accentText`, el rojo para texto (`test/bottom_bar_test.dart`). | A |
| E-02 | ~~Gestos ocultos de la barra (doble toque, mantener): enseñarlos una vez o darles alternativa visible.~~ **Hecho:** mantener una pestaña abre, sobre ella, un menú con sus atajos (Inicio: perfil, arriba, actualizar; Buscar: búsqueda nueva, escribir; Explorar y Biblioteca: arriba); elegir abre la pestaña y lo ejecuta. El doble toque cuenta solo en la pestaña ya abierta (antes, tocar dos veces una pestaña nueva la abría y además disparaba el atajo). El consejo se muestra una vez, al tercer cambio. TalkBack oye una barra de pestañas ("Inicio, pestaña 1 de 4, seleccionada") y "mantén para ver atajos". | B |
| E-03 | ~~Los tres avisos globales (Spotify, reproducción, sincronización) son código repetido dentro de `build`: pasarlos al helper de D-08.~~ **Hecho:** se escuchan con `ref.listen` (nada se muestra desde una reconstrucción) y pasan por un solo `_notice` con `AppSnack` sobre el muelle; se fueron los tres campos que recordaban el último aviso. La franja roja de "Sin conexión" (blanco sobre rojo, unos 3.9:1, bajo AA) es ahora una píldora de vidrio oscuro arriba, con borde y resplandor rojos; al volver la conexión dice "De nuevo en línea" en verde un momento y se va, y TalkBack anuncia los dos cambios (`test/shell_notices_test.dart`). En el mini player, play y pausa cambian girando, al cargar corre un anillo alrededor del botón (que sigue a la vista) y el progreso brilla en el color del reproductor con un punto de luz en la punta. | A |
| E-04 | ~~Seis pantallas (Eco, Lore, Racha, Ascensión, playlist compartida, Letras) abren con `MaterialPageRoute`; usar la transición propia (`cyberPage`).~~ **Hecho:** ninguna pantalla usa `MaterialPageRoute`; `design_tokens_test` lo vigila. | B |
| E-05 | ~~Fundir barra y mini player en un solo muelle: la línea de progreso es el borde superior de la barra.~~ **Hecho:** un solo vidrio con esquinas superiores redondeadas; el progreso de la canción es su borde superior iluminado (sin tocar las esquinas), el color del reproductor es su resplandor, y una línea fina separa la canción de las pestañas. Sin canción, el muelle es solo la barra. | B |
| E-06 | ~~Indicador de pestaña activa que se desliza de una a otra.~~ **Hecho:** un lente de vidrio más claro, con una luz roja al pie, viaja de pestaña en pestaña estirándose como una gota (el borde que avanza va delante y el otro lo alcanza), desde donde esté aunque vaya a medio camino; con menos movimiento salta. Reemplaza a `CyberTabIndicator`. Biblioteca muestra un contador ("+3", "9+") que aparece con un pop y que TalkBack lee. | C |
| E-07 | ~~Mini player: deslizar a los lados cambia de canción; hacia arriba lo abre.~~ **Hecho:** ya existía; ahora la fila sube con el dedo y abre el reproductor al pasar el umbral (o con un gesto rápido), y vuelve si se suelta antes. Al deslizar a los lados aparece, del lado del que viene, el ícono de la canción a la que va, que se enciende al llegar al umbral. TalkBack tiene "Abrir el reproductor", "Siguiente pista" y "Pista anterior" como acciones. | B |
| E-09 | ~~Avisos globales que ayudan.~~ **Hecho:** cada aviso trae lo que se puede hacer. Sin vista previa, formato o error genérico: **Siguiente** (si hay otra canción). Error de red con conexión: **Reintentar** (la misma canción). Sin conexión y sin guardar: **Siguiente**. Spotify cerrado: **Abrir Spotify**. "Spotify en pausa" se dice una vez por sesión. Un cambio que el servidor rechazó se cuenta como pasó ("No se pudo marcar como escuchada: quedó como estaba") en vez de "Intenta de nuevo", que no ayudaba. Todos los textos dicen "canción" (nunca "pista", "track" ni "caché") y son cortos, en es/en/ja (`test/shell_notices_test.dart`, `test/playback_error_classification_test.dart`). | A |
| E-10 | ~~Capas sobre toda la app.~~ **Hecho.** *Avisos:* máscara y nivel son una cápsula de *liquid glass* con borde y resplandor del color de la rareza o del rango (`CelebrationBanner`); el título se aclara hasta leerse (el violeta SR daba 3.9:1), con la fuente del idioma; se queda lo que tarda en leerse (más con TalkBack), se pausa con el dedo encima y baja si está la píldora de conexión. *Rareza:* SSR con un destello que cruza la máscara; UL, divinas e Ikai con un momento a pantalla completa (la máscara flotando en su halo, rayos, "De otro universo" para Ikai, vibración de tres golpes). *Cumpleaños:* una lluvia de pétalos con forma real de unos 12 s la primera vez que se abre ese día, bajo una píldora "Feliz cumpleaños" que la repite al tocarla; antes redibujaba la app entera todo el día. *Hora bruja:* a las 3:33 con música, además del glitch, un susurro del lore ("La hora en que el velo se adelgaza…") y un latido; con menos movimiento llega quieta en vez de no llegar. *Atmósfera:* luna nueva oscurecía hasta un 40% en los bordes (el texto secundario quedaba en unos 2.5:1); ahora el máximo es 13%, justo lo que deja todo el texto sobre 4.5:1, y un test lo mide; la luz de luna llena cae desde fuera de la esquina; los glitches del eclipse, cada 15 a 30 s (`test/app_layers_test.dart`). | B |
| E-11 | ~~**120 fps: nada redibuja en reposo.**~~ **Hecho:** con música sonando y la app quieta, había animaciones que pedían un frame tras otro para siempre, y cada frame vuelve a calcular el vidrio del muelle (un desenfoque): la portada del mini player respiraba sin fin (y cambiaba el radio de su sombra, lo más caro de pintar), la marquesina del título pedía frames también en sus pausas, las barras de la canción en las listas bailaban sin parar y la luz de cada máscara UL giraba sin descanso. Ahora la portada respira dos veces al empezar una canción y queda encendida; el título pasa, descansa 10 s sin pedir frames y vuelve (y su desvanecido solo existe si no cabe); las barras bailan unos 7 s; la luz de las UL da una vuelta y descansa 8 s. Las siluetas de las máscaras bloqueadas se pintan sobre la imagen (sin capa de filtro) y las secretas se difuminan con una copia diminuta de la imagen en vez de un blur que se recalculaba en cada frame del scroll. `test/idle_frames_test.dart` exige que, tras unos segundos quieta, la app no tenga ninguna animación corriendo (fallaba en los tres casos con el código anterior). | A |
| E-12 | ~~**Fluidez al cambiar de sección y en la primera carga.**~~ **Hecho:** *Fuentes:* Plus Jakarta Sans viene dentro de la app (OFL) y se quitó `google_fonts`, que la bajaba de internet al primer arranque (el texto salía en otra fuente y saltaba al llegar); el japonés usa la Noto Sans CJK del sistema. *Pestañas:* la anterior se va de inmediato y solo la nueva aparece con un fundido corto (antes las dos pantallas enteras, semitransparentes, se dibujaban aparte en cada frame del cambio); cada una conserva su estado (`test/fade_indexed_stack_test.dart`). Unos segundos después de abrir, las otras pestañas se construyen por detrás, de a una y solo cuando nada se mueve, para que la primera visita no tenga nada pesado que armar. *Barra:* sin el temblor lateral del ícono, un solo grosor de letra (el que cambiaba volvía a medir la palabra en cada frame) y el lente en 300 ms. *Entrada y login:* el anillo es un aro limpio con una estela que termina en una cabeza de luz (sin la corona de marcas); el cielo se mueve a 60 actualizaciones por segundo (la mitad del costo a 120 Hz, igual a la vista); el panel del login y las tarjetas del onboarding no difuminan la nebulosa, que ya es difusa (ese blur se rehacía en cada frame); la máscara sube trasladándose, sin rehacer el layout, en una entrada de 900 ms. | A |
| E-13 | ~~**Fluidez a fondo: cada frame hace solo lo que cambia.**~~ **Hecho** (medido contando lo que se reconstruye en cada frame, `test/rebuild_budget_test.dart`): *Arrastres:* bajar el reproductor para cerrarlo reconstruía la pantalla entera (portada, controles, letras) en cada frame, y también al volver; ahora solo se mueve (de 1470 a 6 reconstrucciones en 6 frames; la vuelta, de 4900 a 19). Lo mismo al deslizar o levantar el mini player (de 355 a 30 y de 284 a 4), al arrastrar una carta en Descubrir y al bajar el Wrapped. La página del reproductor no se estira al tirar hacia abajo (ya se mueve entera). *Cambio de color entre canciones:* el fundido del color reconstruía en cada frame toda la barra inferior, el mini player, el reproductor abierto y la tarjeta de letras; ahora solo lo pintado del color lo sigue (en el muelle, de 4971 a 766; en el reproductor, de 7637 a 1173). *Listas:* pausar, reanudar o pasar de canción reconstruye solo las filas que cambian (de 36 a 4). *Teléfonos de 360 dp:* la etiqueta "Canción completa · Spotify" se ajusta en vez de sacar de pantalla el temporizador. *Búsqueda:* el historial que llega después de cerrar la pantalla ya no avisa a un proveedor desechado. | A |
| E-08 | ~~Mini player a fondo.~~ **Hecho:** el botón de play y los textos tomados de la portada se aclaran solos cuando el color es demasiado oscuro (3:1 para íconos, 4.5:1 para texto; antes una portada azul marino dejaba el play casi invisible). Detener, con la ✕ o deslizando hacia abajo, ofrece "Reproducción detenida · Deshacer", que devuelve la canción, su cola y el punto exacto. Al deslizar a los lados se ve por su nombre la canción a la que va, o "Desde el inicio" cuando "anterior" repetiría la actual (`PlaybackQueue.peekPrevious`, sin moverla). Mantener presionado lleva al álbum, al artista o a la cola. Solo el título se mueve, con bordes que se desvanecen; el artista termina en "…"; el título sube a 14 y el artista a 12. La portada respira en su propia capa, sin repintar el muelle (`test/mini_player_test.dart`). | B |

### 3. Inicio

| Código | Tarea | Prio |
|---|---|---|
| I-01 | **Velocidad:** la carga es en cadena (destacados → fotos → lanzamientos) y el esqueleto espera a la red cada vez. Mostrar lo último guardado al instante, refrescar por detrás y paralelizar. Está en `_loadHomeData`. | A |
| I-02 | Tirar para refrescar borra todo y vuelve al esqueleto: mantener el contenido mientras recarga. | A |
| I-03 | Cabecera con 4 o 5 íconos a la derecha y el título encogiéndose: mover Bonds o la insignia de fuente. | B |
| I-04 | Stats: ancho fijo de 140, etiqueta a 10 px y pie a 9. Franja compacta, más legible, y tocables hacia su detalle. | B |
| I-05 | Saludo según hora y luna ("Buenas noches · luna menguante"). | C |
| I-06 | Tarjeta grande "seguir escuchando" teñida con la portada, y rejilla 2×3 de accesos rápidos a lo reciente. | B |
| I-07 | Carruseles con imán que dejan asomar el siguiente elemento. | C |

### 4. Buscar

| Código | Tarea | Prio |
|---|---|---|
| B-01 | `search_screen.dart` tiene 1264 líneas en un solo estado: separar resultados, letras y vacío en widgets propios, para que escribir no redibuje todo. | A |
| B-02 | Estado vacío (recientes, géneros, sugerencias) con el estilo común de secciones. | B |
| B-03 | Géneros como mosaico con color e imagen propios. | B |
| B-04 | Mejor resultado como tarjeta destacada arriba de la lista. | B |
| B-05 | Chips de filtro fijos al hacer scroll; recientes con portada. | C |

### 5. Explorar

| Código | Tarea | Prio |
|---|---|---|
| X-01 | Revisar la pantalla en teléfono real: orden de tarjetas, densidad y qué ve un invitado. | A |
| X-02 | Dar identidad común a las pantallas de progresión que cuelgan de aquí (ver P-05). | B |

### 6. Biblioteca

| Código | Tarea | Prio |
|---|---|---|
| L-01 | 1192 líneas con grupos desplegables: confirmar que la lista es perezosa de punta a punta con bibliotecas grandes. | A |
| L-02 | Botones de orden y filtro hechos a mano: pasarlos a chips comunes. | B |
| L-03 | Vacíos de álbumes, playlists y artistas con `EmptyState` y acción directa a Buscar. | B |
| L-04 | Vista de muro de portadas con anillo de progreso, alternable con la lista. | B |
| L-05 | Chips: completos, en progreso, descargados. Índice alfabético lateral. | C |

### 7. Detalle

| Código | Tarea | Prio |
|---|---|---|
| T-01 | Cabeceras de artista, álbum y playlist: misma altura, mismo colapso al hacer scroll, mismos botones. | A |
| T-02 | Color de la portada (ya se calcula en `state/cover_colors.dart`) en la cabecera de álbum y playlist. | B |
| T-03 | La portada viaja de la lista a la cabecera y de ahí al reproductor. | B |
| T-04 | Fila de canción: densidad y texto pequeño del menú. | B |
| T-05 | Cabecera de artista: 4 sombras, aligerar. Nombre con su tipografía propia como protagonista. | C |
| T-06 | Discografía como línea de tiempo por año. | C |

### 8. Reproductor

| Código | Tarea | Prio |
|---|---|---|
| R-01 | La cola (`queue_panel.dart`) es el archivo con más texto diminuto: subir tamaños. | A |
| R-02 | Unificar los sheets: mismo tirador, radio, título y altura. `SwipeableSheet` existe, pero unos 20 sheets abren por su cuenta. | A |
| R-03 | Letras usa desenfoque de fondo: medir en gama baja y ofrecer versión plana. | B |
| R-04 | Confirmar que visualizador, portada y brillo del botón se pausan cuando el reproductor no está a la vista. | A |
| R-05 | Línea actual de la letra asomando bajo el título; tocarla abre Letras. | B |
| R-06 | Deslizar la portada para cambiar de canción. | B |
| R-07 | Barra de progreso más alta al tocarla, con burbuja de tiempo. | C |

### 9. Perfil y ajustes

| Código | Tarea | Prio |
|---|---|---|
| S-01 | Más de 20 opciones en un sheet: pasar a pantalla completa con secciones. | A |
| S-02 | Lo técnico (copiar registro, borrar caché) a un grupo "Avanzado" al final. | B |
| S-03 | `settings_sections.dart` tiene 16 `setState`: cada interruptor redibuja su sección entera. | B |
| S-04 | Pantalla de identidad: máscara como avatar, nivel Eco, racha y géneros top; ajustes debajo. | B |

### 10 a 13. Social, descubrimiento, juegos, progresión y lore

| Código | Tarea | Prio |
|---|---|---|
| P-01 | Adivina (1772 líneas), Wrapped (1795) y Rabbit Hole (1759) son monolitos: partirlos. | B |
| P-02 | Bonds: 18 botones de estilos distintos; pasar a los tres tipos de D-10. | B |
| P-03 | Wrapped: 7 sombras más desenfoque; revisar fluidez entre historias. Plantillas de tarjeta para compartir. | B |
| P-04 | Bonds, Lore, Máscaras, racha y retos escuchan proveedores enteros (`ref.watch(maskProvider)`): pasar a `select`. | A |
| P-05 | Progresión repartida en 6 pantallas con cabeceras y colores distintos: identidad común. | B |
| P-06 | Estados vacíos con personaje: Oni, Tengu y Hannya como ilustración grande con una línea de lore. | B |
| P-07 | Máscaras como santuario (inclinación con el sensor) y ceremonia a pantalla completa al desbloquear. | C |
| P-08 | Cargas con marca: la luna pasando por sus fases en vez del círculo genérico. | C |
| P-09 | La fase lunar modula fondo y brillos en toda la app. | C |
| P-10 | **Lore, lectura:** revisar la pantalla de capítulo como texto para leer: tamaño, interlineado y ancho de línea; facciones, vínculos y rostros con la misma jerarquía. | A |
| P-11 | **Lore, portada:** tomos y capítulos con progreso visible, y un estado bloqueado claro (qué nivel lo abre). | B |
| P-12 | **Lore, técnica:** abre con transición estándar (ver E-04), tiene 9 colores escritos a mano (ver D-11) y escucha el proveedor entero 8 veces (ver P-04). | B |
| P-13 | **Racha:** revisar la pantalla completa (calendario, metas, escudo, recordatorio); tiene 5 colores a mano. | B |
| P-14 | **Ceremonias:** Ascensión, máscara desbloqueada y subida de nivel con un mismo lenguaje visual. | B |
| P-15 | **Niveles Eco:** lista de niveles y "cómo ganar Eco" más fáciles de recorrer; 13 colores a mano. | B |

### 14. Fuera de la app (Android)

| Código | Tarea | Prio |
|---|---|---|
| F-01 | Widgets de luna y reproductor con el mismo lenguaje visual de la app. | B |
| F-02 | Notificaciones (reproducción, lanzamientos, racha, máquina del tiempo): revisar textos, ícono y arte. | B |
| F-03 | Android Auto: revisar cómo se ven las listas y portadas. | C |
| F-04 | Ícono y pantalla de arranque enlazados con la carga inicial (ver A-03). | C |
| F-05 | Imágenes y enlaces para compartir (álbum, artista, playlist, Wrapped) con plantilla común. | B |

## 6. Orden de trabajo

1. Apartado 0, tareas de prioridad A (D-01, D-02, D-03, D-06, D-08, D-12).
2. Estructura (E-01, E-03) e Inicio (I-01, I-02).
3. Buscar, Biblioteca, Detalle y Reproductor, en ese orden, primero las A.
4. Perfil y ajustes.
5. El resto, y al final las C.

## 7. Cómo pedir una tarea

Ejemplo de mensaje: "Haz D-06. Reglas del documento `Documentos/Plan de pulido - Front y diseño.md`." Las reglas ya incluyen la captura de antes y después y cuándo se hace `push` (regla 3), así que no hace falta repetirlas.

## 8. De dónde salen los números

Las cifras (33 tamaños, 95 textos diminutos, 21 radios, 60 snackbars) vienen de contar ocurrencias en `lib/presentation/` el 13-11-2026. Son aproximadas y cambian con cada tarea hecha: conviene volver a contar antes de empezar una.
