package com.tsuki.tsuki_tunes_mobile

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tsuki.tsuki_tunes_mobile/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val title = call.argument<String>("title") ?: "Tsuki Tunes"
                        val artist = call.argument<String>("artist") ?: ""
                        startMusicService(title, artist)
                        result.success(true)
                    }
                    "updateNotification" -> {
                        val title = call.argument<String>("title") ?: "Tsuki Tunes"
                        val artist = call.argument<String>("artist") ?: ""
                        startMusicService(title, artist)
                        result.success(true)
                    }
                    "stopService" -> {
                        stopMusicService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startMusicService(title: String, artist: String) {
        val intent = Intent(this, MusicForegroundService::class.java).apply {
            putExtra("title", title)
            putExtra("artist", artist)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMusicService() {
        val intent = Intent(this, MusicForegroundService::class.java)
        stopService(intent)
    }
}
