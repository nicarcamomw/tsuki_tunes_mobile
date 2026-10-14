

- [x] ## 1. Funcionalidad

¿Hace lo que dice que hace?

- Requisitos funcionales cumplidos
- Casos de uso completos
- Flujos normales y alternativos
- Manejo de errores funcionales
- Estados del sistema bien definidos
- Validaciones de entrada
- Resultados correctos
- Lógica de negocio correcta
- Comportamiento esperado en escenarios extremos
- Integraciones funcionales con otros sistemas

**Preguntas clave:**
- ¿Funciona en todos los casos esperados?
- ¿Falla de forma controlada?


| Criterio                  | Nota | Razon                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Requisitos funcionales    | 100  | Dual engine, smart shuffle con play history, repeat off/all/one, crossfade con fallback recovery, sleep timer wall-clock con lifecycle, queue persistence, offline playback de previews cacheados, error classification trilingüe, Spotify URI cache LRU, prefetch multi-track, partial batch rollback, Spotify session sync bidireccional                                                      |
| Casos de uso completos    | 100  | Shuffle+previous con play history, shuffle+prefetch memoizado con ajuste de índices, secuencial+offline con skip inteligente, crossfade con fallback recovery, queue CRUD con integridad de índices, Spotify external control sync, background lifecycle recovery                                                                                                                               |
| Flujos alternativos       | 100  | Fallback Spotify→Preview con 3 niveles de retry (Web API → ensureDevice → native SDK), loop+crossfade consistente (repeat-one bloquea, repeat-all cicla, repeat-off avanza), audio interruptions auto-pause/resume, becoming noisy detection, sync bidireccional cada 15s, detección de transferencia a otro dispositivo, audio focus management, crossfade recovery con fallback a play normal |
| Manejo de errores         | 100  | Retry con backoff exponencial (3 intentos), clasificación de errores trilingüe (no_preview, network, format, playback), rollback optimista en mark/unmark, partial batch rollback en operaciones masivas (preserva chunks comiteados), Spotify fallback con 3 niveles de retry, _playGeneration para cancelación de operaciones stale                                                           |
| Estados del sistema       | 100  | Buffering/playing/paused/stopped bien definidos, sleep timer wall-clock sincronizado con lifecycle, _spotifyActive/_spotifyFallbackActive para motor actual, audio interruption state, sync bidireccional con Spotify, detección de transferencia a otro dispositivo                                                                                                                            |
| Validaciones de entrada   | 100  | Guards de queue bounds, queue vacía post-remove con stop(), duplicado prevention en addToQueue/addAllToQueue, _playGeneration para cancelación async, _nextShuffleIndex bounds check, _playHistory index adjustment en add/remove/reorder, _currentIndex re-sync post-mutación, guest guards en LibraryProvider                                                                                 |
| Resultados correctos      | 100  | Prefetch shuffle memoizado con _nextShuffleIndex, delta boundary con isGreaterThanOrEqualTo + dedup automático, partial batch rollback preserva datos comiteados, _playGeneration cancela resultados stale, queue index sync post-mutación                                                                                                                                                      |
| Logica de negocio         | 100  | Smart shuffle con penalización artista/album, previous con play history (max 50), loop+crossfade consistente (repeat-one bloquea, repeat-all cicla), _nextShuffleIndex memoizado para coherencia prefetch/playback, _shiftIndicesAfterInsert mantiene integridad en mutaciones de cola, shuffle exhaustion detection con stop automático                                                        |
| Escenarios extremos       | 100  | Queue persistence con restore al reiniciar, offline playback con skip a tracks cacheados, sleep timer wall-clock resistente a background/doze, _playGeneration para cancelación de operaciones stale post-background, Spotify sync al volver de background, audio interruptions auto-pause/resume, detección de transferencia a otro dispositivo                                                |
| Integraciones funcionales | 100  | Firestore con delta sync + partial batch rollback, Spotify Web API con 3 niveles de retry + sync bidireccional + audio focus, Deezer con precache + crossfade, Google Auth con guest guards, crossfade en preview mode (desactivado en Spotify Web API por limitación de la API — Spotify maneja sus propias transiciones)                                                                      |


- [ ] ## 2. Usabilidad (UX/UI) (ready)

¿Es fácil y agradable de usar?

- Interfaz intuitiva
- Curva de aprendizaje
- Consistencia visual
- Feedback al usuario (mensajes, loaders, estados)
- Accesibilidad (teclado, lectores, contrastes)
- Errores entendibles para el usuario
- Flujo lógico de pantallas
- Diseño responsive
- Idioma y claridad de textos

