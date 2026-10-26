import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
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
  final Set<String> _playedIds = {};

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
      _suggestions = [];
      _searchCtrl.clear();
    });

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
          final pick = pool[GuessGame.dailyIndex(_today, pool.length)];
          target = await _api.getTrack(pick.id, forceRefresh: true) ?? pick;
          await _prefs?.setString(
            GuessSongScreen.dailyStateKey,
            DailyRoundState(day: _today, trackId: target.id, outcomes: [], guessLabels: [])
                .encode(),
          );
        }
      } else {
        var pool = _mode == GuessMode.library ? _libraryPool() : <Track>[];
        if (_mode == GuessMode.library && pool.length < _minLibrarySize) {
          fallback = true;
          pool = [];
        }
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
        if (target != null) _playedIds.add(target.id);
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

  void _setMode(GuessMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
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
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final gen = ++_searchGen;
      setState(() => _searching = true);
      List<Track> results;
      try {
        results = await _api.searchTracks(q.trim(), limit: 8);
      } catch (_) {
        results = [];
      }
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _submit(Track guess) {
    final target = _target;
    if (target == null || _finished) return;
    _record(GuessGame.judge(target, guess), '${guess.title} — ${guess.artistName}');
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
      _suggestions = [];
      _searchCtrl.clear();
    });

    if (_mode == GuessMode.daily) {
      _prefs?.setString(
        GuessSongScreen.dailyStateKey,
        DailyRoundState(day: _today, trackId: _target!.id, outcomes: _outcomes, guessLabels: _labels)
            .encode(),
      );
    }
    if (!_finished) return;

    if (_mode == GuessMode.daily) {
      _stats.record(_today, _outcomes);
      _prefs?.setString(_statsKey, _stats.encode());
      _startCountdown();
    } else {
      _sessionStreak = _won ? _sessionStreak + 1 : 0;
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
      GuessMode.chart => strings.guessModeChart,
    };
  }

  void _share() {
    final strings = context.read<LocaleProvider>().strings;
    final header = _mode == GuessMode.daily
        ? strings.guessShareHeader(_today)
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
            if (!_loading && !_error && !_finished) _inputPanel(locale),
          ],
        ),
      ),
    );
  }

  Widget _modeChips(LocaleProvider locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final mode in GuessMode.values) ...[
            Expanded(
              child: ChoiceChip(
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _modeLabel(mode),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                selected: _mode == mode,
                onSelected: (_) => _setMode(mode),
                showCheckmark: false,
                labelStyle: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _mode == mode ? Colors.white : AppColors.textSecondary,
                ),
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.bgCard,
                side: BorderSide(color: _mode == mode ? AppColors.accent : AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (mode != GuessMode.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (_mode == GuessMode.library && _libraryFallback)
          _banner(locale, Icons.info_outline_rounded, strings.guessLibraryTooSmall),
        if (_mode != GuessMode.daily)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              strings.guessSessionStreak(_sessionStreak, _bestStreak),
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sakura,
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
          _clipBar(),
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

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: done || isCurrent ? 0.7 : 1)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
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
          Text(
            '${GuessGame.clipSeconds[i]}s',
            style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _clipBar() {
    final total = _finished ? _revealSeconds : GuessGame.clipSeconds.last;
    final unlocked = _unlockedSeconds / total;
    final head = (_clipPos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 14,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * unlocked,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * head,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (!_finished)
              for (final s in GuessGame.clipSeconds.take(GuessGame.maxAttempts - 1))
                Positioned(
                  left: w * s / total - 0.5,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: Container(color: AppColors.borderGlow),
                ),
          ],
        ),
      );
    });
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
            color: AppColors.accent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: _clipPlaying ? 0.6 : 0.3),
                blurRadius: _clipPlaying ? 22 : 12,
              ),
            ],
          ),
          child: Icon(
            _clipPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: size * 0.55,
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
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.2),
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
                          child: Text(strings.guessNoResults,
                              style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) {
                            final t = _suggestions[i];
                            return InkWell(
                              onTap: () => _submit(t),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          const SizedBox(height: 6),
          _clipBar(),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _skip,
              child: Text(
                isLast ? strings.guessGiveUp : strings.guessSkip(nextExtra),
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _won ? strings.guessWonIn(_outcomes.length) : strings.guessLost,
            style: locale.getTextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(GuessGame.emojiRow(_outcomes), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.coverUrl.isEmpty
                    ? Container(width: 76, height: 76, color: AppColors.bgMid)
                    : CachedNetworkImage(
                        imageUrl: t.coverUrl,
                        width: 76,
                        height: 76,
                        memCacheWidth: 228,
                        fit: BoxFit.cover,
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
            Text(
              strings.guessNextDailyIn('$hh:$mm:$ss'),
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
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
              Text(
                '${strings.guessStatsTitle} · ${strings.guessModeDaily}',
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.5,
                ),
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
                              width: max(22, c.maxWidth * s.distribution[i] / maxCount),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              color: i < GuessGame.maxAttempts
                                  ? AppColors.success.withValues(alpha: 0.7)
                                  : AppColors.accent.withValues(alpha: 0.6),
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
