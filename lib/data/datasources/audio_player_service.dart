import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/logger.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/equalizer_presets.dart';
import '../contracts/audio_player_contract.dart';
import 'audio_precache_service.dart';


final _log = Log.named('AudioPlayerService');

class AudioPlayerService implements AudioPlayerContract {
  final AudioPlayer _playerA;
  final AudioPlayer _playerB;
  late AudioPlayer _activePlayer;
  late AudioPlayer _standbyPlayer;

  Timer? _fadeTimer;
  bool _isCrossfading = false;
  // The deck the streams (and so the UI) follow. During a crossfade it is
  // the incoming one while _activePlayer is still the outgoing one.
  AudioPlayer? _hooked;
  double _incomingLoudness = 1.0;

  /// Volume factor for loudness normalization of a track (1.0 = untouched).
  /// Every volume this service sets is scaled by the active track's factor.
  double Function(Track track)? loudnessFor;
  double _loudness = 1.0;
  Timer? _loudnessRamp;

  /// A factor over every volume this service sets (the sleep timer's
  /// fade-out), so a song starting mid-fade, a crossfade or a loudness
  /// change keeps it instead of jumping back up.
  double _master = 1.0;
  double get masterVolume => _master;
  set masterVolume(double value) {
    _master = value.clamp(0.0, 1.0);
    if (!_isCrossfading) unawaited(_activePlayer.setVolume(_level(_loudness)));
  }

  double _level(double loudness) => (loudness * _master).clamp(0.0, 1.0);

  /// Playback speed for a track (1.0 = normal). The pitch is kept, so small
  /// changes only shift the tempo.
  double Function(Track track)? speedFor;
  double _speed = 1.0;
  Timer? _speedRamp;

  final StreamController<Duration> _positionCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl = StreamController<Duration?>.broadcast();
  final StreamController<Duration> _bufferedCtrl = StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _stateCtrl = StreamController<PlayerState>.broadcast();
  final StreamController<bool> _playingCtrl = StreamController<bool>.broadcast();
  final StreamController<PlaybackEvent> _eventCtrl = StreamController<PlaybackEvent>.broadcast();

  // Gapless: the active deck plays a playlist, [song] or [song, next], so
  // the player starts the next song the instant the current one ends, with
  // no stop, load and start in between. The song after is added near the
  // end (setGaplessNext); moving into it is announced on gaplessAdvances.
  ConcatenatingAudioSource? _playlist;
  AudioPlayer? _playlistOwner;
  Track? _gaplessNext;
  Object? _gaplessTag;
  final StreamController<Track> _advanceCtrl = StreamController<Track>.broadcast();
  StreamSubscription? _seqSubA;
  StreamSubscription? _seqSubB;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _eventSub;

  AudioPlayerService() : this._withEqualizers(_equalizer(), _equalizer());

  AudioPlayerService._withEqualizers(AndroidEqualizer? a, AndroidEqualizer? b)
      : this.withPlayers(_playerWith(a), _playerWith(b), equalizers: [?a, ?b]);

  /// Android's equalizer, one per deck (an effect belongs to one player).
  // The real platform (dart:io), not defaultTargetPlatform, which tests
  // also report as Android while their players have no effects.
  static AndroidEqualizer? _equalizer() => !kIsWeb && Platform.isAndroid ? AndroidEqualizer() : null;

