package com.tsuki.tsuki_tunes_mobile

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity shares its FlutterEngine with audio_service's
// AudioService, which owns the media session and the playback notification.
class MainActivity : AudioServiceActivity()
