import 'dart:math';
import 'dart:ui' show Locale;

import '../../data/datasources/battery_guide.dart';
import '../../data/datasources/bpm_flow.dart';
import '../../data/datasources/weather_service.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/weekly_challenge.dart';
import '../../domain/logic/ambient_sound_generator.dart';
import '../../domain/logic/cadence_detector.dart';
import '../../domain/logic/moon_calculator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_language.dart';

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  static AppStrings of(AppLanguage language) => AppStrings(language);

  // Same texts for the same language, so a derived provider only notifies
  // when the language changes.
  @override
  bool operator ==(Object other) => other is AppStrings && other.language == language;

  @override
  int get hashCode => language.hashCode;

  // Every translated text lives in lib/l10n/app_<code>.arb (plurals and
  // per-value variants as ICU plural/select), compiled to lib/l10n/generated
  // by `flutter gen-l10n`. This class keeps the API the screens use and
  // turns enums and edge cases into the ARB arguments; only texts that are
  // the same in every language (FLOW, SYNC, x / y) are built here.
  static final Map<AppLanguage, AppLocalizations> _byLanguage = {};
  AppLocalizations get _l =>
      _byLanguage[language] ??= lookupAppLocalizations(Locale(language.code));

  // --- Bottom Navigation ---
  String get navHome => language.navHome;
  String get navSearch => language.navSearch;
  String get navLibrary => language.navLibrary;

  String navHudSubtitle(int index) => _l.navHudSubtitle(switch (index) {
        0 => 'home',
        1 => 'search',
        _ => 'library',
      });

  // --- Telemetría Militar Cyberpunk ---
  String get homeTelemetry => _l.homeTelemetry;

  String get searchTelemetry => _l.searchTelemetry;

  String get libraryTelemetry => _l.libraryTelemetry;

  // --- Home Screen ---
  String get homeHeader => _l.homeHeader;

  String get statsTracks => _l.statsTracks;

  String get statsArtists => _l.statsArtists;

  String get statsAlbums => _l.statsAlbums;

  String get statsTopArtist => _l.statsTopArtist;

  String get topArtistsTitle => _l.topArtistsTitle;

  String get latestReleasesTitle => _l.latestReleasesTitle;

  String get recommendedTitle => _l.recommendedTitle;

  // --- Search Screen ---
  String get searchTitle => _l.searchTitle;

  String get searchSubtitle => _l.searchSubtitle;

  String get recentSearches => _l.recentSearches;

  String get clearHistory => _l.clearHistory;

  String get searchHint => _l.searchHint;

  String get tabAll => _l.tabAll;

  String get tabArtists => _l.tabArtists;

  String get tabAlbums => _l.tabAlbums;

  String get tabTracks => _l.tabTracks;

  String get tabFavorites => _l.tabFavorites;

  String get emptyStateTitle => _l.emptyStateTitle;

  String get emptyStateSubtitle => _l.emptyStateSubtitle;

  String noResultsFor(String query) => _l.noResultsFor(query);

  String get noResults => _l.noResults;

  String get confirm => _l.confirm;

  // --- Library Screen ---
  String get libraryTitle => _l.libraryTitle;

  String get librarySubtitle => _l.librarySubtitle;

  String libraryStats(int tracks, int albums) => _l.libraryStats(tracks, albums);

  String showMore(int remaining) => _l.showMore(remaining);

  String get filterHint => _l.filterHint;

  String get sortRecent => _l.sortRecent;

  String get sortAz => _l.sortAz;

  String get sortArtist => _l.sortArtist;

  String get listenedTracksLabel => _l.listenedTracksLabel;

  String get albumsLabel => _l.albumsLabel;

  String get followedArtistsTitle => _l.followedArtistsTitle;

  String get emptyLibraryTitle => _l.emptyLibraryTitle;

  String get emptyLibrarySubtitle => _l.emptyLibrarySubtitle;

  // --- Expanded Player ---
  String get playingFrom => _l.playingFrom;

  String queueTitle(int count) => _l.queueTitle(count);

  // --- Profile & Settings Modal ---
  String get profileTitle => _l.profileTitle;

  String get settingsPlaybackSection => _l.settingsPlaybackSection;

  String get settingsStorageSection => _l.settingsStorageSection;

  String get settingsGeneralSection => _l.settingsGeneralSection;

  String get normalizeTitle => _l.normalizeTitle;

  String get normalizeSubtitle => _l.normalizeSubtitle;

  // --- Flow (queue by tempo) ---
  String get flowButton => 'FLOW';

  String get flowTitle => _l.flowTitle;

  String get flowSubtitle => _l.flowSubtitle;

  String flowAnalyzing(int done, int total) => _l.flowAnalyzing(done, total);

  String flowCoverage(int known, int total) => _l.flowCoverage(known, total);

  String get flowLowCoverage => _l.flowLowCoverage;

  String get flowNotEnough => _l.flowNotEnough;

  String get flowError => _l.flowError;

  String flowModeName(FlowMode mode) => _l.flowModeName(mode.name);

  String flowModeDescription(FlowMode mode) => _l.flowModeDescription(mode.name);

  String flowApplied(int from, int to) => _l.flowApplied(from, to);

  String flowAppliedWave(int from, int peak, int to) => _l.flowAppliedWave(from, peak, to);

  String get flowHalfTimeNote => _l.flowHalfTimeNote;

  // --- Running mode ---
  String get runTitle => _l.runTitle;

  String get runCardSubtitle => _l.runCardSubtitle;

  String runCardActive(int? spm) =>
      spm == null ? _l.runCardReading : _l.runCardSteps(spm);

  String get runIntro => _l.runIntro;

  String get runStart => _l.runStart;

  String get runStop => _l.runStop;

  String get runSpmUnit => _l.runSpmUnit;

  String runState(MotionState state) => _l.runState(state.name);

  String get runWaiting => _l.runWaiting;

  String get runSearching => _l.runSearching;

  String get runNoMatches => _l.runNoMatches;

  String runMusicAt(int bpm) => _l.runMusicAt(bpm);

  String get runLock => _l.runLock;

  String get runUnlock => _l.runUnlock;

  String get runLockedHint => _l.runLockedHint;

  String get runSyncTitle => _l.runSyncTitle;

  String get runSyncSubtitle => _l.runSyncSubtitle;

  String get runSyncSpotify => _l.runSyncSpotify;

  String runSongTempo(int bpm, double rate) {
    final pct = ((rate - 1) * 100).round();
    final adj = pct == 0 ? '' : ' · ${pct > 0 ? '+' : ''}$pct%';
    return '$bpm BPM$adj';
  }

  String get runUnknownTempo => _l.runUnknownTempo;

  String get runStatTime => _l.runStatTime;

  String get runStatSteps => _l.runStatSteps;

  String get runStatAverage => _l.runStatAverage;

  String get runStatSongs => _l.runStatSongs;

  String get runNoSensor => _l.runNoSensor;

  String get runBackgroundHint => _l.runBackgroundHint;

  String get runHalfTimeNote => _l.runHalfTimeNote;

  String get runSettingTitle => _l.runSettingTitle;

  String get runSettingSubtitle => _l.runSettingSubtitle;

  // --- Beat sync (Rinnegan) ---
  String get beatSyncHint => _l.beatSyncHint;

  String beatSyncTapping(int count) {
    final n = count.clamp(0, 4);
    final dots = '●' * n + '○' * max(0, 3 - n);
    return 'SYNC $dots';
  }

  String beatSyncLocked(int bpm) => 'SYNC · $bpm BPM';

  String beatSyncTempo(int bpm) => _l.beatSyncTempo(bpm);

  String beatSyncAuto(int bpm) => 'AUTO · $bpm BPM';

  String get beatSyncNoTempo => _l.beatSyncNoTempo;

  // --- Weather ---
  String dayPartName(DayPart part) => _l.dayPartName(part.name);

  /// "Tarde lluviosa", "Clear night", "雨の夜".
  String skyPhrase(DayPart part, Sky sky, {required bool isDay}) {
    final dark = part == DayPart.night || part == DayPart.lateNight;
    return _l.skyPhrase(
        part.name, sky == Sky.clear && isDay && !dark ? 'sunny' : sky.name);
  }

  String skyName(Sky sky) => _l.skyName(sky.name);

  String get weatherTitle => _l.weatherTitle;

  String get weatherSettingTitle => _l.weatherSettingTitle;

  String get weatherSettingSubtitle => _l.weatherSettingSubtitle;

  String get weatherEnable => _l.weatherEnable;

  String get weatherUseLocation => _l.weatherUseLocation;

  String get weatherOrCity => _l.weatherOrCity;

  String get weatherSearchHint => _l.weatherSearchHint;

  String get weatherPrivacy => _l.weatherPrivacy;

  String get weatherHere => _l.weatherHere;

  String weatherUpdated(int minutes) => _l.weatherUpdated(minutes < 1 ? 0 : minutes);

  String get weatherDenied => _l.weatherDenied;

  String get weatherDeniedForever => _l.weatherDeniedForever;

  String get weatherServiceOff => _l.weatherServiceOff;

  String get weatherLocationFailed => _l.weatherLocationFailed;

  String get weatherOpenSettings => _l.weatherOpenSettings;

  String get weatherOffline => _l.weatherOffline;

  String get weatherNoResults => _l.weatherNoResults;

  String get weatherTurnOff => _l.weatherTurnOff;

  String rainOfferTitle(String? place) =>
      place == null ? _l.rainOfferTitleHere : _l.rainOfferTitleIn(place);

  String get rainOfferQuestion => _l.rainOfferQuestion;

  String get rainOfferYes => _l.rainOfferYes;

  String get rainOfferNo => _l.rainOfferNo;

  String get rainOfferAddRain => _l.rainOfferAddRain;

  String get rainOfferPreparing => _l.rainOfferPreparing;

  String get rainOfferEmpty => _l.rainOfferEmpty;

  String rainOfferPlaying(int count) => _l.rainOfferPlaying(count);

  // --- Shake to skip ---
  String get shakeSkipTitle => _l.shakeSkipTitle;

  String get shakeSkipSubtitle => _l.shakeSkipSubtitle;

  // --- Oni masks ---
  String get masksTitle => _l.masksTitle;

  String masksCount(int unlocked, int total) => '$unlocked / $total';

  String get masksNoneYet => _l.masksNoneYet;

  String get masksEquippedHint => _l.masksEquippedHint;

  String get maskSecretName => _l.maskSecretName;

  String get maskSecretHint => _l.maskSecretHint;

  String get maskEquip => _l.maskEquip;

  String get maskHowToUnlock => _l.maskHowToUnlock;

  String get maskLocked => _l.maskLocked;

  String get maskEquipped => _l.maskEquipped;

  String get maskUnequip => _l.maskUnequip;

  String maskUnlockedOn(String date) => _l.maskUnlockedOn(date);

  String get maskUnlockedTitle => _l.maskUnlockedTitle;

  String maskRarity(MaskRarity r) => _l.maskRarity(r.name);

  String get masksProfileRow => _l.masksProfileRow;

  // --- Moon ---
  String moonPhaseName(MoonPhaseName name) => _l.moonPhaseName(name.name);

  String moonEventName(MoonPhaseKind kind) => moonPhaseName(switch (kind) {
        MoonPhaseKind.newMoon => MoonPhaseName.newMoon,
        MoonPhaseKind.firstQuarter => MoonPhaseName.firstQuarter,
        MoonPhaseKind.fullMoon => MoonPhaseName.fullMoon,
        MoonPhaseKind.lastQuarter => MoonPhaseName.lastQuarter,
      });

  String get moonTonightTitle => _l.moonTonightTitle;

  String moonIlluminated(int percent) => _l.moonIlluminated(percent);

  String moonAge(int day) => _l.moonAge(day);

  String get moonFullTonight => _l.moonFullTonight;

  /// Countdown phrase: [days] when ≥ 1, otherwise [hours].
  String moonUntilFull({int? days, int? hours}) => days != null
      ? _l.moonUntilFullDays(days)
      : _l.moonUntilFullHours(hours ?? 0);

  String get moonCycleTitle => _l.moonCycleTitle;

  String get moonToday => _l.moonToday;

  String get moonUpcomingTitle => _l.moonUpcomingTitle;

  String get moonMixTitle => _l.moonMixTitle;

  String moonMixUnlocked(int count) => _l.moonMixUnlocked(count);

  String moonMixLocked(String when) => _l.moonMixLocked(when);

  String moonMixProgress(int count) => _l.moonMixProgress(count);

  String get moonMixEmpty => _l.moonMixEmpty;

  String get moonMixPlay => _l.moonMixPlay;

  String get moonMixSave => _l.moonMixSave;

  String moonMixPlaylistName(String date) => _l.moonMixPlaylistName(date);

  String get moonMixSaved => _l.moonMixSaved;

  String get moonMixSaveFailed => _l.moonMixSaveFailed;

  String get moonEclipseNow => _l.moonEclipseNow;

  String moonEclipseKind(LunarEclipseKind kind) => _l.moonEclipseKind(kind.name);

  String moonNextEclipse(String date, LunarEclipseKind kind) =>
      _l.moonNextEclipse(date, kind.name);

  String get birthdayTitle => _l.birthdayTitle;

  String get birthdayNotSet => _l.birthdayNotSet;

  String get moonAtmosphereTitle => _l.moonAtmosphereTitle;

  String get moonAtmosphereSubtitle => _l.moonAtmosphereSubtitle;

  String get a11yMoon => _l.a11yMoon;

  String shortDate(DateTime d) => _l.shortDate(d.day, _monthKeys[d.month - 1]);

  static const _monthKeys = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  String longDate(DateTime d) => _l.longDate(shortDate(d), d.year);

  // --- Ambient mixer ---
  String get ambientTitle => _l.ambientTitle;

  String get ambientSubtitle => _l.ambientSubtitle;

  String ambientName(AmbientSound sound) => _l.ambientName(sound.name);

  String get ambientAfterTimerTitle => _l.ambientAfterTimerTitle;

  String ambientAfterTimerOption(int minutes) => minutes < 0
      ? _l.ambientAfterTimerKeep
      : _l.ambientAfterTimerMinutes(minutes);

  String ambientStopsIn(String time) => _l.ambientStopsIn(time);

  String get ambientStopAll => _l.ambientStopAll;

  String get ambientPause => _l.ambientPause;

  String get ambientResume => _l.ambientResume;

  String get ambientHint => _l.ambientHint;

  String get homeAmbientCardSubtitle => _l.homeAmbientCardSubtitle;

  String ambientPlayingCount(int count) => _l.ambientPlayingCount(count);

  // --- Guess the song ---
  String get guessTitle => _l.guessTitle;

  String get guessModeDaily => _l.guessModeDaily;

  String get guessModeLibrary => _l.guessModeLibrary;

  String get guessModeArtist => _l.guessModeArtist;

  String get guessPickArtist => _l.guessPickArtist;

  String get guessArtistSearchHint => _l.guessArtistSearchHint;

  String get guessYourArtists => _l.guessYourArtists;

  String get guessArtistChange => _l.guessArtistChange;

  String get guessArtistTooFew => _l.guessArtistTooFew;

  String get guessModeChart => _l.guessModeChart;

  String get guessHowTo => _l.guessHowTo;

  String get guessSearchHint => _l.guessSearchHint;

  String guessSkip(int seconds) => _l.guessSkip(seconds);

  String get guessGiveUp => _l.guessGiveUp;

  String get guessTapToPlay => _l.guessTapToPlay;

  String get guessAttemptSkipped => _l.guessAttemptSkipped;

  String get guessRightArtist => _l.guessRightArtist;

  String get guessRightArtistHint => _l.guessRightArtistHint;

  String guessWonIn(int attempts) => _l.guessWonIn(attempts);

  String get guessLost => _l.guessLost;

  String get guessListenFull => _l.guessListenFull;

  String get guessShare => _l.guessShare;

  String get guessCopied => _l.guessCopied;

  String get guessNext => _l.guessNext;

  String guessNextDailyIn(String time) => _l.guessNextDailyIn(time);

  String get guessStatsTitle => _l.guessStatsTitle;

  String get guessStatsPlayed => _l.guessStatsPlayed;

  String get guessStatsWinRate => _l.guessStatsWinRate;

  String get guessStatsStreak => _l.guessStatsStreak;

  String get guessStatsMaxStreak => _l.guessStatsMaxStreak;

  String get guessStatsDistribution => _l.guessStatsDistribution;

  String guessSessionStreak(int n, int best) => _l.guessSessionStreak(n, best);

  String get guessLibraryTooSmall => _l.guessLibraryTooSmall;

  String get guessLoadError => _l.guessLoadError;

  String get guessNoResults => _l.guessNoResults;

  String guessShareHeader(int day) => _l.guessShareHeader(day);

  String get guessDailyDone => _l.guessDailyDone;

  String get crossfadeTitle => _l.crossfadeTitle;

  String get crossfadeSubtitle => _l.crossfadeSubtitle;
  String get crossfadeSpotifySubtitle => _l.crossfadeSpotifySubtitle;

  String get autoMarkTitle => _l.autoMarkTitle;

  String get autoMarkSubtitle => _l.autoMarkSubtitle;

  String get precacheWifiTitle => _l.precacheWifiTitle;

  String get precacheWifiSubtitle => _l.precacheWifiSubtitle;

  String get clearAudioCache => _l.clearAudioCache;

  String get audioCacheCleared => _l.audioCacheCleared;
  String get playbackLogCopy => _l.playbackLogCopy;
  String get playbackLogCopied => _l.playbackLogCopied;
  String get appVersionCopied => _l.appVersionCopied;
  String get analyticsSettingTitle => _l.analyticsSettingTitle;
  String get analyticsSettingSubtitle => _l.analyticsSettingSubtitle;

  String crossfadeSecondsLabel(int seconds) => _l.crossfadeSecondsLabel(seconds);

  String get languageOption => _l.languageOption;

  String get languageSelectorTitle => _l.languageSelectorTitle;

  String get languageSelectorSubtitle => _l.languageSelectorSubtitle;

  String languageCardSubtitle(AppLanguage targetLang) =>
      _l.languageCardSubtitle(targetLang.name);

  String get languageInfoNotice => _l.languageInfoNotice;

  String get activeStatus => _l.activeStatus;

  String get tutorialOption => _l.tutorialOption;

  String get logoutOption => _l.logoutOption;

  String get spotifyConnect => _l.spotifyConnect;

  String get spotifyDisconnect => _l.spotifyDisconnect;

  String get spotifyConnected => _l.spotifyConnected;

  String get spotifyNotConnected => _l.spotifyNotConnected;

  String get spotifyConnecting => _l.spotifyConnecting;

  String get spotifyDefaultUser => _l.spotifyDefaultUser;

  String get spotifyCanceledByUser => _l.spotifyCanceledByUser;

  // --- Stats Card Tags & Home Details ---
  String get statsListened => _l.statsListened;

  String get statsInSystem => _l.statsInSystem;

  String statsAffinity(dynamic score) => _l.statsAffinity(score);

  String get emptyReleases => _l.emptyReleases;

  String affinityScore(dynamic score) => _l.affinityScore(score);

  String get affinityInfoTitle => _l.affinityInfoTitle;

  String get affinityInfoIntro => _l.affinityInfoIntro;

  String get affinitySavedTitle => _l.affinitySavedTitle;

  String get affinitySavedBody => _l.affinitySavedBody;

  String get affinityVisitsTitle => _l.affinityVisitsTitle;

  String get affinityVisitsBody => _l.affinityVisitsBody;

  String affinityPoints(int points) => _l.affinityPoints(points);

  String get affinityFormulaLabel => _l.affinityFormulaLabel;

  String get affinityFormula => _l.affinityFormula;

  String get affinityInfoOutro => _l.affinityInfoOutro;

  String get affinityInfoClose => _l.affinityInfoClose;

  String get featured => _l.featured;

  // --- Spotify Status & Dialogs ---
  String spotifyActiveDevice(String device) => _l.spotifyActiveDevice(device);

  String get spotifyPremiumActive => _l.spotifyPremiumActive;

  String get spotifyStandardPreview => _l.spotifyStandardPreview;

  String get spotifySyncSuccess => _l.spotifySyncSuccess;

  String get spotifyConnectError => _l.spotifyConnectError;

  String get logoutConfirmTitle => _l.logoutConfirmTitle;

  String get logoutConfirmMessage => _l.logoutConfirmMessage;

  String get cancel => _l.cancel;

  String get logout => _l.logout;

  // --- Album Detail Screen ---
  String get albumDetailsTitle => _l.albumDetailsTitle;

  String get allListened => _l.allListened;

  String get markAll => _l.markAll;

  String get play => _l.play;

  String get playAll => _l.playAll;

  String get shuffle => _l.shuffle;

  String get addToQueue => _l.addToQueue;

  String get addedToQueue => _l.addedToQueue;

  String get syncing => _l.syncing;

  String get noTracksAvailable => _l.noTracksAvailable;

  String albumMeta(String year, int count, String duration) =>
      _l.albumMeta(year, count, duration);

  String albumTypeLabel(String? type) => _l.albumTypeLabel(type ?? 'album');

  // --- Artist Detail Screen ---
  String artistFans(String count) => _l.artistFans(count);

  String artistDiscographyProgress(int completed, int total) =>
      _l.artistDiscographyProgress(completed, total);

  String artistReleases(int count) => _l.artistReleases(count);

  String albumCountLabel(int count) => _l.albumCountLabel(count);

  String epCountLabel(int count) => _l.epCountLabel(count);

  String singleCountLabel(int count) => _l.singleCountLabel(count);

  String appearsOnCountLabel(int count) => _l.appearsOnCountLabel(count);

  String get popularTracks => _l.popularTracks;

  String get showMoreTracks => _l.showMoreTracks;

  String get showLessTracks => _l.showLessTracks;

  String get discography => _l.discography;

  String get seeMore => _l.seeMore;

  String get tabSingles => _l.tabSingles;

  String get tabEps => _l.tabEps;

  String get tabAppearsOn => _l.tabAppearsOn;

  String get storedContentTitle => _l.storedContentTitle;

  String storedContentSongs(int count) => _l.storedContentSongs(count);

  String storedContentFrom(String artist) => _l.storedContentFrom(artist);

  String get noTracksFound => _l.noTracksFound;

  String get loadingMoreAlbums => _l.loadingMoreAlbums;

  String get retryLoading => _l.retryLoading;

  String get allAlbumsLoaded => _l.allAlbumsLoaded;

  String get lyrics => _l.lyrics;

  String get lyricsLoading => _l.lyricsLoading;

  String get noLyricsFound => _l.noLyricsFound;

  String get instrumentalTrack => _l.instrumentalTrack;

  String get syncedTapToSeek => _l.syncedTapToSeek;

  // --- Telemetry & Spotify Errors in Nav ---
  String get spotifyTokenExpired => _l.spotifyTokenExpired;

  String get spotifyPremiumRequired => _l.spotifyPremiumRequired;

  String get spotifyNoActiveDevice => _l.spotifyNoActiveDevice;

  String get spotifyNoConnection => _l.spotifyNoConnection;

  String get spotifyTrackUnavailablePreview => _l.spotifyTrackUnavailablePreview;

  String get spotifyOpenAppPrompt => _l.spotifyOpenAppPrompt;
  String get spotifyDisabledPreview => _l.spotifyDisabledPreview;

  String get audioStatusPrefix => _l.audioStatusPrefix;

  String get openSpotifyTooltip => _l.openSpotifyTooltip;

  String get errorPrefix => _l.errorPrefix;

  // --- Artist Card & Discography ---
  String artistFansCompact(String count) => _l.artistFansCompact(count);

  // --- Album Progress & Library Items ---
  String albumProgressListened(int listened, int total) => _l.albumProgressListened(listened, total);

  String get unknownAlbum => _l.unknownAlbum;

  String trackCountLabel(int count) => _l.trackCountLabel(count);

  String get viewAlbum => _l.viewAlbum;

  // --- Queue View (Expanded Player) ---
  String get queueUpNext => _l.queueUpNext;

  String get queueClear => _l.queueClear;

  String get queueClearLabel => _l.queueClearLabel;

  String get queueEmpty => _l.queueEmpty;

  String get queueEmptySubtitle => _l.queueEmptySubtitle;

  String get queuedByYou => _l.queuedByYou;

  String get queueRemoveLabel => _l.queueRemoveLabel;

  String get removedFromQueue => _l.removedFromQueue;

  String get lyricsFollowing => _l.lyricsFollowing;

  String get lyricsRetry => _l.lyricsRetry;

  String get lyricsCardTitle => _l.lyricsCardTitle;

  String get lyricsShare => _l.lyricsShare;

  String get lyricsTranslate => _l.lyricsTranslate;

  String get lyricsOriginal => _l.lyricsOriginal;

  // --- Track Context Menu ---
  String get goToArtist => _l.goToArtist;

  String get goToAlbum => _l.goToAlbum;

  String get playNext => _l.playNext;

  String get addedPlayNext => _l.addedPlayNext;
  String get shuffleOffToast => _l.shuffleOffToast;
  String get shuffleOnToast => _l.shuffleOnToast;
  String get shuffleSmartToast => _l.shuffleSmartToast;
  String get smartShuffleTitle => _l.smartShuffleTitle;
  String get smartShuffleSubtitle => _l.smartShuffleSubtitle;
  String get shuffleAvoidArtistTitle => _l.shuffleAvoidArtistTitle;
  String get shuffleAvoidArtistSubtitle => _l.shuffleAvoidArtistSubtitle;
  String get shuffleEnergyTitle => _l.shuffleEnergyTitle;
  String get shuffleEnergyFree => _l.shuffleEnergyFree;
  String get shuffleEnergyFreeHint => _l.shuffleEnergyFreeHint;
  String get shuffleEnergyAlternate => _l.shuffleEnergyAlternate;
  String get shuffleEnergyAlternateHint => _l.shuffleEnergyAlternateHint;
  String get shuffleEnergySmooth => _l.shuffleEnergySmooth;
  String get shuffleEnergySmoothHint => _l.shuffleEnergySmoothHint;
  String get shuffleRecoTitle => _l.shuffleRecoTitle;
  String get shuffleRecoSubtitle => _l.shuffleRecoSubtitle;
  String get shuffleRecoSwitch => _l.shuffleRecoSwitch;
  String get shuffleRecoFew => _l.shuffleRecoFew;
  String get shuffleRecoNormal => _l.shuffleRecoNormal;
  String get shuffleRecoMany => _l.shuffleRecoMany;
  String get recommendedTag => _l.recommendedTag;
  String get queueSmartShuffleTag => _l.queueSmartShuffleTag;
  String get shuffleHoldHint => _l.shuffleHoldHint;
  String get a11yShuffleSmart => _l.a11yShuffleSmart;
  String shuffleRecoEvery(int count) => _l.shuffleRecoEvery(count);
  String get autoplaySimilarTitle => _l.autoplaySimilarTitle;
  String get autoplaySimilarSubtitle => _l.autoplaySimilarSubtitle;
  String get playlistEdit => _l.playlistEdit;
  String get playlistEditDone => _l.playlistEditDone;
  String get playlistEditHint => _l.playlistEditHint;
  String get playlistRemoveFromThis => _l.playlistRemoveFromThis;
  String get queueNowPlaying => _l.queueNowPlaying;
  String get queueComingUp => _l.queueComingUp;
  String get queueShuffledTag => _l.queueShuffledTag;
  String get queueGesturesHint => _l.queueGesturesHint;
  String get queueSaveAsPlaylist => _l.queueSaveAsPlaylist;
  String get queueNothingNext => _l.queueNothingNext;
  String get queueRemovedSongs => _l.queueRemovedSongs;
  String get a11yMoveUp => _l.a11yMoveUp;
  String get a11yMoveDown => _l.a11yMoveDown;
  String queuePlayedHeader(int count) => _l.queuePlayedHeader(count);
  String queueMoreShuffled(int count) => _l.queueMoreShuffled(count);
  String queueSummary(int count, int minutes) => _l.queueSummary(count, minutes);

  // --- Mini Player ---
  String get stoppedPlayback => _l.stoppedPlayback;

  String get undo => _l.undo;

  // Gesture hints
  String get swipeToRemoveHint => _l.swipeToRemoveHint;


  // Listened toggle tooltip
  String get markAsListened => _l.markAsListened;

  String get unmarkAsListened => _l.unmarkAsListened;

  // --- Expanded Player ---
  String get noTrackSelected => _l.noTrackSelected;

  // --- Onboarding & Guide Tutorial ---
  String get onboardingHeaderPrefix => 'TSUKI TUNES // ';

  String get onboardingHeaderGlitch => _l.onboardingHeaderGlitch;

  String get onboardingHeader => '$onboardingHeaderPrefix$onboardingHeaderGlitch';

  String get onboardingSkip => _l.onboardingSkip;

  String get onboardingNext => _l.onboardingNext;

  String get onboardingStart => _l.onboardingStart;

  String get onboardingSlide1Badge => _l.onboardingSlide1Badge;

  String get onboardingSlide1Title => _l.onboardingSlide1Title;

  String get onboardingSlide1Desc => _l.onboardingSlide1Desc;

  String get onboardingPillFavorites => _l.onboardingPillFavorites;

  String get onboardingPillStorage => _l.onboardingPillStorage;

  String get onboardingPillAlbums => _l.onboardingPillAlbums;

  String get onboardingOniMaskHint => _l.onboardingOniMaskHint;

  String get onboardingOniMaskNotListened => _l.onboardingOniMaskNotListened;

  String get onboardingOniMaskListened => _l.onboardingOniMaskListened;

  String get onboardingAlbumProgressHint => _l.onboardingAlbumProgressHint;

  String get onboardingAlbumProgress0 => _l.onboardingAlbumProgress0;

  String get onboardingAlbumProgress100 => _l.onboardingAlbumProgress100;

  String get onboardingSlide2Badge => _l.onboardingSlide2Badge;

  String get onboardingSlide2Title => _l.onboardingSlide2Title;

  String get onboardingSlide2Desc => _l.onboardingSlide2Desc;

  String get onboardingPillSearch => _l.onboardingPillSearch;

  String get onboardingPillTracks => _l.onboardingPillTracks;

  String get onboardingPillPreview => _l.onboardingPillPreview;

  String get onboardingSlide3Badge => _l.onboardingSlide3Badge;

  String get onboardingSlide3Title => _l.onboardingSlide3Title;

  String get onboardingSlide3Desc => _l.onboardingSlide3Desc;

  String get onboardingPillEqualizer => _l.onboardingPillEqualizer;

  String get onboardingPillFullscreen => _l.onboardingPillFullscreen;

  String get onboardingPillCyberHUD => _l.onboardingPillCyberHUD;

  // --- Login Screen ---
  String get loginGuestExplore => _l.loginGuestExplore;

  String get guestLibraryTitle => _l.guestLibraryTitle;

  String get guestLibraryDesc => _l.guestLibraryDesc;

  String get guestLoginAction => _l.guestLoginAction;

  String get loginSubtitlePrefix => _l.loginSubtitlePrefix;

  String get loginSubtitleGlitch => _l.loginSubtitleGlitch;

  String get loginGoogle => _l.loginGoogle;

  String get loginLoading => _l.loginLoading;

  String get loginGranted => _l.loginGranted;

  String get loginGoogleError => _l.loginGoogleError;

  String get loginThrottled => _l.loginThrottled;

  // --- Loading / Startup Screen ---
  String get loadingStatus => _l.loadingStatus;

  String get loadingSubtitle => _l.loadingSubtitle;

  // --- Error / Connectivity ---
  String get searchError => _l.searchError;

  String get loadError => _l.loadError;

  String get retry => _l.retry;

  // --- Public profile ---
  String get profileViewMine => _l.profileViewMine;
  String get profileSongs => _l.profileSongs;
  String get profileAlbums => _l.profileAlbums;
  String get profileArtists => _l.profileArtists;
  String get profileTopArtists => _l.profileTopArtists;
  String profileArtistSongs(int count) => _l.profileArtistSongs(count);
  String get profilePublic => _l.profilePublic;
  String get profilePublicHint => _l.profilePublicHint;
  String get profilePrivateHint => _l.profilePrivateHint;
  String get profileShare => _l.profileShare;
  String profileShareText(String link) => _l.profileShareText(link);
  String get profileUnavailable => _l.profileUnavailable;
  String get profileMakePublicFirst => _l.profileMakePublicFirst;


  /// A link (or a page opened by id) whose album or artist doesn't exist.
  String get linkNotFound => _l.linkNotFound;

  String get offline => _l.offline;

  String get playbackError => _l.playbackError;

  String get playbackNoPreview => _l.playbackNoPreview;

  String get playbackNetworkError => _l.playbackNetworkError;

  String get playbackFormatUnsupported => _l.playbackFormatUnsupported;

  // --- Home Screen Error & Empty States ---
  String get homeLoadError => _l.homeLoadError;

  String get homeLoadErrorSubtitle => _l.homeLoadErrorSubtitle;

  String get homeEmptyTitle => _l.homeEmptyTitle;

  String get homeEmptySubtitle => _l.homeEmptySubtitle;

  String get homeEmptyAction => _l.homeEmptyAction;

  String get offlineNotice => _l.offlineNotice;

  String get offlineNoCache => _l.offlineNoCache;

  String get repeatOff => _l.repeatOff;

  String get repeatAll => _l.repeatAll;

  String get repeatOne => _l.repeatOne;

  // --- Sleep Timer ---
  String get sleepTimer => _l.sleepTimer;

  String get sleepTimerOff => _l.sleepTimerOff;

  String get sleepTimerEndOfTrack => _l.sleepTimerEndOfTrack;

  String sleepTimerMinutes(int minutes) => _l.sleepTimerMinutes(minutes);

  String sleepTimerRemainingLabel(String time) => _l.sleepTimerRemainingLabel(time);

  String get sleepTimerEndOfTrackShort => _l.sleepTimerEndOfTrackShort;

  // --- Accessibility Semantic Labels ---
  String get a11yPlay => _l.a11yPlay;

  String get a11yPause => _l.a11yPause;

  String get a11yStop => _l.a11yStop;

  String get a11yPrevious => _l.a11yPrevious;

  String get a11yNext => _l.a11yNext;

  String get a11yShuffleOn => _l.a11yShuffleOn;

  String get a11yShuffleOff => _l.a11yShuffleOff;

  String get a11yMarkListened => _l.a11yMarkListened;

  String get a11yUnmarkListened => _l.a11yUnmarkListened;

  String get a11yShowStats => _l.a11yShowStats;

  String get a11yHideStats => _l.a11yHideStats;

  String get a11yShowAllTracks => _l.a11yShowAllTracks;

  String get a11yShowLessTracks => _l.a11yShowLessTracks;

  String get a11yViewDiscography => _l.a11yViewDiscography;

  String get a11yExpandStoredContent => _l.a11yExpandStoredContent;

  String get a11yCollapseStoredContent => _l.a11yCollapseStoredContent;

  String get a11yLoginWithGoogle => _l.a11yLoginWithGoogle;

  String get a11yContinueAsGuest => _l.a11yContinueAsGuest;

  String get a11ySelectLanguage => _l.a11ySelectLanguage;

  String get a11yRetryLyrics => _l.a11yRetryLyrics;

  String get a11yGoToSearch => _l.a11yGoToSearch;

  String get a11yCollapsePlayer => _l.a11yCollapsePlayer;

  String get a11yOpenInSpotify => _l.a11yOpenInSpotify;

  String get a11yPlaybackError => _l.a11yPlaybackError;

  String get syncError => _l.syncError;

  String get a11ySyncError => _l.a11ySyncError;

  String get a11ySleepTimer => _l.a11ySleepTimer;

  String get a11yQueue => _l.a11yQueue;

  String get a11yClearQueue => _l.a11yClearQueue;

  String get a11yRemoveFromQueue => _l.a11yRemoveFromQueue;

  String get a11yNowPlaying => _l.a11yNowPlaying;

  String get a11yAlbumCover => _l.a11yAlbumCover;

  String get a11yReorder => _l.a11yReorder;

  String get a11yLyrics => _l.a11yLyrics;

  String get a11yNoLyrics => _l.a11yNoLyrics;

  String get a11yVisualizer => _l.a11yVisualizer;

  String get a11ySyncingLyrics => _l.a11ySyncingLyrics;

  String get a11yPlayTrack => _l.a11yPlayTrack;

  String get a11yArtistAvatar => _l.a11yArtistAvatar;

  String get a11ySeeAll => _l.a11ySeeAll;

  String get a11yFilter => _l.a11yFilter;

  String get a11yClearFilter => _l.a11yClearFilter;

  String get a11yPlayAll => _l.a11yPlayAll;

  String get a11yShuffleAll => _l.a11yShuffleAll;

  String get a11yOffline => _l.a11yOffline;

  String get a11yEmptyLibrary => _l.a11yEmptyLibrary;

  String get a11yCreatePlaylist => _l.a11yCreatePlaylist;

  String get a11yRemoveFromPlaylist => _l.a11yRemoveFromPlaylist;

  String get a11yPlaylistCover => _l.a11yPlaylistCover;

  String get a11yOpenPlaylist => _l.a11yOpenPlaylist;

  String get a11yClearSearch => _l.a11yClearSearch;

  String get a11ySearchEmpty => _l.a11ySearchEmpty;

  String get a11yClearHistory => _l.a11yClearHistory;

  String get a11ySearchHistory => _l.a11ySearchHistory;

  String get a11yFillSearch => _l.a11yFillSearch;

  String get a11yBack => _l.a11yBack;

  String get a11yMoreOptions => _l.a11yMoreOptions;

  String get a11yEditPlaylist => _l.a11yEditPlaylist;

  String get a11yDeletePlaylist => _l.a11yDeletePlaylist;

  String get a11yEmptyPlaylist => _l.a11yEmptyPlaylist;

  String get a11yRetry => _l.a11yRetry;

  String get a11yLoginError => _l.a11yLoginError;

  String get a11ySelected => _l.a11ySelected;

  String get a11yDeselect => _l.a11yDeselect;

  String get a11yUpdateInfo => _l.a11yUpdateInfo;

  String get a11yLoginRequired => _l.a11yLoginRequired;

  String get a11yRelatedArtists => _l.a11yRelatedArtists;

  String get a11yStoredContent => _l.a11yStoredContent;

  String get a11yPlayNext => _l.a11yPlayNext;

  String get a11yAddToQueue => _l.a11yAddToQueue;

  String get a11yAddToPlaylist => _l.a11yAddToPlaylist;

  String get a11yGoToArtist => _l.a11yGoToArtist;

  String get a11yGoToAlbum => _l.a11yGoToAlbum;

  String get a11yOpenExternal => _l.a11yOpenExternal;

  String get a11yCloudStatus => _l.a11yCloudStatus;

  String get a11yClearCache => _l.a11yClearCache;

  String get a11yAbout => _l.a11yAbout;

  String get a11yDebugInfo => _l.a11yDebugInfo;

  String get a11yLogout => _l.a11yLogout;

  String get a11yDeleteAccount => _l.a11yDeleteAccount;

  String get a11yClose => _l.a11yClose;

  String get a11yRepeatOff => _l.a11yRepeatOff;

  String get a11yRepeatAll => _l.a11yRepeatAll;

  String get a11yRepeatOne => _l.a11yRepeatOne;

  String get a11yEmptyQueue => _l.a11yEmptyQueue;

  String get a11yFollowArtist => _l.a11yFollowArtist;

  String get a11yUnfollowArtist => _l.a11yUnfollowArtist;

  String get a11yMusicNote => _l.a11yMusicNote;

  // --- Playlists ---
  String get playlistsTab => _l.playlistsTab;

  String get albumsTab => _l.albumsTab;

  String get createPlaylist => _l.createPlaylist;

  String get newPlaylist => _l.newPlaylist;

  String get playlistName => _l.playlistName;

  String get playlistNameHint => _l.playlistNameHint;

  String get create => _l.create;

  String get renamePlaylist => _l.renamePlaylist;

  String get rename => _l.rename;

  String get deletePlaylist => _l.deletePlaylist;

  String deletePlaylistConfirm(String name) => _l.deletePlaylistConfirm(name);

  String get delete => _l.delete;

  String get addToPlaylist => _l.addToPlaylist;

  String addedToPlaylist(String name) => _l.addedToPlaylist(name);

  String get trackAlreadyInPlaylist => _l.trackAlreadyInPlaylist;
  String get playlistFull => _l.playlistFull;

  // --- Android Auto ---
  String get autoRecent => _l.autoRecent;
  String get autoFavorites => _l.autoFavorites;
  String get autoPlaylists => _l.autoPlaylists;
  String get autoTopChart => _l.autoTopChart;

  String get removedFromPlaylist => _l.removedFromPlaylist;

  String get emptyPlaylistTitle => _l.emptyPlaylistTitle;

  String get emptyPlaylistSubtitle => _l.emptyPlaylistSubtitle;

  String get noPlaylistsTitle => _l.noPlaylistsTitle;

  String get noPlaylistsSubtitle => _l.noPlaylistsSubtitle;

  String playlistMeta(int count, String duration) => _l.playlistMeta(count, duration);

  String get playlistRenamed => _l.playlistRenamed;

  String get playlistDeleted => _l.playlistDeleted;

  String get playlistCreated => _l.playlistCreated;

  String get selectPlaylist => _l.selectPlaylist;

  // --- Lyrics Translation ---
  String get translateButton => _l.translateButton;

  String get translateTooltip => _l.translateTooltip;

  String get translationHide => _l.translationHide;

  String get translating => _l.translating;

  String get translationError => _l.translationError;

  String get downloadingModel => _l.downloadingModel;

  String get downloadModelTitle => _l.downloadModelTitle;

  String downloadModelDesc(String size) => _l.downloadModelDesc(size);

  String get downloadModelConfirm => _l.downloadModelConfirm;

  String get translatedTag => _l.translatedTag;

  String get a11yTranslate => _l.a11yTranslate;

  String get a11yHideTranslation => _l.a11yHideTranslation;

  // --- Lyrics Search ---
  String get tabByLyrics => _l.tabByLyrics;

  String get lyricsSearchHint => _l.lyricsSearchHint;

  String get lyricsSearchEmpty => _l.lyricsSearchEmpty;

  String get lyricsSearchEmptySubtitle => _l.lyricsSearchEmptySubtitle;

  String lyricsSearchResults(int count) => _l.lyricsSearchResults(count);

  String get lyricsSearchError => _l.lyricsSearchError;

  String get lyricsSearchNoResults => _l.lyricsSearchNoResults;

  String get a11yLyricsSearch => _l.a11yLyricsSearch;

  // --- Tsuki Wrapped ---
  String get wrappedTitle => _l.wrappedTitle;

  String wrappedYear(int year) => _l.wrappedYear(year);

  String get wrappedIntroSlide => _l.wrappedIntroSlide;

  String get wrappedTopTracks => _l.wrappedTopTracks;

  String get wrappedTopArtists => _l.wrappedTopArtists;

  String get wrappedListeningTime => _l.wrappedListeningTime;

  String wrappedMinutes(int minutes) => _l.wrappedMinutes(minutes);

  String wrappedHours(int hours) => _l.wrappedHours(hours);

  String wrappedTotalTracks(int count) => _l.wrappedTotalTracks(count);

  String wrappedUniqueCount(int tracks, int artists) => _l.wrappedUniqueCount(tracks, artists);

  String get wrappedFavoriteHour => _l.wrappedFavoriteHour;

  String wrappedHourLabel(int hour) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return switch (language) {
      AppLanguage.es => '$h12:00 $amPm',
      AppLanguage.en => '$h12:00 $amPm',
      AppLanguage.ja => '$hour:00',
    };
  }

  String get wrappedFunFacts => _l.wrappedFunFacts;

  String wrappedFactLateNight(String title, String artist) => _l.wrappedFactLateNight(title, artist);

  String wrappedFactMarathon(String date, int count) => _l.wrappedFactMarathon(date, count);

  String wrappedFactLoyal(String artist, int count) => _l.wrappedFactLoyal(artist, count);

  String wrappedFactDawn(int count) => _l.wrappedFactDawn(count);

  String wrappedFactOneHit(String title, String artist, int count) =>
      _l.wrappedFactOneHit(title, artist, count);

  String wrappedFactNightOwl(int pct) => _l.wrappedFactNightOwl(pct);

  String wrappedFactEarlyBird(int pct) => _l.wrappedFactEarlyBird(pct);

  String wrappedFactWeekend(int weekendAvg, int weekdayAvg) =>
      _l.wrappedFactWeekend(weekendAvg, weekdayAvg);

  String wrappedPlays(int count) => _l.wrappedPlays(count);

  String get wrappedOutro => _l.wrappedOutro;

  String get wrappedOutroSubtitle => _l.wrappedOutroSubtitle;

  String get wrappedShare => _l.wrappedShare;

  String get wrappedNoData => _l.wrappedNoData;

  String get wrappedNoDataSubtitle => _l.wrappedNoDataSubtitle;

  String get wrappedViewYourWrapped => _l.wrappedViewYourWrapped;

  String get a11yWrapped => _l.a11yWrapped;

  // --- Weekly challenges ---
  String weeklyChallengeText(ChallengeKind kind, int n) => switch (language) {
        AppLanguage.es => switch (kind) {
            ChallengeKind.newArtists => 'Escucha $n artistas nuevos',
            ChallengeKind.minutes => 'Escucha $n minutos de música',
            ChallengeKind.plays => 'Escucha $n canciones',
            ChallengeKind.days => 'Escucha música $n días distintos',
            ChallengeKind.night => 'Escucha $n canciones después de medianoche',
            ChallengeKind.morning => 'Escucha $n canciones antes de las 9 AM',
            ChallengeKind.rain => 'Escucha $n minutos con lluvia de fondo',
            ChallengeKind.album => n == 1 ? 'Escucha un álbum en orden (5+ canciones seguidas)' : 'Escucha $n álbumes en orden',
            ChallengeKind.guess => 'Gana $n desafíos de Adivina la canción',
            ChallengeKind.oneArtist => 'Escucha $n canciones de un mismo artista',
          },
        AppLanguage.en => switch (kind) {
            ChallengeKind.newArtists => 'Listen to $n new artists',
            ChallengeKind.minutes => 'Listen to $n minutes of music',
            ChallengeKind.plays => 'Listen to $n songs',
            ChallengeKind.days => 'Listen to music on $n different days',
            ChallengeKind.night => 'Listen to $n songs after midnight',
            ChallengeKind.morning => 'Listen to $n songs before 9 AM',
            ChallengeKind.rain => 'Listen for $n minutes with rain ambience',
            ChallengeKind.album => n == 1 ? 'Play an album in order (5+ songs in a row)' : 'Play $n albums in order',
            ChallengeKind.guess => 'Win $n Guess the song challenges',
            ChallengeKind.oneArtist => 'Listen to $n songs by one artist',
          },
        AppLanguage.ja => switch (kind) {
            ChallengeKind.newArtists => '新しいアーティストを$n人聴く',
            ChallengeKind.minutes => '音楽を$n分聴く',
            ChallengeKind.plays => '$n曲聴く',
            ChallengeKind.days => '$n日間音楽を聴く',
            ChallengeKind.night => '深夜0時以降に$n曲聴く',
            ChallengeKind.morning => '朝9時前に$n曲聴く',
            ChallengeKind.rain => '雨の音と一緒に$n分聴く',
            ChallengeKind.album => 'アルバムを順番に聴く（5曲以上連続）',
            ChallengeKind.guess => '曲当てチャレンジに$n回勝つ',
            ChallengeKind.oneArtist => '同じアーティストの曲を$n曲聴く',
          },
      };

  String get weeklyTitle => switch (language) {
        AppLanguage.es => 'DESAFÍOS DE LA SEMANA',
        AppLanguage.en => "THIS WEEK'S CHALLENGES",
        AppLanguage.ja => '今週のチャレンジ',
      };

  String weeklyTimeLeft(Duration left) {
    final days = left.inDays;
    final hours = left.inHours;
    return switch (language) {
      AppLanguage.es => days >= 1
          ? 'Quedan $days ${days == 1 ? 'día' : 'días'}'
          : 'Quedan $hours h',
      AppLanguage.en => days >= 1
          ? '$days ${days == 1 ? 'day' : 'days'} left'
          : '$hours h left',
      AppLanguage.ja => days >= 1 ? '残り$days日' : '残り$hours時間',
    };
  }

  String weeklyRewardHint(String mask) => switch (language) {
        AppLanguage.es => 'Completa los 3 y gana «$mask», una máscara que solo se consigue con los desafíos semanales.',
        AppLanguage.en => 'Complete all 3 to win “$mask”, a mask you can only get from weekly challenges.',
        AppLanguage.ja => '3つすべて達成で「$mask」を獲得。週間チャレンジ限定の面。',
      };

  String weeklyRewardWon(String mask) => switch (language) {
        AppLanguage.es => '¡Ganaste «$mask» esta semana! El lunes llegan desafíos nuevos.',
        AppLanguage.en => 'You won “$mask” this week! New challenges arrive on Monday.',
        AppLanguage.ja => '今週は「$mask」を獲得！月曜日に新しいチャレンジ。',
      };

  String get weeklyAllCollected => switch (language) {
        AppLanguage.es => 'Ya tienes todas las máscaras semanales. ¡Sigue jugando por diversión!',
        AppLanguage.en => 'You have every weekly mask. Keep playing for fun!',
        AppLanguage.ja => '週間の面をすべて集めた！',
      };

  String weeklyDoneCount(int done) => switch (language) {
        AppLanguage.es => '$done de 3 completados',
        AppLanguage.en => '$done of 3 done',
        AppLanguage.ja => '3つ中$doneつ達成',
      };

  String get weeklyMaskTag => switch (language) {
        AppLanguage.es => 'SEMANAL',
        AppLanguage.en => 'WEEKLY',
        AppLanguage.ja => '週間',
      };

  // --- Wrapped: monthly recaps and the redesign ---
  String monthName(int month) {
    const es = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
        'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December'];
    return switch (language) {
      AppLanguage.es => es[month - 1],
      AppLanguage.en => en[month - 1],
      AppLanguage.ja => '$month月',
    };
  }

  /// "OCTUBRE 2026" / "2026" for the period of a recap.
  String wrappedPeriod(int year, int? month) {
    if (month == null) return '$year';
    return switch (language) {
      AppLanguage.ja => '$year年$month月',
      _ => '${monthName(month).toUpperCase()} $year',
    };
  }

  String wrappedIntro({required bool monthly}) => switch (language) {
        AppLanguage.es => monthly ? '¿Listo para revivir tu mes?' : '¿Listo para revivir tu año?',
        AppLanguage.en => monthly ? 'Ready to relive your month?' : 'Ready to relive your year?',
        AppLanguage.ja => monthly ? '今月を振り返ろう' : '今年を振り返ろう',
      };

  String wrappedReportTag({required bool monthly}) =>
      monthly ? '月報 // MONTHLY.REPORT' : '年間報告 // ANNUAL.REPORT.SYS';

  String get wrappedMinutesLabel => switch (language) {
        AppLanguage.es => 'MINUTOS ESCUCHADOS',
        AppLanguage.en => 'MINUTES LISTENED',
        AppLanguage.ja => '再生時間（分）',
      };

  String wrappedHoursOfMusic(int hours) => switch (language) {
        AppLanguage.es => hours == 1 ? 'Eso es 1 hora de música' : 'Eso son $hours horas de música',
        AppLanguage.en => hours == 1 ? "That's 1 hour of music" : "That's $hours hours of music",
        AppLanguage.ja => '$hours時間分の音楽',
      };

  String wrappedActiveDays(int active, int total) => switch (language) {
        AppLanguage.es => 'Hubo música $active de $total días',
        AppLanguage.en => 'Music on $active of $total days',
        AppLanguage.ja => '$total日中$active日音楽を聴いた',
      };

  /// "23% more than in September" / "12% less than in 2025".
  String wrappedVsPrevious(int pct, String previous) {
    final up = pct >= 0;
    final n = pct.abs();
    return switch (language) {
      AppLanguage.es => '$n% ${up ? 'más' : 'menos'} que en $previous',
      AppLanguage.en => '$n% ${up ? 'more' : 'less'} than in $previous',
      AppLanguage.ja => '$previousより$n%${up ? '多い' : '少ない'}',
    };
  }

  String get wrappedPlaysLabel => switch (language) {
        AppLanguage.es => 'REPRODUCCIONES',
        AppLanguage.en => 'PLAYS',
        AppLanguage.ja => '再生回数',
      };
  String get wrappedSongsLabel => switch (language) {
        AppLanguage.es => 'CANCIONES',
        AppLanguage.en => 'SONGS',
        AppLanguage.ja => '曲',
      };
  String get wrappedArtistsLabel => switch (language) {
        AppLanguage.es => 'ARTISTAS',
        AppLanguage.en => 'ARTISTS',
        AppLanguage.ja => 'アーティスト',
      };

  String get wrappedTopSongLabel => switch (language) {
        AppLanguage.es => 'TU CANCIÓN #1',
        AppLanguage.en => 'YOUR #1 SONG',
        AppLanguage.ja => 'あなたの1位の曲',
      };
  String get wrappedTopArtistLabel => switch (language) {
        AppLanguage.es => 'TU ARTISTA #1',
        AppLanguage.en => 'YOUR #1 ARTIST',
        AppLanguage.ja => 'あなたの1位のアーティスト',
      };
  String get wrappedRunnersUp => switch (language) {
        AppLanguage.es => 'LE SIGUEN',
        AppLanguage.en => 'RUNNERS-UP',
        AppLanguage.ja => '続いて',
      };

  String wrappedDayPart(int part) => switch (language) {
        AppLanguage.es => const ['Madrugada', 'Mañana', 'Tarde', 'Noche'][part],
        AppLanguage.en => const ['Late night', 'Morning', 'Afternoon', 'Evening'][part],
        AppLanguage.ja => const ['深夜', '朝', '午後', '夜'][part],
      };

  String get wrappedAuraTitle => switch (language) {
        AppLanguage.es => 'TU AURA MUSICAL',
        AppLanguage.en => 'YOUR MUSIC AURA',
        AppLanguage.ja => 'あなたの音楽オーラ',
      };

  /// Name and description of each listening profile (see WrappedAura).
  (String, String) wrappedAura(String key) => switch (language) {
        AppLanguage.es => switch (key) {
            'night' => ('Criatura nocturna', 'La luna es tu mejor oyente: tu música suena cuando el resto duerme.'),
            'dawn' => ('Madrugador', 'Empiezas el día con banda sonora antes que nadie.'),
            'loyal' => ('Alma fiel', 'Cuando un artista te atrapa, no lo sueltas.'),
            'explorer' => ('Explorador', 'Siempre buscando algo nuevo: muchísimos artistas distintos.'),
            'marathon' => ('Maratonista', 'Días enteros con música sin parar.'),
            _ => ('Equilibrio', 'Un poco de todo, a cualquier hora: tu música fluye contigo.'),
          },
        AppLanguage.en => switch (key) {
            'night' => ('Night creature', 'The moon is your best listener: your music plays while others sleep.'),
            'dawn' => ('Early riser', 'You start the day with a soundtrack before anyone else.'),
            'loyal' => ('Loyal soul', 'Once an artist hooks you, you never let go.'),
            'explorer' => ('Explorer', 'Always after something new: so many different artists.'),
            'marathon' => ('Marathoner', 'Whole days of music, non-stop.'),
            _ => ('Balance', 'A bit of everything, any time: your music flows with you.'),
          },
        AppLanguage.ja => switch (key) {
            'night' => ('夜の住人', '月が一番のリスナー。みんなが眠る頃にあなたの音楽が流れる。'),
            'dawn' => ('早起き', '誰よりも早く、音楽とともに一日を始める。'),
            'loyal' => ('一途な魂', '一度ハマったアーティストは離さない。'),
            'explorer' => ('探検家', 'いつも新しい音を探している。たくさんのアーティスト。'),
            'marathon' => ('マラソンランナー', '一日中ずっと音楽。'),
            _ => ('調和', '何でも、いつでも。音楽があなたと一緒に流れる。'),
          },
      };

  String get wrappedSummaryTitle => switch (language) {
        AppLanguage.es => 'TU RESUMEN',
        AppLanguage.en => 'YOUR RECAP',
        AppLanguage.ja => 'まとめ',
      };
  String get wrappedTopSongsShort => switch (language) {
        AppLanguage.es => 'CANCIONES',
        AppLanguage.en => 'TOP SONGS',
        AppLanguage.ja => 'トップ曲',
      };
  String get wrappedTopArtistsShort => switch (language) {
        AppLanguage.es => 'ARTISTAS',
        AppLanguage.en => 'TOP ARTISTS',
        AppLanguage.ja => 'トップアーティスト',
      };
  String wrappedOutroFor({required bool monthly}) => switch (language) {
        AppLanguage.es => monthly ? 'NOS VEMOS EL PRÓXIMO MES' : 'NOS VEMOS EL PRÓXIMO AÑO',
        AppLanguage.en => monthly ? 'SEE YOU NEXT MONTH' : 'SEE YOU NEXT YEAR',
        AppLanguage.ja => monthly ? 'また来月' : 'また来年',
      };
  String get wrappedShareCta => switch (language) {
        AppLanguage.es => 'COMPARTIR RESUMEN',
        AppLanguage.en => 'SHARE RECAP',
        AppLanguage.ja => 'まとめをシェア',
      };
  String wrappedNoDataFor({required bool monthly}) => switch (language) {
        AppLanguage.es => monthly ? 'No hay datos suficientes para este mes' : 'No hay datos suficientes para este año',
        AppLanguage.en => monthly ? 'Not enough data for this month' : 'Not enough data for this year',
        AppLanguage.ja => monthly ? '今月はデータが足りません' : '今年はデータが足りません',
      };
  String get wrappedPickerSubtitle => switch (language) {
        AppLanguage.es => 'Tu resumen de cada mes y del año',
        AppLanguage.en => 'Your recap for every month and the year',
        AppLanguage.ja => '毎月と一年のまとめ',
      };
  String get wrappedThisMonth => switch (language) {
        AppLanguage.es => 'este mes',
        AppLanguage.en => 'this month',
        AppLanguage.ja => '今月',
      };
  String wrappedWholeYear(int year) => switch (language) {
        AppLanguage.es => 'Año $year completo',
        AppLanguage.en => 'All of $year',
        AppLanguage.ja => '$year年の一年',
      };
  String get wrappedMonthlyLabel => switch (language) {
        AppLanguage.es => 'MENSUAL',
        AppLanguage.en => 'MONTHLY',
        AppLanguage.ja => '月間',
      };
  String get wrappedYearlyLabel => switch (language) {
        AppLanguage.es => 'ANUAL',
        AppLanguage.en => 'YEARLY',
        AppLanguage.ja => '年間',
      };
  String get wrappedHomeSubtitle => switch (language) {
        AppLanguage.es => 'MES Y AÑO',
        AppLanguage.en => 'MONTH & YEAR',
        AppLanguage.ja => '月と年',
      };

  String get a11yShareSlide => _l.a11yShareSlide;

  String get a11yNextSlide => _l.a11yNextSlide;

  String get a11yPreviousSlide => _l.a11yPreviousSlide;

  // --- Listening Clock ---
  String get clockTitle => _l.clockTitle;

  String get clockRadar => _l.clockRadar;

  String get clockDailyActivity => _l.clockDailyActivity;

  String clockPeakHour(String hour, int count) => _l.clockPeakHour(hour, count);

  String clockTotalYear(int count) => _l.clockTotalYear(count);

  String get clockNoData => _l.clockNoData;

  String get clockNoDataSubtitle => _l.clockNoDataSubtitle;

  String get clockViewClock => _l.clockViewClock;

  String get a11yClock => _l.a11yClock;

  // --- Rabbit Hole (Artist Graph) ---
  String get rabbitHoleTitle => _l.rabbitHoleTitle;

  String get rabbitHoleSubtitle => _l.rabbitHoleSubtitle;

  String get rabbitHoleLoading => _l.rabbitHoleLoading;

  String get rabbitHoleTapToExpand => _l.rabbitHoleTapToExpand;

  String rabbitHoleConnections(int count) => _l.rabbitHoleConnections(count);

  String get rabbitHoleDeadEnd => _l.rabbitHoleDeadEnd;

  String get rabbitHoleMaxReached => _l.rabbitHoleMaxReached;

  String get rabbitHoleRestartHere => _l.rabbitHoleRestartHere;

  String get rabbitHoleOpenArtist => _l.rabbitHoleOpenArtist;

  String get rabbitHoleFitAll => _l.rabbitHoleFitAll;

  String get rabbitHoleHint => _l.rabbitHoleHint;

  String get rabbitHoleEmpty => _l.rabbitHoleEmpty;

  String get rabbitHoleEmptySubtitle => _l.rabbitHoleEmptySubtitle;

  String get rabbitHoleOffline => _l.rabbitHoleOffline;

  String get rabbitHoleOfflineSubtitle => _l.rabbitHoleOfflineSubtitle;

  String get rabbitHoleNodeError => _l.rabbitHoleNodeError;

  String get rabbitHoleListenShort => _l.rabbitHoleListenShort;

  String get rabbitHoleListen => _l.rabbitHoleListen;

  String get rabbitHoleKnown => _l.rabbitHoleKnown;

  String get rabbitHoleRecenter => _l.rabbitHoleRecenter;

  String rabbitHoleNodes(int count) => _l.rabbitHoleNodes(count);

  String rabbitHoleDepth(int count) => _l.rabbitHoleDepth(count);

  String get rabbitHoleViewGraph => _l.rabbitHoleViewGraph;

  String get a11yRabbitHole => _l.a11yRabbitHole;

  // --- Release Radar ---
  String get radarTitle => _l.radarTitle;

  String radarWatching(int count) => _l.radarWatching(count);

  String radarNewCount(int count) => _l.radarNewCount(count);

  String get radarSectionNew => _l.radarSectionNew;

  String get radarSectionRecent => _l.radarSectionRecent;

  String get radarNotifyToggle => _l.radarNotifyToggle;

  String get radarNotifyToggleSubtitle => _l.radarNotifyToggleSubtitle;

  String get radarPermissionDenied => _l.radarPermissionDenied;

  String get radarPermissionAction => _l.radarPermissionAction;

  String get radarPermissionSettingsHint => _l.radarPermissionSettingsHint;

  String get radarCheckNow => _l.radarCheckNow;

  String get radarChecking => _l.radarChecking;

  String radarLastCheck(Duration? ago) {
    if (ago == null) return _l.radarNotChecked;
    final String span;
    if (ago.inMinutes < 1) {
      span = _l.radarSpanNow;
    } else if (ago.inHours < 1) {
      span = _l.radarSpanMinutes(ago.inMinutes);
    } else if (ago.inDays < 1) {
      span = _l.radarSpanHours(ago.inHours);
    } else {
      span = _l.radarSpanDays(ago.inDays);
    }
    return _l.radarLastChecked(span);
  }

  String get radarEmptyNoArtistsTitle => _l.radarEmptyNoArtistsTitle;

  String get radarEmptyNoArtists => _l.radarEmptyNoArtists;

  String get radarEmptyNoReleasesTitle => _l.radarEmptyNoReleasesTitle;

  String get radarEmptyNoReleases => _l.radarEmptyNoReleases;

  String get radarIosNote => _l.radarIosNote;

  String radarType(String recordType) => _l.radarType(recordType);

  String radarReleasedAgo(int days) =>
      days < 0 ? _l.radarUpcoming : _l.radarDaysAgo(days);

  String radarNotifSingle(String artist, String recordType) =>
      _l.radarNotifSingle(artist, recordType);

  String radarNotifMany(int count) => _l.radarNotifMany(count);

  String radarNotifManyBody(List<String> artists) {
    final shown = artists.take(2).toList();
    final rest = artists.length - shown.length;
    if (rest > 0) return _l.radarNamesMore(shown.join(', '), rest);
    if (shown.length < 2) return shown.join(', ');
    return _l.radarNamesPair(shown[0], shown[1]);
  }

  String get radarChannelName => _l.radarChannelName;

  String get radarChannelDescription => _l.radarChannelDescription;

  String radarFollowSnack(String artist) => _l.radarFollowSnack(artist);

  String get a11yRadar => _l.a11yRadar;

  // --- Song Radio ---
  String get radioStart => _l.radioStart;

  String radioStarted(String title) => _l.radioStarted(title);

  String get radioNoResults => _l.radioNoResults;

  String get radioLabel => _l.radioLabel;

  String radioBasedOn(String title) => _l.radioBasedOn(title);

  String radioReasonLastFm(String title) => _l.radioReasonLastFm(title);

  String radioReasonDeezer(String artist) => _l.radioReasonDeezer(artist);

  String get radioLoadingMore => _l.radioLoadingMore;

  String get radioInfinite => _l.radioInfinite;

  String get radioOffline => _l.radioOffline;

  String get radioExhausted => _l.radioExhausted;

  String get radioModeTitle => _l.radioModeTitle;

  String get radioModeFamiliar => _l.radioModeFamiliar;

  String get radioModeFamiliarDesc => _l.radioModeFamiliarDesc;

  String get radioModeBalanced => _l.radioModeBalanced;

  String get radioModeBalancedDesc => _l.radioModeBalancedDesc;

  String get radioModeAdventurous => _l.radioModeAdventurous;

  String get radioModeAdventurousDesc => _l.radioModeAdventurousDesc;

  String get radioMoreLikeThis => _l.radioMoreLikeThis;

  String get radioLessLikeThis => _l.radioLessLikeThis;

  String get radioMoreSnack => _l.radioMoreSnack;

  String radioLessSnack(String artist) => _l.radioLessSnack(artist);

  String get radioStop => _l.radioStop;

  String get radioStopped => _l.radioStopped;

  String get radioSourcesBoth => _l.radioSourcesBoth;

  String get radioSourcesDeezerOnly => _l.radioSourcesDeezerOnly;

  String get radioLearnHint => _l.radioLearnHint;

  String get radioTune => _l.radioTune;

  String get a11yRadio => _l.a11yRadio;

  // --- Dates ---
  /// [weekday] uses DateTime's 1 (Monday) .. 7 (Sunday).
  String weekdayName(int weekday) =>
      _l.weekdayName(_weekdayKeys[weekday.clamp(1, 7) - 1]);

  static const _weekdayKeys = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];

  // --- Wrapped: play log vs discoveries ---
  String get wrappedTopDiscoveries => _l.wrappedTopDiscoveries;

  String wrappedDiscoveredSongs(int count) => _l.wrappedDiscoveredSongs(count);

  String get wrappedNewMusicTime => _l.wrappedNewMusicTime;

  String wrappedFactMarathonDiscovery(String date, int count) =>
      _l.wrappedFactMarathonDiscovery(date, count);

  String wrappedFactLoyalDiscovery(String artist, int count) =>
      _l.wrappedFactLoyalDiscovery(artist, count);

  String get wrappedBasedOnDiscoveries => _l.wrappedBasedOnDiscoveries;

  String wrappedPlaysSince(String date) => _l.wrappedPlaysSince(date);

  // --- Time Machine ---
  String get timeMachineTitle => _l.timeMachineTitle;

  String get timeMachineYearAgo => _l.timeMachineYearAgo;

  String get timeMachineSixMonthsAgo => _l.timeMachineSixMonthsAgo;

  String get timeMachineMonthAgo => _l.timeMachineMonthAgo;

  String get timeMachineWeekAgo => _l.timeMachineWeekAgo;

  String get timeMachineRandom => _l.timeMachineRandom;

  String get timeMachineRewinding => _l.timeMachineRewinding;

  String get timeMachineKindPlays => _l.timeMachineKindPlays;

  String get timeMachineKindDiscoveries => _l.timeMachineKindDiscoveries;

  String get timeMachineExactDay => _l.timeMachineExactDay;

  String get timeMachineThatWeek => _l.timeMachineThatWeek;

  String get timeMachineHeadlineRepeat => _l.timeMachineHeadlineRepeat;

  String get timeMachineHeadlinePlayed => _l.timeMachineHeadlinePlayed;

  String get timeMachineHeadlineDiscovered => _l.timeMachineHeadlineDiscovered;

  String timeMachineTimes(int count, bool exactDay) => exactDay
      ? _l.timeMachineTimesDay(count)
      : _l.timeMachineTimesWeek(count);

  String timeMachineDiscoveredAt(String time) => _l.timeMachineDiscoveredAt(time);

  String timeMachineDiscoveredOn(String weekday) => _l.timeMachineDiscoveredOn(weekday);

  String get timeMachinePlay => _l.timeMachinePlay;

  String get timeMachinePlaying => _l.timeMachinePlaying;

  String get timeMachinePlayFailed => _l.timeMachinePlayFailed;

  String get timeMachineNothingTitle => _l.timeMachineNothingTitle;

  String get timeMachineNothing => _l.timeMachineNothing;

  String get timeMachineNoHistory => _l.timeMachineNoHistory;

  String timeMachineCountingSince(String date) => _l.timeMachineCountingSince(date);

  String get timeMachineCountingStarts => _l.timeMachineCountingStarts;

  String get timeMachineNotifyToggle => _l.timeMachineNotifyToggle;

  String get timeMachineNotifyToggleSubtitle => _l.timeMachineNotifyToggleSubtitle;

  String timeMachineNotifRepeat(String title) => _l.timeMachineNotifRepeat(title);

  String timeMachineNotifRepeatBody(String artist, int count) =>
      _l.timeMachineNotifRepeatBody(artist, count);

  String timeMachineNotifPlayed(String title) => _l.timeMachineNotifPlayed(title);

  String timeMachineNotifDiscovered(String title) => _l.timeMachineNotifDiscovered(title);

  String get timeMachineChannelName => _l.timeMachineChannelName;

  String get timeMachineChannelDescription => _l.timeMachineChannelDescription;

  String get timeMachineCardEmpty => _l.timeMachineCardEmpty;

  String timeMachineCardTeaser(String title) => _l.timeMachineCardTeaser(title);

  String timeMachineCardTeaserRepeat(String title) => _l.timeMachineCardTeaserRepeat(title);

  String get a11yTimeMachine => _l.a11yTimeMachine;

  // --- Similar Artists ---
  String get similarArtists => _l.similarArtists;

  // --- Follow Artist ---
  String get followArtist => _l.followArtist;

  String get unfollowArtist => _l.unfollowArtist;

  String get artistFollowed => _l.artistFollowed;

  String get artistUnfollowed => _l.artistUnfollowed;

  String get artistCompleteTooltip => _l.artistCompleteTooltip;

  String get artistIncompleteTooltip => _l.artistIncompleteTooltip;

  // --- Voice Search ---
  String get a11yVoiceSearch => _l.a11yVoiceSearch;

  String get voicePlaying => _l.voicePlaying;

  // --- Battery guide (Spotify frozen by the phone) ---
  String get batteryGuideSnack => _l.batteryGuideSnack;

  String get batteryGuideAction => _l.batteryGuideAction;

  String get batteryGuideTitle => _l.batteryGuideTitle;

  String batteryGuideIntro(String maker) => _l.batteryGuideIntro(maker);

  String get batteryGuideStepOpen => _l.batteryGuideStepOpen;

  String batteryGuideStepBattery(BatteryFamily family) =>
      _l.batteryGuideStepBattery(family.name);

  String batteryGuideStepAutostart(BatteryFamily family) =>
      _l.batteryGuideStepAutostart(family.name);

  String get batteryGuideStepRetry => _l.batteryGuideStepRetry;

  String get batteryGuideOpenSettings => _l.batteryGuideOpenSettings;

  String get batteryGuideDontShow => _l.batteryGuideDontShow;

  String get batteryGuideOpenFailed => _l.batteryGuideOpenFailed;

  String get deleteAccountOption => _l.deleteAccountOption;

  String get deleteAccountConfirmTitle => _l.deleteAccountConfirmTitle;

  String get deleteAccountConfirmMessage => _l.deleteAccountConfirmMessage;

  String get deleteAccountConfirm => _l.deleteAccountConfirm;

  String get deleteAccountInProgress => _l.deleteAccountInProgress;

  String get deleteAccountDone => _l.deleteAccountDone;

  String get deleteAccountOffline => _l.deleteAccountOffline;

  String get deleteAccountFailed => _l.deleteAccountFailed;

  String get privacyPolicyOption => _l.privacyPolicyOption;

  String get termsOption => _l.termsOption;

  String get spotifyLimitedNote => _l.spotifyLimitedNote;

  String get spotifyNotRegisteredTitle => _l.spotifyNotRegisteredTitle;

  String get spotifyNotRegisteredMessage => _l.spotifyNotRegisteredMessage;

  String get spotifyNotRegisteredOk => _l.spotifyNotRegisteredOk;

  String get deleteAccountNotConfirmed => _l.deleteAccountNotConfirmed;

  String get deleteAccountClosing => _l.deleteAccountClosing;

  String get deleteAccountCloseApp => _l.deleteAccountCloseApp;

  String get crossfadeGapless => _l.crossfadeGapless;

  String get lyricsPreviewNote => _l.lyricsPreviewNote;
}
