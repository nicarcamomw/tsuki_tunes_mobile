part of '../guess_song_screen.dart';

/// The round's views: mode chips, artist picker, attempts, clip bar,
/// answers, reveal card and stats.
extension _GuessSongViews on _GuessSongScreenState {
  Widget _modeChips(LocaleProvider locale) {
    // Room for each chip's 48 dp touch target (it was squeezed to 36).
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 8),
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
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            // White text on it: the deeper crimson reads at AA.
            selectedColor: AppColors.accentFill,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
                fontSize: AppFontSize.bodyLg,
                fontWeight: FontWeight.w800,
                color: AppColors.textBright,
              ),
            ),
          ),
          TextButton(
            onPressed: () { Haptics.tap(); _changeArtist(); },
            child: Text(
              locale.strings.guessArtistChange,
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
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
    final library = ref.read(libraryProvider);
    final favorites = library.favoriteArtists;
    final favoriteNames = favorites.map((a) => a.name.toLowerCase()).toSet();
    final topNames = library
        .getTopArtists(limit: 8)
        .map((e) => e.name)
        .where((n) => n.isNotEmpty && n != '---' && !favoriteNames.contains(n.toLowerCase()))
        .toList();

    Widget artistRow(Artist a) => InkWell(
          onTap: () => _pickArtist(a),
          borderRadius: BorderRadius.circular(AppRadius.card),
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
                      fontSize: AppFontSize.bodyLg,
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
      children: [
        Text(
          strings.guessPickArtist,
          style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (_artistTooFew) _banner(locale, Icons.info_outline_rounded, strings.guessArtistTooFew),
        TextField(
          controller: _artistSearchCtrl,
          onChanged: _onArtistSearch,
          textInputAction: TextInputAction.search,
          style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textBright),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: strings.guessArtistSearchHint,
            hintStyle: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textMuted),
            isDense: true,
            filled: true,
            fillColor: AppColors.bgCard,
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_artistSearching)
          const SkeletonRowList(count: 3, leading: 36, round: true, padding: EdgeInsets.symmetric(vertical: 4))
        else if (_artistResults.isNotEmpty)
          ..._artistResults.map(artistRow)
        else if (favorites.isNotEmpty || topNames.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            strings.guessYourArtists,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
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
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                      backgroundColor: AppColors.bgCard,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
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
    if (_loading) return const _RoundSkeleton();
    if (_error) {
      return ErrorState(message: strings.guessLoadError, onRetry: _startRound, iconSize: 32);
    }

    if (_mode == GuessMode.artist && (_artist == null || _artistTooFew)) {
      return _artistPicker(locale);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 16),
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
                borderRadius: BorderRadius.circular(AppRadius.card),
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
                      fontSize: AppFontSize.caption,
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
              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textPrimary)),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                fontSize: AppFontSize.caption,
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
                fontSize: AppFontSize.body,
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
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              '${GuessGame.clipSeconds[i]}s',
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
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
        duration: AppMotion.normal,
        curve: Curves.elasticOut,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: rowContent,
      );
    }
    return rowContent;
  }

  Widget _clipBar(LocaleProvider locale) {
    final total = _finished ? _GuessSongScreenState._revealSeconds : GuessGame.clipSeconds.last;
    final unlocked = _unlockedSeconds / total;
    final head = (_clipPos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
    final timeStyle = locale.getTextStyle(
      fontSize: AppFontSize.micro,
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
                  borderRadius: BorderRadius.circular(AppRadius.chip),
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
                    borderRadius: BorderRadius.circular(AppRadius.chip),
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
                    borderRadius: BorderRadius.circular(AppRadius.chip),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 12),
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
                  ? const SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: SkeletonRowList(count: 3, leading: 36, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
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
                                  style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(AppRadius.card),
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
                                      borderRadius: BorderRadius.circular(AppRadius.chip),
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
                                              fontSize: AppFontSize.body,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textBright,
                                            ),
                                          ),
                                          Text(
                                            t.artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: locale.getTextStyle(
                                                fontSize: AppFontSize.micro, color: AppColors.textSecondary),
                                          ),
                                          if (t.albumTitle.isNotEmpty)
                                            Text(
                                              t.albumTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: locale.getTextStyle(
                                                  fontSize: AppFontSize.micro, color: AppColors.textMuted),
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
                  style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textBright),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    hintText: strings.guessSearchHint,
                    hintStyle: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bgCard,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
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
                    fontSize: AppFontSize.caption,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
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
              borderRadius: BorderRadius.circular(AppRadius.chip),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                  style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: color),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_won ? _outcomes.length : 'X'}/${GuessGame.maxAttempts}',
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.bodyLg,
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
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
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
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.fullArtistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary),
                    ),
                    if (t.albumTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.albumTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
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
                    filled: true)
              else if (_isAdmin)
                _actionButton(locale, Icons.arrow_forward_rounded, strings.guessNext, _replayDaily,
                    filled: true),
            ],
          ),
          if (_mode == GuessMode.daily) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    strings.guessNextDailyIn('$hh:$mm:$ss'),
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.caption,
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
          fontSize: AppFontSize.micro,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : AppColors.accent,
          letterSpacing: 0.8,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: filled ? AppColors.accent : Colors.transparent,
        side: const BorderSide(color: AppColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
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
                      fontSize: AppFontSize.headline, fontWeight: FontWeight.w800, color: AppColors.textBright)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted)),
            ],
          ),
        );

    showAppSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${strings.guessStatsTitle} · ${strings.guessModeDaily}',
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.bodyLg,
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
                  fontSize: AppFontSize.micro,
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
                          style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
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
                                borderRadius: BorderRadius.circular(AppRadius.chip),
                              ),
                              child: Text(
                                '${s.distribution[i]}',
                                textAlign: TextAlign.right,
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.micro,
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

/// A round being prepared: the streak chip, the clip's card, the answers.
class _RoundSkeleton extends StatelessWidget {
  const _RoundSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonScope(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 16),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SkeletonLoader(width: 90, height: 24, borderRadius: AppRadius.pill),
            ),
            const SizedBox(height: 10),
            const SkeletonLoader(height: 140, borderRadius: AppRadius.sheet),
            const SizedBox(height: 16),
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SkeletonLoader(height: 44, borderRadius: AppRadius.card),
              ),
          ],
        ),
      );
}
