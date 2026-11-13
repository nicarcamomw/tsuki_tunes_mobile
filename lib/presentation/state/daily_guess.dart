import 'package:flutter/foundation.dart';

import '../screens/guess_song_screen.dart';

/// Whether today's "guess the song" round is finished, for the cards that
/// invite to it (Home's card of the day, Explore's game card).
class DailyGuess {
  DailyGuess._();

  static final ValueNotifier<bool> done = ValueNotifier<bool>(false);

  /// Reads it again: at start and after coming back from the game.
  static Future<void> refresh() async => done.value = await GuessSongScreen.isDailyDone();
}
