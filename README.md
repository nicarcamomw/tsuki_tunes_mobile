# Tsuki Tunes Mobile

Reproductor de música con estética Cyberpunk & folklore japonés. Catálogo y previews de **Deezer**, reproducción completa con **Spotify Premium**, biblioteca sincronizada en **Firebase**, tags y metadatos de **Last.fm** y letras de **LRCLIB**.

## Requisitos

- Flutter estable (Dart ≥ 3.0)
- Proyecto de Firebase con Auth (Google) y Firestore. `lib/firebase_options.dart` y `android/app/google-services.json` deben apuntar a él.
- (Opcional) API key de Last.fm.

## Ejecutar

```bash
flutter pub get
flutter run --dart-define=LASTFM_API_KEY=tu_api_key
```

## Ambientes: dev y prod

La app se compila en dos versiones que conviven en el mismo teléfono (flavors de Android, `android/app/build.gradle.kts`):

| | dev | prod |
|---|---|---|
| ID de la app | `com.tsuki.tsuki_tunes_mobile.dev` | `com.tsuki.tsuki_tunes_mobile` |
| Nombre | Tsuki DEV | Tsuki Tunes |
| Proyecto Firebase | `tsuki-tunes-dev` (`android/app/src/dev/google-services.json`, `lib/firebase_options_dev.dart`) | `tsuki-tunes-web` (`android/app/google-services.json`, `lib/firebase_options.dart`) |
| Links | `tsukitunes-dev://` | `tsukitunes://` |
| Callback de Spotify | `com.tsuki.tsukitunesmobile.dev://spotify-callback` | `com.tsuki.tsukitunesmobile://spotify-callback` |

- `flutter run` y `flutter build` usan **dev** por defecto (`default-flavor` en `pubspec.yaml`); prod solo con `--flavor prod`, que es lo que compila el CI para los APK publicados.
- En Dart, `lib/core/constants/app_environment.dart` dice en qué ambiente corre la app.
- Las reglas e índices se despliegan a cada proyecto: `firebase deploy --only firestore --project tsuki-tunes-dev` (el workflow solo despliega a prod).
- Para que dev inicie sesión con Google, el proveedor Google tiene que estar activado en Authentication del proyecto `tsuki-tunes-dev`, y su `google-services.json` descargado de nuevo después (`firebase apps:sdkconfig ANDROID <app id> --project tsuki-tunes-dev`).
- Spotify en dev: en el panel de la app de Spotify Developer, agregar el paquete `com.tsuki.tsuki_tunes_mobile.dev` con la huella SHA-1 de la llave de debug, y el redirect URI de dev.

## Tests y análisis

```bash
flutter analyze
flutter test
```

El CI (`.github/workflows/ci.yml`) corre ambos en cada PR y en cada push a `main`.

## Reglas de Firestore

Las reglas viven en `firestore.rules`, la única fuente de verdad: un deploy reemplaza **todas** las reglas del proyecto. La antigua versión web (React, repo `Tsuki-Notes`) quedó abandonada y no debe desplegarse: su `firebase.json` apunta al mismo proyecto (`tsuki-tunes-web`, nombre heredado) y pisaría estas reglas con las viejas.

```bash
firebase deploy --only firestore:rules
```

Los tests de las reglas (`tool/firestore_rules_test/`, con `@firebase/rules-unit-testing`) corren contra el emulador de Firestore; el workflow de deploy los pasa antes de publicar:

```bash
cd tool/firestore_rules_test && npm ci && npm test
```

## Respaldos de Firestore

Firestore guarda un respaldo **diario** de la base `(default)` y lo conserva **98 días** (programación creada el 2026-11-02; el proyecto está en el plan Blaze). Comandos con el CLI de Firebase (v13.7 o más nuevo):

```bash
firebase firestore:backups:schedules:list --project tsuki-tunes-web
firebase firestore:backups:list --project tsuki-tunes-web
```

