/// Why listening stopped without a usable result.
enum VoiceError {
  /// Microphone permission denied.
  permission,

  /// No speech recognizer on this phone (e.g. no Google app).
  unavailable,

  /// Heard nothing, or nothing it could recognize.
  noMatch,

  /// The recognizer needs the network and couldn't reach it.
  network,

  /// The chosen language isn't supported by the recognizer.
  language,

  /// A previous session was still closing.
  busy,

  other,
}
