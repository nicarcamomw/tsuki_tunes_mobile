package com.tsuki.tsuki_tunes_mobile

import android.os.Build
import android.os.Bundle
import android.view.Display
import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity shares its FlutterEngine with audio_service's
// AudioService, which owns the media session and the playback notification.
class MainActivity : AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    // Some phones (Xiaomi/HyperOS, OnePlus, Realme...) keep apps at 60 Hz
    // unless the window asks for a faster display mode.
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