Restaurar crea una base **nueva** con el contenido del respaldo; la actual no se toca:

```bash
firebase firestore:databases:restore --backup projects/tsuki-tunes-web/locations/nam5/backups/<id> --database restaurada --project tsuki-tunes-web
```

Para volver a usar esos datos: revisarlos en la base nueva y copiarlos a `(default)` (o borrar `(default)` y restaurar con ese nombre). La base restaurada se cobra aparte: borrarla al terminar.

## Logging estructurado

`lib/core/logger.dart` con `package:logging`. Cada subsistema tiene su propio logger (`Log.named('AudioProvider')`, `Log.named('SpotifyService')`, …) con cuatro niveles:

| Nivel | Cuándo |
|---|---|
| `fine` | Traza: syncs de posición, prefetches, ediciones de cola |
| `info` | Cambios de estado que vale la pena saber: audífonos desconectados, crossfade iniciado |
| `warning` | Errores atrapados de los que la app se recupera (fallback, retry) |
| `severe` | Errores atrapados que pierden funcionalidad (init failures, errores de streams) |

En release el root level es `OFF` → no se imprime nada (el `debugPrint` override de `main.dart` ya bloqueaba la salida, ahora `Log.init()` también apaga `package:logging`). En debug se imprime todo con la etiqueta, nivel y mensaje en una línea: `I [AudioProvider] Headphones unplugged, pausing`.

Los registros siguen llegando a `PlaybackLog` (el usuario los copia desde configuraciones) porque `Log._print` llama a `debugPrint`, que pasa por el override que captura a `PlaybackLog`.

## Reportes de errores (Crashlytics)

Además de los crashes, `lib/data/datasources/crash_reporter.dart` manda a Crashlytics (apagado en builds debug):

- **Claves** con el estado del momento: `env`, `track_id`, `playback_mode` (`idle`, `preview`, `preview_fallback`, `spotify_app_remote`, `spotify_web_api`), `spotify_connected`, `is_playing` y un `flag_<parámetro>` por cada feature flag.
- **Breadcrumbs:** los eventos del registro de reproducción, sin títulos de canciones, búsquedas ni nombres de dispositivos.
- **Problemas no fatales**, que no cierran la app pero conviene ver por modelo de teléfono: `spotify_track_not_found`, `spotify_app_remote_unreachable`, `spotify_all_attempts_failed`, `spotify_did_not_start`, `spotify_queue_refused`. Cada uno se reporta como máximo una vez cada 10 minutos.

## Tiempos (Firebase Performance)

`lib/data/datasources/perf_tracker.dart` mide lo que el usuario espera (apagado en builds debug):

- `time_to_audio`: desde que se elige una canción hasta que suena, con `mode` (como en Crashlytics: `preview`, `spotify_app_remote`, …) y `woke_spotify` (si hubo que despertar a Spotify).
- `spotify_wake`: cuánto tarda en conectar App Remote, con `result` (`connected` o `failed`, que incluye pasar de los 4 s de espera).
- Cada request a Deezer y a la Web API de Spotify, por endpoint: la URL va sin parámetros, así que el texto de una búsqueda no sale del teléfono.

## Analytics de producto

Qué hace la gente en la app (embudos y retención), con Firebase Analytics a través de `ProductEvents` (`lib/domain/repositories/product_events.dart`, implementado en `lib/data/datasources/product_analytics.dart`):

| Evento | Parámetros |
|---|---|
| `play_start` (cuando la canción suena) | `mode` |
| `spotify_connected` / `spotify_connect_failed` | `premium` / `canceled` |
| `spotify_fallback` | `reason`: `track_not_found`, `all_attempts_failed`, `did_not_start` |
| `track_listened`, `album_completed` | `album_id` |
| `follow_artist`, `unfollow_artist` | `artist_id` |
| `playlist_created` | `tracks` (cuántas canciones) |
| Pantallas | por patrón de ruta (`/album/:id`), sin ids |

