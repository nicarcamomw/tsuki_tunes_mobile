package com.tsuki.tsuki_tunes_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class TsukiPlayerWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val ACTION_PLAY_PAUSE = "com.tsuki.widget.PLAY_PAUSE"
        private const val ACTION_NEXT = "com.tsuki.widget.NEXT"
        private const val ACTION_PREV = "com.tsuki.widget.PREV"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val keyCode = when (intent.action) {
            ACTION_PLAY_PAUSE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            ACTION_PREV -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return
        }
        sendMediaKey(context, keyCode)
    }

    private fun sendMediaKey(context: Context, keyCode: Int) {
        val target = ComponentName(
            context,
            "com.ryanheise.audioservice.MediaButtonReceiver"
        )
        for (action in intArrayOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)) {
            val mediaIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component = target
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(action, keyCode))
            }
            context.sendBroadcast(mediaIntent)
        }
    }

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

        views.setOnClickPendingIntent(R.id.btn_prev, makeActionIntent(context, ACTION_PREV, 1))
        views.setOnClickPendingIntent(R.id.btn_play_pause, makeActionIntent(context, ACTION_PLAY_PAUSE, 2))
        views.setOnClickPendingIntent(R.id.btn_next, makeActionIntent(context, ACTION_NEXT, 3))

        return views
    }

    private fun makeActionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, TsukiPlayerWidgetProvider::class.java).apply {
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
            val original = connection.inputStream.use { BitmapFactory.decodeStream(it) }
                ?: return null

            val scale = maxSize.toFloat() / maxOf(original.width, original.height)
            if (scale < 1f) {
                Bitmap.createScaledBitmap(
                    original,
                    (original.width * scale).toInt(),
                    (original.height * scale).toInt(),
                    true
                )
            } else {
                original
            }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }
}
