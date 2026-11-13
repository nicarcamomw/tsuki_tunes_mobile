# Informe de la noche — pulido de front

Trabajo hecho sobre el plan `Ajustes_front.md`, tarea por tarea. Cada tarea es un commit propio, con `flutter analyze` limpio y la suite completa en verde (de 1192 tests al empezar a más de 1210 al final). Las capturas de antes y después están en `Documentos/capturas/`.

## Lo primero: dos avisos

1. **Rama.** Este entorno en la nube solo me deja subir a la rama `ccr-2150d4d3-d0qq8i`, no a `main`. Todo está ahí, subido. Para traerlo a tu `main`: `git fetch origin && git merge origin/ccr-2150d4d3-d0qq8i` (o `rebase`).
2. **Falta la barra de 4 pestañas en el repo.** El apartado 4 del documento ("Ya hecho": Explorar, `main_tab.dart`, `section_title.dart`, `explore_tab_test.dart`) no está en `main` ni en ninguna rama remota. Seguramente vive solo en tu máquina. Al fusionar habrá conflictos, sobre todo en `main_navigation_screen.dart`, `home_screen.dart` y `cyber_nav_icon.dart`. Para que sean fáciles:
   - Los cambios mecánicos (tamaños de letra, radios, duraciones y márgenes) salen de un script que se puede volver a correr: `python3 tool/design_tokens/migrate.py fonts radii durations margins`. Ante un conflicto en esos archivos, quédate con tu versión y vuelve a correr el script.
   - **D-07 (un solo `SectionTitle`) no lo hice**, porque `widgets/section_title.dart` ya existe en tu copia y crearlo aquí también chocaría.

## Revisión de bugs (antes del paso 5)

- Biblioteca (tirar para refrescar) y Adivina la canción (clip): `setState` después de un `await` sin comprobar `mounted`.
- Avatares de Bonds y del perfil de usuario: si la foto falla (URL caducada o sin conexión), ahora se ve la inicial en vez del recuadro de imagen rota.
- Modo correr: el gráfico de historial dividía por cero con un solo punto.
- Ajustes: las filas no mostraban la onda al tocar (estaban dentro de un `Container` con color; Flutter lo avisaba en cada build).
- Snackbars: la mayoría tapaba la barra inferior o el mini player (ver D-08).
- Títulos de Biblioteca y Buscar: desbordaban en pantallas estrechas o con texto grande.
- Cola: la cabecera cortaba su propio título.

## Hecho

