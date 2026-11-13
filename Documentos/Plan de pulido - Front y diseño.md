# Tsuki Tunes Mobile — Plan de pulido de front y diseño

Documento de trabajo para ir apartado por apartado. Cada tarea tiene un código (por ejemplo `D-03`) para poder pedirla por su nombre.

## 1. Contexto

- App Flutter de música. Código en `lib/`, interfaz en `lib/presentation/` (pantallas en `screens/`, piezas compartidas en `widgets/`, estado en `state/`).
- Tema y colores: `lib/core/theme/cyber_theme.dart` y `lib/core/constants/app_colors.dart`.
- Tamaños de letra: `lib/core/theme/app_font_size.dart` (`AppFontSize`). Ningún `fontSize` con número suelto en `presentation/`.
- Textos: `lib/l10n/app_es.arb` (plantilla), `app_en.arb`, `app_ja.arb`, expuestos por `lib/core/localization/app_strings.dart`. El código de traducciones se regenera solo en cada `flutter pub get` y en cada build (no se commitea); `test/l10n_test.dart` falla si un texto falta en alguno de los tres idiomas.
- Identidad visual: cyberpunk japonés. Fondo oscuro, acento rojo puro (`AppColors.accent`, `#FF1919`), neones cian/púrpura/verde, luna, máscaras (Oni, Tengu y Hannya como ilustraciones base, más unas 130 coleccionables en `lib/domain/entities/oni_mask.dart`: Namahage, Raijin, Kitsune…), tarjetas de "tinta" (`GlassCard`), subtítulos en japonés tipo HUD.

## 2. Reglas (no negociables)

1. **Pulir, no rediseñar.** Se refina lo que hay; la identidad visual no se reemplaza.
2. **Solo Android.** iOS no es objetivo.
3. **Trabajar en `main`.** Sin ramas ni worktrees. Commit sí; `push` solo si se pide.
4. **Una tarea por vez**, con `flutter analyze` y `flutter test` en verde antes de dar algo por hecho.
5. **Todo cambio visual se muestra** con captura de antes y después.
6. **Accesibilidad ya ganada, no se pierde:** contraste AA, objetivos táctiles de 48 dp, etiquetas para TalkBack y respeto a "reducir movimiento" (`lib/presentation/widgets/motion.dart`).
7. **Texto nuevo siempre en los tres idiomas** (es, en, ja).

## 3. Mapa completo de apartados

Inventario hecho contra el código el 13-11-2026: las 26 rutas, todos los archivos de `screens/` y `widgets/`, y lo que vive fuera de la app en `android/`. Si algo no está aquí, no existe en el código.

Rutas base: pantallas en `lib/presentation/screens/`, piezas en `lib/presentation/widgets/`.

### 0. Sistema de diseño (transversal)

- **Tema y colores:** `core/theme/cyber_theme.dart`, `core/constants/app_colors.dart`.
- **Tipografía:** Plus Jakarta Sans y Noto Sans JP (google_fonts); tipografías propias por artista (`core/utils/artist_fonts.dart`, 26 fuentes en `assets/fonts/`).
- **Superficies:** `GlassCard` (tarjeta de tinta), `cyberCardBox`.
- **Botones y toques:** `CyberButton`, `TapScale`, `MoonButton`, vibración (`haptics.dart`).
- **Texto con efecto:** `GlitchText`, `CyberGlitchText`, `DistortedArtistName`, `LoreText`.
- **Estados:** carga (`skeleton_loader.dart`, 20 esqueletos), error (`ErrorState`), vacío (7 versiones sueltas), sin conexión (franja superior).
- **Hojas inferiores:** `SwipeableSheet` y unas 25 hojas (listadas en su apartado).
- **Títulos de sección:** `SectionTitle` y 5 versiones sueltas.
- **Movimiento:** `motion.dart` (reducir movimiento), transiciones `cyberPage` y `fadePage`.
- **Íconos:** `CyberNavIcon` (barra), `AppCustomIcons`, `ShuffleModeIcon`, `OniMaskIcon`; el resto, Material.