- Sin ID de publicidad ni personalización de anuncios (`AndroidManifest.xml`); solo ids y categorías, nunca títulos, búsquedas ni nombres.
- Nada desde builds debug, y nada si el usuario apaga "Compartir estadísticas de uso" en configuraciones (queda guardado).
- Los datos aparecen en la consola si el proyecto tiene Google Analytics vinculado (Configuración del proyecto → Integraciones).

## Feature flags (Remote Config)

`lib/data/datasources/feature_flags.dart` lee interruptores de Firebase Remote Config, para cambiar lo que hace la app sin publicar un APK nuevo:

| Parámetro | Por defecto | En `false` |
|---|---|---|
| `spotify_playback_enabled` | `true` | **Kill switch**: todos pasan a las vistas previas de Deezer; una canción que suena en Spotify pasa a su vista previa en segundos |
| `spotify_queue_next_enabled` | `true` | Sin encolar la siguiente canción en Spotify (sin crossfade); Tsuki pone la siguiente él mismo |

- Sin red, antes de la primera descarga, en modo emuladores o si Remote Config falla, rigen los valores por defecto del código: la app tal como está.
- Al abrir se aplican los últimos valores descargados; los nuevos llegan en segundo plano y en vivo (en segundos a las apps abiertas).
- Para activar algo a un porcentaje de usuarios: en la consola, una condición "Usuario en percentil aleatorio" (cada usuario cae siempre en el mismo grupo) con su valor para ese parámetro.
- Los parámetros y su descripción viven en `remoteconfig.template.json`. `firebase deploy --only remoteconfig` publica esa plantilla y **reemplaza la configuración entera**, condiciones hechas en la consola incluidas: o se editan en la consola o en la plantilla, no en las dos. Ojo con un `firebase deploy` sin `--only`, que también la publica.
- Un flag nuevo: su clave y valor por defecto en `FeatureFlags.defaults`, un getter, y el parámetro en la plantilla.

## Desarrollo con los emuladores de Firebase

Para probar sin tocar el proyecto real: Auth y Firestore corren en el PC (con `firestore.rules`) y la app se conecta a ellos.

```bash
bash tool/dev_emulators.sh
flutter run --dart-define=USE_EMULATORS=true
```