| Código | Qué cambió |
|---|---|
| D-01 / D-02 | 8 tamaños de letra (10, 11, 12, 13, 14, 16, 22, 28) más 40 y 64 para cifras y adornos. Mínimo de 10 para todo lo que informa (95 usos estaban entre 7,5 y 9,5). `lib/core/theme/design_tokens.dart`. |
| D-03 | 4 radios: chip 4, tarjeta 12, hoja 20 y píldora. |
| D-04 | Duraciones de animación: 100, 200, 300 y 450 ms, más curvas comunes. Los bucles largos de ambiente (respiración, sakura) no se tocaron. |
| D-05 | Un solo margen de página: 16. Los títulos ya se alinean con las tarjetas. |
| D-06 | Un `EmptyState` común (había 9 versiones), con el mismo botón de 48 dp que `ErrorState`. |
| D-08 / E-03 | `AppSnack` con variantes info, error y deshacer. Mide la altura real del muelle (barra + mini player) para no taparlo. Los tres avisos globales pasan a ser tres llamadas. |
| D-09 | Una sola flecha de volver. |
| D-11 | Paleta "santuario" en `AppColors` para Eco, Lore, Máscaras, Ascensión y Racha. Esas pantallas ya no tienen `Color(0x…)`. |
| D-12 | Rojo con significado. La guía está en `AppColors` y en `Documentos/Guia de color (D-12).md`, y se aplicó en Inicio, Buscar y Biblioteca. |
| E-01 | Subtítulo japonés de la barra a 10 px y solo en la pestaña activa. Pestañas de igual ancho. |
| E-04 | Eco, Lore, Racha, Ascensión y playlist compartida abren con la transición propia (`cyberRoute`). |
| I-01 / I-02 | Inicio muestra al instante la última versión guardada, carga destacados y fotos en paralelo, y al refrescar no vuelve al esqueleto. |
| B-01 | `search_screen.dart` partido (1264 → 470 líneas). La pantalla ya no se redibuja entera con cada aviso del proveedor. |
| L-01 | Confirmado con un test de 5000 canciones: la lista es perezosa de punta a punta. Además, cada fila solo se redibuja si la canción que suena entra o sale de ella. |
| L-02 | `AppChip` común para el orden de Biblioteca y las pestañas de Buscar (ahora con 48 dp de toque). |
| T-01 | Una cabecera común (`DetailHeader`) para artista, álbum y playlist: misma altura, mismo colapso, mismos botones. |
| T-02 | Las cabeceras de álbum y playlist se tiñen con el color de la portada. |
| R-01 | Cola: los detalles que informan pasan a 11 px y la cabecera ya cabe entera. |
| R-02 | `showAppSheet` y `SheetHandle`: las 11 hojas sueltas y los 22 tiradores hechos a mano ahora son iguales. |
| R-03 | Letras: el desenfoque de sigma 60 pasa a un degradado plano con el color de la portada. |
| R-04 | Confirmado que las animaciones fuera de pantalla se pausan. El muelle escondido (por el teclado o con el reproductor abierto) también se pausa ahora. |
| S-01 / S-02 | Perfil y ajustes pasan a pantalla completa, con un grupo "Avanzado" al final. |
| S-03 | Cada interruptor se redibuja solo, no su sección entera. |
| P-01 | Adivina, Wrapped y Rabbit Hole partidos en archivos `part` (373, 815 y 678 líneas). |
| P-04 | `select` en lugar de escuchar el proveedor entero en Bonds, perfil, Lore, Máscaras y tarjetas de Eco. |
| P-06 | Estados vacíos con personaje: Oni (Biblioteca), Hannya (Playlists) y Tengu (Buscar), con una línea de lore en es, en y ja. |
| P-10 | Lore como lectura: nombres más integrados en la línea, ancho de lectura en tablet y una jerarquía común en facciones, vínculos y rostros. |
| P-11 | Cada tomo de Lore muestra su progreso. |
| D-10 / P-02 | Tres botones definidos en el tema: primario (relleno carmesí), secundario (contorno neutro) y de texto. Todos con 48 dp y la esquina de chip. Los 18 botones de Bonds dejan de repetir estilos. |
| E-02 | Los gestos ocultos de la barra se enseñan una sola vez (a la tercera vez que cambias de pestaña), y TalkBack anuncia la pulsación larga de cada pestaña. |
| B-03 | Cada género tiene su propio tono profundo, estable y sin chocar con los neones. |
| B-04 | Tarjeta de "Mejor resultado" arriba de la búsqueda (el artista si coincide con lo escrito; si no, la primera canción). |
| L-03 | El vacío de Playlists también tiene acción directa (crear una playlist). |
| R-05 | La línea de la letra que suena aparece bajo el título del reproductor; al tocarla abre Letras. |
| R-06 | Deslizar la portada del reproductor cambia de canción. |
| P-12 | Cubierto por E-04 (transición), D-11 (colores) y P-04 (`select`). |
| F-01 | Los widgets de inicio usan la paleta de la app (como recursos de color), con el gris AA y sin texto de 9 sp. No lo pude compilar aquí (no hay SDK de Android): son cambios solo de recursos. |
| E-07 | Ya estaba hecho en el código (deslizar a los lados cambia de canción y hacia arriba abre el reproductor). |
| T-04 | Cubierto por D-02. |

## Sin hacer, y por qué

- **X-01** (revisar en un teléfono real): no tengo un teléfono aquí.
- **D-07**: chocaría con tu `section_title.dart` local (ver arriba).
- **I-03 a I-07** (cabecera, stats y carruseles de Inicio): Inicio es la pantalla que más cambió en tu copia local; preferí no tocar su diseño hasta fusionar.
- **D-13** (tipografía display y monoespaciada): es un cambio de identidad visible y necesita tu ojo para elegir la fuente.
- **E-05** (fundir barra y mini player): es un rediseño del muelle; mejor decidirlo viéndolo.
- El resto de B y C que no aparece en la tabla quedó pendiente por tiempo.

## Herramientas que quedan

- `test/screenshots/design_shots_test.dart`: capturas de unas 20 pantallas con las fuentes reales. Se corre con `TSUKI_SHOTS=<carpeta> TSUKI_SHOT_FONTS=<carpeta con PlusJakartaSans-400..800.ttf y NotoSansJP-Regular/Bold.otf> flutter test --tags shots test/screenshots`. Sin `TSUKI_SHOT_FONTS` usa Roboto.
- `test/design_tokens_test.dart`: falla si vuelve un `fontSize:` suelto, un radio suelto, un `SnackBar(` a mano, un `MaterialPageRoute`, otra flecha de volver, una duración suelta o un margen de 20 en pantallas.
- `tool/design_tokens/migrate.py`: el script de los cambios mecánicos.
