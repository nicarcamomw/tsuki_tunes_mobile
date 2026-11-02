import 'package:flutter/services.dart';

/// Which environment this build is (the Android flavor it was built with,
/// android/app/build.gradle.kts): dev talks to its own Firebase project
/// and link schemes, prod to what real users use. Tests and builds with no
/// flavor count as prod, where every value below is what the app always had.
final bool isDevEnvironment = appFlavor == 'dev';

/// The app's link scheme: tsukitunes://album/123 (tsukitunes-dev:// in dev,
/// so links open the build they're meant for).
final String deepLinkScheme = isDevEnvironment ? 'tsukitunes-dev' : 'tsukitunes';

/// Where Spotify sends the sign-in back to; each environment's scheme is
/// registered in the Spotify app's dashboard and in the manifest.
final String spotifyRedirectScheme =
    isDevEnvironment ? 'com.tsuki.tsukitunesmobile.dev' : 'com.tsuki.tsukitunesmobile';
final String spotifyRedirectUri = '$spotifyRedirectScheme://spotify-callback';
