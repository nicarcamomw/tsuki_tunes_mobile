package com.tsuki.tsuki_tunes_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
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
            val views = RemoteViews(context.packageName, R.layout.widget_player)

            val title = widgetData.getString("track_title", "") ?: ""
            val artist = widgetData.getString("track_artist", "") ?: ""
            val coverUrl = widgetData.getString("track_cover", "") ?: ""
            val isPlaying = widgetData.getBoolean("is_playing", false)

            views.setTextViewText(R.id.txt_title, title.ifEmpty { "Tsuki Tunes" })
            views.setTextViewText(R.id.txt_artist, artist.ifEmpty { "No track playing" })

            val playPauseIcon = if (isPlaying) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            }
            views.setImageViewResource(R.id.btn_play_pause, playPauseIcon)

            // Tapping the widget root opens the app
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tsukitunes://widget/player")
            )
            views.setOnClickPendingIntent(R.id.widget_player_root, launchIntent)

            // Control buttons → background intents
            val prevIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("tsukitunes://widget/previous")
            )
            views.setOnClickPendingIntent(R.id.btn_prev, prevIntent)

            val playPauseIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("tsukitunes://widget/playpause")
            )
            views.setOnClickPendingIntent(R.id.btn_play_pause, playPauseIntent)

            val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("tsukitunes://widget/next")
            )
            views.setOnClickPendingIntent(R.id.btn_next, nextIntent)

            // Load cover art in a background thread
            if (coverUrl.isNotEmpty()) {
                thread {
                    try {
                        val bitmap = loadBitmap(coverUrl, 256)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.img_cover, bitmap)
                            appWidgetManager.updateAppWidget(widgetId, views)
                        }
                    } catch (_: Exception) {
                        // Keep placeholder on failure
                    }
                }
            } else {
                views.setImageViewResource(R.id.img_cover, R.drawable.widget_cover_placeholder)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun loadBitmap(url: String, maxSize: Int): Bitmap? {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 5000
        connection.readTimeout = 5000
        connection.doInput = true
        connection.connect()
        val input = connection.inputStream
        val original = BitmapFactory.decodeStream(input)
        input.close()
        connection.disconnect()
        if (original == null) return null

        val scale = maxSize.toFloat() / maxOf(original.width, original.height)
        return if (scale < 1f) {
            Bitmap.createScaledBitmap(
                original,
                (original.width * scale).toInt(),
                (original.height * scale).toInt(),
                true
            )
        } else {
            original
        }
    }
}
