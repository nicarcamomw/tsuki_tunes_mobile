import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayerService _service = AudioPlayerService();

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isShuffle = false;
  bool _isLoop = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 30);
  Duration _bufferedPosition = Duration.zero;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;

  // Callback to log recently played track
  Function(Track)? onTrackStarted;

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  bool get isLoop => _isLoop;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;

  AudioProvider() {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _posSub = _service.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durSub = _service.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    _bufSub = _service.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });

    _stateSub = _service.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;

      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }

      notifyListeners();
    });
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _currentTrack = track;
    _position = Duration.zero;
    _duration = Duration(seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    notifyListeners();

    try {
      await _service.playTrack(track);
      onTrackStarted?.call(track);
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> togglePlay() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }
    if (_isPlaying) {
      await _service.pause();
    } else {
      await _service.resume();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle && _queue.length > 1) {
      final list = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      list.shuffle();
      _currentIndex = list.first;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }

    await playTrack(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> seek(Duration pos) async {
    _position = pos;
    notifyListeners();
    await _service.seek(pos);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
    notifyListeners();
  }

  void _handleTrackCompleted() {
    if (_isLoop) {
      seek(Duration.zero);
      _service.resume();
    } else {
      next();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
