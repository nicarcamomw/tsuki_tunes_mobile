# Guía de color — rojo con significado (D-12)

El carmesí (`AppColors.accent`) es la firma de Tsuki, y por eso se usa poco. Si todo es rojo, nada lo es.

## El rojo se usa solo para

1. **Lo que suena:** la fila de la canción actual, el botón de play, la barra de progreso y el visualizador.
2. **La acción principal de la pantalla:** reproducir todo, crear, el botón primario de un diálogo.
3. **Lo activo o seleccionado:** la pestaña actual, un chip elegido, un interruptor encendido, el indicador de carga.
4. **Las marcas de la casa:** el `// 01` de los títulos de pantalla y el logo.

En código nuevo conviene usar los alias por nombre: `AppColors.playing`, `AppColors.primaryAction` y `AppColors.active`. Los tres son el mismo carmesí; el nombre dice por qué está ahí.

## Todo lo demás es neutro

- Cifras, totales y stats: `textBright` (la cifra) y `textSecondary` (la etiqueta).
- Títulos de sección: `textSecondary` o `textMuted`.
- Acciones secundarias ("Aleatorio", "Limpiar", "Ver álbum"): borde `borderGlow` y texto `textPrimary` o `textSecondary`.
- Iconos de estado vacío o de error: `textMuted`.

## Los neones, cada uno con un solo sentido

| Neón | Alias | Significa | Ejemplos |
|---|---|---|---|
| Cian `neonCyan` | `AppColors.info` | ambiente e información | clima, luna, radar, sugerencias ("¿quisiste decir?"), reloj de escucha |
| Púrpura `neonPurple` | `AppColors.social` | social y máscaras | Bonds, playlists compartidas, seres etéreos, Rabbit Hole |
| Verde `neonGreen` | `AppColors.spotify` | Spotify y correr | tarjeta de Spotify, modo correr |

## Texto

Para texto en rojo o púrpura, `getTextStyle` cambia solo a la variante legible (`accentText`, `neonPurpleText`), que cumple AA (4,5:1). No se escribe `accentText` a mano salvo fuera de `getTextStyle`.

## Aplicado (13-11-2026)

- **Biblioteca:** el total de canciones y álbumes, el contador de artistas seguidos y "Ver álbum" pasan a neutro. "Aleatorio" es acción secundaria (borde neutro); "Reproducir todo" sigue en rojo. Las playlists compartidas pasan a púrpura (social).
- **Buscar:** los títulos de sección de resultados, "Limpiar" y el contador de letras pasan a neutro. "¿Quisiste decir?" pasa a cian (sugerencia). El micrófono y la miniatura de letras pasan a neutro.
- **Inicio:** las cifras de stats pasan a blanco (antes rojas) y el icono de "sin conexión" a gris, como en `ErrorState`.
- **Estados vacíos y de error** (`EmptyState`, `ErrorState`): icono neutro; la acción toma el tono de su contexto (cian en el reloj y el radar, púrpura en Rabbit Hole, rojo por defecto).
