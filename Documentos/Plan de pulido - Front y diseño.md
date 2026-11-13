# Tsuki Tunes Mobile — Plan de pulido de front y diseño

Documento de trabajo para ir apartado por apartado. Cada tarea tiene un código (por ejemplo `D-03`) para poder pedirla por su nombre.

## 1. Contexto

- App Flutter de música. Código en `lib/`, interfaz en `lib/presentation/` (pantallas en `screens/`, piezas compartidas en `widgets/`, estado en `state/`).
- Tema y colores: `lib/core/theme/cyber_theme.dart` y `lib/core/constants/app_colors.dart`.
- Textos: `lib/l10n/app_es.arb` (plantilla), `app_en.arb`, `app_ja.arb`, expuestos por `lib/core/localization/app_strings.dart`. Tras tocar un `.arb`: `flutter gen-l10n`.
- Identidad visual: cyberpunk japonés. Fondo oscuro, acento carmesí, neones cian/púrpura/verde, luna, máscaras Oni/Tengu/Hannya, tarjetas de "tinta" (`GlassCard`), subtítulos en japonés tipo HUD.

## 2. Reglas (no negociables)

1. **Pulir, no rediseñar.** Se refina lo que hay; la identidad visual no se reemplaza.
2. **Solo Android.** iOS no es objetivo.
3. **Trabajar en `main`.** Sin ramas ni worktrees. Commit sí; `push` solo si se pide.
4. **Una tarea por vez**, con `flutter analyze` y `flutter test` en verde antes de dar algo por hecho.
5. **Todo cambio visual se muestra** con captura de antes y después.
6. **Accesibilidad ya ganada, no se pierde:** contraste AA, objetivos táctiles de 48 dp, etiquetas para TalkBack y respeto a "reducir movimiento" (`lib/presentation/widgets/motion.dart`).
7. **Texto nuevo siempre en los tres idiomas** (es, en, ja).

## 3. Mapa de apartados

| # | Apartado | Secciones | Archivos principales |
|---|---|---|---|
| 0 | Sistema de diseño | Colores, tipografía, radios, espaciado, animaciones, botones, sheets, snackbars, diálogos, estados vacío/error/carga | `core/theme`, `core/constants`, `presentation/widgets` |
| 1 | Acceso | Carga inicial, Login, Onboarding (3 slides), Tutorial | `screens/login/`, `screens/onboarding/` |
| 2 | Estructura | Barra inferior, mini player, avisos globales, transiciones | `screens/main_navigation_screen.dart`, `widgets/mini_player.dart`, `navigation/routes.dart` |
| 3 | Inicio | Cabecera, stats, tarjeta de hoy, top artistas, casi completos, lanzamientos, recomendados | `screens/home_screen.dart`, `screens/home/` |
| 4 | Buscar | Barra y voz, sugerencias, recientes, géneros, resultados, letras, pantalla de género | `screens/search_screen.dart`, `screens/genre_screen.dart` |
| 5 | Explorar (nuevo) | Música nueva, Jugar, Tu camino | `screens/explore_screen.dart` |
| 6 | Biblioteca | Álbumes, playlists, artistas seguidos, bloqueo de invitado | `screens/library_screen.dart` |
| 7 | Detalle | Artista, discografía, álbum, playlist, playlist compartida, fila de canción | `screens/artist_detail_screen.dart`, `album_detail_screen.dart`, `playlist_detail_screen.dart`, `widgets/track_tile.dart` |
| 8 | Reproductor | Expandido, visualizador, controles, cola, letras, sheets | `screens/expanded_player_screen.dart`, `widgets/queue_panel.dart`, `screens/lyrics_screen.dart` |
| 9 | Perfil y ajustes | Sheet de perfil, Spotify, reproducción, almacenamiento, general, idioma, cuenta | `widgets/profile_bottom_sheet.dart`, `widgets/profile/` |
| 10 | Social | Bonds, perfil de usuario, Party | `screens/bonds_screen.dart`, `user_profile_screen.dart`, `party_screen.dart` |
| 11 | Descubrimiento | Discovery, Rabbit Hole, Radar, Máquina del tiempo, Importar de Spotify | `screens/discovery_screen.dart`, `rabbit_hole_screen.dart`, `release_radar_screen.dart`, `time_machine_screen.dart` |
| 12 | Stats y juegos | Wrapped, Reloj de escucha, Adivina la canción, Modo correr | `screens/wrapped_screen.dart`, `listening_clock_screen.dart`, `guess_song_screen.dart`, `run_mode_screen.dart` |
| 13 | Progresión y ambiente | Eco, racha, retos, máscaras, Ascensión, Lore, luna, clima | `widgets/eco_widgets.dart`, `screens/eco_levels_screen.dart`, `streak_screen.dart`, `mask_collection_screen.dart`, `lore_screen.dart` |

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
| D-01 | Escala tipográfica: hoy hay 33 tamaños, con medios puntos (10.5, 11.5, 12.5). Definir 7 u 8 tokens y migrar. | No queda ningún `fontSize:` suelto fuera de los tokens en `presentation/`. | A |
| D-02 | Texto diminuto: unos 95 usos bajo 10 px (hasta 7.5). Mínimo 10 u 11 en todo lo que informe. | Ningún texto informativo bajo el mínimo; solo adornos pueden ir por debajo. | A |
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

### 10 a 13. Social, descubrimiento, juegos y progresión

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
