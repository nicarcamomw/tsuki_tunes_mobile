import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/synced_lyrics.dart';

void main() {
  group('SyncedLyrics LRC Parser & Time Indexing', () {
    const sampleLrc = '''
[00:05.20] First lyric line begins
[00:12.50] Second line starts playing
[00:25.80] Chorus drop happens here
[00:30.00] Final outro line
''';

    test('SyncedLyrics.fromLrc parses timestamps and line count accurately', () {
      final lyrics = SyncedLyrics.fromLrc(sampleLrc);

      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, 4);
      expect(lyrics.lines[0].text, 'First lyric line begins');
      expect(lyrics.lines[0].time, const Duration(seconds: 5, milliseconds: 200));
      expect(lyrics.lines[2].text, 'Chorus drop happens here');
      expect(lyrics.lines[2].time, const Duration(seconds: 25, milliseconds: 800));
    });

    test('activeIndexAt returns correct active line for current playback position', () {
      final lyrics = SyncedLyrics.fromLrc(sampleLrc);

      // Before first line
      expect(lyrics.activeIndexAt(const Duration(seconds: 2)), -1);

      // During first line
      expect(lyrics.activeIndexAt(const Duration(seconds: 6)), 0);

      // During second line
      expect(lyrics.activeIndexAt(const Duration(seconds: 15)), 1);

      // During chorus
      expect(lyrics.activeIndexAt(const Duration(seconds: 28)), 2);

      // After final line
      expect(lyrics.activeIndexAt(const Duration(seconds: 35)), 3);
    });

    test('activeIndexAt anticipates upcoming line with leadOffset', () {
      final lyrics = SyncedLyrics.fromLrc(sampleLrc);

      // First line is at 5.20s. At 4.95s (250ms before vocal), default 320ms offset triggers it:
      expect(lyrics.activeIndexAt(const Duration(milliseconds: 4950)), 0);

      // Without lead offset, 4.95s is still before the line:
      expect(lyrics.activeIndexAt(const Duration(milliseconds: 4950), leadOffset: Duration.zero), -1);
    });

    test('SyncedLyrics handles empty LRC text gracefully', () {
      final lyrics = SyncedLyrics.fromLrc('');
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.lines, isEmpty);
      expect(lyrics.activeIndexAt(const Duration(seconds: 10)), -1);
    });
  });
}