### 1. Acceso

- **Carga inicial** (`LoadingRoute`) y control de sesión (`navigation/session_gate.dart`).
- **Login** (`login/login_screen.dart`): fondo animado (`login/painters.dart`), botón de Google (`login/google_button.dart`), entrar como observador (invitado), avisos de error.
- **Onboarding** (`onboarding/`): tres slides (identidad, reproductor, búsqueda), sus fondos animados, indicador de paso y botones.
- **Tutorial** (`TutorialRoute`): el mismo onboarding abierto desde ajustes.
- **Permisos explicados** (`permission_primer.dart`): notificaciones y segundo plano.

### 2. Estructura

- **Barra inferior** (`main_navigation_screen.dart`): 4 pestañas, ícono animado, subtítulo japonés, indicador, punto de novedades en Biblioteca, gestos (doble toque, mantener).
- **Mini player** (`mini_player.dart`): portada que respira, título en marquesina, barra de progreso, marcar escuchada, tinte por portada.
- **Avisos globales:** error de Spotify (con guía de batería), error de reproducción, error de sincronización, franja sin conexión.
- **Capas sobre toda la app:** aviso de máscara desbloqueada (`mask_unlock_banner.dart`), aviso de subida de nivel (`EcoLevelUpBanner`), hora bruja (`witching_hour_overlay.dart`), sakura (`sakura_overlay.dart`), atmósfera lunar (`moon_atmosphere.dart`).
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

Prioridad: **A** = primero, **B** = después, **C** = cuando haya tiempo.

### 0. Sistema de diseño (hacer primero: abarata todo lo demás)

| Código | Tarea | Hecho cuando… | Prio |
|---|---|---|---|
| D-01 | ~~Escala tipográfica: hoy hay 33 tamaños, con medios puntos (10.5, 11.5, 12.5). Definir 7 u 8 tokens y migrar.~~ **Hecho (13-11-2026).** `AppFontSize`: 8 de lectura (`micro` 9, `caption` 10, `label` 11, `body` 12, `bodyLg` 13, `title` 14, `heading` 16, `headline` 22) y 3 de display (`display` 26, `hero` 40, `giant` 64). Los medios puntos se redondearon hacia arriba (10.5 → 11), y lo de 7.5 a 8.5 subió a 9. Excepciones: tamaños proporcionales a su pieza (`size * 0.42`), cifras de póster de Wrapped y el lienzo de la imagen de historia. | No queda ningún `fontSize:` suelto fuera de los tokens en `presentation/`. | A |
| D-02 | ~~Texto diminuto: mínimo 10 en todo lo que informe.~~ **Hecho (13-11-2026).** De los 85 textos a 9 px, 62 informaban y subieron a `caption` (10): contadores, fechas, etiquetas, horas del reloj, la «E» de explícito. Quedan 23 en `micro` (9), todos adorno: telemetrías HUD (`◈ 発見 // ROAM.NET.03`), subtítulos japoneses de la barra, rótulos del orbe, `歌詞 // LIVE.SYNC`, el kanji de país del login y el texto de las maquetas del onboarding. La tira de fases lunares crece de 112 a 116 px para que quepa. | Ningún texto informativo bajo el mínimo; solo adornos pueden ir por debajo. | A |
| D-03 | Radios: 21 valores distintos. Dejar 4 tokens (chip, tarjeta, sheet, píldora). | Todos los `BorderRadius.circular` usan un token. | A |
| D-04 | Animaciones: unas 25 duraciones sueltas. Tokens rápido / normal / lento y curvas comunes. | Las duraciones salen de los tokens. | B |
| D-05 | Margen lateral: alterna 16 y 20 según pantalla. Unificar. | Un solo valor de margen de página. | B |
| D-06 | Un `EmptyState` compartido (hoy hay 7 distintos), como ya existe `ErrorState`. | Las 7 pantallas usan el mismo widget. | A |
| D-07 | Usar `SectionTitle` en todas partes (hay 5 versiones más en Buscar, Bonds, Radar, ajustes y cola). | Solo existe un título de sección. | B |
| D-08 | Un helper de snackbar con variantes info / error / deshacer (hoy unos 60 armados a mano en 28 archivos). | Ningún `SnackBar(` construido a mano. | A |
| D-09 | Una sola flecha de volver (hoy 4 íconos distintos). | Un único ícono en toda la app. | C |
| D-10 | Botones: definir primario, secundario y de texto; hoy conviven `CyberButton`, `FilledButton`, `TextButton` y contenedores a mano. | Cada botón es uno de los tres tipos. | B |
| D-11 | Colores fuera de paleta (Eco, racha, Lore, Ascensión) a `AppColors`. | Ningún `Color(0x…)` en pantallas. | C |
| D-12 | **Rojo con significado:** el acento aparece más de 600 veces. Reservarlo para lo que suena, la acción principal y lo activo; el resto, neutros. Neones con sentido fijo: cian = ambiente/información, púrpura = social/máscaras, verde = Spotify/correr. | Guía escrita y aplicada en las pestañas principales. | A |
| D-13 | **Tipografía de titulares:** sumar una display técnica y condensada para títulos (`INICIO // 01`) y cifras monoespaciadas para stats y tiempos. El cuerpo sigue en Plus Jakarta. | Títulos y números usan las nuevas familias. | B |
| D-14 | **Profundidad con luz:** tres niveles de superficie (fondo, tarjeta, elevado); el borde brillante solo para lo activo. | Tokens de superficie aplicados a las tarjetas. | B |
| D-15 | Un solo juego de íconos: igualar grosor y estilo de los 20 o 30 más usados con los de la barra. | Íconos principales redibujados o sustituidos. | C |

