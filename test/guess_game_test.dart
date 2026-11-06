import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/guess_game.dart';

Track _track(String id, String title, String artist, {String artistId = ''}) => Track(
      id: id,
      title: title,
      artistId: artistId,
      artistName: artist,
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

void main() {
  group('GuessGame.normalize', () {
    test('ignores accents, case, brackets, versions and features', () {
      expect(GuessGame.normalize('Canción (Remastered 2011)'), 'cancion');
      expect(GuessGame.normalize('Chop Suey! - Live'), 'chopsuey');
      expect(GuessGame.normalize('Song [Radio Edit] feat. Someone'), 'song');
      expect(GuessGame.normalize('Bad Guy ft. Justin'), 'badguy');
    });

    test('keeps non-Latin titles', () {
      expect(GuessGame.normalize('夜に駆ける'), '夜に駆ける');
    });
  });

  group('GuessGame.judge', () {
    final target = _track('1', 'Toxicity', 'System Of A Down', artistId: '458');

    test('same id is correct', () {
      expect(GuessGame.judge(target, target), GuessOutcome.correct);
    });

    test('another version of the same song is correct', () {
      final live = _track('2', 'Toxicity (Live)', 'System of a Down', artistId: '458');
      expect(GuessGame.judge(target, live), GuessOutcome.correct);
    });

    test('same title by a different artist is wrong', () {
      final cover = _track('3', 'Toxicity', 'Some Cover Band', artistId: '999');
      expect(GuessGame.judge(target, cover), GuessOutcome.wrong);
    });

    test('other song by the same artist is a partial hit', () {
      final other = _track('4', 'Aerials', 'System Of A Down', artistId: '458');
      expect(GuessGame.judge(target, other), GuessOutcome.rightArtist);
    });

    test('artist match falls back to the name when ids are missing', () {
      final t = _track('5', 'Song A', 'Bad Bunny');
      final g = _track('6', 'Song B', 'Bad Bunny, Jhay Cortez');
      expect(GuessGame.judge(t, g), GuessOutcome.rightArtist);
    });
  });

  group('GuessGame.uniqueSongs', () {
    test('keeps one version per song, in order', () {
      final songs = GuessGame.uniqueSongs([
        _track('1', 'Toxicity', 'System Of A Down'),
        _track('2', 'Toxicity (Live)', 'System of a Down'),
        _track('3', 'Aerials', 'System Of A Down'),
        _track('4', 'Toxicity', 'Another Band'),
      ]);
      expect(songs.map((t) => t.id), ['1', '3', '4']);
    });
  });

  group('daily challenge', () {
    test('the daily pick survives the chart reordering', () {
      final pool = [for (var i = 0; i < 100; i++) _track('$i', 'Song $i', 'A')];
      for (var day = 1; day < 50; day++) {
        final pick = GuessGame.dailyPick(day, pool, (t) => t.id);
        final shuffled = [...pool.reversed];
        expect(GuessGame.dailyPick(day, shuffled, (t) => t.id).id, pick.id);
        // Another song leaving the chart doesn't change it either.
        final smaller = pool.where((t) => t.id != pick.id).toList()..removeAt(0);
        smaller.add(pick);
        expect(GuessGame.dailyPick(day, smaller, (t) => t.id).id, pick.id);
      }
      final picks = {for (var d = 1; d < 30; d++) GuessGame.dailyPick(d, pool, (t) => t.id).id};
      expect(picks.length, greaterThan(20), reason: 'different songs on different days');
    });

    test('day number starts at 1 on launch day and is stable within the day', () {
      expect(GuessGame.dayNumber(DateTime(2026, 10, 26, 0, 5)), 1);
      expect(GuessGame.dayNumber(DateTime(2026, 10, 26, 23, 59)), 1);
      expect(GuessGame.dayNumber(DateTime(2026, 10, 27, 0, 0)), 2);
    });

  });

  group('results', () {
    test('share text shows score and the attempts, without emoji', () {
      final text = GuessGame.shareText(
        header: 'Tsuki Tunes · Reto #3',
        outcomes: [GuessOutcome.skipped, GuessOutcome.rightArtist, GuessOutcome.correct],
      );
      expect(text, 'Tsuki Tunes · Reto #3  3/6\n– ◐ ● · · ·');
    });

    test('a lost game scores X', () {
      final text = GuessGame.shareText(
        header: 'h',
        outcomes: List.filled(6, GuessOutcome.wrong),
      );
      expect(text, startsWith('h  X/6'));
    });

    test('finished after a correct guess or six attempts', () {
      expect(GuessGame.isFinished([GuessOutcome.wrong]), isFalse);
      expect(GuessGame.isFinished([GuessOutcome.wrong, GuessOutcome.correct]), isTrue);
      expect(GuessGame.isFinished(List.filled(6, GuessOutcome.skipped)), isTrue);
    });
  });

  group('GuessStats', () {
    test('streak grows on consecutive wins and resets on a loss', () {
      final s = GuessStats();
      s.record(1, [GuessOutcome.correct]);
      s.record(2, [GuessOutcome.wrong, GuessOutcome.correct]);
      expect(s.streak, 2);
      expect(s.maxStreak, 2);
      s.record(3, List.filled(6, GuessOutcome.wrong));
      expect(s.streak, 0);
      expect(s.maxStreak, 2);
      expect(s.played, 3);
      expect(s.wins, 2);
      expect(s.distribution, [1, 1, 0, 0, 0, 0, 1]);
    });

    test('a skipped day breaks the streak', () {
      final s = GuessStats();
      s.record(1, [GuessOutcome.correct]);
      s.record(3, [GuessOutcome.correct]);
      expect(s.streak, 1);
      expect(s.currentStreak(3), 1);
      expect(s.currentStreak(5), 0);
    });

    test('recording the same day twice counts once', () {
      final s = GuessStats();
      s.record(1, [GuessOutcome.correct]);
      s.record(1, [GuessOutcome.correct]);
      expect(s.played, 1);
    });

    test('survives an encode/decode round trip', () {
      final s = GuessStats()..record(1, [GuessOutcome.correct]);
      final back = GuessStats.decode(s.encode());
      expect(back.played, 1);
      expect(back.wins, 1);
      expect(back.distribution, s.distribution);
      expect(GuessStats.decode('not json').played, 0);
    });
  });

  test('DailyRoundState survives an encode/decode round trip', () {
    final state = DailyRoundState(
      day: 4,
      trackId: '123',
      outcomes: [GuessOutcome.skipped, GuessOutcome.correct],
      guessLabels: ['', 'Song — Artist'],
    );
    final back = DailyRoundState.decode(state.encode())!;
    expect(back.day, 4);
    expect(back.trackId, '123');
    expect(back.outcomes, state.outcomes);
    expect(back.guessLabels, state.guessLabels);
    expect(back.scope, '');
    expect(DailyRoundState.decode(null), isNull);
  });

  test('a free round keeps its artist scope', () {
    final state = DailyRoundState(
      day: 4,
      trackId: '9',
      outcomes: [GuessOutcome.wrong],
      guessLabels: ['Song'],
      scope: '458',
    );
    expect(DailyRoundState.decode(state.encode())!.scope, '458');
  });
}
