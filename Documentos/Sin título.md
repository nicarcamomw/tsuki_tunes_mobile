


**2. `_albumTrackCounts` crece sin bound (impacto: bajo)**  
El mapa persiste a storage sin pruning. Usuarios que navegan miles de albums acumulan datos que nunca se limpian. Solucion: podar entries que no tengan tracks escuchados asociados.

**3. Spotify: cache de URI resueltos (impacto: latencia)**  
Cada vez que se reproduce un track ya buscado antes, se repite la busqueda en Spotify Web API. Un cache `deezer_id → spotify_uri` persistido localmente eliminaria esta latencia recurrente.

**4. Error diferenciado en playback (impacto: UX)**  
`_lastPlaybackError = 'playback_error'` es generico. Diferenciar entre "no preview available", "network error", "format unsupported" permitiria mensajes de error mas utiles al usuario.

**5. Firestore writes parcialmente exitosos en batch de album (impacto: consistencia)**  
Si `markAlbumTracks` tiene 900 tracks (2 chunks de 450), y el primer chunk se commitea pero el segundo falla, el rollback restaura TODO el estado local — pero el primer chunk ya esta en Firestore. El siguiente snapshot sincronizara esos 450, creando una inconsistencia temporal.

---