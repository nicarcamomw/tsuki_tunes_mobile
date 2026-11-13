import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../data/datasources/audio_precache_service.dart';
import '../../data/datasources/battery_guide.dart';
import '../../data/datasources/beat_clock.dart';
import '../../data/datasources/bpm_flow.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/firebase_service.dart';
import '../../data/datasources/lyrics_service.dart';
import '../../data/datasources/play_history.dart';
import '../../data/datasources/playback_log.dart';
import '../../data/datasources/product_analytics.dart';
import '../../data/datasources/rain_mix.dart';
import '../../data/datasources/release_radar_service.dart';
import '../../data/datasources/storage_service.dart';
import '../../data/datasources/streak_reminder.dart';
import '../../data/datasources/style_service.dart';
import '../../data/datasources/tile_channel_service.dart';
import '../../data/datasources/time_machine_service.dart';
import '../../data/datasources/voice_search_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../di/injection.dart';
import '../../domain/entities/social.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/playback_source.dart';
import '../../domain/repositories/party_repository.dart';
import '../../domain/repositories/product_events.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/shared_playlist_repository.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/library/mark_track_listened.dart';
import '../navigation/session_gate.dart';
import 'ambient_provider.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'locale_provider.dart';
import 'mask_provider.dart';
import 'moon_provider.dart';
import 'party_controller.dart';
import 'profile_controller.dart';
import 'run_provider.dart';
import 'search_provider.dart';
import 'shake_skip_provider.dart';
import 'shared_playlists_controller.dart';
import 'social_controller.dart';
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

final authProvider = ChangeNotifierProvider<AuthProvider>(
    (ref) => AuthProvider(firebase: getIt<FirebaseService>()));

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

/// Followed artists' new releases: the list, what is watched, and the
/// notifications it opens. The type stays inferred so screens don't import
/// the data layer for it.
final releaseRadarProvider = Provider((ref) => ReleaseRadarService());

/// Whether this platform runs the release radar (Android and iOS).
final releaseRadarSupportedProvider =
    Provider<bool>((ref) => ReleaseRadarService.isSupported);

/// "A year ago today": its moments, schedule and notification setting.
final timeMachineProvider = Provider((ref) => TimeMachineService());

/// Song tempos (BPM), fetched and cached for the player and the flows.
final bpmProvider = Provider((ref) => BpmService.shared);

/// The battery guide offered on phones that freeze Spotify.
final batteryGuideProvider = Provider((ref) => BatteryGuide.instance);

/// Settings and small values kept on the phone.
final storageProvider = Provider((ref) => getIt<StorageService>());

/// Product analytics, for the setting that turns it off (the use cases
/// report through productEventsProvider).
final analyticsProvider = Provider((ref) => ProductAnalytics.instance);

/// The playback log, copied from settings to report a problem.
final playbackLogProvider = Provider((ref) => PlaybackLog.instance);

/// Previews kept on the phone for offline and instant starts.
final audioCacheProvider = Provider((ref) => AudioPrecacheService());

/// On-device speech recognition for voice search.
final voiceSearchProvider = Provider((ref) => VoiceSearchService());

/// Beat grids tapped by the user for each song.
final beatSyncProvider = Provider((ref) => BeatSyncStore.shared);

/// Song search in the catalog, as a function (tests pass their own).
final trackSearchProvider =
    Provider<Future<List<Track>> Function(String query)>(
        (ref) => DeezerApiService().searchTracks);

/// A queue for a rainy moment from the listener's own calm songs (see
/// RainMix), with the BPM cache and the catalog search.
final rainMixProvider = Provider((ref) => ({
      required List<Track> library,
      required List<String> favoriteArtists,
    }) =>
        RainMix.build(
          library: library,
          artistNames: RainMix.artistsFrom(library, favoriteArtists),
          bpm: ref.read(bpmProvider),
          search: ref.read(trackSearchProvider),
        ));

final searchProvider = ChangeNotifierProvider<SearchProvider>(
    (ref) => SearchProvider(api: getIt<DeezerApiService>(), lyrics: getIt<LyricsService>()));

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

/// The daily streak's quiet evening reminder (on unless turned off).
final streakReminderProvider = Provider<StreakReminder>((ref) => StreakReminder.shared);

