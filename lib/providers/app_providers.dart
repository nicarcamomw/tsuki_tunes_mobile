import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/play_history.dart';
import '../services/release_radar_service.dart';
import '../services/storage_service.dart';
import '../services/tile_channel_service.dart';
import 'ambient_provider.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'library_provider.dart';
import 'locale_provider.dart';
import 'mask_provider.dart';
import 'moon_provider.dart';
import 'playlist_provider.dart';
import 'run_provider.dart';
import 'search_provider.dart';
import 'shake_skip_provider.dart';
import 'weather_provider.dart';

// The app's state, owned by Riverpod. Each provider builds its object once
// and wires it to the others it needs, so a test can build the whole graph
// (or override a piece) with a ProviderContainer, no widgets involved.
//
// While the screens move over, main.dart also hands these same instances to
// the old `provider` tree, so context.watch<X>() and ref.watch(xProvider)
// see the same object.
//
// The wiring listens to the ChangeNotifiers directly instead of ref.listen:
// Riverpod pauses the subscriptions of providers nobody watches, and these
// links (sign-in to masks, library to radar...) must hold even then.

final connectivityProvider = ChangeNotifierProvider<ConnectivityProvider>(
  (ref) => ConnectivityProvider(),
);

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());

final libraryProvider = ChangeNotifierProvider<LibraryProvider>((ref) {
  final library = LibraryProvider();
  _follow(ref, library, () {
    ReleaseRadarService().watchArtists(library.followedArtists);
  }, now: false);
  return library;
});

final playlistProvider = ChangeNotifierProvider<PlaylistProvider>((ref) => PlaylistProvider());

final searchProvider = ChangeNotifierProvider<SearchProvider>((ref) => SearchProvider());

final localeProvider = ChangeNotifierProvider<LocaleProvider>(
  (ref) => LocaleProvider(storage: StorageService()),
);

final ambientProvider = ChangeNotifierProvider<AmbientProvider>((ref) {
  return AmbientProvider(labelFor: (sound) => ref.read(localeProvider).strings.ambientName(sound));
});

/// Masks belong to the signed-in account (null while signed out or guest).
final maskProvider = ChangeNotifierProvider<MaskProvider>((ref) {
  final masks = MaskProvider();
  final auth = ref.read(authProvider);
  _follow(ref, auth, () => masks.setUser(auth.isAuthenticated ? auth.uid : null));
  return masks;
});

final moonProvider = ChangeNotifierProvider<MoonProvider>((ref) {
  return MoonProvider()..onEclipseSeen = () => ref.read(maskProvider).onEclipseSeen();
});

final playHistoryProvider = ChangeNotifierProvider<PlayHistory>((ref) => PlayHistory()..load());

final weatherProvider = ChangeNotifierProvider<WeatherProvider>((ref) => WeatherProvider());

/// The one player. Built without its links to the rest of the app: when
/// Android Auto starts the app there is no screen, and the car only needs
/// the player. [playbackWiringProvider] adds the links once the app's tree
/// is built.
final audioProvider = ChangeNotifierProvider<AudioProvider>((ref) => AudioProvider());

/// Connects the player to the library, masks, ambient sounds and history.
/// Read once when the app's tree is built.
final playbackWiringProvider = Provider<void>((ref) {
  final player = ref.read(audioProvider);
  final library = ref.read(libraryProvider);
  final playlists = ref.read(playlistProvider);
  final ambient = ref.read(ambientProvider);
  final history = ref.read(playHistoryProvider);
  final masks = ref.read(maskProvider);

  player.setConnectivityProvider(ref.read(connectivityProvider));
  // Smart shuffle only recommends songs the user doesn't have.
  player.isInLibrary = (id) =>
      library.isTrackListened(id) ||
      library.isFavoriteTrack(id) ||
      playlists.playlists.any((p) => p.tracks.any((t) => t.id == id));
  player.onPlayCounted = (track) {
    history.record(track);
    masks.onPlayCounted(track);
    library.recordPlay(track);
  };
  player.onTrackCompleted = masks.onTrackCompleted;
  player.onSleepTimerFinished = ambient.onSleepTimerFinished;
  player.onAmbientPlay = ambient.resumeAll;
  player.onAmbientPause = ambient.pauseAll;
  player.onAmbientStop = ambient.stopAll;
  ambient.onMediaStateChanged = player.setAmbientMediaState;
  masks.isMusicPlaying = () => player.isPlaying;
  masks.isRainPlaying = () =>
      ambient.isPlaying && (ambient.isOn(AmbientSound.rain) || ambient.isOn(AmbientSound.storm));
  player.onTrackStarted = (track) {
    library.addRecentTrack(track);
    masks.onTrackStarted(track);
  };
  player.onListenedThreshold = (track) {
    if (!library.isTrackListened(track.id)) library.markTrack(track);
  };

  // The "new artist" mask needs the artists the user already knew, once
  // the library has loaded.
  void seedArtists() {
    if (!library.listenedTracksLoaded || masks.artistsSeeded) return;
    masks.seedKnownArtists([
      ...library.listenedTracks.map((t) => t.artistName),
      ...library.favoriteArtists.map((a) => a.name),
    ]);
  }

  _follow(ref, library, seedArtists);
  _follow(ref, masks, seedArtists, now: false);

  TileChannelService.init(player);
});

final runProvider = ChangeNotifierProvider<RunProvider>((ref) {
  return RunProvider()..attach(ref.read(audioProvider), ref.read(libraryProvider));
});

/// Has to listen from launch once switched on, so the app reads it at start.
final shakeSkipProvider = ChangeNotifierProvider<ShakeSkipProvider>((ref) {
  return ShakeSkipProvider()..attach(ref.read(audioProvider), ref.read(runProvider));
});

/// Calls [onChange] whenever [source] notifies (and right away unless [now]
/// is false), until the provider holding [ref] is disposed.
void _follow(Ref ref, Listenable source, VoidCallback onChange, {bool now = true}) {
  if (now) onChange();
  source.addListener(onChange);
  ref.onDispose(() => source.removeListener(onChange));
}
