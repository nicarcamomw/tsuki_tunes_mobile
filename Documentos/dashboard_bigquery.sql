-- =========================================================================
-- Tsuki Tunes — Looker Studio dashboard queries
-- =========================================================================
-- Prerequisito: activar la exportación de Firebase Analytics a BigQuery
-- (consola de Firebase → Configuración del proyecto → Integraciones →
-- BigQuery → Vincular).  Los eventos caen en:
--
--   `<project>.analytics_<property_id>.events_*`
--
-- Crashlytics → BigQuery se activa en la misma sección.  Los datos caen
-- en `<project>.firebase_crashlytics.*`.
--
-- Reemplaza PROJECT y PROPERTY_ID con los valores reales del proyecto.
-- En Looker Studio, cada consulta se agrega como fuente de datos
-- "Consulta personalizada de BigQuery".
-- =========================================================================


-- -----------------------------------------------------------------
-- 1. DAU  (Daily Active Users)
-- -----------------------------------------------------------------
-- Firebase Analytics registra `user_pseudo_id` por dispositivo.
-- Un usuario activo = al menos un evento ese día.

SELECT
  event_date,
  COUNT(DISTINCT user_pseudo_id) AS dau
FROM
  `PROJECT.analytics_PROPERTY_ID.events_*`
WHERE
  -- Últimos 90 días; en Looker Studio se reemplaza por el filtro de fecha.
  _TABLE_SUFFIX BETWEEN
    FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
GROUP BY
  event_date
ORDER BY
  event_date;


-- -----------------------------------------------------------------
-- 2. % reproducción Spotify vs preview  (por día)
-- -----------------------------------------------------------------
-- El evento `play_start` lleva el parámetro `mode` con los valores:
--   preview, preview_fallback, spotify_app_remote, spotify_web_api.
-- Agrupamos en dos cubetas: spotify (las dos últimas) y preview (las
-- dos primeras).

SELECT
  event_date,
  COUNTIF(mode LIKE 'spotify%')              AS plays_spotify,
  COUNTIF(mode NOT LIKE 'spotify%')          AS plays_preview,
  COUNT(*)                                   AS plays_total,
  SAFE_DIVIDE(
    COUNTIF(mode LIKE 'spotify%'),
    COUNT(*)
  )                                          AS spotify_pct
FROM (
  SELECT
    event_date,
    (SELECT value.string_value
       FROM UNNEST(event_params)
      WHERE key = 'mode')                    AS mode
  FROM
    `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE
    event_name = 'play_start'
    AND _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
)
GROUP BY
  event_date
ORDER BY
  event_date;


-- -----------------------------------------------------------------
-- 3. Crash-free users  (por día)
-- -----------------------------------------------------------------
-- Crashlytics exporta a `firebase_crashlytics.<bundle_id>_ANDROID` y
-- `…_IOS`.  Cada fila es un evento de crash con `installation_uuid`.
-- Crash-free % = 1 − (usuarios con crash / DAU).

WITH dau AS (
  SELECT
    event_date,
    COUNT(DISTINCT user_pseudo_id)           AS active_users
  FROM
    `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  GROUP BY
    event_date
),
crashes AS (
  SELECT
    FORMAT_DATE('%Y%m%d', event_timestamp)   AS event_date,
    COUNT(DISTINCT installation_uuid)        AS crashed_users
  FROM
    `PROJECT.firebase_crashlytics.com_tsuki_tsuki_tunes_mobile_ANDROID`
  WHERE
    event_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
    AND is_fatal = TRUE
  GROUP BY
    event_date
)
SELECT
  d.event_date,
  d.active_users,
  COALESCE(c.crashed_users, 0)              AS crashed_users,
  1 - SAFE_DIVIDE(
    COALESCE(c.crashed_users, 0),
    d.active_users
  )                                          AS crash_free_pct
FROM
  dau d
LEFT JOIN
  crashes c ON d.event_date = c.event_date
ORDER BY
  d.event_date;


-- -----------------------------------------------------------------
-- 4. Spotify fallback breakdown  (por razón, por día)
-- -----------------------------------------------------------------
-- Para el embudo Spotify: de las veces que se intentó Spotify, ¿cuántas
-- cayeron a preview y por qué?

SELECT
  event_date,
  reason,
  COUNT(*)                                   AS fallbacks
FROM (
  SELECT
    event_date,
    (SELECT value.string_value
       FROM UNNEST(event_params)
      WHERE key = 'reason')                  AS reason
  FROM
    `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE
    event_name = 'spotify_fallback'
    AND _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
)
GROUP BY
  event_date, reason
ORDER BY
  event_date, fallbacks DESC;


-- -----------------------------------------------------------------
-- 5. Retención: album funnel
-- -----------------------------------------------------------------
-- Del total de usuarios que reproducen (play_start), ¿cuántos escuchan
-- una canción completa (track_listened) y cuántos completan un álbum
-- (album_completed)?

WITH plays AS (
  SELECT DISTINCT user_pseudo_id
  FROM `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE event_name = 'play_start'
    AND _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
),
listened AS (
  SELECT DISTINCT user_pseudo_id
  FROM `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE event_name = 'track_listened'
    AND _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
),
completed AS (
  SELECT DISTINCT user_pseudo_id
  FROM `PROJECT.analytics_PROPERTY_ID.events_*`
  WHERE event_name = 'album_completed'
    AND _TABLE_SUFFIX BETWEEN
      FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
      AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
)
SELECT
  'play_start'       AS step,
  1                  AS step_order,
  (SELECT COUNT(*) FROM plays)     AS users
UNION ALL
SELECT
  'track_listened',
  2,
  (SELECT COUNT(*) FROM listened)
UNION ALL
SELECT
  'album_completed',
  3,
  (SELECT COUNT(*) FROM completed)
ORDER BY
  step_order;