/// Masks belong to the signed-in account (null while signed out or guest).
final maskProvider = ChangeNotifierProvider<MaskProvider>((ref) {
  final masks = MaskProvider()..userName = () => ref.read(authProvider).user?.displayName;
  // The streak's evening reminder follows the run (it changes nothing
  // when the run hasn't changed).
  masks.addListener(() => unawaited(StreakReminder.shared.sync(masks.streakForReminder)));
  final auth = ref.read(authProvider);
  void follow() {
    masks.observer = auth.isGuest;
    masks.isAdmin = auth.isAdmin;
    masks.setUser(auth.isAuthenticated ? auth.uid : null);
  }

  _follow(ref, auth, follow);
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

/// What plays now: the whole song (Spotify) or a 30 s preview, and why
/// (the player's badge).
final playbackSourceProvider = Provider<PlaybackSource>((ref) {
  final (full, fallback, connected, premium, restricted) = ref.watch(audioProvider.select((a) => (
        a.playsFullSong,
        a.lastSpotifyError,
        a.spotify.isConnected,
        a.spotify.isPremium,
        a.spotify.accessRestricted,
      )));
  return PlaybackSource.of(
    playsFullSong: full,
    spotifyConnected: connected,
    premium: premium,
    notAllowed: restricted,
    online: ref.watch(connectivityProvider.select((c) => c.isOnline)),
    fallback: fallback,
  );
});

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
  player.onSleepTimerFinished = () {
    ambient.onSleepTimerFinished();
    masks.onSleepTimerFinished();
  };
  player.onAmbientPlay = ambient.resumeAll;
  player.onAmbientPause = ambient.pauseAll;
  player.onAmbientStop = ambient.stopAll;
  ambient.onMediaStateChanged = player.setAmbientMediaState;
  masks.isMusicPlaying = () => player.isPlaying;
  // What the masks' achievements read: each song's style and tempo, the
  // ambient sounds on, and the weather (only when the user turned it on).
  masks.styleOf = StyleService.shared.styleOf;
  masks.bpmOf = BpmService.shared.cached;
  masks.ambientOn = () => ambient.isPlaying
      ? {for (final s in AmbientSound.values) if (ambient.isOn(s)) s.name}
      : const <String>{};
  final weather = ref.read(weatherProvider);
  masks.weatherNow = () => weather.enabled ? weather.current : null;
  masks.isRainPlaying = () =>
      ambient.isPlaying && (ambient.isOn(AmbientSound.rain) || ambient.isOn(AmbientSound.storm));
  final lyrics = getIt<LyricsService>();
  player.onTrackStarted = (track) {
    // Running in the background is offered once some music has been heard,
    // with its reason (MainNavigationScreen, PermissionPrimer), not here
    // while the song is starting.
    library.addRecentTrack(track);
    masks.onTrackStarted(track);
    // Tempo for the player (menu, eye, queue) even when loudness isn't
    // looked up (Spotify, normalization off).
    unawaited(BpmService.shared.ensure(track.id));
    // Lyrics of this song and the next are ready before the player opens.
    lyrics.prefetch(track.title, track.artistName, durationSeconds: track.durationSeconds);
    final queue = player.queue;
    final next = player.currentIndex + 1;
    if (next > 0 && next < queue.length) {
      lyrics.prefetch(queue[next].title, queue[next].artistName,
          durationSeconds: queue[next].durationSeconds);
    }
  };
  // Resonances: what the Bonds hear about (rarer beings, new ranks, long
  // streaks, albums heard whole).
  final milestones = ref.read(milestoneLogProvider);
  masks.onMilestone = milestones.add;
  void albumMilestone(String albumId) {
    for (final t in library.listenedTracks) {
      if (t.albumId == albumId && t.albumTitle.isNotEmpty) {
        milestones.album(t.albumTitle, t.artistName);
        return;
      }
    }
  }

  final markListened = MarkTrackListened(library, events: _MilestoneEvents(albumMilestone));
  player.onListenedThreshold = markListened.call;

  // When a track count arrives late (the album screen is opened after all
  // songs were heard through radio/shuffle), fire the album_completed event
  // that MarkTrackListened couldn't fire at listen time.
  library.onAlbumCompleted = (albumId) {
    ProductAnalytics.instance.log('album_completed', {'album_id': albumId});
    albumMilestone(albumId);
  };

  // The "new artist" mask needs the artists the user already knew, once
  // the library has loaded.
  void seedArtists() {
    if (!library.listenedTracksLoaded || masks.artistsSeeded) return;
    masks.seedKnownArtists([
      ...library.listenedTracks.expand((t) => t.artists),
      ...library.favoriteArtists.map((a) => a.name),
    ]);
  }

  _follow(ref, library, seedArtists);
  _follow(ref, masks, seedArtists, now: false);

  // Plays from before the masks existed (or from another phone) count
  // toward them: read once from the play log, once the library is ready.
  masks.historyLoader = () {
    final now = DateTime.now();
    return library.loadPlayDays(now.subtract(const Duration(days: 365)), now);
  };
  void catchUpMasks() {
    if (library.listenedTracksLoaded) unawaited(masks.catchUpFromHistory());
  }

  _follow(ref, library, catchUpMasks);
  _follow(ref, masks, catchUpMasks, now: false);

  TileChannelService.init(player);
});

