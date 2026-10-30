package com.tsuki.tsuki_tunes_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class TsukiPlayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = buildViews(context, widgetData)
            val coverUrl = widgetData.getString("track_cover", "") ?: ""

            if (coverUrl.isNotEmpty()) {
                thread {
                    val bitmap = loadBitmap(coverUrl, 256)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.img_cover, bitmap)
                    }
                    appWidgetManager.updateAppWidget(widgetId, views)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildViews(context: Context, widgetData: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_player)

        val title = widgetData.getString("track_title", "") ?: ""
        val artist = widgetData.getString("track_artist", "") ?: ""
        val isPlaying = widgetData.getBoolean("is_playing", false)

        views.setTextViewText(R.id.txt_title, title.ifEmpty { "Tsuki Tunes" })
        views.setTextViewText(R.id.txt_artist, artist.ifEmpty { "No track playing" })

        val playPauseIcon = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        views.setImageViewResource(R.id.btn_play_pause, playPauseIcon)
        views.setImageViewResource(R.id.img_cover, R.drawable.widget_cover_placeholder)

        val launchIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("tsukitunes://widget/player")
        )
        views.setOnClickPendingIntent(R.id.widget_player_root, launchIntent)

        views.setOnClickPendingIntent(R.id.btn_prev, makeActionIntent(context, WidgetActionReceiver.ACTION_PREV, 1))
        views.setOnClickPendingIntent(R.id.btn_play_pause, makeActionIntent(context, WidgetActionReceiver.ACTION_PLAY_PAUSE, 2))
        views.setOnClickPendingIntent(R.id.btn_next, makeActionIntent(context, WidgetActionReceiver.ACTION_NEXT, 3))

        return views
    }

    private fun makeActionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun loadBitmap(url: String, maxSize: Int): Bitmap? {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.doInput = true
            connection.connect()
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
            // Covers are small; refuse anything bigger than this rather
            // than buffer it in the widget's process.
            val bytes = connection.inputStream.use { readCapped(it, 4 * 1024 * 1024) }
                ?: return null

            // Decode already downsampled, so a large image never lands in
            // memory at full size.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSize) {
                sample *= 2
            }
            val decoded = BitmapFactory.decodeByteArray(
                bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample }
            ) ?: return null

            val scale = maxSize.toFloat() / maxOf(decoded.width, decoded.height)
            if (scale < 1f) {
                Bitmap.createScaledBitmap(
                    decoded,
                    (decoded.width * scale).toInt(),
                    (decoded.height * scale).toInt(),
                    true
                )
            } else {
                decoded
            }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun readCapped(input: InputStream, limit: Int): ByteArray? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) break
            if (out.size() + n > limit) return null
            out.write(buffer, 0, n)
        }
        return out.toByteArray()
    }
}
