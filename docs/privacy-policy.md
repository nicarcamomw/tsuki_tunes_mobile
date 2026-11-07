---
title: Política de Privacidad — Tsuki Tunes
---

# Política de Privacidad — Tsuki Tunes

**Última actualización:** 7 de noviembre de 2026

Tsuki Tunes ("la app") es un reproductor de música desarrollado por Nicolás Cárcamo ("nosotros", "nos"). Esta política explica qué datos recopilamos, para qué los usamos, con quién se comparten y qué derechos tienes.

## 1. Datos que recopilamos

### Datos de cuenta
- **Nombre, correo electrónico y foto de perfil** de tu cuenta de Google, si inicias sesión con Google. Los usamos para identificar tu cuenta y sincronizar tu biblioteca entre dispositivos.
- Puedes usar la app **sin cuenta**, como **Observador**. En ese caso tu biblioteca se guarda solo en tu teléfono y no se acumula Eco ni niveles.

### Tu biblioteca y actividad en la app
Si inicias sesión, se guardan en Firebase Firestore, vinculados a tu cuenta:
- Canciones escuchadas, playlists, artistas seguidos y el registro diario de reproducciones.
- Estadísticas de escucha, tu avance hacia los seres etéreos (por ejemplo, cuántas canciones escuchaste de cada estilo musical o tu racha de días seguidos), los seres que despertaste y tu nivel de Eco, que se calcula con esos mismos datos.
- Si llegas al **nivel 100 de Eco**, se guarda un aviso con tu nombre, tu nivel, tu Eco, tu elección (volverte un ser etéreo o seguir siendo Portador) y el nombre que elijas para tu máscara etérea. Solo lo lee el equipo de Tsuki Tunes, para crear tu máscara; ningún otro usuario puede verlo.

### Perfil público (opcional)
- Si activas tu **perfil público**, otras personas pueden ver tu nombre, tu foto, tu máscara, tus estadísticas, tus artistas más escuchados y tus **Resonancias** (tus últimos logros: álbumes que completaste, seres que despertaste, rangos y rachas). También pueden **encontrarte buscando tu nombre**. Viene **desactivado**, y puedes desactivarlo cuando quieras.

### Lazos (opcional)
- Puedes pedirle un **Lazo** a otra persona. La solicitud le muestra tu nombre, tu foto y tu máscara. Si la acepta, los dos quedan en la lista de Lazos del otro.
- Tus Lazos pueden ver tu perfil y tus Resonancias **aunque tu perfil sea privado**. Nadie más ve a quién tienes como Lazo.
- Puedes rechazar solicitudes, cancelar las que enviaste y deshacer un Lazo cuando quieras. Al eliminar tu cuenta se borran tus Lazos y solicitudes, también de las listas de las otras personas.
- Los Observadores (sin cuenta) no usan Lazos.

### Escuchar juntos (opcional)
- Si abres una fiesta o te unes a una, sus participantes ven tu nombre, y quien la abre comparte qué canción suena y en qué segundo, para que todos escuchen lo mismo. Solo se invita a Lazos. La fiesta se borra cuando quien la abrió la termina o elimina su cuenta.

### Playlists colaborativas (opcional)
- Si creas una playlist colaborativa o te unes a una, sus miembros ven tu nombre y las canciones que agregaste. Solo puedes invitar a tus Lazos.
- Al eliminar tu cuenta, las playlists colaborativas que creaste se borran para todos, y sales de las demás.

