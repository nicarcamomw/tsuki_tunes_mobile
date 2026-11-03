package com.tsuki.tsuki_tunes_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    companion object {
        var pendingAction: String? = null

        // Kept for the whole process: the engine outlives the activity
        // while music plays in the background.
        private var noisyReceiver: BroadcastReceiver? = null
        private var screenReceiver: BroadcastReceiver? = null
    }

    private val tileChannel = "com.tsuki.tsuki_tunes_mobile/tile"
    private val deviceChannel = "com.tsuki.tsuki_tunes_mobile/device"
    private val noisyChannel = "com.tsuki.tsuki_tunes_mobile/noisy"
    private val screenChannel = "com.tsuki.tsuki_tunes_mobile/screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Phone maker (some freeze background apps such as Spotify) and a way
        // to open another app's settings page, where its battery options are.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "maker" -> result.success(
                        mapOf("manufacturer" to Build.MANUFACTURER, "brand" to Build.BRAND)
                    )
                    "openAppSettings" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.success(false)
                        } else {
                            result.success(openAppSettings(pkg))
                        }
                    }
                    "runsInBackground" -> result.success(ignoresBatteryOptimizations())
                    "integrity" -> result.success(deviceIntegrity())
                    "askToRunInBackground" -> result.success(askToRunInBackground())
                    else -> result.notImplemented()
                }
            }

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

        // Screen on (true) / off (false): while Spotify plays, Tsuki posts
        // its media card again then, so the lock screen shows Tsuki's
        // player rather than Spotify's.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, screenChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    unregisterScreen()
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            when (intent.action) {
                                Intent.ACTION_SCREEN_ON -> events.success(true)
                                Intent.ACTION_SCREEN_OFF -> events.success(false)
                            }
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_SCREEN_ON)
                        addAction(Intent.ACTION_SCREEN_OFF)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        applicationContext.registerReceiver(receiver, filter)
                    }
                    screenReceiver = receiver
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScreen()
                }
            })
    }

    private fun unregisterScreen() {
        val receiver = screenReceiver ?: return
        screenReceiver = null
        try {
            applicationContext.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
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

    private fun openAppSettings(pkg: String): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (e: Exception) {
        false
    }

    /// Signs of a rooted phone or an emulator. Only reported (Crashlytics
    /// keys, one analytics event), never acted on: they're easy to hide
    /// (Magisk), custom ROMs trip them, and what guards the backend is Play
    /// Integrity through Firebase App Check.
    private fun deviceIntegrity(): Map<String, Any> {
        val signals = mutableListOf<String>()
        val suPaths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
            "/system/sd/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
            "/system/app/Superuser.apk", "/data/adb/magisk",
        )
        if (suPaths.any { File(it).exists() }) signals += "su"
        if (Build.TAGS?.contains("test-keys") == true) signals += "test_keys"
        val rootApps = listOf(
            "com.topjohnwu.magisk", "eu.chainfire.supersu",
            "com.koushikdutta.superuser", "com.noshufou.android.su",
            "com.kingroot.kinguser",
        )
        if (rootApps.any { isInstalled(it) }) signals += "root_app"
        val emulator = Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu") ||
            Build.PRODUCT.contains("sdk_gphone")
        return mapOf(
            "rooted" to signals.isNotEmpty(),
            "emulator" to emulator,
            "signals" to signals.joinToString(","),
        )
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /// Whether Android leaves Tsuki alone in the background (no battery
    /// optimization), so locking the phone doesn't kill it mid-song.
    private fun ignoresBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /// The system's own "let this app always run in the background?" dialog.
    private fun askToRunInBackground(): Boolean {
        if (ignoresBatteryOptimizations()) return true
        return try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
            )
            true
        } catch (e: Exception) {
            false
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