  static AudioPlayer _playerWith(AndroidEqualizer? eq) =>
      eq == null ? AudioPlayer() : AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq]));

  @visibleForTesting
  AudioPlayerService.withPlayers(this._playerA, this._playerB, {List<AndroidEqualizer> equalizers = const []})
      : _equalizers = equalizers {
    _activePlayer = _playerA;
    _standbyPlayer = _playerB;
    _hookActivePlayer(_activePlayer);
    _seqSubA = _playerA.sequenceStateStream.listen((s) => _onSequence(_playerA, s));
    _seqSubB = _playerB.sequenceStateStream.listen((s) => _onSequence(_playerB, s));
  }

  // ── Equalizer (Android; what Tsuki plays itself, not Spotify) ──

  final List<AndroidEqualizer> _equalizers;
  EqPreset _eqPreset = EqPreset.off;
  EqPreset get eqPreset => _eqPreset;

  /// Whether this phone has the equalizer.
  bool get hasEqualizer => _equalizers.isNotEmpty;

  /// Shapes both decks with [preset]. The bands are the phone's own, known
  /// once a deck has played; until then the gains wait and apply then.
  Future<void> setEqPreset(EqPreset preset) async {
    _eqPreset = preset;
    for (final eq in _equalizers) {
      try {
        await eq.setEnabled(preset != EqPreset.off);
        if (preset == EqPreset.off) continue;
        unawaited(eq.parameters.then((params) async {
          if (_eqPreset != preset) return; // changed meanwhile
          for (final band in params.bands) {
            // just_audio counts Android's millibels in thousands (its
            // "decibels" are tens of dB): a curve's dB go in divided by 10.
            final db = EqCurves.gainAt(preset, band.centerFrequency);
            await band.setGain((db / 10).clamp(params.minDecibels, params.maxDecibels));
          }
        }).catchError((Object e) => _log.warning('equalizer bands: $e')));
      } catch (e) {
        _log.warning('equalizer: $e');
      }
    }
  }

  /// The song queued with [setGaplessNext], while it hasn't started.
  @override
  Track? get gaplessNext => _gaplessNext;

  /// A queued song started by itself, right after the one before ended.
  @override
  Stream<Track> get gaplessAdvances => _advanceCtrl.stream;

  static AudioSource _sourceFor(Track track, Object tag) {
    final localPath = AudioPrecacheService().getCachedFilePath(track.id);
    if (localPath != null && !kIsWeb) return AudioSource.file(localPath, tag: tag);
    return AudioSource.uri(Uri.parse(track.previewUrl), tag: tag);
  }

  void _forgetGaplessNext() {
    _gaplessNext = null;
    _gaplessTag = null;
  }

  /// Puts [next] right after the song playing, so it follows with no gap;
  /// null takes back what was put there. False when it can't: during a
  /// crossfade, or on a deck a crossfade left without a playlist (the next
  /// song then starts the usual way).
  @override
  Future<bool> setGaplessNext(Track? next) async {
    final playlist = _playlist;
    if (playlist == null || !identical(_playlistOwner, _activePlayer) || _isCrossfading) {
      _forgetGaplessNext();
      return false;
    }
    try {
      final current = _activePlayer.currentIndex ?? 0;
      if (playlist.length > current + 1) {
        await playlist.removeRange(current + 1, playlist.length);
      }
      if (!identical(_playlist, playlist)) return false;
      _forgetGaplessNext();
      if (next == null || next.previewUrl.isEmpty) return false;
      final tag = Object();
      await playlist.add(_sourceFor(next, tag));
      // A new song may have started meanwhile, in a playlist of its own.
      if (!identical(_playlist, playlist)) return false;
      _gaplessNext = next;
      _gaplessTag = tag;
      return true;
    } catch (e) {
      _log.warning('gapless next not queued: $e');
      _forgetGaplessNext();
      return false;
    }
  }

  void _onSequence(AudioPlayer player, SequenceState? state) {
    final tag = state?.currentSource?.tag;
    final next = _gaplessNext;
    if (tag == null || next == null || !identical(tag, _gaplessTag)) return;
    if (!identical(player, _activePlayer)) return;
    _forgetGaplessNext();
    // The new song's own level and tempo, from its first note.
    _loudnessRamp?.cancel();
    _loudness = loudnessFor?.call(next) ?? 1.0;
    unawaited(player.setVolume(_level(_loudness)));
    _speedRamp?.cancel();
    _speed = speedFor?.call(next) ?? 1.0;
    unawaited(player.setSpeed(_speed));
    // Only the song playing stays in the playlist.
    final playlist = _playlist;
    final index = state!.currentIndex;
    if (playlist != null && index > 0) {
      unawaited(playlist.removeRange(0, index).catchError((Object e) {
        _log.fine('could not trim the playlist: $e');
      }));
    }
    if (!_advanceCtrl.isClosed) _advanceCtrl.add(next);
  }

  void _hookActivePlayer(AudioPlayer player) {
    _hooked = player;
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _playingSub?.cancel();
    _eventSub?.cancel();

    _posSub = player.positionStream.listen((p) {
      if (!_positionCtrl.isClosed) _positionCtrl.add(p);
    });
    _durSub = player.durationStream.listen((d) {
      if (!_durationCtrl.isClosed) _durationCtrl.add(d);
    });
    _bufSub = player.bufferedPositionStream.listen((b) {
      if (!_bufferedCtrl.isClosed) _bufferedCtrl.add(b);
    });
    _stateSub = player.playerStateStream.listen((s) {
      if (!_stateCtrl.isClosed) _stateCtrl.add(s);
    });
    _playingSub = player.playingStream.listen((pl) {
      if (!_playingCtrl.isClosed) _playingCtrl.add(pl);
    });
    _eventSub = player.playbackEventStream.listen((e) {
      if (!_eventCtrl.isClosed) _eventCtrl.add(e);
    });
  }

  AudioPlayer get player => _activePlayer;

  /// Starts [p] without waiting on it: just_audio's play() only completes
  /// when playback pauses or ends (Android holds the reply until then), so
  /// awaiting it would hold the caller for the whole song. That stalled the
  /// crossfade (the incoming deck stayed silent) and delayed everything that
  /// runs once a track has started.
  void _start(AudioPlayer p) {
    unawaited(p.play().catchError((Object e) {
      _log.severe('play error: $e');
    }));
  }

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedCtrl.stream;
  @override
  Stream<PlayerState> get playerStateStream => _stateCtrl.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _eventCtrl.stream;

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    if (track.previewUrl.isEmpty) {
      throw Exception('Audio preview is unavailable for this track');
    }

    _cancelCrossfade();
    _forgetGaplessNext();

    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _activePlayer.stop();
        _loudnessRamp?.cancel();
        _loudness = loudnessFor?.call(track) ?? 1.0;
        unawaited(_activePlayer.setVolume(_level(_loudness)));
        _speedRamp?.cancel();
        _speed = speedFor?.call(track) ?? 1.0;
        unawaited(_activePlayer.setSpeed(_speed));
        // A playlist of one, which the next song can join (gapless).
        final playlist = ConcatenatingAudioSource(children: [_sourceFor(track, Object())]);
        await _activePlayer.setAudioSource(
          playlist,
          initialPosition: initialPosition != null && initialPosition > Duration.zero
              ? initialPosition
              : null,
        );
        _playlist = playlist;
        _playlistOwner = _activePlayer;
        _start(_activePlayer);
        return;
      } catch (e) {
        lastError = e;
        _log.severe('playTrack attempt $attempt/$maxRetries error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    throw lastError ?? Exception('Audio playback failed after retries');
  }

  @override
  Future<void> crossfadeTo(Track nextTrack, int durationSeconds) async {
    if (nextTrack.previewUrl.isEmpty || durationSeconds <= 0) {
      await playTrack(nextTrack);
      return;
    }

    _cancelCrossfade();
    _forgetGaplessNext();
    _isCrossfading = true;

    final localPath = AudioPrecacheService().getCachedFilePath(nextTrack.id);

    try {
      unawaited(_standbyPlayer.setVolume(0.0));
      final inSpeed = speedFor?.call(nextTrack) ?? 1.0;
      unawaited(_standbyPlayer.setSpeed(inSpeed));
      if (localPath != null && !kIsWeb) {
        _log.fine('Crossfade loading pre-cached file: $localPath');
        await _standbyPlayer.setFilePath(localPath);
      } else {
        await _standbyPlayer.setUrl(nextTrack.previewUrl);
      }
      _start(_standbyPlayer);

      // Hook active stream to incoming player so UI reflects incoming track
      _hookActivePlayer(_standbyPlayer);

      final totalMs = durationSeconds * 1000;
      const stepMs = 50;
      final totalSteps = (totalMs / stepMs).round();
      int currentStep = 0;

      final outgoingPlayer = _activePlayer;
      final incomingPlayer = _standbyPlayer;
      _loudnessRamp?.cancel();
      _speedRamp?.cancel();
      _speed = inSpeed;
      final outLevel = _loudness;
      final inLevel = loudnessFor?.call(nextTrack) ?? 1.0;
      _incomingLoudness = inLevel;

      _fadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
        currentStep++;
        final progress = (currentStep / totalSteps).clamp(0.0, 1.0);

        outgoingPlayer.setVolume(_level((1.0 - progress) * outLevel));
        incomingPlayer.setVolume(_level(progress * inLevel));

        if (currentStep >= totalSteps) {
          timer.cancel();
          _fadeTimer = null;
          outgoingPlayer.stop();
          outgoingPlayer.setVolume(1.0);

          _activePlayer = incomingPlayer;
          _standbyPlayer = outgoingPlayer;
          _loudness = inLevel;
          _isCrossfading = false;
          _log.fine('Crossfade complete! Swapped active deck.');
        }
      });
    } catch (e) {
      _log.warning('Crossfade start error: $e. Falling back to normal play.');
      _cancelCrossfade();
      await playTrack(nextTrack);
    }
  }

  /// Ends a crossfade at once (a seek, a new song, stop). Once the incoming
  /// song is the one shown, it is the one kept: dropping it instead left
  /// the old song playing under the new one's title, with the UI following
  /// a stopped deck (stuck position, "paused" while playing, no advance).
  void _cancelCrossfade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (!_isCrossfading) return;
    _isCrossfading = false;
    if (identical(_hooked, _standbyPlayer)) {
      final outgoing = _activePlayer;
      _activePlayer = _standbyPlayer;
      _standbyPlayer = outgoing;
      outgoing.stop();
      outgoing.setVolume(1.0);
      _loudness = _incomingLoudness;
      _activePlayer.setVolume(_level(_loudness));
    } else {
      _standbyPlayer.stop();
      _standbyPlayer.setVolume(1.0);
      _activePlayer.setVolume(_level(_loudness));
    }
  }

  /// The deck the UI follows is the one that plays: true outside a
  /// crossfade.
  @visibleForTesting
  bool get followsActiveDeck => identical(_hooked, _activePlayer);

  @visibleForTesting
  bool get isCrossfading => _isCrossfading;

  @override
  Future<void> resume() async {
    _start(_activePlayer);
    if (_isCrossfading) _start(_standbyPlayer);
  }

  @override
  Future<void> pause() async {
    await _activePlayer.pause();
    if (_isCrossfading) {
      await _standbyPlayer.pause();
    }
  }

  @override
  Future<void> stop() async {
    _cancelCrossfade();
    _forgetGaplessNext();
    await _activePlayer.stop();
    await _standbyPlayer.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _cancelCrossfade();
    await _activePlayer.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async =>
      await _activePlayer.setVolume(_level(volume * _loudness));

  /// Re-reads [track]'s loudness (it may have arrived after playback began)
  /// and glides the volume there, so the change is not heard as a jump.
  void refreshLoudness(Track track) {
    if (_isCrossfading) return;
    final target = loudnessFor?.call(track) ?? 1.0;
    final from = _loudness;
    if ((target - from).abs() < 0.01) return;
    _loudnessRamp?.cancel();
    const steps = 12;
    var i = 0;
    _loudnessRamp = Timer.periodic(const Duration(milliseconds: 50), (t) {
      i++;
      _loudness = from + (target - from) * (i / steps);
      _activePlayer.setVolume(_level(_loudness));
      if (i >= steps) t.cancel();
    });
  }

  /// Re-reads [track]'s speed and glides there over about a second, so a
  /// tempo change sounds like the song easing faster or slower, not a jump.
  void refreshSpeed(Track track) {
    if (_isCrossfading) return;
    final target = speedFor?.call(track) ?? 1.0;
    final from = _speed;
    if ((target - from).abs() < 0.002) return;
    _speedRamp?.cancel();
    const steps = 10;
    var i = 0;
    _speedRamp = Timer.periodic(const Duration(milliseconds: 120), (t) {
      i++;
      _speed = from + (target - from) * (i / steps);
      _activePlayer.setSpeed(_speed);
      if (i >= steps) t.cancel();
    });
  }

  double get speed => _speed;

  @override
  Future<void> dispose() async {
    _speedRamp?.cancel();
    _loudnessRamp?.cancel();
    _cancelCrossfade();
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_bufSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_playingSub?.cancel());
    unawaited(_eventSub?.cancel());
    unawaited(_seqSubA?.cancel());
    unawaited(_seqSubB?.cancel());
    await _advanceCtrl.close();

    await _positionCtrl.close();
    await _durationCtrl.close();
    await _bufferedCtrl.close();
    await _stateCtrl.close();
    await _playingCtrl.close();
    await _eventCtrl.close();

    await _playerA.dispose();
    await _playerB.dispose();
  }
}