### Ubicación aproximada (opcional)
- Si activas el **clima**, la app usa tu ubicación aproximada (unos 2 km) para mostrar el clima. Se envía redondeada a [Open-Meteo](https://open-meteo.com/en/terms), que no exige cuenta. Nunca se usa en segundo plano y no la guardamos. En vez de eso puedes elegir una ciudad. Con el clima activado, dos seres etéreos despiertan escuchando con tormenta o con frío: eso se revisa en el teléfono y no se guarda el clima.

### Micrófono (opcional)
- La **búsqueda por voz** usa el micrófono solo mientras la estás usando. El audio lo procesa el servicio de reconocimiento de voz de tu teléfono, que normalmente es de Google, para convertirlo en texto. Tsuki Tunes no guarda ni envía el audio a ningún otro lugar. Solo usa el texto para buscar.

### Estadísticas de uso (opcional)
- **Eventos de uso** (qué funciones se usan, modo de reproducción, errores de reproducción), enviados a Firebase Analytics para mejorar la app. No incluyen canciones, búsquedas ni nombres, y no están vinculados a tu cuenta. Puedes desactivarlos en **Perfil → General → Compartir estadísticas de uso**.

### Datos de diagnóstico
- **Reportes de errores** enviados a Firebase Crashlytics cuando la app falla. Incluyen el modelo del dispositivo, la versión del sistema, el detalle técnico del error y el estado de la app en ese momento. No incluyen tu nombre ni tu correo.
- **Mediciones de rendimiento** (tiempos de carga y de red) enviadas a Firebase Performance.
- Para proteger el servicio contra abusos, Firebase App Check verifica que las solicitudes vengan de la app original (Google Play Integrity).
- **Si el teléfono tiene acceso root o es un emulador**: se anota junto a los reportes de errores y, si dejas activadas las estadísticas de uso, una vez en ellas. Solo sirve para entender fallas y cuántos teléfonos así hay; la app no te bloquea ni cambia por eso.

### Spotify (opcional)
- Si conectas tu cuenta de Spotify, la app usa la API de Spotify para buscar canciones, controlar la reproducción y leer tu perfil (nombre, país y tipo de suscripción), tu biblioteca y tus artistas más escuchados.
- **No vemos tu contraseña de Spotify.** El inicio de sesión se hace directamente con Spotify (OAuth). Los tokens de acceso se guardan cifrados **solo en tu teléfono**, y se borran cuando desconectas Spotify o cierras sesión.

### Datos que se guardan solo en tu teléfono
- Tu fecha de cumpleaños (si la indicas), tus preferencias, el historial de búsqueda, los estilos musicales de los artistas que escuchas los fragmentos de canciones y carátulas guardados en caché para reproducirlos más rápido, y los álbumes que descargues para escuchar sin internet (sus fragmentos de 30 segundos).

## 2. Datos que NO recopilamos

- No accedemos a tus contactos, fotos, archivos ni cámara.
- No recopilamos tu ubicación precisa, ni tu ubicación en segundo plano.
- No recopilamos información de pago ni financiera.
- No vendemos datos personales ni los compartimos con terceros para publicidad. La app no tiene anuncios.

## 3. Servicios de terceros

La app usa estos servicios, cada uno con su propia política de privacidad:

- [Firebase (Google)](https://firebase.google.com/support/privacy): inicio de sesión, base de datos, Analytics, Crashlytics, Performance, Remote Config, App Check y Cloud Functions (el servidor de la app, ver abajo).
- [Inicio de sesión con Google](https://policies.google.com/privacy): si eliges entrar con Google.
- [Spotify](https://www.spotify.com/legal/privacy-policy/): reproducción completa, si conectas tu cuenta.
- [Deezer](https://www.deezer.com/legal/personal-datas): catálogo y fragmentos de canciones de 30 segundos.
- [Last.fm](https://www.last.fm/legal/privacy): canciones similares para la radio, y los estilos musicales de cada artista que escuchas (para los seres etéreos).
- [LRCLIB](https://lrclib.net/): letras de canciones.
- [Open-Meteo](https://open-meteo.com/en/terms): clima, si lo activas.
- Reconocimiento de voz de tu teléfono (normalmente [Google](https://policies.google.com/privacy)): búsqueda por voz, si la usas.
- [Google ML Kit](https://developers.google.com/ml-kit/terms): reconocer el idioma de una letra y traducirla, en el teléfono (solo se descargan los idiomas que elijas).

A Deezer, Last.fm, LRCLIB y Open-Meteo solo se envía lo necesario para cada consulta (por ejemplo, el título y el artista de una canción, o una ubicación redondeada), sin datos de tu cuenta.

Las consultas a Last.fm pasan por el **servidor de la app** (Firebase Cloud Functions), que guarda la clave de Last.fm para que no vaya dentro de la app. El servidor recibe la consulta y la dirección IP de tu conexión: guarda las respuestas unas horas para no repetir consultas, y usa la IP solo para limitar los abusos, en memoria, sin guardarla.

## 4. Almacenamiento y seguridad

- Los datos de tu cuenta se guardan en Firebase Firestore, protegidos por reglas de seguridad para que solo tú puedas leer y modificar los tuyos. La excepción es tu perfil público, si lo activas.
- Toda la comunicación con los servidores usa HTTPS.
- Los tokens de Spotify se guardan cifrados en el teléfono.

## 5. Retención y eliminación de datos

- Los datos de tu cuenta se conservan mientras tu cuenta exista.
- Puedes **eliminar tu cuenta y todos sus datos** desde la app: **Perfil → Eliminar cuenta**. Se borran de inmediato:
  - Tu biblioteca.
  - Tu historial.
  - Tu perfil público, tus Lazos y tus solicitudes de Lazo (también de las listas de las otras personas).
  - Tu cuenta de inicio de sesión.
  - Lo que la app guardaba en tu teléfono (historial, búsquedas, cumpleaños, ciudad del clima, seres etéreos, nivel de Eco, estilos de artistas y cachés).
- También puedes pedir la eliminación sin la app; mira [cómo eliminar tu cuenta](delete-account.md).
- La base de datos se respalda una vez al día para recuperarla ante fallas, y cada copia se borra sola a los 98 días. Los datos de una cuenta eliminada pueden seguir en esas copias hasta 98 días.
- Las estadísticas de uso y los reportes de errores no están vinculados a tu cuenta. Firebase los elimina automáticamente: los de Analytics después de un máximo de 14 meses y los de Crashlytics después de 90 días.
- Una copia de esas estadísticas y reportes se guarda en BigQuery, dentro del proyecto de Google Cloud de la app, para ver métricas generales (usuarios activos por día, fallas). Solo la ve el equipo de Tsuki Tunes, y se borra sola después de un año.

## 6. Tus derechos

Puedes:
- **Ver** tus datos en la app (historial, playlists, perfil).
- **Eliminar** tu cuenta y tus datos desde la app o [pidiéndolo por correo](delete-account.md).
- **Desactivar** las estadísticas de uso, el perfil público, el clima y la búsqueda por voz cuando quieras.
- **Desconectar** Spotify en cualquier momento desde el perfil.
- **Retirar los permisos** de ubicación y micrófono desde los ajustes de tu teléfono.

## 7. Menores de edad

La app no está dirigida a menores de 13 años, y no recopilamos a sabiendas datos de menores de 13 años. Si crees que un menor nos dio datos, escríbenos y los eliminaremos.

## 8. Cambios a esta política

Podemos actualizar esta política. La fecha de "Última actualización" indica la versión vigente. Si los cambios son importantes, los avisaremos en la app.

## 9. Contacto

Si tienes preguntas sobre esta política o tus datos:

- **Email:** ni.carcamo.hernandez@gmail.com
