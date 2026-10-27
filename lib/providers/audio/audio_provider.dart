library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/deezer_preview.dart';
import '../../models/playback_error.dart';
import '../../models/repeat_mode.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/audio_precache_service.dart';
import '../../services/deezer_api_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/media_session_handler.dart';
import '../../services/playback_queue.dart';
import '../../services/song_radio.dart';
import '../../services/spotify_service.dart';
import '../../services/spotify_web_player.dart';
import '../../services/storage_service.dart';
import '../connectivity_provider.dart';

export '../../models/playback_error.dart';
export '../../models/repeat_mode.dart';
export '../../services/song_radio.dart' show RadioMode, RadioReason, RadioSource;

part 'base.dart';
part 'spotify_playback_mixin.dart';
part 'playback_state_mixin.dart';
part 'queue_mixin.dart';
part 'radio_mixin.dart';
part 'crossfade_mixin.dart';
part 'sleep_timer_mixin.dart';

enum RadioStatus { loading, ready, offline, exhausted }

/// The full audio provider, composed from focused mixins.
///
/// Each mixin groups a single concern (Spotify playback, crossfade, sleep
/// timer, song radio, queue operations, and playback-state persistence).
/// Shared state lives in [_AudioProviderBase].
class AudioProvider extends _AudioProviderBase
    with
        _SpotifyPlaybackMixin,
        _PlaybackStateMixin,
        _QueueMixin,
        _RadioMixin,
        _CrossfadeMixin,
        _SleepTimerMixin {
  AudioProvider({
    super.service,
    super.storage,
    super.connectivityProvider,
    super.mediaHandler,
    super.spotifyService,
    super.nativePlayer,
  });
}
