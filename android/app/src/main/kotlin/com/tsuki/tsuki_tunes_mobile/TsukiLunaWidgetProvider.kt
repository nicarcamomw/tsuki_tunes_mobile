package com.tsuki.tsuki_tunes_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TsukiLunaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_luna)

            val moonPhase = widgetData.getString("moon_phase", null)?.toFloatOrNull() ?: 0.5f
            val moonNameJp = widgetData.getString("moon_name_jp", "月") ?: "月"
            val moonNameEn = widgetData.getString("moon_name_en", "Moon") ?: "Moon"
            val trackTitle = widgetData.getString("track_title", "") ?: ""
            val trackArtist = widgetData.getString("track_artist", "") ?: ""
            val isPlaying = widgetData.getBoolean("is_playing", false)

            views.setImageViewBitmap(R.id.img_moon, moonBitmap(moonPhase, 168))
            views.setTextViewText(R.id.txt_moon_name_jp, moonNameJp)
            views.setTextViewText(R.id.txt_moon_name_en, moonNameEn)

            if (trackTitle.isNotEmpty() && isPlaying) {
                views.setTextViewText(R.id.txt_now_playing_label, "♪ now playing")
                views.setTextViewText(R.id.txt_song_title, trackTitle)
                views.setTextViewText(R.id.txt_song_artist, trackArtist)
                views.setViewVisibility(R.id.now_playing, View.VISIBLE)
            } else if (trackTitle.isNotEmpty()) {
                views.setTextViewText(R.id.txt_now_playing_label, "♪ last played")
                views.setTextViewText(R.id.txt_song_title, trackTitle)
                views.setTextViewText(R.id.txt_song_artist, trackArtist)
                views.setViewVisibility(R.id.now_playing, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.txt_song_title, "—")
                views.setTextViewText(R.id.txt_song_artist, "")
                views.setTextViewText(R.id.txt_now_playing_label, "♪ tsuki tunes")
                views.setViewVisibility(R.id.now_playing, View.VISIBLE)
            }

            // Tap anywhere opens the app
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tsukitunes://widget/luna")
            )
            views.setOnClickPendingIntent(R.id.widget_luna_root, launchIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /**
     * The moon at [phase] (0 new, 0.5 full, back to 1), lit on the right
     * while it grows: a lit half, then the terminator as an ellipse, dark
     * over a crescent and lit over a gibbous moon.
     */
    private fun moonBitmap(phase: Float, size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val c = size / 2f
        val r = c * 0.86f
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x33FFF4D6 }
        val dark = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF2A2F3D.toInt() }
        val lit = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFF4EFE0.toInt() }
        val disc = RectF(c - r, c - r, c + r, c + r)
        canvas.drawCircle(c, c, c * 0.98f, glow)
        canvas.drawCircle(c, c, r, dark)
        val waxing = phase < 0.5f
        canvas.drawArc(disc, if (waxing) -90f else 90f, 180f, true, lit)
        val k = Math.cos(2 * Math.PI * phase).toFloat()
        val w = r * Math.abs(k)
        canvas.drawOval(RectF(c - w, c - r, c + w, c + r), if (k > 0) dark else lit)
        return bmp
    }
}
