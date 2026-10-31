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

Las reglas viven en `firestore.rules`. El proyecto de Firebase se comparte con la versión web, así que un deploy reemplaza **todas** las reglas: mantener un solo archivo como fuente de verdad antes de desplegar.

```bash
firebase deploy --only firestore:rules
```

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

`test/architecture_test.dart` hace cumplir la regla: el dominio no importa Flutter, Firebase, `data` ni `presentation`; `data` no importa `presentation`.

Documentación detallada por versión en `Documentos/`.