### 1. Acceso

| Código | Tarea | Prio |
|---|---|---|
| A-01 | Login tiene 7 `CustomPaint` animados: medir en gama baja y pausar los que no se ven. | B |
| A-02 | Onboarding: es donde más texto diminuto y sombras hay. Subir tamaños y aligerar. | B |
| A-03 | Que la pantalla de carga enlace con el login sin salto visual; entrada animada desde el ícono. | C |

### 2. Estructura

| Código | Tarea | Prio |
|---|---|---|
| E-01 | Subtítulo japonés de la barra (8.5 px): subirlo o dejarlo solo en la pestaña activa. | A |
| E-02 | Gestos ocultos de la barra (doble toque, mantener): enseñarlos una vez o darles alternativa visible. | B |
| E-03 | Los tres avisos globales (Spotify, reproducción, sincronización) son código repetido dentro de `build`: pasarlos al helper de D-08. | A |
| E-04 | Seis pantallas (Eco, Lore, Racha, Ascensión, playlist compartida, Letras) abren con `MaterialPageRoute`; usar la transición propia (`cyberPage`). | B |
| E-05 | Fundir barra y mini player en un solo muelle: la línea de progreso es el borde superior de la barra. | B |
| E-06 | Indicador de pestaña activa que se desliza de una a otra. | C |
| E-07 | Mini player: deslizar a los lados cambia de canción; hacia arriba lo abre. | B |

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

Ejemplo de mensaje: "Haz D-06. Reglas del documento `Documentos/Plan de pulido - Front y diseño.md`. Muéstrame captura de antes y después y no hagas push."

## 8. De dónde salen los números

Las cifras (33 tamaños, 95 textos diminutos, 21 radios, 60 snackbars) vienen de contar ocurrencias en `lib/presentation/` el 13-11-2026. Son aproximadas y cambian con cada tarea hecha: conviene volver a contar antes de empezar una.