**Pregunta clave:**
- ¿Un usuario nuevo entiende qué hacer sin que le expliquen?


| Criterio               | Nota | Razon                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Interfaz intuitiva     | 100  | Localización completa es/en/ja sin strings hardcodeadas, undo reversible en stop y clear queue con restauración de posición exacta, gestos naturales swipe-to-dismiss en cola y pull-to-refresh en librería, haptic feedback en controles clave, menú contextual expandido con Go to Artist/Album/Play Next, sleep timer con estado visual del preset activo via originalMinutes tracking, historial de búsqueda persistente con swipe-to-delete y SharedPreferences, infinite scroll con loading indicator reemplazando paginación manual, AnimatedSize en expand/collapse de álbumes, tooltips localizados en OniMaskIcon, conteo de resultados en tabs de búsqueda, mini player tappable en toda su superficie, hint de gestos descubribles en cola, nav subtitle accesible a 8.5px, retry button en lyrics fallidos, Spotify Connect audio session fix para evitar robo de foco |
| Casos de uso completos | 100  | Shuffle+previous con play history, shuffle+prefetch memoizado con ajuste de índices, secuencial+offline con skip inteligente, crossfade con fallback recovery, queue CRUD con integridad de índices, Spotify external control sync, background lifecycle recovery                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Flujos alternativos    | 100  | Fallback Spotify→Preview con 3 niveles de retry (Web API → ensureDevice → native SDK), loop+crossfade consistente (repeat-one bloquea, repeat-all cicla, repeat-off avanza), audio interruptions auto-pause/resume, becoming noisy detection, sync bidireccional cada 15s, detección de transferencia a otro dispositivo, audio focus management, crossfade recovery con fallback a play normal                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

- [x] ## 3. Seguridad (MUY IMPORTANTE)

¿Qué tan fácil es romperlo o hackearlo?

### Autenticación
- Login seguro
- Hash de contraseñas (bcrypt/argon2)
- MFA / 2FA
- Protección contra fuerza bruta
- Gestión de sesiones

### Autorización
- Control de roles
- Principio de menor privilegio
- Acceso a recursos correcto
- Prevención de escalamiento de privilegios

### Vulnerabilidades comunes (OWASP TOP 10)
- SQL Injection
- XSS
- CSRF
- IDOR
- SSRF
- RCE
- Insecure Deserialization
- Broken Authentication
- Security Misconfiguration
- Sensitive Data Exposure

### Datos
- Encriptación en tránsito (HTTPS)
- Encriptación en reposo
- Manejo de secretos (env vars, vault)
- No hardcodear credenciales

### Infraestructura
- Firewall
- Rate limiting
- WAF
- Logs de seguridad
- Auditoría de accesos

**Pregunta clave:**
- ¿Qué pasa si un usuario malicioso intenta romper el sistema?

- [x] ## 4. Rendimiento (Performance)

¿Qué tan rápido y eficiente es?

- Tiempo de respuesta
- Uso de CPU / RAM
- Consultas a base de datos optimizadas
- Caché (Redis, CDN, etc.)
- Escalabilidad horizontal / vertical
- Latencia
- Carga simultánea
- Uso eficiente de recursos

**Pregunta clave:**
- ¿Se cae cuando entran muchos usuarios?

- [x] ## 5. Escalabilidad

¿Crece sin morir?

- Arquitectura preparada para crecer
- Separación de responsabilidades
- Microservicios vs monolito
- Balanceadores de carga
- Stateless services
- Bases de datos escalables
- Colas (RabbitMQ, Kafka)

**Pregunta clave:**
- ¿Qué pasa si mañana hay 10x usuarios?

## 6. Mantenibilidad

¿Otro dev puede entenderlo?

- Código limpio
- Naming correcto
- Comentarios útiles (no redundantes)
- Arquitectura clara
- Principios SOLID
- DRY / KISS
- Modularidad
- Baja dependencia
- Refactorización fácil

**Pregunta clave:**
- ¿Puedo arreglar un bug sin romper todo?

## 7. Calidad del Código

¿Está bien escrito o solo "funciona"?

- Estructura del proyecto
- Convenciones de estilo
- Linting
- Tipado (TypeScript, tipos fuertes)
- Manejo de errores
- Tests unitarios
- Tests de integración
- Tests end-to-end

## 8. Operatividad (DevOps)

¿Se puede ejecutar y mantener en producción?

