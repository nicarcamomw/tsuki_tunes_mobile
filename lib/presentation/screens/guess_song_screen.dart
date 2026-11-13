import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/logger.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/artist_names.dart';
import '../../domain/logic/guess_game.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/app_snack.dart';
import '../widgets/error_state.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_sheet.dart';

part 'guess_song/guess_song_views.dart';


final _log = Log.named('GuessSong');

class GuessSongScreen extends ConsumerStatefulWidget {
  const GuessSongScreen({super.key});

  static const dailyStateKey = 'guess_daily_state';

  /// True when today's daily challenge is already finished.
  static Future<bool> isDailyDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = DailyRoundState.decode(prefs.getString(dailyStateKey));
      return s != null &&
          s.day == GuessGame.dayNumber(DateTime.now()) &&
          GuessGame.isFinished(s.outcomes);
    } catch (_) {
      return false;
    }
  }

  @override
  ConsumerState<GuessSongScreen> createState() => _GuessSongScreenState();
}

class _GuessSongScreenState extends ConsumerState<GuessSongScreen> {
  static const _statsKey = 'guess_daily_stats';
  static const _bestStreakKey = 'guess_free_best_streak';
  static const _lastArtistKey = 'guess_last_artist';
  static const _lastModeKey = 'guess_last_mode';
  static const _sessionStreakKey = 'guess_free_streak';
  static const _minArtistPool = 6;
  static const _minLibrarySize = 5;
  static const _revealSeconds = 30;

  late final _api = ref.read(musicCatalogProvider);
  final _player = AudioPlayer();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _rng = Random();

  Timer? _debounce;
  Timer? _clipTimer;
  Timer? _countdown;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  SharedPreferences? _prefs;

  GuessMode _mode = GuessMode.daily;
  bool _loading = true;
  bool _error = false;
  bool _libraryFallback = false;
  Track? _target;
  List<GuessOutcome> _outcomes = [];
  List<String> _labels = [];
  List<Track> _suggestions = [];
  bool _searching = false;
  int _searchGen = 0;
  int _roundGen = 0;
  bool _clipPlaying = false;
  Duration _clipPos = Duration.zero;
  GuessStats _stats = GuessStats();
  int _sessionStreak = 0;
  int _bestStreak = 0;
  int _lastRecordedAttempt = -1;
  final Set<String> _playedIds = {};

  // Artist mode.
  Artist? _artist;
  List<Track> _artistPool = [];
  bool _artistTooFew = false;
  final _artistSearchCtrl = TextEditingController();
  List<Artist> _artistResults = [];
  bool _artistSearching = false;
  int _artistSearchGen = 0;

  int get _today => GuessGame.dayNumber(DateTime.now());
  bool get _finished => GuessGame.isFinished(_outcomes);
  bool get _won => GuessGame.isWon(_outcomes);
  int get _unlockedSeconds =>
      _finished ? _revealSeconds : GuessGame.clipSeconds[_outcomes.length];

