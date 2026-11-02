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
