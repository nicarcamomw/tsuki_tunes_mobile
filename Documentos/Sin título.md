

#### Resumen por criterio del checklist

| Criterio                  | Nota | Razon                                                                                        |
| ------------------------- | ---- | -------------------------------------------------------------------------------------------- |
| Requisitos funcionales    | 85   | Dual engine, shuffle, loop, crossfade, sleep timer — todo implementado                       |
| Casos de uso completos    | 65   | Shuffle+previous roto, shuffle+prefetch desperdiciado                                        |
| Flujos alternativos       | 75   | Fallback Spotify excelente, pero loop+crossfade inconsistente                                |
| Manejo de errores         | 80   | Retry+rollback solido, pero batch parcial no se maneja                                       |
| Estados del sistema       | 70   | Buffering/playing/paused bien definidos, pero sleep timer no se sincroniza con lifecycle     |
| Validaciones de entrada   | 78   | Guards de guest, queue bounds, gen counter — faltan edge cases de queue vacia post-remove    |
| Resultados correctos      | 68   | Prefetch en shuffle da resultado incorrecto, delta boundary puede perder docs                |
| Logica de negocio         | 72   | Smart shuffle bien, pero previous en shuffle y loop+crossfade tienen logica contradictoria   |
| Escenarios extremos       | 60   | Sin queue persistence, sin offline playback, sleep timer en background                       |
| Integraciones funcionales | 78   | Firestore, Spotify, Deezer, Google Auth — todas funcionan, pero crossfade Spotify silencioso |




- **Offline playback** — sin internet no hay forma de reproducir nada. Los previews precacheados existen en disco pero no hay flujo para tocarlos offline.
- **Repeat queue mode** — solo hay repeat-one. No hay modo "repetir toda la cola" (loop queue), que es standard en cualquier player.
- **`previous()` en shuffle** — ya lo sabes, sin history stack.
- **Sleep timer wall-clock** — ya lo sabes.
- **Crossfade feedback para Spotify** — el usuario configura crossfade, se conecta a Spotify, y el setting se ignora sin aviso.


---