- El script levanta los emuladores (interfaz en http://127.0.0.1:4000), usa el JDK de Android Studio si el `java` del PATH es anterior a 11, y hace `adb reverse` de los puertos a cada dispositivo conectado (teléfono o emulador). Si el dispositivo se reconecta, correrlo de nuevo.
- Los datos quedan entre sesiones en `.emulator-data/` (ignorado por git); borrar la carpeta para empezar vacío.
- En modo emuladores la app no usa App Check, Firestore no guarda caché en disco y la biblioteca local va en otro archivo (`tsuki_library_emulators`), así que nada se mezcla con los datos reales ni llega al proyecto real. Solo funciona en builds debug.
- Al volver al modo normal puede que pida iniciar sesión de nuevo.

## Firma de release (Android)

Sin `android/key.properties`, el build de release se firma con la clave debug. Para firmar con tu propia clave:

1. Crear el keystore:
   ```bash
   keytool -genkey -v -keystore ~/tsuki-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tsuki
   ```
2. Crear `android/key.properties` (está en `.gitignore`, no se sube):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=tsuki
   storeFile=/ruta/absoluta/tsuki-release.jks
   ```
3. Agregar el SHA-1 y SHA-256 de esa clave en Firebase (Configuración del proyecto → tu app Android). Si no, Google Sign-In falla en release:
   ```bash
   keytool -list -v -keystore ~/tsuki-release.jks -alias tsuki
   ```
4. `flutter build appbundle`

## Arquitectura

Clean Architecture en tres capas. Las dependencias apuntan hacia adentro:
`presentation` → `domain` ← `data`.

| Capa | Dónde | Qué hace |
|---|---|---|
| Dominio | `lib/domain/entities/` | Modelos: `Track`, `Album`, `Artist`, `Playlist`, máscaras, Wrapped… |
| | `lib/domain/repositories/` | Interfaces que el resto de la app usa: `LibraryRepository`, `PlaylistRepository`, `PlaybackController` |
| | `lib/domain/usecases/` | Casos de uso: `PlayTrack`, `PlayTracks`, `MarkAlbum`, `ToggleTrackListened`, `ToggleFollowArtist`, `CreatePlaylist`, `AddTrackToPlaylist`… |
| | `lib/domain/logic/` | Lógica pura sin Flutter ni red: cola de reproducción, radio, fases lunares, juego de adivinar, ritmo al correr |
| Datos | `lib/data/datasources/` | Deezer API (con caché y deduplicación), Spotify (PKCE + Web API + SDK nativo), Firebase, Last.fm, letras, almacenamiento, sensores |
| | `lib/data/repositories/` | Implementaciones de los repositorios (biblioteca y playlists), con caché local y sincronización a Firestore |
| | `lib/data/contracts/` | Interfaces de las fuentes de datos (API de música, almacenamiento, reproductor, Spotify) |
| Presentación | `lib/presentation/state/` | Estado con Riverpod (`app_providers.dart` crea y conecta todo, con providers derivados como `currentTrackProvider`): audio y cola, biblioteca, playlists, búsqueda, auth, idioma |
| | `lib/presentation/screens/`, `widgets/` | Home, búsqueda, biblioteca, detalle de artista/álbum, reproductor expandido. Llaman a los casos de uso (`use_cases.dart`), no a los repositorios |

**Inyección de dependencias:** get_it + injectable (`lib/di/`). get_it arma las capas `data` y `domain`: fuentes de datos, repositorios (registrados también bajo su interfaz del dominio) y casos de uso (`@injectable`). Riverpod queda para el estado de la UI y toma esas instancias desde get_it. Después de agregar o cambiar una anotación: `dart run build_runner build -d`. En los tests, cada test parte con un get_it limpio (`test/flutter_test_config.dart`) y `useFake<T>(...)` reemplaza una pieza por un falso.

**Navegación:** go_router con rutas tipadas (`lib/presentation/navigation/routes.dart`, generadas con go_router_builder): `AlbumRoute(id: '123').push(context)` en lugar de armar pantallas y rutas a mano. La sesión decide la primera pantalla (login, tutorial o la app) desde el `redirect`, sin que ninguna pantalla navegue tras el login.

**Deep links:** `tsukitunes://album/123`, `tsukitunes://artist/27`, `tsukitunes://playlist/<id>` y `tsukitunes://track/<id>` (reproduce la canción y muestra su álbum). Si la sesión no está lista, el enlace espera detrás del login o del tutorial y se abre después. Para probar en Android: `adb shell am start -a android.intent.action.VIEW -d "tsukitunes://album/302127"`.

**Offline-first:** la biblioteca vive en SQLite (Drift, `lib/data/local/`) y es la fuente de verdad. Marcar canciones, seguir artistas y editar playlists se guarda en el teléfono al instante junto con una entrada en la outbox (`lib/data/sync/outbox.dart`), en la misma transacción. La outbox envía en orden a Firestore y reintenta con espera creciente hasta que llega; sobrevive al cierre de la app y reintenta apenas vuelve la conexión. Un rechazo definitivo del servidor deshace el cambio. Lo que llega de otros dispositivos se mezcla sin pisar lo pendiente. Las escrituras son idempotentes (Firestore también reintenta por su cuenta). Las migraciones del esquema se verifican con las fotos de cada versión (`drift_schemas/`, `test/drift/`): al cambiar una tabla, subir `schemaVersion` y correr `dart run drift_dev make-migrations`.

`test/architecture_test.dart` hace cumplir la regla: el dominio no importa Flutter, Firebase, `data` ni `presentation`; `data` no importa `presentation`.

Documentación detallada por versión en `Documentos/`.
