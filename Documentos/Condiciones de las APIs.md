# Condiciones de las APIs que usa Tsuki Tunes

Revisado el 7 de noviembre de 2026. Las condiciones cambian: volver a revisarlas antes de publicar en Google Play o de cobrar por la app.

## Resumen

Mientras la app sea **gratis, sin anuncios y sin suscripción**, cumple con todas. **Cobrar o poner anuncios** (AdMob incluido) la vuelve uso comercial, y eso exige acuerdos con Deezer, Spotify y Last.fm, una licencia de letras y un plan pagado de Open-Meteo.

| Servicio | Para qué | Uso gratis | Uso comercial | Qué pide |
|---|---|---|---|---|
| Deezer | Catálogo, búsqueda, fragmentos de 30 s | Solo no comercial; hay cuota de consultas | Solo con acuerdo comercial (formulario de partners) | No guardar sus imágenes; no entrega audio completo |
| Spotify | Conectar la cuenta y reproducir completo | Modo desarrollo: pocos usuarios autorizados, con Premium | Cuota extendida solo para empresas registradas con unos 250.000 usuarios al mes | Revisión de la app contra su Developer Policy y reglas de marca |
| Last.fm | Canciones y artistas parecidos, estilos, "quisiste decir" | Gratis, no comercial; unas 5 consultas por segundo por IP | Con permiso de Last.fm | Dar crédito a Last.fm (está en Ajustes) |
| Open-Meteo | Clima de los sonidos ambiente | No comercial, menos de 10.000 consultas al día | Plan pagado | Licencia CC BY 4.0: dar crédito (está en Ajustes) |
| LRCLIB | Letras | Libre, sin clave | Las letras tienen derechos de autor: mostrarlas en una app pagada requiere licencia (Musixmatch, LyricFind) | Identificar al cliente en las consultas (la app lo hace) |
| Google ML Kit | Detectar idioma y traducir letras, en el teléfono | Libre | Libre | Sus términos de ML Kit |

## Spotify: lo más delicado

- En modo desarrollo solo pueden conectar Spotify los usuarios que se agregan a mano en el panel de desarrolladores, y deben tener Premium. Los reportes de 2026 hablan de **5 usuarios**, no los 25 de antes.
- Para salir de ese modo, Spotify pide desde mayo de 2025: empresa legalmente registrada, servicio comercial ya lanzado y **unos 250.000 usuarios activos al mes**. Una app personal no califica, así que **no se puede pedir la extensión** por ahora.
- Por eso la app funciona completa sin Spotify: Deezer da los fragmentos de 30 segundos, y Remote Config tiene un interruptor (`spotify_playback_enabled`) para apagar Spotify para todos si hiciera falta.

## Fuentes

- Deezer: https://support.deezer.com/hc/en-gb/articles/360011538897-Deezer-FAQs-For-Developers
- Spotify: https://developer.spotify.com/documentation/web-api/concepts/quota-modes y https://community.spotify.com/t5/Spotify-for-Developers/Updating-the-Criteria-for-Web-API-Extended-Access/td-p/6920661
- Last.fm: https://www.last.fm/api/tos
- Open-Meteo: https://open-meteo.com/en/terms
- LRCLIB: https://lrclib.net/docs
