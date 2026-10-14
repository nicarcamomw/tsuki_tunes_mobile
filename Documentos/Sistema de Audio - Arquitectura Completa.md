# Sistema de Audio - Arquitectura Completa (Tsuki Tunes Mobile)

> Documento actualizado: Octubre 2026
> Describe el estado actual del motor de audio tras la eliminacion del SDK nativo de Spotify.

---

## Tabla de Contenidos

1. [[#Vision General]]
2. [[#Componentes Principales]]
3. [[#Flujo de Reproduccion]]
4. [[#Motor Spotify (Web API)]]
5. [[#Motor Deezer (Preview via just_audio)]]
6. [[#Fallback Spotify → Preview]]
7. [[#Deteccion de Fin de Pista]]
8. [[#Toggle Play/Pause]]
9. [[#Shuffle y Navegacion]]
10. [[#Crossfade]]
11. [[#Prefetch (Pre-carga Predictiva)]]
12. [[#Sleep Timer]]
13. [[#Persistencia de Estado]]
14. [[#Servicio en Primer Plano]]
15. [[#Diagrama de Flujo Completo]]
16. [[#Problemas Conocidos y Soluciones]]

---

## Vision General

Tsuki Tunes utiliza una **arquitectura de doble motor** administrada por `AudioProvider`:

```
                    ┌──────────────────────────────────┐
                    │         AudioProvider             │
                    │   (Controlador Central de Estado) │
                    └───────────────┬──────────────────┘
                                    │
                  Usuario tiene Spotify Premium conectado?
                                  /     \
                                SI       NO
                               /           \
         ┌─────────────────────┐    ┌──────────────────────┐
         │   Motor Spotify     │    │   Motor Deezer       │
         │  (Web API solamente)│    │  (just_audio/ExoPlayer)│
         │  - Cancion completa │    │  - Preview 30s       │
         │  - Control remoto   │    │  - Audio local       │
         └────────┬────────────┘    └──────────────────────┘
                  │
           Si falla Spotify:
         Fallback automatico
           a Motor Deezer
```

**Cambio critico**: El SDK nativo de Spotify (`SpotifySdk.connectToSpotifyRemote`) fue **eliminado completamente** porque abria la app de Spotify en primer plano cada vez que se reproducia una cancion. Ahora solo se usa la **Web API** de Spotify Connect.

---

## Componentes Principales

### Archivos clave

| Archivo | Responsabilidad |
|---|---|
| `lib/providers/audio_provider.dart` | Estado central, logica de reproduccion, queue, shuffle, crossfade |
| `lib/services/spotify_service.dart` | Autenticacion OAuth, busqueda de tracks, Web API (play/pause/seek) |
| `lib/services/audio_player_service.dart` | Wrapper de just_audio para preview de Deezer |
| `lib/services/audio_precache_service.dart` | Pre-descarga de audio en RAM para reproduccion sin lag |
| `lib/services/spotify_web_player.dart` | (Legado) SpotifyNativePlayer — ya no se conecta activamente |
| `lib/services/foreground_service.dart` | Servicio Android para mantener la app viva en background |

### Flags de estado criticos

```dart
bool _useSpotify         // true si el usuario tiene Spotify Premium conectado
bool _spotifyActive      // true si la reproduccion actual ES via Spotify Web API
bool _spotifyFallbackActive  // true si Spotify fallo y estamos usando preview de Deezer
```

**Regla fundamental**: Estos tres flags determinan que motor controla la reproduccion:

| _useSpotify | _spotifyActive | _spotifyFallbackActive | Resultado |
|---|---|---|---|
| false | false | false | Motor Deezer puro |
| true | true | false | Spotify Web API reproduciendo |
| true | false | true | Spotify fallo → preview Deezer |
| true | false | false | Estado inicial, aun no se ha reproducido nada |

---

## Flujo de Reproduccion

Cuando el usuario toca "play" en una cancion:

```
playTrack(track, newQueue?)
  │
  ├─ Si hay newQueue → reemplazar cola, limpiar historial
  ├─ Resetear flags: _completionHandled, _crossfadeTriggered
  ├─ Incrementar _playGeneration (cancela operaciones async anteriores)
  │
  └─ _useSpotify?
       │
       ├─ SI → _playViaSpotify(track)
       │     │
       │     ├─ _spotifyActive = true  (bloquear streams de just_audio)
       │     ├─ _service.stop()        (detener preview anterior)
       │     │
       │     ├─ Buscar URI de Spotify:
       │     │   ├─ Prefetched? → usar URI cacheada
       │     │   └─ No → _spotify.searchTrack()
       │     │
       │     ├─ URI no encontrada?
       │     │   ├─ _spotifyActive = false
       │     │   ├─ _spotifyFallbackActive = true
       │     │   └─ _service.playTrack(track)  ← preview Deezer
       │     │
       │     ├─ Intentar _spotify.play(uri)
       │     │   └─ Fallo? → ensureActiveDevice() + reintentar
       │     │
       │     ├─ Sigue fallando? → Ultimo recurso:
       │     │   ├─ _nativePlayer.connect() (registra dispositivo)
       │     │   ├─ Esperar 1.5s + ensureActiveDevice + retry play
       │     │   └─ Si aun falla:
       │     │       ├─ _spotifyActive = false
       │     │       ├─ _spotifyFallbackActive = true
       │     │       └─ _service.playTrack(track)  ← preview Deezer
       │     │
       │     └─ Exito!
       │         ├─ _spotifyActive = true
       │         ├─ _spotifyFallbackActive = false
       │         ├─ _isPlaying = true
       │         └─ _startPositionTimer()
       │
       └─ NO → _service.playTrack(track)  ← preview Deezer directo
```

---

## Motor Spotify (Web API)

### Autenticacion

- OAuth 2.0 con PKCE via `flutter_web_auth_2`
- Tokens almacenados en `FlutterSecureStorage`
- Refresh automatico antes de cada operacion (`_ensureValidToken`)
- Scopes: `streaming`, `user-modify-playback-state`, `user-read-playback-state`, `user-read-currently-playing`, etc.

### Dispositivo activo

Spotify Web API requiere un **dispositivo activo** para reproducir. El metodo `ensureActiveDevice()`:

1. Consulta `GET /v1/me/player/devices`
2. Prioriza smartphones activos
3. Si hay un smartphone inactivo, transfiere la reproduccion a el
4. Si no hay smartphone, usa cualquier dispositivo activo
5. Como ultimo recurso, transfiere al primer dispositivo disponible

**Pre-calentamiento**: Al iniciar la app (`_initSpotify`), si el usuario tiene Spotify Premium, se llama `_warmUpSpotifyDevice()` que ejecuta `ensureActiveDevice()` en segundo plano. Esto asegura que cuando el usuario quiera reproducir, ya haya un dispositivo registrado.

### Reproduccion

`_spotify.play(trackUri)` envia `PUT /v1/me/player/play` con el URI del track.
Si falla, reintenta con `ensureActiveDevice()` + `_transferPlayback()`.

### Seguimiento de posicion

Spotify Web API no envia streams en tiempo real. La posicion se estima con **reloj de pared**:

```dart
_spotifySyncPosition = Duration.zero;  // posicion conocida
_spotifySyncTime = DateTime.now();      // momento de la sincronizacion

// Cada segundo el timer calcula:
_position = _spotifySyncPosition + (DateTime.now() - _spotifySyncTime);
```

Cada **15 segundos**, el timer sincroniza con el estado real de Spotify (`GET /v1/me/player`) para:
- Corregir drift de posicion
- Obtener la duracion real del track de Spotify (puede diferir de la metadata de Deezer)
- Detectar si Spotify dejo de reproducir (track completado externamente)

---

## Motor Deezer (Preview via just_audio)

### Funcionamiento

- Usa `just_audio` que internamente usa ExoPlayer en Android
- Reproduce el `previewUrl` del track (MP3 de 30 segundos proporcionado por la API de Deezer)
- Pre-descarga en RAM via `AudioPrecacheService` para reproduccion instantanea

### Streams

just_audio proporciona streams reactivos que `AudioProvider` escucha:

```dart
positionStream   → actualiza _position
durationStream   → actualiza _duration
bufferedStream   → actualiza _bufferedPosition
playerStateStream → actualiza _isPlaying, _isBuffering
                    detecta ProcessingState.completed → _handleTrackCompleted()
```

**Importante**: Estos streams solo se procesan cuando `_spotifyActive == false`. Si Spotify Web API esta reproduciendo (`_spotifyActive == true`), los streams de just_audio se ignoran para evitar interferencia.

---

## Fallback Spotify → Preview

Cuando Spotify Web API falla (track no encontrado, no hay dispositivo, error de red):

1. Se marca `_spotifyFallbackActive = true`
2. Se marca `_spotifyActive = false`
3. Se reproduce via `_service.playTrack(track)` (preview de Deezer)
4. El mini player muestra "Preview" junto al nombre del artista
5. `togglePlay()` y `seek()` usan just_audio (no Spotify API)

El fallback es **por track**, no permanente. Si el siguiente track se encuentra en Spotify, se reproduce via Web API normalmente.

---

## Deteccion de Fin de Pista

### Motor Deezer (just_audio)
- `ProcessingState.completed` dispara `_handleTrackCompleted()`
- Crossfade detecta el final anticipadamente via `_checkCrossfade(pos)`

### Motor Spotify (Web API)
- Timer de 1 segundo estima la posicion con reloj de pared
- Cuando `_position >= _duration` → `_handleTrackCompleted()`
- Cada 15 segundos sincroniza con `GET /v1/me/player` para obtener estado real
- Al volver del background (`didChangeAppLifecycleState.resumed`):
  - Recalcula posicion estimada
  - Sincroniza con Spotify API inmediatamente
  - Si la cancion termino durante el background, avanza

### Protecciones anti-duplicado

```dart
bool _completionHandled    // Evita doble-disparo de _handleTrackCompleted
bool _crossfadeTriggered   // Evita doble crossfade
int _playGeneration        // Cancela operaciones async de reproducciones anteriores
DateTime _lastPlayStart    // Ignora completions dentro de los primeros 3 segundos
```

### Que hace _handleTrackCompleted()

```
_handleTrackCompleted()
  │
  ├─ _stopAfterCurrentTrack? → stop() (sleep timer "fin de cancion")
  │
  ├─ RepeatMode.one? → playTrack(currentTrack) (repetir la misma)
  │
  ├─ RepeatMode.all? → next() (siempre avanza, cicla al inicio)
  │
  └─ RepeatMode.off?
       ├─ Shuffle? → Toda la cola ya se reprodujo? → stop()
       │              └─ No → next()
       └─ No shuffle? → Hay mas tracks? → next()
                         └─ No → stop()
```

---

## Toggle Play/Pause

```dart
togglePlay()
  │
  ├─ No hay track actual pero si cola? → playTrack(queue.first)
  │
  ├─ Spotify activo (Web API reproduciendo)?
  │   ├─ Reproduciendo → _spotify.pause() + detener timer
  │   └─ Pausado → _spotify.resume() + iniciar timer
  │
  └─ Preview/Deezer (o Spotify fallback)?
      ├─ Reproduciendo → _service.pause()
      └─ Pausado → _service.resume()
          └─ Sin audio source? → playTrack(currentTrack) desde cero
```

**Antes del fix**: `togglePlay()` siempre usaba `_spotify.pause()` cuando `_useSpotify == true`, incluso si la reproduccion real era via preview (fallback). Esto causaba que el preview no se pausara nunca.

**Despues del fix**: Se verifica `_spotifyActive && !_spotifyFallbackActive` para determinar que motor pausar.

---

## Shuffle y Navegacion

### Smart Shuffle

No es aleatorio puro. Usa un **sistema de puntuacion ponderada** (`_pickSmartNext()`):

1. Score base = random [0, 1)
2. Penalizacion si el artista fue reciente: `-3.0 / recencia`
3. Penalizacion si el album fue reciente: `-1.5 / recencia`
4. Se elige entre los candidatos con score dentro de 0.3 del mejor

Esto evita que el mismo artista suene dos veces seguidas.

### Historial de reproduccion

- `_playHistory`: lista de indices reproducidos (max 50)
- `previous()` en shuffle navega hacia atras en el historial
- Si no hay historial → `seek(Duration.zero)` (reiniciar la cancion)

### Memoizacion del siguiente track

`_nextShuffleIndex` se pre-calcula para que el prefetch y la reproduccion real apunten al **mismo track**. Sin esto, el prefetch descargaria un track y next() elegiria otro diferente.

```dart
_peekNextIndex()  // Consulta sin avanzar, memoiza _nextShuffleIndex
next()            // Usa _nextShuffleIndex si existe, luego lo limpia
_prefetchNextTrack() // Usa _peekNextIndex() para saber que pre-cargar
```

---

## Crossfade

### Como funciona

1. `_checkCrossfade(pos)` se ejecuta en cada tick de posicion (solo para just_audio)
2. Cuando faltan `_crossfadeSeconds` segundos, dispara `_triggerCrossfade()`
3. `_triggerCrossfade()`:
   - Determina el siguiente track (respeta shuffle memoizado)
   - Actualiza estado (currentTrack, index, etc.)
   - Llama `_service.crossfadeTo(nextTrack, seconds)`
   - Si falla el crossfade → fallback a `_service.playTrack(nextTrack)` normal

### Restricciones

- **Repeat One**: crossfade desactivado completamente
- **Spotify Web API activo**: crossfade desactivado (no controlamos el audio)
- **Spotify fallback (preview)**: crossfade **SI** funciona
- **Track muy corto** (duracion <= crossfade seconds): crossfade desactivado
- **Primeros 2 segundos**: crossfade desactivado (evitar triggers prematuros)

---

## Prefetch (Pre-carga Predictiva)

### Deezer Audio Pre-cache

`AudioPrecacheService.precacheTrack(track)` descarga el MP3 preview a RAM antes de que se necesite. Cuando se reproduce, el audio esta listo instantaneamente.

### Spotify URI Pre-resolution

Si el usuario tiene Spotify, `_prefetchNextTrack()` busca el URI de Spotify del siguiente track en segundo plano:

```dart
_prefetchedUri         // URI de Spotify pre-resuelto
_prefetchedForTrackId  // ID del track para el que se resolvio
_prefetchedTargetTrackId // ID del track que estamos pre-resolviendo
_prefetchGeneration    // Generacion para cancelar operaciones stale
```

Cuando se llama `_playViaSpotify()` para ese track, el URI ya esta listo — ahorrando 200-500ms de latencia de red.

---

## Sleep Timer

Tres modos:

1. **Temporizador** (`Duration > 0`): usa `_sleepTimerDeadline` (hora absoluta, no relativa). Cada segundo revisa si paso la hora → `stop()`.
2. **Fin de cancion** (`Duration.zero`): `_stopAfterCurrentTrack = true`. Al completar el track → `stop()`.
3. **Cancelar** (`null`): limpia todo.

El deadline absoluto funciona correctamente cuando la app esta en background (no depende de timers que Android puede pausar).

---

## Persistencia de Estado

### Playback State

`_persistPlaybackState()` guarda con debounce (500ms):
- Cola completa
- Indice actual
- Posicion en ms

Al reiniciar la app, `_restorePlaybackState()` restaura el estado sin reproducir automaticamente.

### Crossfade Setting

`_crossfadeSeconds` se persiste via `StorageService`.

### Tokens de Spotify

Almacenados en `FlutterSecureStorage` (EncryptedSharedPreferences en Android).

---

## Servicio en Primer Plano

`ForegroundService` mantiene la app viva cuando esta en background:
- Se inicia cuando comienza la reproduccion con titulo y artista
- Se detiene cuando se para la reproduccion
- Usa WakeLock para evitar que Android mate el proceso

---

## Diagrama de Flujo Completo

```
                         USUARIO TOCA PLAY
                              │
                     ┌────────▼────────┐
                     │   playTrack()   │
                     │ Preparar queue, │
                     │ resetear flags  │
                     └────────┬────────┘
                              │
                    ┌─────────▼──────────┐
                    │  _useSpotify?      │
                    └────┬──────────┬────┘
                     SI  │          │ NO
                         │          │
              ┌──────────▼─────┐    │
              │_playViaSpotify │    │
              │                │    │
              │ 1. Gate streams│    │
              │ 2. Stop just_  │    │
              │    audio       │    │
              │ 3. Buscar URI  │    │
              └───┬────────┬───┘    │
              URI │        │ null   │
             found│        │        │
                  │    ┌───▼────┐   │
                  │    │FALLBACK│   │
                  │    │Preview │◄──┘
                  │    └───┬────┘
                  │        │
          ┌───────▼──┐     │
          │Web API   │     │
          │play(uri) │     │
          └──┬────┬──┘     │
         OK  │    │ FAIL   │
             │    │        │
             │  ┌─▼──────┐ │
             │  │Retry w/ │ │
             │  │device   │ │
             │  └─┬────┬──┘ │
             │ OK │    │FAIL│
             │    │    │    │
             │    │  ┌─▼──┐ │
             │    │  │FALL│ │
             │    │  │BACK│─┘
             │    │  └────┘
             │    │
     ┌───────▼────▼────┐      ┌──────────────┐
     │SPOTIFY PLAYING   │      │PREVIEW PLAYING│
     │_spotifyActive=T  │      │_spotifyActive │
     │Timer 1s + sync   │      │  = false      │
     │cada 15s          │      │just_audio     │
     │                  │      │streams activos│
     └───────┬──────────┘      └──────┬────────┘
             │                        │
     ┌───────▼────────────────────────▼───────┐
     │          _handleTrackCompleted()       │
     │ → next() / playTrack() / stop()        │
     └────────────────────────────────────────┘
```

---

## Problemas Conocidos y Soluciones

### 1. "Abre Spotify para escuchar completo"

**Causa**: No habia dispositivo activo registrado en Spotify. Sin el SDK nativo que "calentaba" el dispositivo al inicio, el primer intento de play fallaba.

**Solucion**: `_warmUpSpotifyDevice()` ejecuta `ensureActiveDevice()` al iniciar la app (solo Web API, sin abrir Spotify). Tambien se pre-calienta cuando el usuario conecta su cuenta.

### 2. Preview no se pausaba

**Causa**: `togglePlay()` siempre usaba `_spotify.pause()` (Web API) cuando `_useSpotify == true`, incluso cuando la reproduccion real era un preview via just_audio (fallback).

**Solucion**: Verificar `_spotifyActive && !_spotifyFallbackActive` antes de decidir que motor pausar.

### 3. Canciones no avanzaban al siguiente track

**Causa**: `_spotifyActive` nunca se establecio a `true` tras eliminar el SDK nativo. Esto hacia que los streams de just_audio (que emitian `playing = false` despues de `_service.stop()`) sobrescribieran `_isPlaying = false`, desactivando el timer de posicion.

**Solucion**: Establecer `_spotifyActive = true` cuando Spotify Web API reproduce exitosamente, y `false` cuando se usa fallback. El timer ahora verifica `_spotifyActive` ademas de `_useSpotify`.

### 4. Drift de posicion en Spotify

**Causa**: La posicion se estimaba puramente con reloj de pared, acumulando error con el tiempo. Ademas, la duracion provenia de metadata de Deezer que podia diferir de la duracion real en Spotify.

**Solucion**: Cada 15 segundos se sincroniza con `GET /v1/me/player` para obtener la posicion y duracion reales. Al volver del background se sincroniza inmediatamente.

### 5. Doble skip al cambiar cancion

**Causa**: `_handleTrackCompleted()` se disparaba dos veces (una por el timer y otra por el stream de just_audio).

**Solucion**: Flag `_completionHandled` que se activa en el primer disparo y se resetea solo cuando se reproduce un nuevo track.

### 6. Interrupciones de audio con Spotify activo (llamadas, alarmas)

**Causa**: Cuando Spotify Web API reproduce, just_audio esta detenido y no gestiona audio focus. Si entra una llamada o alarma, Spotify no se pausa automaticamente desde nuestra app.

**Solucion**: `AudioSession.interruptionEventStream` escucha interrupciones del sistema y pausa/reanuda Spotify via Web API. Tambien `becomingNoisyEventStream` pausa cuando se desconectan audifonos.

### 7. Spotify sin dispositivo activo (ultimo recurso)

**Causa**: La Web API requiere un dispositivo registrado. Si Spotify no esta abierto, `getDevices()` retorna vacio y `play()` falla siempre.

**Solucion**: Despues de agotar todos los intentos Web API (play → ensureActiveDevice → retry), se intenta UNA vez conectar via SDK nativo (`_nativePlayer.connect()`). Esto registra un dispositivo en Spotify. Si funciona, se reintenta el play via Web API. El SDK nativo puede mostrar Spotify brevemente, pero solo se usa como ultimo recurso, no en cada cancion.

### 8. Sync bidireccional con Spotify

**Causa**: Si el usuario pausa o reanuda desde la app de Spotify, Tsuki Tunes no se entera hasta que el usuario interactua.

**Solucion**: Cada 15 segundos el timer sincroniza con `GET /v1/me/player`. Si Spotify reporta `is_playing = false` y nosotros creemos que esta reproduciendo, se actualiza el estado. Tambien detecta resume externo.

---

*Ultima actualizacion: Octubre 2026*
