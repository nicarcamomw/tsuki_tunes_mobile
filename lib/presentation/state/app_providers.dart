import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../data/datasources/play_history.dart';
import '../../data/datasources/release_radar_service.dart';
import '../../data/datasources/storage_service.dart';
import '../../data/datasources/tile_channel_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../di/injection.dart';
import '../../domain/entities/track.dart';
import '../../domain/usecases/library/mark_track_listened.dart';
import '../navigation/session_gate.dart';
import 'ambient_provider.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'locale_provider.dart';
import 'mask_provider.dart';
import 'moon_provider.dart';
import 'run_provider.dart';
import 'search_provider.dart';
import 'shake_skip_provider.dart';
import 'weather_provider.dart';

// The app's state, owned by Riverpod. The library, playlists and player
// come from get_it (di/injection.dart), which owns their lifetime; the rest
// are built here. Each provider builds its object once
// and wires it to the others it needs, so a test can build the whole graph
// (or override a piece) with a ProviderContainer, no widgets involved.
// Widgets read them with ref.watch / ref.read, narrowing with .select so
// they rebuild only when the value they show changes.
//
// The wiring listens to the ChangeNotifiers directly instead of ref.listen:
// Riverpod pauses the subscriptions of providers nobody watches, and these
// links (sign-in to masks, library to radar...) must hold even then.

final connectivityProvider = ChangeNotifierProvider<ConnectivityProvider>(
  (ref) => ConnectivityProvider(),
);

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());

final libraryProvider = ChangeNotifierProvider<LibraryRepositoryImpl>(
  disposeNotifier: false,
  (ref) {
    final library = getIt<LibraryRepositoryImpl>();
    _follow(ref, library, () {
      ReleaseRadarService().watchArtists(library.followedArtists);
    }, now: false);
    return library;
  },
);

final playlistProvider = ChangeNotifierProvider<PlaylistRepositoryImpl>(
  disposeNotifier: false,
  (ref) => getIt<PlaylistRepositoryImpl>(),
);

final searchProvider = ChangeNotifierProvider<SearchProvider>((ref) => SearchProvider());

final localeProvider = ChangeNotifierProvider<LocaleProvider>(
  (ref) => LocaleProvider(storage: getIt<StorageService>()),
);

/// The app's language. Changes only when the user picks another one (or the
/// saved choice loads), unlike [localeProvider], which also notifies once
/// it has loaded.
final appLanguageProvider = Provider<AppLanguage>(
  (ref) => ref.watch(localeProvider).currentLanguage,
);

/// The texts in the app's language; widgets watching it rebuild only when
/// the language changes.
final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings.of(ref.watch(appLanguageProvider)),
);

final ambientProvider = ChangeNotifierProvider<AmbientProvider>((ref) {
  return AmbientProvider(labelFor: (sound) => ref.read(stringsProvider).ambientName(sound));
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
final audioProvider = ChangeNotifierProvider<AudioProvider>(
  disposeNotifier: false,
  (ref) => getIt<AudioProvider>(),
);

/// Connects the player to the library, masks, ambient sounds and history.
/// Read once when the app's tree is built.
final playbackWiringProvider = Provider<void>((ref) {
  final player = ref.read(audioProvider);
  final library = ref.read(libraryProvider);
  final playlists = ref.read(playlistProvider);
  final ambient = ref.read(ambientProvider);
  final history = ref.read(playHistoryProvider);
  final masks = ref.read(maskProvider);

  final connectivity = ref.read(connectivityProvider);
  player.setConnectivityProvider(connectivity);
  // Back online: what was marked offline goes to the server now, without
  // waiting for the outbox's next retry.
  var wasOnline = connectivity.isOnline;
  _follow(ref, connectivity, () {
    if (connectivity.isOnline && !wasOnline) library.retryPendingSync();
    wasOnline = connectivity.isOnline;
  }, now: false);
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
  final markListened = MarkTrackListened(library);
  player.onListenedThreshold = markListened.call;

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

// --- Derived state: narrow views that notify only when their value changes.

/// The song playing (or paused) now, null when nothing is loaded.
final currentTrackProvider = Provider<Track?>(
  (ref) => ref.watch(audioProvider.select((a) => a.currentTrack)),
);

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider.select((c) => c.isOnline)),
);

/// Whether the song with this id is marked as listened in the library.
final isTrackListenedProvider = Provider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(libraryProvider.select((l) => l.isTrackListened(id))),
);

/// Sign-in state for the router: connects the library and playlists to the
/// account and knows whether the tutorial was seen.
final sessionGateProvider = ChangeNotifierProvider<SessionGate>((ref) {
  return SessionGate(
    auth: ref.read(authProvider),
    library: ref.read(libraryProvider),
    playlists: ref.read(playlistProvider),
    storage: getIt<StorageService>(),
  );
});

/// Calls [onChange] whenever [source] notifies (and right away unless [now]
/// is false), until the provider holding [ref] is disposed.
void _follow(Ref ref, Listenable source, VoidCallback onChange, {bool now = true}) {
  if (now) onChange();
  source.addListener(onChange);
  ref.onDispose(() => source.removeListener(onChange));
}

/// For helpers outside widgets that only get a BuildContext (snack bars,
/// dialogs, sheets): reads a provider once, without listening. Widgets use
/// ref.read / ref.watch instead.
extension ReadAppState on BuildContext {
  T readState<T>(ProviderListenable<T> provider) =>
      ProviderScope.containerOf(this, listen: false).read(provider);
}