final runProvider = ChangeNotifierProvider<RunProvider>((ref) {
  return RunProvider()
    ..attach(ref.read(audioProvider), ref.read(libraryProvider))
    ..onSessionEnded = (elapsed) => ref.read(maskProvider).onRunFinished(elapsed);
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

/// The signed-in user's public profile, kept published as their library,
/// mask and account change. Built at launch (see main.dart).
final profileControllerProvider = ChangeNotifierProvider<ProfileController>((ref) {
  final auth = ref.read(authProvider);
  final library = ref.read(libraryProvider);
  final masks = ref.read(maskProvider);
  final milestones = ref.read(milestoneLogProvider);
  return ProfileController(
    repository: getIt<ProfileRepository>(),
    changes: Listenable.merge([auth, library, masks, milestones]),
    milestones: () => milestones.items,
    // Guests have no profile.
    uid: () => auth.isAuthenticated ? auth.uid : null,
    displayName: () => auth.user?.displayName ?? '',
    photoUrl: () => auth.user?.photoURL,
    maskId: () => masks.equipped?.id,
    libraryLoaded: () => library.listenedTracksLoaded,
    listenedTrackArtists: () => library.listenedTracks.map((t) => t.artists),
    albumsCompleted: () => library.completedAlbumsCount,
    knownArtists: () => [...library.followedArtists, ...library.favoriteArtists],
  );
});

/// What this Bearer's Echo did lately, per account (none for Observers).
final milestoneLogProvider = ChangeNotifierProvider<MilestoneLog>((ref) {
  final log = MilestoneLog();
  final auth = ref.read(authProvider);
  _follow(ref, auth, () => unawaited(log.setUser(auth.isAuthenticated ? auth.uid : null)));
  return log;
});

/// Bonds (Lazos): search, requests, Bonds, Resonances and Sintonía.
final socialProvider = ChangeNotifierProvider<SocialController>((ref) {
  final auth = ref.read(authProvider);
  final profile = ref.read(profileControllerProvider);
  final masks = ref.read(maskProvider);
  return SocialController(
    repository: getIt<SocialRepository>(),
    profiles: getIt<ProfileRepository>(),
    changes: auth,
    uid: () => auth.isAuthenticated ? auth.uid : null,
    myCard: () {
      final uid = auth.uid;
      if (!auth.isAuthenticated || uid == null) return null;
      final name = auth.user?.displayName?.trim();
      return SocialPerson(
        uid: uid,
        name: name == null || name.isEmpty ? 'Tsuki' : name,
        photoUrl: auth.user?.photoURL,
        maskId: masks.equipped?.id,
      );
    },
    myTops: () => profile.current?.tops ?? const [],
  );
});

/// Collaborative playlists (with Bonds).
final sharedPlaylistsProvider = ChangeNotifierProvider<SharedPlaylistsController>((ref) {
  final auth = ref.read(authProvider);
  return SharedPlaylistsController(
    repository: getIt<SharedPlaylistRepository>(),
    changes: auth,
    uid: () => auth.isAuthenticated ? auth.uid : null,
    myName: () {
      final n = auth.user?.displayName?.trim();
      return n == null || n.isEmpty ? 'Tsuki' : n;
    },
  );
});

/// Listening together with Bonds.
final partyProvider = ChangeNotifierProvider<PartyController>((ref) {
  final auth = ref.read(authProvider);
  return PartyController(
    repository: getIt<PartyRepository>(),
    changes: auth,
    uid: () => auth.isAuthenticated ? auth.uid : null,
    myName: () {
      final n = auth.user?.displayName?.trim();
      return n == null || n.isEmpty ? 'Tsuki' : n;
    },
    player: _AudioPartyPlayer(ref.read(audioProvider)),
  );
});

/// The party's view of the app's player.
class _AudioPartyPlayer implements PartyPlayer {
  _AudioPartyPlayer(this._audio);
  final AudioProvider _audio;

  @override
  Track? get current => _audio.currentTrack;
  @override
  bool get playing => _audio.isPlaying;
  @override
  Duration get position => _audio.position;
  @override
  Future<void> play(Track track) => _audio.playTrack(track, newQueue: [track]);
  @override
  Future<void> setPlaying(bool playing) async {
    if (_audio.isPlaying != playing) await _audio.togglePlay();
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);
  @override
  void addListener(VoidCallback listener) => _audio.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _audio.removeListener(listener);
}

/// Forwards the use cases' events to analytics, and turns a completed album
/// into a Resonance.
class _MilestoneEvents implements ProductEvents {
  const _MilestoneEvents(this._album);
  final void Function(String albumId) _album;

  @override
  void log(String name, [Map<String, Object> parameters = const {}]) {
    ProductAnalytics.instance.log(name, parameters);
    if (name == 'album_completed' && parameters['album_id'] is String) _album(parameters['album_id'] as String);
  }
}

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
