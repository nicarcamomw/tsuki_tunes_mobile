package com.tsuki.tsuki_tunes_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    companion object {
        var pendingAction: String? = null

        // Kept for the whole process: the engine outlives the activity
        // while music plays in the background.
        private var noisyReceiver: BroadcastReceiver? = null
    }

    private val tileChannel = "com.tsuki.tsuki_tunes_mobile/tile"
    private val noisyChannel = "com.tsuki.tsuki_tunes_mobile/noisy"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, tileChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingAction" -> {
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            }

        // Headphones unplugged (or Bluetooth audio gone). audio_session only
        // hears this while Tsuki holds audio focus, which it doesn't while
        // Spotify plays, so listen for it here all the time.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, noisyChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    unregisterNoisy()
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                                events.success(null)
                            }
                        }
                    }
                    val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                    } else {
                        applicationContext.registerReceiver(receiver, filter)
                    }
                    noisyReceiver = receiver
                }

                override fun onCancel(arguments: Any?) {
                    unregisterNoisy()
                }
            })
    }

    private fun unregisterNoisy() {
        val receiver = noisyReceiver ?: return
        noisyReceiver = null
        try {
            applicationContext.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeTsukiAction(intent)
        requestHighestRefreshRate()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        consumeTsukiAction(intent)
    }

    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    private fun consumeTsukiAction(intent: Intent?) {
        val action = intent?.getStringExtra("tsuki_action") ?: return
        intent.removeExtra("tsuki_action")
        pendingAction = action

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, tileChannel).invokeMethod(action, null)
        }
    }

    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = currentDisplay() ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        val params = window.attributes
        if (params.preferredDisplayModeId != best.modeId) {
            params.preferredDisplayModeId = best.modeId
            window.attributes = params
        }
    }

    @Suppress("DEPRECATION")
    private fun currentDisplay(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
}
