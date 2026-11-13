/// Why signing in with Google didn't work (AuthProvider.authError).
enum AuthError {
  /// Too many attempts in a row: wait a moment before the next one.
  throttled,

  /// Google sign-in failed (network, Play services, another account).
  failed,
}