  @override
  void initState() {
    super.initState();
    // The clips would be inaudible over the music.
    final audio = ref.read(audioProvider);
    if (audio.isPlaying) audio.togglePlay();

    _posSub = _player.positionStream.listen((p) {
      if (!_clipPlaying) return;
      if (p >= Duration(seconds: _unlockedSeconds)) {
        _stopClip();
      } else if (mounted) {
        setState(() => _clipPos = p);
      }
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _stopClip();
    });
    _init();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _stats = GuessStats.decode(_prefs!.getString(_statsKey));
      _bestStreak = _prefs!.getInt(_bestStreakKey) ?? 0;
      _sessionStreak = _prefs!.getInt(_sessionStreakKey) ?? 0;
      final rawArtist = _prefs!.getString(_lastArtistKey);
      if (rawArtist != null) {
        _artist = Artist.fromDeezer(jsonDecode(rawArtist) as Map<String, dynamic>);
      }
      // Reopen on the mode the user was playing.
      final lastMode = _prefs!.getString(_lastModeKey);
      _mode = GuessMode.values.firstWhere((m) => m.name == lastMode, orElse: () => _mode);
    } catch (_) {}
    await _startRound();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clipTimer?.cancel();
    _countdown?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _artistSearchCtrl.dispose();
    super.dispose();
  }

  // ── Rounds ──

  Future<List<Track>> _chartPool() async {
    final pool = await _api.getLargeChartTracks();
    return pool.where((t) => t.previewUrl.isNotEmpty).toList();
  }

  List<Track> _libraryPool() {
    final library = ref.read(libraryProvider);
    final seen = <String>{};
    return [...library.favoriteTracks, ...library.recentTracks]
        .where((t) => t.id.isNotEmpty && seen.add(t.id))
        .toList();
  }

  /// Admin accounts can play the daily again, with another chart song, as
  /// often as they like. Only the first round of the day counts for the
  /// stats, the streak and the masks.
  bool get _isAdmin => ref.read(authProvider).isAdmin;
  bool _dailyReplay = false;

  Future<void> _replayDaily() {
    _dailyReplay = true;
    return _startRound();
  }

  Future<void> _startRound() async {
    final gen = ++_roundGen;
    final replay = _dailyReplay && _mode == GuessMode.daily;
    final previousId = _target?.id;
    _dailyReplay = false;
    _stopClip();
    _countdown?.cancel();
    setState(() {
      _loading = true;
      _error = false;
      _target = null;
      _outcomes = [];
      _labels = [];
      _lastRecordedAttempt = -1;
      _suggestions = [];
      _searchCtrl.clear();
    });

    if (_mode == GuessMode.artist && _artist == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      Track? target;
      var outcomes = <GuessOutcome>[];
      var labels = <String>[];
      var fallback = false;

      if (_mode == GuessMode.daily) {
        final saved = DailyRoundState.decode(_prefs?.getString(GuessSongScreen.dailyStateKey));
        if (saved != null && saved.day == _today && !replay) {
          target = await _api.getTrack(saved.trackId, forceRefresh: true);
          outcomes = saved.outcomes;
          labels = saved.guessLabels;
        } else {
          final pool = await _chartPool();
          if (pool.isEmpty) throw StateError('empty chart');
          final others = pool.where((t) => t.id != previousId).toList()..shuffle(_rng);
          final pick = replay && others.isNotEmpty
              ? others.first
              : GuessGame.dailyPick(_today, pool, (t) => t.id);
          target = await _api.getTrack(pick.id, forceRefresh: true) ?? pick;
          await _prefs?.setString(
            GuessSongScreen.dailyStateKey,
            DailyRoundState(day: _today, trackId: target.id, outcomes: [], guessLabels: [])
                .encode(),
          );
        }
      } else {
        var pool = switch (_mode) {
          GuessMode.library => _libraryPool(),
          GuessMode.artist => await _loadArtistPool(),
          _ => <Track>[],
        };
        if (_mode == GuessMode.artist && pool.length < _minArtistPool) {
          if (!mounted || gen != _roundGen) return;
          setState(() {
            _artistTooFew = true;
            _loading = false;
          });
          return;
        }
        if (_mode == GuessMode.library && pool.length < _minLibrarySize) {
          fallback = true;
          pool = [];
        }
        // Pick up the round left half-played in this mode, if any.
        final saved = _savedRound();
        if (saved != null) {
          final t = await _api.getTrack(saved.trackId, forceRefresh: true);
          if (t != null && t.previewUrl.isNotEmpty) {
            target = t;
            outcomes = saved.outcomes;
            labels = saved.guessLabels;
          }
        }
        if (target == null) {
          if (pool.isEmpty) pool = await _chartPool();
          if (pool.isEmpty) throw StateError('empty pool');
          var fresh = pool.where((t) => !_playedIds.contains(t.id)).toList();
          if (fresh.isEmpty) {
            _playedIds.clear();
            fresh = pool;
          }
          fresh.shuffle(_rng);
          // Library tracks can have stale or missing previews; try a few.
          for (final candidate in fresh.take(5)) {
            final t = await _api.getTrack(candidate.id, forceRefresh: true);
            if (t != null && t.previewUrl.isNotEmpty) {
              target = t;
              break;
            }
          }
        }
        if (target != null) {
          _playedIds.add(target.id);
          _saveRound(target, outcomes, labels);
        }
      }

      if (target == null || target.previewUrl.isEmpty) throw StateError('no preview');
      await _player.setUrl(target.previewUrl);
      if (!mounted || gen != _roundGen) return;
      setState(() {
        _target = target;
        _outcomes = outcomes;
        _labels = labels;
        _libraryFallback = fallback;
        _loading = false;
      });
      if (_finished) _startCountdown();
    } catch (e) {
      _log.severe('round error: $e');
      if (!mounted || gen != _roundGen) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<List<Track>> _loadArtistPool() async {
    final artist = _artist!;
    if (_artistPool.isEmpty || _artistPool.first.artistId != artist.id) {
      final top = await _api.getArtistTopTracks(artist.id, limit: 50);
      final seen = <String>{};
      // Keep one version per title so live/remaster duplicates don't repeat.
      _artistPool = top
          .where((t) => t.previewUrl.isNotEmpty && seen.add(GuessGame.normalize(t.title)))
          .toList();
    }
    return _artistPool;
  }

  String _roundKey(GuessMode mode) => 'guess_round_${mode.name}';

  String get _roundScope => _mode == GuessMode.artist ? (_artist?.id ?? '') : '';

  /// This mode's unfinished round from an earlier visit (artist mode: only
  /// for the same artist).
  DailyRoundState? _savedRound() {
    final s = DailyRoundState.decode(_prefs?.getString(_roundKey(_mode)));
    if (s == null || s.scope != _roundScope || GuessGame.isFinished(s.outcomes)) return null;
    return s;
  }

  void _saveRound(Track target, List<GuessOutcome> outcomes, List<String> labels) {
    if (_mode == GuessMode.daily) return; // the daily round has its own key
    _prefs?.setString(
      _roundKey(_mode),
      DailyRoundState(
        day: _today,
        trackId: target.id,
        outcomes: outcomes,
        guessLabels: labels,
        scope: _roundScope,
      ).encode(),
    );
  }

  void _setSessionStreak(int value) {
    _sessionStreak = value;
    _prefs?.setInt(_sessionStreakKey, value);
  }

  Future<void> _pickArtist(Artist artist) async {
    Haptics.selection();
    FocusScope.of(context).unfocus();
    setState(() {
      _artist = artist;
      _artistPool = [];
      _artistTooFew = false;
      _artistResults = [];
      _artistSearchCtrl.clear();
      _playedIds.clear();
      _setSessionStreak(0);
    });
    unawaited(_prefs?.setString(
      _lastArtistKey,
      jsonEncode({
        'id': artist.id,
        'name': artist.name,
        'picture_medium': artist.pictureMedium ?? artist.pictureUrl,
      }),
    ));
    await _startRound();
  }

  void _changeArtist() {
    _stopClip();
    setState(() {
      _artist = null;
      _artistTooFew = false;
      _target = null;
      _outcomes = [];
    });
  }

  void _onArtistSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _artistResults = [];
        _artistSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final gen = ++_artistSearchGen;
      setState(() => _artistSearching = true);
      List<Artist> results;
      try {
        results = await _api.searchArtists(q.trim(), limit: 8);
      } catch (_) {
        results = [];
      }
      if (!mounted || gen != _artistSearchGen) return;
      setState(() {
        _artistResults = results;
        _artistSearching = false;
      });
    });
  }

  Future<void> _pickArtistByName(String name) async {
    try {
      final found = await _api.searchArtists(name, limit: 1);
      if (found.isNotEmpty && mounted) await _pickArtist(found.first);
    } catch (_) {}
  }

  void _setMode(GuessMode mode) {
    if (mode == _mode) return;
    Haptics.selection();
    setState(() => _mode = mode);
    _prefs?.setString(_lastModeKey, mode.name);
    _startRound();
  }

  void _startCountdown() {
    _countdown?.cancel();
    if (_mode != GuessMode.daily) return;
    final roundDay = _today;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_today != roundDay) {
        // Midnight passed while the screen was open: a new challenge is up.
        _startRound();
        return;
      }
      setState(() {});
    });
  }

  // ── Clip playback ──

  Future<void> _toggleClip() async {
    if (_target == null) return;
    if (_clipPlaying) {
      _stopClip();
      return;
    }
    Haptics.tap();
    await _player.seek(Duration.zero);
    if (!mounted) return;
    setState(() {
      _clipPlaying = true;
      _clipPos = Duration.zero;
    });
    unawaited(_player.play());
    _clipTimer?.cancel();
    // Backup in case position updates arrive late.
    _clipTimer = Timer(
        Duration(seconds: _unlockedSeconds, milliseconds: 250), _stopClip);
  }

  void _stopClip() {
    _clipTimer?.cancel();
    if (!_clipPlaying) return;
    _clipPlaying = false;
    _player.pause();
    if (mounted) setState(() => _clipPos = Duration.zero);
  }

  // ── Guessing ──

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      _searchGen++; // drop a lookup still in flight for the old text
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    final artist = _mode == GuessMode.artist ? _artist : null;
    var local = <Track>[];
    if (artist != null) {
      // The round's pool answers instantly; the rest of the artist's catalog
      // (songs outside their top 50) is looked up below and appended.
      final needle = GuessGame.normalize(q);
      local = GuessGame.uniqueSongs(_artistPool.where((t) =>
          GuessGame.normalize(t.title).contains(needle) ||
          GuessGame.normalize(t.albumTitle).contains(needle)));
      setState(() => _suggestions = local);
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final gen = ++_searchGen;
      setState(() => _searching = true);
      List<Track> results;
      try {
        if (artist != null) {
          final artistKey = GuessGame.normalize(artist.name);
          final found = await _api.searchTracksUnfiltered('${artist.name} ${q.trim()}', limit: 50);
          results = found
              .where((t) =>
                  t.artistId == artist.id ||
                  GuessGame.normalize(ArtistNames.primary(t.artistName)) == artistKey)
              .toList();
        } else {
          results = await _api.searchTracksUnfiltered(q.trim(), limit: 40);
        }
      } catch (_) {
        results = [];
      }
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _suggestions = GuessGame.uniqueSongs([...local, ...results]);
        _searching = false;
      });
    });
  }

  void _submit(Track guess) {
    final target = _target;
    if (target == null || _finished) return;
    var outcome = GuessGame.judge(target, guess);
    // Every answer in artist mode is by the same artist, so "right artist"
    // tells nothing.
    if (_mode == GuessMode.artist && outcome == GuessOutcome.rightArtist) {
      outcome = GuessOutcome.wrong;
    }
    final albumSuffix = guess.albumTitle.isNotEmpty ? ' · ${guess.albumTitle}' : '';
    final label = _mode == GuessMode.artist
        ? '${guess.title}$albumSuffix'
        : '${guess.title} — ${guess.artistName}$albumSuffix';
    _record(outcome, label);
  }

  void _skip() {
    if (_target == null || _finished) return;
    _record(GuessOutcome.skipped, '');
  }

  void _record(GuessOutcome outcome, String label) {
    _debounce?.cancel();
    _searchFocus.unfocus();
    _stopClip();
    switch (outcome) {
      case GuessOutcome.correct:
        Haptics.success();
      case GuessOutcome.rightArtist:
        Haptics.confirm();
      default:
        Haptics.error();
    }
    setState(() {
      _outcomes = [..._outcomes, outcome];
      _labels = [..._labels, label];
      _lastRecordedAttempt = _outcomes.length - 1;
      _suggestions = [];
      _searchCtrl.clear();
    });

    if (_mode == GuessMode.daily) {
      _prefs?.setString(
        GuessSongScreen.dailyStateKey,
        DailyRoundState(day: _today, trackId: _target!.id, outcomes: _outcomes, guessLabels: _labels)
            .encode(),
      );
    } else {
      _saveRound(_target!, _outcomes, _labels);
    }
    if (!_finished) return;

    if (_mode == GuessMode.daily) {
      // An admin's replays of the day don't count again.
      final firstToday = _stats.lastPlayedDay != _today;
      _stats.record(_today, _outcomes);
      _prefs?.setString(_statsKey, _stats.encode());
      if (firstToday) {
        ref.read(maskProvider).onDailyGuessFinished(
              won: _won,
              attempts: _outcomes.length,
              streak: _stats.currentStreak(_today),
            );
      }
      _startCountdown();
    } else {
      _setSessionStreak(_won ? _sessionStreak + 1 : 0);
      if (_sessionStreak > _bestStreak) {
        _bestStreak = _sessionStreak;
        _prefs?.setInt(_bestStreakKey, _bestStreak);
      }
    }
    // Reveal: play the song from the start.
    _toggleClip();
  }

  String _modeLabel(GuessMode mode) {
    final strings = ref.read(stringsProvider);
    return switch (mode) {
      GuessMode.daily => strings.guessModeDaily,
      GuessMode.library => strings.guessModeLibrary,
      GuessMode.artist => strings.guessModeArtist,
      GuessMode.chart => strings.guessModeChart,
    };
  }

  void _share() {
    final strings = ref.read(stringsProvider);
    final header = _mode == GuessMode.daily
        ? strings.guessShareHeader(_today)
        : _mode == GuessMode.artist
            ? 'Tsuki Tunes · ${_artist?.name ?? ''}'
            : 'Tsuki Tunes · ${_modeLabel(_mode)}';
    Clipboard.setData(ClipboardData(
      text: GuessGame.shareText(header: header, outcomes: _outcomes),
    ));
    Haptics.tap();
    AppSnack.of(context).info(strings.guessCopied);
  }

  void _listenFull() {
    final target = _target;
    if (target == null) return;
    _stopClip();
    ref.read(playTrackProvider)(target, queue: [target]);
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.guessTitle,
          style: locale.getTextStyle(
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: strings.guessStatsTitle,
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textBright),
            onPressed: () { Haptics.tap(); _showStats(locale); },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _modeChips(locale),
            Expanded(child: _body(locale)),
            if (!_loading && !_error && !_finished && _target != null) _inputPanel(locale),
          ],
        ),
      ),
    );
  }
}