- Deploy automatizado
- CI/CD
- Manejo de entornos (dev, qa, prod)
- Rollback
- Variables de entorno
- Logs centralizados
- Monitorización
- Alertas
- Health checks

**Pregunta clave:**
- ¿Qué hago si se cae a las 3 AM?

## 9. Disponibilidad y Resiliencia

¿Qué tan robusto es?

- Tolerancia a fallos
- Retries
- Circuit breakers
- Backups
- Replicación
- Recuperación ante desastres
- Uptime
- SLA

## 10. Compatibilidad

¿Funciona en todos lados?

- Navegadores
- Sistemas operativos
- Dispositivos
- Versiones antiguas
- APIs backward compatible

## 11. Integraciones

¿Cómo se comunica con otros sistemas?

- APIs bien documentadas
- Manejo de errores externos
- Timeouts
- Versionado de API
- Seguridad en integraciones
- Webhooks

## 12. Datos y Base de Datos

¿La info está bien cuidada?

- Modelo de datos correcto
- Normalización
- Índices
- Integridad referencial
- Migraciones
- Backups
- Consistencia
- Manejo de datos corruptos

## 13. Cumplimiento y Legal

¿Cumple la ley?

- Protección de datos personales
- GDPR / Ley local
- Consentimiento
- Logs legales
- Retención de datos
- Auditoría

## 14. Documentación

¿Está documentado o es magia negra?

- README
- Diagramas
- Documentación técnica
- Documentación de API
- Manual de usuario
- Manual de despliegue

## 15. Riesgos y Deuda Técnica

¿Qué puede explotar después?

- Puntos críticos
- Componentes frágiles
- Dependencias obsoletas
- Deuda técnica identificada
- Plan de mejora

## 16. Optimización de Costos
¿Vale lo que cuesta correrlo?

Costos de infraestructura (cloud, hosting, servidores)
Uso eficiente de servicios de terceros (APIs pagadas, SaaS)
Reads/writes innecesarios a base de datos
Funciones serverless mal configuradas (ejecuciones largas, memoria sobreprovisada)
Caché para reducir llamadas repetidas
Almacenamiento sin política de retención ni limpieza
Cold starts y tiempo de cómputo ocioso
Alertas de gasto (billing alerts, presupuestos)
Revisión de tier/plan vs uso real
Costo por usuario activo (unit economics)

Pregunta clave:

¿Cuánto cuesta esto cuando escale a 10x usuarios, y es sostenible?

## 17. Orden y Estructura del Código dentro del Proyecto
¿Se sabe dónde está cada cosa?

Estructura de carpetas coherente y predecible
Separación clara entre capas (presentación, lógica, datos)
Archivos nombrados de forma consistente y descriptiva
No mezclar responsabilidades en un mismo archivo
Componentes/módulos en su carpeta correcta (no todo en /utils o /helpers)
Archivos de configuración separados del código de negocio
Imports ordenados (externos → internos → locales)
No tener código muerto o archivos huérfanos
Consistencia entre cómo está organizado el frontend vs el backend
Convención definida y respetada por todo el equipo (o proyecto)

Pregunta clave:

¿Un dev nuevo puede encontrar cualquier cosa en menos de 2 minutos sin preguntar?

Aquí está el bloque:

18. Métodos de Pago e Integraciones Financieras (opcional)
¿La plata fluye bien y segura?

Integración correcta con el proveedor de pagos (Stripe, Transbank, MercadoPago, etc.)
Flujos de pago probados end-to-end (éxito, rechazo, error, timeout)
Manejo correcto de webhooks (confirmación asíncrona de pagos)
Idempotencia: no cobrar dos veces si hay retry o doble clic
Reembolsos y anulaciones funcionando
Suscripciones y cobros recurrentes bien configurados
Modo test vs modo producción claramente separados
No almacenar datos de tarjeta directamente (PCI-DSS)
Tokens de pago manejados de forma segura
Logs de transacciones para auditoría
Alertas ante fallos en cobros recurrentes
Manejo de estados intermedios (pendiente, procesando, fallido, expirado)
UX clara para el usuario en cada estado del pago
Facturación / boletas electrónicas si aplica legalmente
Conciliación: lo que entra al proveedor coincide con lo registrado en tu BD

Pregunta clave:

¿Qué pasa si el usuario paga, la red falla, y el webhook llega tarde o nunca llega?

## 19. Evaluación Global (visión senior)

¿Es un buen sistema o solo "funciona"?

- Arquitectura correcta
- Escalable
- Seguro
- Mantenible
- Preparado para el futuro
- Costos controlados
- Fácil de evolucionar