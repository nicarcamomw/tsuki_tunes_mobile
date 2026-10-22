import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import 'audio_precache_service.dart';
import 'contracts/audio_player_contract.dart';

class AudioPlayerService implements AudioPlayerContract {
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();
  late AudioPlayer _activePlayer;
  late AudioPlayer _standbyPlayer;

  Timer? _fadeTimer;
  bool _isCrossfading = false;

  final StreamController<Duration> _positionCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl = StreamController<Duration?>.broadcast();
  final StreamController<Duration> _bufferedCtrl = StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _stateCtrl = StreamController<PlayerState>.broadcast();
  final StreamController<bool> _playingCtrl = StreamController<bool>.broadcast();
  final StreamController<PlaybackEvent> _eventCtrl = StreamController<PlaybackEvent>.broadcast();

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _eventSub;

  AudioPlayerService() {
    _activePlayer = _playerA;
    _standbyPlayer = _playerB;
    _hookActivePlayer(_activePlayer);
  }

  void _hookActivePlayer(AudioPlayer player) {
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

    final localPath = AudioPrecacheService().getCachedFilePath(track.id);

    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _activePlayer.stop();
        unawaited(_activePlayer.setVolume(1.0));
        if (localPath != null && !kIsWeb) {
          debugPrint('[AudioPlayerService] Zero-latency play from pre-cached file: $localPath');
          await _activePlayer.setFilePath(localPath);
        } else {
          await _activePlayer.setUrl(track.previewUrl);
        }
        if (initialPosition != null && initialPosition > Duration.zero) {
          await _activePlayer.seek(initialPosition);
        }
        await _activePlayer.play();
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[AudioPlayerService] playTrack attempt $attempt/$maxRetries error: $e');
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
    _isCrossfading = true;

    final localPath = AudioPrecacheService().getCachedFilePath(nextTrack.id);

    try {
      unawaited(_standbyPlayer.setVolume(0.0));
      if (localPath != null && !kIsWeb) {
        debugPrint('[AudioPlayerService] Crossfade loading pre-cached file: $localPath');
        await _standbyPlayer.setFilePath(localPath);
      } else {
        await _standbyPlayer.setUrl(nextTrack.previewUrl);
      }
      await _standbyPlayer.play();

      // Hook active stream to incoming player so UI reflects incoming track
      _hookActivePlayer(_standbyPlayer);

      final totalMs = durationSeconds * 1000;
      const stepMs = 50;
      final totalSteps = (totalMs / stepMs).round();
      int currentStep = 0;

      final outgoingPlayer = _activePlayer;
      final incomingPlayer = _standbyPlayer;

      _fadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
        currentStep++;
        final progress = (currentStep / totalSteps).clamp(0.0, 1.0);

        outgoingPlayer.setVolume((1.0 - progress).clamp(0.0, 1.0));
        incomingPlayer.setVolume(progress.clamp(0.0, 1.0));

        if (currentStep >= totalSteps) {
          timer.cancel();
          _fadeTimer = null;
          outgoingPlayer.stop();
          outgoingPlayer.setVolume(1.0);

          _activePlayer = incomingPlayer;
          _standbyPlayer = outgoingPlayer;
          _isCrossfading = false;
          debugPrint('[AudioPlayerService] Crossfade complete! Swapped active deck.');
        }
      });
    } catch (e) {
      debugPrint('[AudioPlayerService] Crossfade start error: $e. Falling back to normal play.');
      _cancelCrossfade();
      await playTrack(nextTrack);
    }
  }

  void _cancelCrossfade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    if (_isCrossfading) {
      _standbyPlayer.stop();
      _standbyPlayer.setVolume(1.0);
      _activePlayer.setVolume(1.0);
      _isCrossfading = false;
    }
  }

  @override
  Future<void> resume() async {
    await _activePlayer.play();
    if (_isCrossfading) {
      await _standbyPlayer.play();
    }
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
    await _activePlayer.stop();
    await _standbyPlayer.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _cancelCrossfade();
    await _activePlayer.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async => await _activePlayer.setVolume(volume);

  @override
  Future<void> dispose() async {
    _cancelCrossfade();
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_bufSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_playingSub?.cancel());
    unawaited(_eventSub?.cancel());

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
