package com.tsuki.tsuki_tunes_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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

            val moonEmoji = widgetData.getString("moon_emoji", "🌙") ?: "🌙"
            val moonNameJp = widgetData.getString("moon_name_jp", "月") ?: "月"
            val moonNameEn = widgetData.getString("moon_name_en", "Moon") ?: "Moon"
            val trackTitle = widgetData.getString("track_title", "") ?: ""
            val trackArtist = widgetData.getString("track_artist", "") ?: ""
            val isPlaying = widgetData.getBoolean("is_playing", false)

            views.setTextViewText(R.id.txt_moon_emoji, moonEmoji)
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
}
