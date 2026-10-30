/// The shuffle button's three states.
enum ShuffleMode {
  off,

  /// Smart shuffle of the user's songs.
  on,

  /// Smart shuffle with recommended songs slipped in between theirs.
  smart,
}

/// How smart shuffle orders songs by tempo (BPM, the data running mode
/// uses).
enum ShuffleEnergy {
  /// Left to chance.
  free,

  /// A fast song, then a calmer one, and so on.
  alternate,

  /// Each song close in tempo to the last, for a smooth flow.
  smooth,
}
