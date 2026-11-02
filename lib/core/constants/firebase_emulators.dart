import 'package:flutter/foundation.dart';

/// Debug builds run with `--dart-define=USE_EMULATORS=true` use the local
/// Firebase Emulator Suite (`tool/dev_emulators.sh`) instead of the real
/// project: Auth and Firestore, with data that never leaves the PC. Never in
/// release builds.
const bool useFirebaseEmulators =
    !kReleaseMode && bool.fromEnvironment('USE_EMULATORS');

/// The PC as the app sees it. With `adb reverse` (the script does it) that's
/// 127.0.0.1 on a phone and on the Android emulator alike.
const String firebaseEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1');
