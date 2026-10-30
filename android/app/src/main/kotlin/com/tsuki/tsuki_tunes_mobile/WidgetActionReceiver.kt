package com.tsuki.tsuki_tunes_mobile

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent

/**
 * Handles the player widget's buttons. Not exported: only this app's own
 * PendingIntents can reach it, so other apps can't drive playback through
 * the widget's actions.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.tsuki.widget.PLAY_PAUSE"
        const val ACTION_NEXT = "com.tsuki.widget.NEXT"
        const val ACTION_PREV = "com.tsuki.widget.PREV"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            ACTION_PLAY_PAUSE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            ACTION_PREV -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return
        }
        // Explicitly addressed to audio_service's receiver in this app.
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
}
