import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'contracts/audio_player_contract.dart';

class AudioPlayerService implements AudioPlayerContract {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    if (track.previewUrl.isEmpty) {
      throw Exception('Audio preview is unavailable for this track');
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _player.stop();
        await _player.setUrl(track.previewUrl);
        if (initialPosition != null && initialPosition > Duration.zero) {
          await _player.seek(initialPosition);
        }
        await _player.play();
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
  Future<void> resume() async => await _player.play();
  @override
  Future<void> pause() async => await _player.pause();
  @override
  Future<void> stop() async => await _player.stop();
  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> setVolume(double volume) async => await _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}
