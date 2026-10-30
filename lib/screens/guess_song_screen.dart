import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/mask_provider.dart';
import '../services/deezer_api_service.dart';
import '../services/guess_game.dart';

class GuessSongScreen extends StatefulWidget {
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
  State<GuessSongScreen> createState() => _GuessSongScreenState();
}

class _GuessSongScreenState extends State<GuessSongScreen> {
  static const _statsKey = 'guess_daily_stats';
  static const _bestStreakKey = 'guess_free_best_streak';
  static const _lastArtistKey = 'guess_last_artist';
  static const _lastModeKey = 'guess_last_mode';
  static const _sessionStreakKey = 'guess_free_streak';
  static const _minArtistPool = 6;
  static const _minLibrarySize = 5;
  static const _revealSeconds = 30;

  final _api = DeezerApiService();
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
    final audio = context.read<AudioProvider>();
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
        _artist = Artist.fromJson(jsonDecode(rawArtist) as Map<String, dynamic>);
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
    final library = context.read<LibraryProvider>();
    final seen = <String>{};
    return [...library.favoriteTracks, ...library.recentTracks]
        .where((t) => t.id.isNotEmpty && seen.add(t.id))
        .toList();
  }

  Future<void> _startRound() async {
    final gen = ++_roundGen;
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
        if (saved != null && saved.day == _today) {
          target = await _api.getTrack(saved.trackId, forceRefresh: true);
          outcomes = saved.outcomes;
          labels = saved.guessLabels;
        } else {
          final pool = await _chartPool();
          if (pool.isEmpty) throw StateError('empty chart');
          final pick = GuessGame.dailyPick(_today, pool, (t) => t.id);
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
      debugPrint('[GuessSong] round error: $e');
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
    unawaited(HapticFeedback.selectionClick());
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
    HapticFeedback.selectionClick();
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
    unawaited(HapticFeedback.lightImpact());
    await _player.seek(Duration.zero);
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
                  GuessGame.normalize(t.artistName.split(',').first) == artistKey)
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
        HapticFeedback.heavyImpact();
      case GuessOutcome.rightArtist:
        HapticFeedback.mediumImpact();
      default:
        HapticFeedback.lightImpact();
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
      _stats.record(_today, _outcomes);
      _prefs?.setString(_statsKey, _stats.encode());
      context.read<MaskProvider>().onDailyGuessFinished(
            won: _won,
            attempts: _outcomes.length,
            streak: _stats.currentStreak(_today),
          );
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
    final strings = context.read<LocaleProvider>().strings;
    return switch (mode) {
      GuessMode.daily => strings.guessModeDaily,
      GuessMode.library => strings.guessModeLibrary,
      GuessMode.artist => strings.guessModeArtist,
      GuessMode.chart => strings.guessModeChart,
    };
  }

  void _share() {
    final strings = context.read<LocaleProvider>().strings;
    final header = _mode == GuessMode.daily
        ? strings.guessShareHeader(_today)
        : _mode == GuessMode.artist
            ? 'Tsuki Tunes 🌙 · ${_artist?.name ?? ''}'
            : 'Tsuki Tunes 🌙 ${_modeLabel(_mode)}';
    Clipboard.setData(ClipboardData(
      text: GuessGame.shareText(header: header, outcomes: _outcomes),
    ));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.guessCopied),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
      ),
    );
  }

  void _listenFull() {
    final target = _target;
    if (target == null) return;
    _stopClip();
    context.read<AudioProvider>().playTrack(target, newQueue: [target]);
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.guessTitle,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: strings.guessStatsTitle,
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textBright),
            onPressed: () => _showStats(locale),
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

  Widget _modeChips(LocaleProvider locale) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: GuessMode.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final mode = GuessMode.values[i];
          final selected = _mode == mode;
          return ChoiceChip(
            label: Text(_modeLabel(mode)),
            selected: selected,
            onSelected: (_) => _setMode(mode),
            showCheckmark: false,
            labelStyle: locale.getTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );
        },
      ),
    );
  }

  Widget _artistAvatar(Artist a, double size) {
    final url = a.pictureMedium ?? a.pictureUrl;
    return ClipOval(
      child: url.isEmpty
          ? Container(
              width: size,
              height: size,
              color: AppColors.bgMid,
              child: Icon(Icons.person_rounded, size: size * 0.55, color: AppColors.textMuted),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              memCacheWidth: (size * 3).round(),
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _artistHeader(LocaleProvider locale) {
    final a = _artist!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _artistAvatar(a, 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: locale.getTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textBright,
              ),
            ),
          ),
          TextButton(
            onPressed: _changeArtist,
            child: Text(
              locale.strings.guessArtistChange,
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artistPicker(LocaleProvider locale) {
    final strings = locale.strings;
    final library = context.read<LibraryProvider>();
    final favorites = library.favoriteArtists;
    final favoriteNames = favorites.map((a) => a.name.toLowerCase()).toSet();
    final topNames = library
        .getTopArtists(limit: 8)
        .map((e) => e.name)
        .where((n) => n.isNotEmpty && n != '---' && !favoriteNames.contains(n.toLowerCase()))
        .toList();

    Widget artistRow(Artist a) => InkWell(
          onTap: () => _pickArtist(a),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                _artistAvatar(a, 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          strings.guessPickArtist,
          style: locale.getTextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (_artistTooFew) _banner(locale, Icons.info_outline_rounded, strings.guessArtistTooFew),
        TextField(
          controller: _artistSearchCtrl,
          onChanged: _onArtistSearch,
          textInputAction: TextInputAction.search,
          style: locale.getTextStyle(fontSize: 13, color: AppColors.textBright),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: strings.guessArtistSearchHint,
            hintStyle: locale.getTextStyle(fontSize: 12, color: AppColors.textMuted),
            isDense: true,
            filled: true,
            fillColor: AppColors.bgCard,
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_artistSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
          )
        else if (_artistResults.isNotEmpty)
          ..._artistResults.map(artistRow)
        else if (favorites.isNotEmpty || topNames.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            strings.guessYourArtists,
            style: locale.getTextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...favorites.take(12).map(artistRow),
          if (topNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in topNames)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => _pickArtistByName(name),
                      labelStyle: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                      backgroundColor: AppColors.bgCard,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _body(LocaleProvider locale) {
    final strings = locale.strings;
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
        ),
      );
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(strings.guessLoadError,
                style: locale.getTextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _startRound,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accent)),
              child: Text(strings.retry,
                  style: locale.getTextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accent)),
            ),
          ],
        ),
      );
    }

    if (_mode == GuessMode.artist && (_artist == null || _artistTooFew)) {
      return _artistPicker(locale);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (_mode == GuessMode.artist && _artist != null) _artistHeader(locale),
        if (_mode == GuessMode.library && _libraryFallback)
          _banner(locale, Icons.info_outline_rounded, strings.guessLibraryTooSmall),
        if (_mode != GuessMode.daily)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(
                color: AppColors.sakura.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sakura.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 14,
                      color: _sessionStreak > 0 ? AppColors.sakura : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    strings.guessSessionStreak(_sessionStreak, _bestStreak),
                    style: locale.getTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sakura,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_outcomes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              strings.guessHowTo,
              style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        if (_finished) ...[
          _revealCard(locale),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < GuessGame.maxAttempts; i++) _attemptRow(locale, i),
        if (_finished) ...[
          const SizedBox(height: 12),
          _clipBar(locale),
          const SizedBox(height: 8),
          Center(child: _playButton(locale, size: 52)),
        ],
      ],
    );
  }

  Widget _banner(LocaleProvider locale, IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: locale.getTextStyle(fontSize: 11, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _attemptRow(LocaleProvider locale, int i) {
    final strings = locale.strings;
    final done = i < _outcomes.length;
    final isCurrent = i == _outcomes.length && !_finished;
    final outcome = done ? _outcomes[i] : null;

    final (Color color, IconData? icon) = switch (outcome) {
      GuessOutcome.correct => (AppColors.success, Icons.check_rounded),
      GuessOutcome.rightArtist => (AppColors.warning, Icons.person_rounded),
      GuessOutcome.wrong => (AppColors.accent, Icons.close_rounded),
      GuessOutcome.skipped => (AppColors.textMuted, Icons.skip_next_rounded),
      null => (isCurrent ? AppColors.neonPurple : AppColors.border, null),
    };

    var text = '';
    if (outcome == GuessOutcome.skipped) {
      text = strings.guessAttemptSkipped;
    } else if (done) {
      text = _labels.length > i ? _labels[i] : '';
      if (outcome == GuessOutcome.rightArtist) text = '$text · ${strings.guessRightArtist}';
    }

    final rowContent = Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: done || isCurrent ? color.withValues(alpha: 0.07) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: done ? 0.4 : isCurrent ? 0.5 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(width: 3, color: color.withValues(alpha: done || isCurrent ? 0.8 : 0.15)),
          const SizedBox(width: 10),
          SizedBox(
            width: 18,
            child: Text(
              '${i + 1}',
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: done ? color : AppColors.textMuted,
              ),
            ),
          ),
          if (icon != null) ...[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.textBright : AppColors.textMuted,
              ),
            ),
          ),
          if (!done && !isCurrent) ...[
            Icon(Icons.lock_outline_rounded,
                size: 12, color: AppColors.textMuted.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.neonPurple : AppColors.bgMid,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${GuessGame.clipSeconds[i]}s',
              style: locale.getTextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );

    if (i == _lastRecordedAttempt && done) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: rowContent,
      );
    }
    return rowContent;
  }

  Widget _clipBar(LocaleProvider locale) {
    final total = _finished ? _revealSeconds : GuessGame.clipSeconds.last;
    final unlocked = _unlockedSeconds / total;
    final head = (_clipPos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
    final timeStyle = locale.getTextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.5,
    );

    final bar = LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (unlocked > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * unlocked,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (head > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: max(8, w * head),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.sakura],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (!_finished)
              for (final s in GuessGame.clipSeconds.take(GuessGame.maxAttempts - 1))
                // Gaps that split the bar into the attempts' steps.
                Positioned(
                  left: w * s / total - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: const ColoredBox(color: AppColors.bgMid),
                ),
          ],
        ),
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        const SizedBox(height: 4),
        Row(
          children: [
            Text('0:${_clipPos.inSeconds.toString().padLeft(2, '0')}', style: timeStyle),
            const Spacer(),
            Text(
              '${_unlockedSeconds}s / ${total}s',
              style: timeStyle.copyWith(color: AppColors.neonPurple),
            ),
          ],
        ),
      ],
    );
  }

  Widget _playButton(LocaleProvider locale, {double size = 60}) {
    return Semantics(
      button: true,
      label: locale.strings.guessTapToPlay,
      child: GestureDetector(
        onTap: _toggleClip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, Color(0xFFCC1414)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: _clipPlaying ? 0.5 : 0.25),
                blurRadius: _clipPlaying ? 20 : 10,
              ),
            ],
          ),
          child: Icon(
            _clipPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _inputPanel(LocaleProvider locale) {
    final strings = locale.strings;
    final isLast = _outcomes.length == GuessGame.maxAttempts - 1;
    final nextExtra = isLast
        ? 0
        : GuessGame.clipSeconds[_outcomes.length + 1] - GuessGame.clipSeconds[_outcomes.length];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty || _searching || _searchCtrl.text.trim().length >= 2)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
              child: _searching && _suggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    )
                  : _suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(strings.guessNoResults,
                                  style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 58,
                            endIndent: 12,
                            color: AppColors.border,
                          ),
                          itemBuilder: (_, i) {
                            final t = _suggestions[i];
                            return InkWell(
                              onTap: () => _submit(t),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: t.coverUrl.isEmpty
                                          ? Container(
                                              width: 38,
                                              height: 38,
                                              color: AppColors.bgMid,
                                              child: const Icon(Icons.music_note_rounded,
                                                  size: 18, color: AppColors.textMuted),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: t.coverUrl,
                                              width: 38,
                                              height: 38,
                                              memCacheWidth: 114,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: locale.getTextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textBright,
                                            ),
                                          ),
                                          Text(
                                            t.artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: locale.getTextStyle(
                                                fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                          if (t.albumTitle.isNotEmpty)
                                            Text(
                                              t.albumTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: locale.getTextStyle(
                                                  fontSize: 9, color: AppColors.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 16, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        ),
            ),
          const SizedBox(height: 6),
          _clipBar(locale),
          const SizedBox(height: 10),
          Row(
            children: [
              _playButton(locale, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: locale.getTextStyle(fontSize: 13, color: AppColors.textBright),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    hintText: strings.guessSearchHint,
                    hintStyle: locale.getTextStyle(fontSize: 12, color: AppColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bgCard,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // How the attempts went so far, at a glance.
              Expanded(child: _outcomeDots()),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _skip,
                icon: Icon(isLast ? Icons.flag_rounded : Icons.skip_next_rounded, size: 16),
                label: Text(
                  isLast ? strings.guessGiveUp : strings.guessSkip(nextExtra),
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.bgCard,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outcomeDots() {
    return Row(
      children: List.generate(GuessGame.maxAttempts, (i) {
        final done = i < _outcomes.length;
        final color = done
            ? switch (_outcomes[i]) {
                GuessOutcome.correct => AppColors.success,
                GuessOutcome.rightArtist => AppColors.warning,
                GuessOutcome.wrong => AppColors.accent,
                GuessOutcome.skipped => AppColors.border,
              }
            : Colors.transparent;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i < GuessGame.maxAttempts - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: done ? color : null,
              borderRadius: BorderRadius.circular(3),
              border: done ? null : Border.all(color: AppColors.border),
            ),
          ),
        );
      }),
    );
  }

  Widget _revealCard(LocaleProvider locale) {
    final strings = locale.strings;
    final t = _target!;
    final color = _won ? AppColors.success : AppColors.accent;
    final untilNext = GuessGame.untilNextDay(DateTime.now());
    final hh = untilNext.inHours.toString().padLeft(2, '0');
    final mm = (untilNext.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (untilNext.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: -4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _won ? strings.guessWonIn(_outcomes.length) : strings.guessLost,
                  style: locale.getTextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_won ? _outcomes.length : 'X'}/${GuessGame.maxAttempts}',
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _outcomeDots(),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: t.coverUrl.isEmpty
                      ? Container(width: 80, height: 80, color: AppColors.bgMid)
                      : CachedNetworkImage(
                          imageUrl: t.coverUrl,
                          width: 80,
                          height: 80,
                          memCacheWidth: 240,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.fullArtistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (t.albumTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.albumTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(locale, Icons.headphones_rounded, strings.guessListenFull, _listenFull),
              _actionButton(locale, Icons.copy_rounded, strings.guessShare, _share),
              if (_mode != GuessMode.daily)
                _actionButton(locale, Icons.arrow_forward_rounded, strings.guessNext, _startRound,
                    filled: true),
            ],
          ),
          if (_mode == GuessMode.daily) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    strings.guessNextDailyIn('$hh:$mm:$ss'),
                    style: locale.getTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(LocaleProvider locale, IconData icon, String label, VoidCallback onTap,
      {bool filled = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: filled ? Colors.white : AppColors.accent),
      label: Text(
        label,
        style: locale.getTextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : AppColors.accent,
          letterSpacing: 0.8,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: filled ? AppColors.accent : Colors.transparent,
        side: const BorderSide(color: AppColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showStats(LocaleProvider locale) {
    final strings = locale.strings;
    final s = _stats;
    final maxCount = s.distribution.fold<int>(1, max);

    Widget number(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: locale.getTextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textBright)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.borderGlow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${strings.guessStatsTitle} · ${strings.guessModeDaily}',
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  number('${s.played}', strings.guessStatsPlayed),
                  number('${s.winRate}', strings.guessStatsWinRate),
                  number('${s.currentStreak(_today)}', strings.guessStatsStreak),
                  number('${s.maxStreak}', strings.guessStatsMaxStreak),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                strings.guessStatsDistribution,
                style: locale.getTextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < s.distribution.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          i < GuessGame.maxAttempts ? '${i + 1}' : 'X',
                          style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, c) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: max(24, c.maxWidth * s.distribution[i] / maxCount),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: i < GuessGame.maxAttempts
                                    ? AppColors.success.withValues(alpha: 0.7)
                                    : AppColors.accent.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${s.distribution[i]}',
                                textAlign: TextAlign.right,
                                style: locale.getTextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
