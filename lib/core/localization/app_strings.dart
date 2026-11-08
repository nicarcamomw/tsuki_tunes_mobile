import 'dart:math';
import 'dart:ui' show Locale;

import '../../data/datasources/battery_guide.dart';
import '../../data/datasources/bpm_flow.dart';
import '../../data/datasources/weather_service.dart';
import '../../domain/entities/oni_mask.dart';
import '../../domain/entities/social.dart';
import '../../domain/entities/weekly_challenge.dart';
import '../../domain/logic/ambient_sound_generator.dart';
import '../../domain/logic/cadence_detector.dart';
import '../../domain/logic/eco_levels.dart';
import '../../domain/logic/equalizer_presets.dart';
import '../../domain/logic/moon_calculator.dart';
import '../../domain/logic/music_styles.dart';
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

  /// Label over a secret mask's riddle.
  String get maskRiddleLabel => switch (language) {
        AppLanguage.es => 'PISTA',
        AppLanguage.en => 'RIDDLE',
        AppLanguage.ja => '手がかり',
      };

  /// Under a secret mask while its riddle is still hidden.
  String maskRiddleAfter(int count) => switch (language) {
        AppLanguage.es => 'Despierta $count seres etéreos para ver una pista.',
        AppLanguage.en => 'Wake $count ethereal beings to see a riddle.',
        AppLanguage.ja => '霊なる者を$count体目覚めさせると手がかりが見える。',
      };

  String get maskEquip => _l.maskEquip;

  String get maskHowToUnlock => _l.maskHowToUnlock;

  String get maskLocked => _l.maskLocked;

  String get maskEquipped => _l.maskEquipped;

  String get maskUnequip => _l.maskUnequip;

  String maskUnlockedOn(String date) => _l.maskUnlockedOn(date);

  String get maskUnlockedTitle => _l.maskUnlockedTitle;

  String maskRarity(MaskRarity r) => _l.maskRarity(r.name);

  // --- Tsuki Lore ---
  // ── Eco levels ──
  String _es(String es, String en, String ja) => switch (language) {
        AppLanguage.es => es,
        AppLanguage.en => en,
        AppLanguage.ja => ja,
      };

  String get ecoTitle => _es('NIVELES DE ECO', 'ECO LEVELS', 'エコーレベル');
  String ecoLevel(int n) => _es('Nivel $n', 'Level $n', 'レベル$n');
  String ecoLevelShort(int n) => _es('NV $n', 'LV $n', 'LV $n');

  /// "12.430" (es) / "12,430" (en): Eco amounts.
  String ecoAmount(int n) {
    final digits = '$n';
    final sep = language == AppLanguage.es ? '.' : ',';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(sep);
      out.write(digits[i]);
    }
    return '$out Eco';
  }

  String ecoToNext(int missing, int next) => _es(
      'Te faltan ${ecoAmount(missing)} para el nivel $next',
      '${ecoAmount(missing)} to level $next',
      'レベル$nextまであと${ecoAmount(missing)}');

  String ecoRankName(EcoRank r) => switch (r) {
        EcoRank.errante => _es('Errante', 'Wanderer', '放浪者'),
        EcoRank.guerrero => _es('Guerrero', 'Warrior', '戦士'),
        EcoRank.senor => _es('Señor', 'Lord', '領主'),
        EcoRank.ultra => _es('Ultra', 'Ultra', 'ウルトラ'),
        EcoRank.cara => _es('Cara', 'Face', '顔'),
        EcoRank.portador => _es('Portador', 'Bearer', '運び手'),
        EcoRank.oyente => _es('Oyente de lo Etéreo', 'Hearer of the Ethereal', '霊を聴く者'),
        EcoRank.vidente => _es('Vidente de lo Etéreo', 'Seer of the Ethereal', '霊を視る者'),
        EcoRank.etereo => _es('Ser Etéreo', 'Ethereal Being', '霊なる者'),
        EcoRank.inconmensurable => _es('Portador Inconmensurable', 'Immeasurable Bearer', '計り知れぬ運び手'),
      };

  String ecoFeatureName(EcoFeature f) => switch (f) {
        EcoFeature.lyrics => _es('Letras sincronizadas', 'Synced lyrics', '同期歌詞'),
        EcoFeature.discovery => _es('Modo descubrimiento', 'Discovery mode', 'ディスカバリー'),
        EcoFeature.artistRadio => _es('Radio por artista', 'Artist radio', 'アーティストラジオ'),
        EcoFeature.streak => _es('Racha diaria', 'Daily streak', '連続記録'),
        EcoFeature.wrapped => _es('Wrapped', 'Wrapped', 'Wrapped'),
        EcoFeature.guessSong => _es('Adivina la canción', 'Guess the song', '曲当てゲーム'),
        EcoFeature.weekly => _es('Desafíos semanales', 'Weekly challenges', '週間チャレンジ'),
        EcoFeature.listeningClock => _es('Reloj de escucha', 'Listening clock', 'リスニング時計'),
        EcoFeature.lyricsTranslate => _es('Traducir letras', 'Translate lyrics', '歌詞の翻訳'),
        EcoFeature.ambient => _es('Mezclador de ambiente', 'Ambient mixer', '環境音ミキサー'),
        EcoFeature.running => _es('Modo Running', 'Running mode', 'ランニングモード'),
        EcoFeature.radioFamiliar => _es('Radio en modo Familiar', 'Radio in Familiar mode', 'ラジオ:おなじみモード'),
        EcoFeature.timeMachine => _es('Máquina del Tiempo', 'Time Machine', 'タイムマシン'),
        EcoFeature.rabbitHole => _es('Madriguera de artistas', 'Artist rabbit hole', 'アーティストの迷宮'),
        EcoFeature.bpmFlow => _es('Cola por ritmo (BPM)', 'Queue by tempo (BPM)', 'テンポ順キュー'),
        EcoFeature.moonMix => _es('Mezcla de luna llena', 'Full moon mix', '満月ミックス'),
        EcoFeature.radioAdventurous => _es('Radio en modo Aventurero', 'Radio in Adventurous mode', 'ラジオ:冒険モード'),
        EcoFeature.smartShuffle => _es('Aleatorio con recomendaciones', 'Shuffle with recommendations', 'おすすめ入りシャッフル'),
        EcoFeature.hearBeings => _es('Escuchar a los seres etéreos', 'Hear the ethereal beings', '霊なる者の声を聴く'),
        EcoFeature.seeBeings => _es('Ver a los seres etéreos', 'See the ethereal beings', '霊なる者を視る'),
        EcoFeature.ethereal => _es('Volverte un ser etéreo', 'Become an ethereal being', '霊なる者になる'),
      };

  String ecoColorName(EcoColor c) => c.name.of(language);

  /// One line for a level's reward.
  String ecoRewardLabel(EcoReward r) => switch (r.kind) {
        EcoRewardKind.start => _es('Escuchar, buscar, tu biblioteca y la radio por canción',
            'Listening, search, your library and song radio', '再生、検索、ライブラリ、曲ラジオ'),
        EcoRewardKind.feature => ecoFeatureName(r.feature!),
        EcoRewardKind.sound => _es('Sonido de ambiente: ${ambientName(r.sound!)}',
            'Ambient sound: ${ambientName(r.sound!)}', '環境音:${ambientName(r.sound!)}'),
        EcoRewardKind.chapter => 'Tsuki Lore · ${r.chapter!.title.of(language)}',
        EcoRewardKind.color => _es('Color del reproductor: ${ecoColorName(r.color!)}',
            'Player colour: ${ecoColorName(r.color!)}', 'プレーヤーの色:${ecoColorName(r.color!)}'),
        EcoRewardKind.rank => _es('Nuevo rango: ${ecoRankName(r.rank!)}', 'New rank: ${ecoRankName(r.rank!)}',
            '新しいランク:${ecoRankName(r.rank!)}'),
        EcoRewardKind.fragment => _es('Fragmento de la leyenda', 'Fragment of the legend', '伝説の断片'),
      };

  String get ecoLevelUp => _es('SUBISTE DE NIVEL', 'LEVEL UP', 'レベルアップ');
  String get ecoNowOpen => _es('Se abre', 'Now open', '解放');
  String ecoMore(int n) => _es('y $n más', 'and $n more', 'ほか$n件');
  String ecoOpensAt(int level) => _es('Se abre en el nivel $level', 'Opens at level $level', 'レベル$levelで解放');
  String get ecoLockedBody => _es(
      'Gana Eco escuchando música para subir de nivel. Cada nivel abre algo nuevo.',
      'Earn Eco by listening to music to level up. Every level opens something new.',
      '音楽を聴いてエコーを集め、レベルを上げよう。レベルごとに新しいものが開きます。');
  String get ecoSeeLevels => _es('Ver niveles', 'See levels', 'レベルを見る');

  // ── Listening parties ──
  String get partyTitle => _es('Escuchar juntos', 'Listen together', '一緒に聴く');
  String get partyHint => _es(
      'Abre tu fiesta e invita a tus Lazos: escucharán lo mismo que tú, en el mismo segundo.',
      'Open your party and invite your Bonds: they will hear what you hear, at the same second.',
      'パーティーを開いて絆の仲間を招待しよう。同じ曲を同じ瞬間に聴ける。');
  String get partyOpen => _es('Abrir mi fiesta', 'Open my party', 'パーティーを開く');
  String get partyEnd => _es('Terminar la fiesta', 'End the party', 'パーティーを終了');
  String get partyLeave => _es('Salir', 'Leave', '退出');
  String get partyInvite => _es('Invitar Lazos', 'Invite Bonds', '絆を招待');
  String get partyInvitations => _es('Te invitaron', 'You were invited', '招待');
  String partyHostedBy(String name) => _es('Fiesta de $name', '$name\'s party', '$nameのパーティー');
  String get partyYouHost => _es('Tu fiesta', 'Your party', 'あなたのパーティー');
  String partyListening(int n) => _es(
      n == 0 ? 'Nadie más escuchando todavía' : n == 1 ? '1 escuchando contigo' : '$n escuchando contigo',
      n == 0 ? 'No one else listening yet' : n == 1 ? '1 listening with you' : '$n listening with you',
      n == 0 ? 'まだ誰も聴いていない' : '$n人が一緒に聴いている');
  String get partySynced => _es('Sincronizado con el anfitrión', 'In sync with the host', 'ホストと同期中');
  String get partyNothing => _es('Pon una canción y todos la escucharán.', 'Play a song and everyone will hear it.', '曲を再生すれば、みんなに届く。');
  String get partyHostPaused => _es('El anfitrión pausó la música', 'The host paused the music', 'ホストが一時停止中');
  String get partyEnded => _es('La fiesta terminó.', 'The party ended.', 'パーティーは終わった。');
  String get partyPreviewNote => _es(
      'Sin Spotify, cada canción suena 30 segundos.',
      'Without Spotify, each song plays for 30 seconds.',
      'Spotifyなしでは各曲30秒だけ再生される。');
  String get partyObserver => _es(
      'Escuchar juntos es entre Portadores. Vuélvete Portador para abrir una fiesta.',
      'Listening together is between Bearers. Become a Bearer to open a party.',
      '一緒に聴くのは運び手同士。運び手になってパーティーを開こう。');

  // ── Collaborative playlists ──
  String get sharedTitle => _es('Colaborativas', 'Collaborative', '共同プレイリスト');
  String get sharedNew => _es('Nueva colaborativa', 'New collaborative', '新しい共同プレイリスト');
  String get sharedNewHint => _es(
      'Una playlist que armas con tus Lazos: todos agregan y quitan canciones.',
      'A playlist you build with your Bonds: everyone adds and removes songs.',
      '絆の仲間と作るプレイリスト。みんなで曲を追加・削除できる。');
  String sharedMembers(int n) => _es(n == 1 ? '1 persona' : '$n personas', n == 1 ? '1 person' : '$n people', '$n人');
  String sharedInvitedBy(String name) => _es('$name te invitó', '$name invited you', '$nameから招待');
  String get sharedJoin => _es('Unirme', 'Join', '参加');
  String get sharedDecline => _es('No, gracias', 'No, thanks', '辞退');
  String get sharedInvite => _es('Invitar', 'Invite', '招待');
  String get sharedInviteTitle => _es('Invitar a tus Lazos', 'Invite your Bonds', '絆の仲間を招待');
  String get sharedInviteNone => _es(
      'Todos tus Lazos ya están aquí, o todavía no tienes Lazos.',
      'All your Bonds are already here, or you have no Bonds yet.',
      '絆の仲間は全員参加済みか、まだ絆がない。');
  String get sharedInvitedTag => _es('Invitado', 'Invited', '招待中');
  String get sharedOwnerTag => _es('Creador', 'Owner', '作成者');
  String sharedAddedBy(String name) => _es('agregó $name', 'added by $name', '$nameが追加');
  String get sharedPlayAll => _es('Reproducir', 'Play', '再生');
  String get sharedRename => _es('Cambiar nombre', 'Rename', '名前を変更');
  String get sharedLeave => _es('Salir de la playlist', 'Leave the playlist', 'プレイリストから抜ける');
  String get sharedDelete => _es('Eliminar para todos', 'Delete for everyone', '全員から削除');
  String get sharedDeleteBody => _es(
      'La playlist desaparece para todos sus miembros.',
      'The playlist disappears for all its members.',
      'すべてのメンバーからプレイリストが消える。');
  String get sharedEmpty => _es(
      'Todavía no hay canciones. Agrega desde cualquier canción con "Agregar a playlist".',
      'No songs yet. Add from any song with "Add to playlist".',
      'まだ曲がない。どの曲からでも「プレイリストに追加」で追加できる。');
  String get sharedGone => _es('Esta playlist ya no existe o no eres parte de ella.', 'This playlist no longer exists or you are not part of it.', 'このプレイリストは存在しないか、参加していない。');
  String get sharedObserver => _es(
      'Las playlists colaborativas son entre Portadores. Vuélvete Portador para crearlas.',
      'Collaborative playlists are between Bearers. Become a Bearer to create them.',
      '共同プレイリストは運び手同士のもの。運び手になって作ろう。');

  // ── Import from Spotify ──
  String get importTitle => _es('Importar de Spotify', 'Import from Spotify', 'Spotifyからインポート');
  String get importHint => _es(
      'Elige qué traer. Cada canción se busca en el catálogo de Tsuki y las que se encuentran forman una playlist con el mismo nombre.',
      'Choose what to bring. Each song is looked up in Tsuki\'s catalog, and the ones found make a playlist with the same name.',
      '持ってくるものを選んで。各曲をツキのカタログで探し、見つかった曲で同じ名前のプレイリストを作る。');
  String get importLiked => _es('Canciones que te gustan (Spotify)', 'Liked Songs (Spotify)', 'お気に入りの曲（Spotify）');
  String importSongs(int n) => _es(n == 1 ? '1 canción' : '$n canciones', n == 1 ? '1 song' : '$n songs', '$n曲');
  String importButton(int n) => _es(
      n == 1 ? 'Importar 1 playlist' : 'Importar $n playlists',
      n == 1 ? 'Import 1 playlist' : 'Import $n playlists',
      '$n個のプレイリストをインポート');
  String importProgress(int done, int total) => _es('$done de $total canciones', '$done of $total songs', '$total曲中$done曲');
  String get importKeepOpen => _es(
      'Deja esta pantalla abierta hasta que termine.',
      'Keep this screen open until it finishes.',
      '終わるまでこの画面を開いたままにして。');
  String importFound(int found, int total) => _es('$found de $total encontradas', '$found of $total found', '$total曲中$found曲見つかった');
  String get importDone => _es('Listo. Tus playlists ya están en la biblioteca.', 'Done. Your playlists are in the library.', '完了。プレイリストはライブラリにある。');
  String get importCancel => _es('Detener', 'Stop', '停止');
  String get importReconnect => _es(
      'Para leer tus playlists, Spotify necesita un permiso nuevo. Desconecta y vuelve a conectar Spotify en tu perfil.',
      'To read your playlists, Spotify needs a new permission. Disconnect and connect Spotify again in your profile.',
      'プレイリストを読むにはSpotifyの新しい許可が必要。プロフィールでSpotifyを接続し直して。');
  String get importNone => _es('No encontré playlists en tu Spotify.', 'No playlists found in your Spotify.', 'Spotifyにプレイリストが見つからない。');
  String get importNotConnected => _es('Conecta Spotify en tu perfil para importar.', 'Connect Spotify in your profile to import.', 'インポートするにはプロフィールでSpotifyを接続して。');

  // ── Discovery ──
  String get discoveryTitle => _es('Descubrir', 'Discover', 'ディスカバー');
  String get discoverySubtitle => _es(
      'Desliza canciones nuevas: derecha para guardar, izquierda para pasar',
      'Swipe new songs: right to save, left to pass',
      '新しい曲をスワイプ。右で保存、左でパス');
  String get discoveryPlaylist => _es('Descubrimientos', 'Discoveries', 'ディスカバリー');
  String get discoverySave => _es('Guardar', 'Save', '保存');
  String get discoveryPass => _es('Pasar', 'Pass', 'パス');
  String get discoveryPlay => _es('Escuchar', 'Listen', '再生');
  String get discoveryPause => _es('Pausar', 'Pause', '一時停止');
  String discoveryBecause(String artist) => _es('Porque escuchas a $artist', 'Because you listen to $artist', '$artistを聴いているから');
  String get discoveryFromCharts => _es('Sonando en el mundo', 'Playing around the world', '世界で人気');
  String discoverySaved(int n) => _es(
      n == 1 ? '1 guardada en Descubrimientos' : '$n guardadas en Descubrimientos',
      n == 1 ? '1 saved to Discoveries' : '$n saved to Discoveries',
      'ディスカバリーに$n曲保存');
  String get discoveryLoading => _es('Buscando canciones para ti', 'Finding songs for you', 'あなたのための曲を探しています');
  String get discoveryEmpty => _es(
      'No encontré canciones nuevas ahora. Revisa tu conexión o vuelve más tarde.',
      'No new songs found right now. Check your connection or come back later.',
      '今は新しい曲が見つからない。接続を確認するか、あとで戻ってきて。');
  String get discoveryRetry => _es('Buscar de nuevo', 'Search again', 'もう一度探す');
  String get discoveryOpenPlaylist => _es('Ver guardadas', 'See saved', '保存した曲');

  // ── Bonds (Lazos) ──
  String get bondsTitle => _es('Lazos', 'Bonds', '絆');
  String get bondsTabResonances => _es('Resonancias', 'Resonances', '共鳴');
  String get bondsTabBonds => _es('Lazos', 'Bonds', '絆');
  String get bondsTabSearch => _es('Buscar', 'Search', '探す');
  String get bondsSearchHint => _es('Busca un Portador por su nombre', 'Search a Bearer by name', '名前で運び手を探す');
  String get bondsSearchHelp => _es(
      'Solo aparecen los Portadores con perfil público. Si tu amigo lo tiene privado, pídele el enlace a su perfil.',
      'Only Bearers with a public profile show up. If your friend\'s is private, ask them for the link to their profile.',
      '公開プロフィールの運び手だけが表示される。友達が非公開なら、プロフィールのリンクを送ってもらおう。');
  String bondsSearchNone(String q) => _es('Nadie se llama "$q" todavía.', 'No one called "$q" yet.', '「$q」という人はまだいない。');
  String get bondsSearchFailed => _es('No se pudo buscar. Revisa tu conexión.', 'Could not search. Check your connection.', '検索できなかった。接続を確認して。');
  String get bondsRequests => _es('Solicitudes', 'Requests', 'リクエスト');
  String get bondsSent => _es('Enviadas', 'Sent', '送信済み');
  String get bondsYours => _es('Tus Lazos', 'Your Bonds', 'あなたの絆');
  String get bondsNone => _es(
      'Todavía no tienes Lazos. Busca a alguien o comparte tu perfil para que te encuentren.',
      'No Bonds yet. Search for someone, or share your profile so they find you.',
      'まだ絆がない。誰かを探すか、プロフィールを共有して見つけてもらおう。');
  String get bondsAsk => _es('Crear Lazo', 'Create Bond', '絆を結ぶ');
  String get bondsAskShort => _es('Pedir Lazo', 'Ask', '申請');
  String get bondsAsked => _es('Solicitud enviada', 'Request sent', '申請済み');
  String get bondsCancel => _es('Cancelar solicitud', 'Cancel request', '申請を取り消す');
  String get bondsAccept => _es('Aceptar', 'Accept', '承認');
  String get bondsDecline => _es('Rechazar', 'Decline', '拒否');
  String get bondsBonded => _es('Lazo', 'Bond', '絆');
  String get bondsUnbond => _es('Deshacer Lazo', 'Undo Bond', '絆を解く');
  String bondsUnbondBody(String name) => _es(
      'Dejarás de escuchar las Resonancias de $name, y $name las tuyas.',
      'You will stop hearing $name\'s Resonances, and $name yours.',
      '$nameの共鳴が聞こえなくなり、$nameにもあなたの共鳴が届かなくなる。');
  String bondsWantsYou(String name) => _es('$name quiere crear un Lazo contigo', '$name wants to create a Bond with you', '$nameがあなたと絆を結びたがっている');
  String bondsNowBonded(String name) => _es('Ahora tienes un Lazo con $name', 'You now have a Bond with $name', '$nameと絆を結んだ');
  String bondsSentTo(String name) => _es('Solicitud enviada a $name', 'Request sent to $name', '$nameに申請した');
  String get bondsFailed => _es('No se pudo. Inténtalo de nuevo.', 'It did not work. Try again.', 'うまくいかなかった。もう一度試して。');
  String get bondsObserver => _es(
      'Los Observadores no crean Lazos. Vuélvete Portador para encontrar a los tuyos.',
      'Observers do not create Bonds. Become a Bearer to find yours.',
      '観測者は絆を結べない。運び手になって仲間を見つけよう。');
  String get bondsResonancesNone => _es(
      'Cuando tus Lazos completen álbumes, despierten seres o suban de rango, lo escucharás aquí.',
      'When your Bonds complete albums, awaken beings or rise in rank, you will hear it here.',
      '絆の仲間がアルバムを聴き終えたり、霊を目覚めさせたり、位を上げたりすると、ここに届く。');
  String get bondsResonancesNoBonds => _es(
      'Las Resonancias son el Eco de tus Lazos. Crea tu primer Lazo para empezar a escucharlas.',
      'Resonances are your Bonds\' Echo. Create your first Bond to start hearing them.',
      '共鳴は絆の仲間のエコー。最初の絆を結んで聞き始めよう。');
  String get bondsYourResonances => _es('Tus Resonancias', 'Your Resonances', 'あなたの共鳴');
  String bondsMilestone(Milestone m, String maskName) => switch (m.kind) {
        MilestoneKind.album => _es('completó el álbum ${m.a} de ${m.b ?? ''}', 'completed the album ${m.a} by ${m.b ?? ''}',
            '${m.b ?? ''}のアルバム「${m.a}」を聴き終えた'),
        MilestoneKind.mask => _es('despertó a $maskName', 'awakened $maskName', '$maskNameを目覚めさせた'),
        MilestoneKind.rank => _es('llegó al nivel ${m.a} de Eco', 'reached Eco level ${m.a}', 'エコーレベル${m.a}に到達した'),
        MilestoneKind.streak => _es('lleva ${m.a} días seguidos escuchando', 'has listened ${m.a} days in a row', '${m.a}日連続で聴いている'),
      };
  String get sintoniaTitle => _es('Sintonía', 'Sintonía', '同調');
  String sintoniaShared(int n) => _es(
      n == 1 ? '1 artista en común' : '$n artistas en común',
      n == 1 ? '1 artist in common' : '$n artists in common',
      '共通のアーティスト $n人');
  String get sintoniaNone => _es(
      'Todavía no comparten artistas. Puede que se descubran algo.',
      'No artists in common yet. You might discover something from each other.',
      'まだ共通のアーティストはいない。お互いに何か見つかるかも。');
  String sintoniaLabel(int pct) => switch (pct) {
        >= 70 => _es('Ecos gemelos', 'Twin Echoes', '双子のエコー'),
        >= 45 => _es('En la misma frecuencia', 'On the same frequency', '同じ周波数'),
        >= 20 => _es('Ecos cercanos', 'Close Echoes', '近いエコー'),
        _ => _es('Ecos lejanos', 'Distant Echoes', '遠いエコー'),
      };
  String bondsAgo(Duration d) {
    if (d.inMinutes < 60) return _es('hace ${d.inMinutes.clamp(1, 59)} min', '${d.inMinutes.clamp(1, 59)} min ago', '${d.inMinutes.clamp(1, 59)}分前');
    if (d.inHours < 24) return _es('hace ${d.inHours} h', '${d.inHours} h ago', '${d.inHours}時間前');
    return _es('hace ${d.inDays} d', '${d.inDays} d ago', '${d.inDays}日前');
  }

  // ── Downloaded albums ──
  String get downloadAlbum => _es(
      'Descargar para escuchar sin internet (vistas previas de 30 s)',
      'Download to listen offline (30 s previews)',
      'オフライン用にダウンロード（30秒プレビュー）');
  String downloadAlbumProgress(int pct) => _es('Descargando, $pct%', 'Downloading, $pct%', 'ダウンロード中 $pct%');
  String get downloadAlbumDone => _es(
      'Álbum descargado: sus vistas previas suenan sin internet.',
      'Album downloaded: its previews play offline.',
      'ダウンロード完了。プレビューはオフラインで再生できる。');
  String get downloadAlbumPartial => _es(
      'Se descargó una parte. Lo demás sonará cuando haya internet.',
      'Part of it was downloaded. The rest will play when there is internet.',
      '一部だけダウンロードできた。残りはネット接続時に再生される。');
  String get downloadAlbumNone => _es(
      'Este álbum no tiene vistas previas para descargar.',
      'This album has no previews to download.',
      'このアルバムにはダウンロードできるプレビューがない。');
  String get downloadAlbumSaved => _es('Descargado', 'Downloaded', 'ダウンロード済み');
  String get downloadAlbumRemove => _es('Quitar descarga', 'Remove download', 'ダウンロードを削除');
  String downloadAlbumRemoveBody(String album) => _es(
      'Se borran del teléfono las vistas previas de $album.',
      'The previews of $album are deleted from the phone.',
      '$albumのプレビューを端末から削除する。');
  String get downloadAlbumObserver => _es(
      'Los Observadores no guardan nada. Vuélvete Portador para descargar álbumes.',
      'Observers keep nothing. Become a Bearer to download albums.',
      '観測者は何も残せない。運び手になるとアルバムをダウンロードできる。');

  // ── Spotify Connect ──
  String get devicesTitle => _es('Escuchar en', 'Listen on', '再生する場所');
  String get devicesHint => _es(
      'Los dispositivos con Spotify abierto en tu cuenta: tu PC, un parlante, la tele o la consola. Si falta uno, abre Spotify en él.',
      'The devices with Spotify open on your account: your PC, a speaker, the TV or the console. If one is missing, open Spotify on it.',
      'あなたのアカウントでSpotifyが開いている機器。PC、スピーカー、テレビ、ゲーム機など。見つからない場合は、その機器でSpotifyを開いてください。');
  String get devicesEmpty => _es(
      'No hay dispositivos. Abre Spotify en el que quieras usar y vuelve a buscar.',
      'No devices. Open Spotify on the one you want and search again.',
      '機器が見つからない。使いたい機器でSpotifyを開いて、もう一度探して。');
  String get devicesRefresh => _es('Buscar de nuevo', 'Search again', 'もう一度探す');
  String get devicesPlayingHere => _es('Sonando aquí', 'Playing here', 'ここで再生中');
  String get devicesRestricted => _es('Spotify no deja controlarlo', 'Spotify does not allow controlling it', 'Spotifyで操作できない');
  String devicesMoved(String name) => _es('Sonando en $name', 'Playing on $name', '$nameで再生中');
  String get devicesFailed => _es(
      'Spotify no pudo pasar la música a ese dispositivo.',
      'Spotify could not move the music to that device.',
      'その機器に音楽を移せなかった。');

  // ── Equalizer ──
  String get eqTitle => _es('Ecualizador', 'Equalizer', 'イコライザー');
  String get eqSubtitle => _es(
      'Da forma al sonido de las vistas previas. Con Spotify, usa el ecualizador de Spotify.',
      'Shapes the sound of the previews. With Spotify, use Spotify\'s equalizer.',
      'プレビューの音を整える。Spotifyでは Spotify のイコライザーを使う。');
  String get eqUnavailable => _es(
      'Este teléfono no tiene ecualizador para la app.',
      'This phone has no equalizer for the app.',
      'この端末ではイコライザーを使えない。');
  String eqPresetName(EqPreset p) => switch (p) {
        EqPreset.off => _es('Apagado', 'Off', 'オフ'),
        EqPreset.bass => _es('Graves', 'Bass', '低音'),
        EqPreset.rock => _es('Rock', 'Rock', 'ロック'),
        EqPreset.pop => _es('Pop', 'Pop', 'ポップ'),
        EqPreset.vocal => _es('Voces', 'Vocals', 'ボーカル'),
        EqPreset.electronic => _es('Electrónica', 'Electronic', 'エレクトロ'),
        EqPreset.acoustic => _es('Acústico', 'Acoustic', 'アコースティック'),
        EqPreset.night => _es('Nocturno', 'Night', 'ナイト'),
      };
  String eqPresetHint(EqPreset p) => switch (p) {
        EqPreset.off => _es('El sonido tal como viene.', 'The sound as it comes.', 'そのままの音。'),
        EqPreset.bass => _es('Más golpe abajo.', 'More punch down low.', '低音を厚く。'),
        EqPreset.rock => _es('Graves y agudos arriba.', 'Lows and highs up.', '低音と高音を強く。'),
        EqPreset.pop => _es('Brillo y presencia.', 'Sparkle and presence.', '明るく前に。'),
        EqPreset.vocal => _es('La voz al frente.', 'The voice up front.', '声を前に。'),
        EqPreset.electronic => _es('Bajo profundo y brillo.', 'Deep sub and sparkle.', '深い低音ときらめき。'),
        EqPreset.acoustic => _es('Cálido y natural.', 'Warm and natural.', '温かく自然に。'),
        EqPreset.night => _es('Suave, para tarde en la noche.', 'Soft, for late at night.', '夜更けにやさしく。'),
      };

  /// Where the app's data comes from, as those services ask to be credited.
  String get dataCredits => _es(
      'Música y artistas: Deezer. Canciones y artistas parecidos: Last.fm. Letras: LRCLIB. Clima: Open-Meteo.',
      'Music and artists: Deezer. Similar songs and artists: Last.fm. Lyrics: LRCLIB. Weather: Open-Meteo.',
      '音楽とアーティスト: Deezer。似た曲とアーティスト: Last.fm。歌詞: LRCLIB。天気: Open-Meteo。');

  /// Without an account one is an Observer: no Eco, no levels.
  String get ecoObserver => _es('Observador', 'Observer', '観測者');
  String get ecoObserverShort => _es(
      'Sin Eco ni niveles: solo un Portador los acumula.',
      'No Eco, no levels: only a Bearer gathers them.',
      'エコーもレベルもない。貯められるのは運び手だけ。');
  String get ecoObserverBody => _es(
      'Los Observadores miran Tsuki desde afuera. Su música no llega a la luna: no acumulan Eco, no suben de nivel y no abren nada. Inicia sesión para volverte Portador, y cada canción que escuches empezará a sonar allá arriba.',
      'Observers watch Tsuki from outside. Their music never reaches the moon: they gather no Eco, gain no levels and open nothing. Sign in to become a Bearer, and every song you hear will start to sound up there.',
      '観測者は外からツキを見るだけ。その音楽は月に届かず、エコーも貯まらず、レベルも上がらず、何も開かない。ログインして運び手になれば、聴く曲のすべてがあの空で響き始める。');
  String get ecoObserverAction => _es('Volverme Portador', 'Become a Bearer', '運び手になる');
  String ecoObserverLocked(int level) => _es(
      'Se abre para los Portadores en el nivel $level.',
      'Opens for Bearers at level $level.',
      '運び手のレベル$levelで開く。');
  String get ecoHowTitle => _es('CÓMO SE GANA ECO', 'HOW TO EARN ECO', 'エコーの集め方');
  List<(String, String)> get ecoHowItems => [
        (_es('Cada canción escuchada', 'Each song heard', '1曲ごと'), '+10'),
        (_es('Cada álbum completo', 'Each whole album', 'アルバム1枚まるごと'), '+100'),
        (_es('Cada día con música (más con racha)', 'Each day with music (more on a streak)', '音楽のある日(連続でさらに)'), '+50 / +200'),
        (_es('Cada desafío semanal', 'Each weekly challenge', '週間チャレンジ1つ'), '+150'),
        (_es('Ganar el reto diario', 'Winning the daily game', 'デイリーゲームに勝つ'), '+40'),
        (_es('Despertar un ser etéreo (según su rango)', 'Awakening an ethereal being (by rank)', '霊なる者を目覚めさせる(ランク別)'),
            '+100 / +4.000'),
      ];
  String get ecoAllLevels => _es('LOS 100 NIVELES', 'THE 100 LEVELS', '全100レベル');
  String get ecoLegendTitle => _es('NIVEL 100+ · DIOS SUPREMO', 'LEVEL 100+ · SUPREME GOD', 'レベル100+・至高神');
  String get ecoLegendText => _es(
      'Cuenta la leyenda que más allá del nivel 100 está el nivel de los Dioses Supremos. Muchos Portadores llegaron a escuchar a los seres etéreos; menos llegaron a verlos; contados con los dedos escogieron cruzar y se volvieron seres etéreos. Pero ningún Portador ha alcanzado jamás el nivel de un Dios Supremo. El día que alguien lo logre, el equilibrio se romperá.',
      'Legend says that beyond level 100 lies the level of the Supreme Gods. Many Bearers came to hear the ethereal beings; fewer came to see them; few enough to count on one hand chose to cross over and became ethereal beings. But no Bearer has ever reached the level of a Supreme God. The day someone does, the balance will break.',
      '伝説によれば、レベル100の先には至高神のレベルがある。多くの運び手が霊なる者の声を聴き、より少ない者がその姿を視た。指で数えるほどの者だけが境を越え、霊なる者となった。だが至高神の域に達した運び手はいない。それが成された日、均衡は崩れる。');
  String get ecoLegendNever => _es('Nunca alcanzado', 'Never reached', '未踏');
  String get ecoBalanceBroken => _es('El equilibrio se ha roto.', 'The balance is broken.', '均衡は崩れた。');
  String get ecoPlayerColor => _es('COLOR DEL REPRODUCTOR', 'PLAYER COLOUR', 'プレーヤーの色');
  String get ecoColorDefault => _es('Rojo Tsuki', 'Tsuki red', 'ツキの赤');
  String get ecoWhisper => _es('SU SUSURRO', 'ITS WHISPER', 'そのささやき');
  String ecoWhisperLocked(int level) =>
      _es('En el nivel $level podrás escuchar su voz.', 'At level $level you will hear its voice.', 'レベル$levelでその声が聴こえる。');
  String ecoLegendAmount(int eco) => '${ecoAmount(eco).replaceAll(' Eco', '')} / ??????? Eco';
  String get ecoChoicePending => _es('Tu elección te espera', 'Your choice awaits', 'あなたの選択が待っている');

  // ── Level 100: the choice ──
  List<String> get ascensionCall => language == AppLanguage.es
      ? const [
          'Has llegado a este punto siendo un Portador de niveles incomprendidos.',
          'La Luna Madre se regocija con tu Eco.',
          'Es la señal. Es el momento de tu elección:',
          'seguir siendo un ser acumulador de Eco,',
          'o traspasar la muralla de lo lógico y viajar hasta el centro del universo,',
          'para así volverte...',
        ]
      : const [
          'You have come this far as a Bearer of levels beyond understanding.',
          'The Mother Moon rejoices in your Echo.',
          'It is the sign. It is the moment of your choice:',
          'to remain a being who gathers Echo,',
          'or to pass through the wall of the logical and travel to the centre of the universe,',
          'and so become...',
        ];
  String get ascensionBeing => _es('Un Ser Etéreo', 'An Ethereal Being', '霊なる者');
  String get ascensionSer => _es('SER', 'BE', '成る');
  String get ascensionNoSer => _es('NO SER', 'NOT BE', '成らない');
  String get ascensionWarningTitle => _es('ADVERTENCIA', 'WARNING', '警告');
  String get ascensionWarning => _es(
      'Si decides mantener tu forma de Portador, no podrás transformarte nunca más en un Ser Etéreo. Esta es tu elección. Seguirás gozando de los privilegios de un Portador de niveles inconmensurables.',
      'If you decide to keep your form as a Bearer, you will never be able to become an Ethereal Being. This is your choice. You will keep enjoying the privileges of a Bearer of immeasurable levels.',
      '運び手の姿を保つなら、二度と霊なる者にはなれない。これはあなたの選択だ。計り知れぬレベルの運び手としての特権は続く。');
  String get ascensionKeepForm => _es('Mantener mi forma', 'Keep my form', '姿を保つ');
  String get ascensionBack => _es('Volver', 'Back', '戻る');
  String get ascensionLater => _es('Más tarde', 'Later', 'あとで');
  String get ascensionNameTitle =>
      _es('¿Cómo se llamará tu máscara etérea?', 'What will your ethereal mask be called?', 'あなたの霊の面の名は?');
  String get ascensionNameHint => _es(
      'Este nombre viajará hasta el centro del universo, donde se forjará tu máscara.',
      'This name will travel to the centre of the universe, where your mask will be forged.',
      'この名は宇宙の中心へ届き、そこであなたの面が鍛えられる。');
  String get ascensionCross => _es('CRUZAR', 'CROSS', '越える');
  String get ascensionCrossed => _es(
      'Has traspasado la muralla de lo lógico. Ya no escuchas la música: eres parte de ella. Tu máscara etérea se está forjando en el centro del universo, con todo lo que escuchaste. La Luna Madre te la entregará cuando esté lista.',
      'You have passed through the wall of the logical. You no longer hear music: you are part of it. Your ethereal mask is being forged at the centre of the universe, with everything you ever heard. The Mother Moon will give it to you when it is ready.',
      'あなたは論理の壁を越えた。もう音楽を聴くのではない。その一部なのだ。あなたの霊の面は、聴いてきたすべてと共に宇宙の中心で鍛えられている。');
  String get ascensionStayed => _es(
      'Sigues siendo Portador. Tu Eco seguirá cayendo sobre Tsuki como una estrella, y los seres etéreos sabrán siempre que pudiste cruzar y elegiste quedarte.',
      'You remain a Bearer. Your Echo will keep falling on Tsuki like a star, and the ethereal beings will always know you could have crossed and chose to stay.',
      'あなたは運び手のままだ。あなたのエコーは星のようにツキに降り続け、霊なる者たちは、あなたが越えられたのに留まったことを忘れない。');
  String get ascensionDone => _es('Continuar', 'Continue', '続ける');

  String get a11yEcoLevels => _es('Abrir los niveles de Eco', 'Open the Eco levels', 'エコーレベルを開く');

  // ── Artist radio ──
  String get artistRadioButton => switch (language) {
        AppLanguage.es => 'RADIO',
        AppLanguage.en => 'RADIO',
        AppLanguage.ja => 'ラジオ',
      };
  String artistRadioOf(String artist) => switch (language) {
        AppLanguage.es => 'Radio de $artist',
        AppLanguage.en => '$artist radio',
        AppLanguage.ja => '$artistのラジオ',
      };
  String artistRadioStarted(String artist) => switch (language) {
        AppLanguage.es => 'Radio de $artist en marcha: sus éxitos y artistas parecidos',
        AppLanguage.en => '$artist radio is on: their hits and artists like them',
        AppLanguage.ja => '$artistのラジオを開始:ヒット曲と似たアーティスト',
      };
  String a11yArtistRadio(String artist) => switch (language) {
        AppLanguage.es => 'Iniciar la radio de $artist',
        AppLanguage.en => 'Start $artist radio',
        AppLanguage.ja => '$artistのラジオを開始',
      };
  /// Why a song is in an artist radio.
  String radioReasonArtistTop(String artist) => switch (language) {
        AppLanguage.es => 'Lo más escuchado de $artist',
        AppLanguage.en => 'Top song by $artist',
        AppLanguage.ja => '$artistの人気曲',
      };
  String radioReasonRelated(String artist) => switch (language) {
        AppLanguage.es => 'Parecido a $artist',
        AppLanguage.en => 'Like $artist',
        AppLanguage.ja => '$artistに似ている',
      };

  // ── Daily streak ──
  String get streakTitle => switch (language) {
        AppLanguage.es => 'RACHA',
        AppLanguage.en => 'STREAK',
        AppLanguage.ja => '連続記録',
      };
  /// "DAY" / "DAYS" under the big number.
  String streakUnit(int n) => switch (language) {
        AppLanguage.es => n == 1 ? 'DÍA' : 'DÍAS',
        AppLanguage.en => n == 1 ? 'DAY' : 'DAYS',
        AppLanguage.ja => '日',
      };
  String streakDays(int n) => switch (language) {
        AppLanguage.es => n == 1 ? '1 día' : '$n días',
        AppLanguage.en => n == 1 ? '1 day' : '$n days',
        AppLanguage.ja => '$n日',
      };
  String get streakInARow => switch (language) {
        AppLanguage.es => 'seguidos con música',
        AppLanguage.en => 'in a row with music',
        AppLanguage.ja => '連続で音楽',
      };
  /// Where today stands: [state] is a StreakState's name.
  String streakStateText(String state, {int shields = 0}) => switch (language) {
        AppLanguage.es => switch (state) {
            'done' => 'Hoy ya sumaste. Vuelve mañana para seguir.',
            'atRisk' => 'Escucha una canción hoy para mantenerla.',
            'shielded' => 'Un escudo lunar cubre el día que faltaste. Escucha hoy para seguir.',
            'lost' => 'Tu racha se apagó. Una canción hoy empieza otra.',
            _ => 'Escucha una canción al día para empezar tu racha.',
          },
        AppLanguage.en => switch (state) {
            'done' => 'Today counts. Come back tomorrow to keep going.',
            'atRisk' => 'Play one song today to keep it alive.',
            'shielded' => 'A moon shield covers the day you missed. Listen today to keep going.',
            'lost' => 'Your streak went out. One song today starts a new one.',
            _ => 'Play one song a day to start your streak.',
          },
        AppLanguage.ja => switch (state) {
            'done' => '今日の分は達成。また明日。',
            'atRisk' => '今日1曲聴けば記録が続きます。',
            'shielded' => '月の盾が休んだ日を守りました。今日聴いて続けよう。',
            'lost' => '記録が途切れました。今日の1曲から再スタート。',
            _ => '毎日1曲聴いて記録を始めよう。',
          },
      };
  /// The short line on Home.
  String streakStateShort(String state) => switch (language) {
        AppLanguage.es => switch (state) {
            'done' => 'Hoy ya sumaste',
            'atRisk' => 'Escucha algo hoy para no perderla',
            'shielded' => 'Te cubre un escudo lunar',
            'lost' => 'Empieza una nueva hoy',
            _ => 'Una canción al día',
          },
        AppLanguage.en => switch (state) {
            'done' => 'Today counts',
            'atRisk' => 'Play something today to keep it',
            'shielded' => 'A moon shield has you covered',
            'lost' => 'Start a new one today',
            _ => 'One song a day',
          },
        AppLanguage.ja => switch (state) {
            'done' => '今日は達成',
            'atRisk' => '今日聴いて記録をキープ',
            'shielded' => '月の盾が守っています',
            'lost' => '今日から再スタート',
            _ => '1日1曲',
          },
      };
  String get streakBest => switch (language) {
        AppLanguage.es => 'MEJOR RACHA',
        AppLanguage.en => 'BEST STREAK',
        AppLanguage.ja => '最高記録',
      };
  String get streakShields => switch (language) {
        AppLanguage.es => 'ESCUDOS',
        AppLanguage.en => 'SHIELDS',
        AppLanguage.ja => '盾',
      };
  String get streakThisMonth => switch (language) {
        AppLanguage.es => 'DÍAS ESTE MES',
        AppLanguage.en => 'DAYS THIS MONTH',
        AppLanguage.ja => '今月の日数',
      };
  String get streakCalendar => switch (language) {
        AppLanguage.es => 'ÚLTIMAS 5 SEMANAS',
        AppLanguage.en => 'LAST 5 WEEKS',
        AppLanguage.ja => '直近5週間',
      };
  /// Monday to Sunday, one letter each.
  List<String> get streakWeekdays => switch (language) {
        AppLanguage.es => const ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
        AppLanguage.en => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        AppLanguage.ja => const ['月', '火', '水', '木', '金', '土', '日'],
      };
  String get streakGoalsTitle => switch (language) {
        AppLanguage.es => 'METAS',
        AppLanguage.en => 'GOALS',
        AppLanguage.ja => '目標',
      };
  String streakGoalLeft(int left) => switch (language) {
        AppLanguage.es => left == 1 ? 'falta 1 día' : 'faltan $left días',
        AppLanguage.en => left == 1 ? '1 day to go' : '$left days to go',
        AppLanguage.ja => 'あと$left日',
      };
  String get streakGoalReached => switch (language) {
        AppLanguage.es => 'Lograda',
        AppLanguage.en => 'Reached',
        AppLanguage.ja => '達成',
      };
  String get streakShieldTitle => switch (language) {
        AppLanguage.es => 'ESCUDO LUNAR',
        AppLanguage.en => 'MOON SHIELD',
        AppLanguage.ja => '月の盾',
      };
  String streakShieldText(int every, int max) => switch (language) {
        AppLanguage.es =>
          'Cada $every días seguidos ganas un escudo (máximo $max). Si un día no escuchas nada, el escudo lo cubre y tu racha sigue.',
        AppLanguage.en =>
          'Every $every days in a row you earn a shield (up to $max). If you miss a day, the shield covers it and your streak goes on.',
        AppLanguage.ja => '$every日連続ごとに盾を1つ獲得(最大$max個)。聴けなかった日は盾が守り、記録は続きます。',
      };
  String get streakReminderTitle => switch (language) {
        AppLanguage.es => 'Recordatorio suave',
        AppLanguage.en => 'Gentle reminder',
        AppLanguage.ja => 'やさしいリマインダー',
      };
  String streakReminderSubtitle(int hour) => switch (language) {
        AppLanguage.es =>
          'Un solo aviso a las $hour:00, sin sonido, solo si ese día aún no escuchas nada.',
        AppLanguage.en => 'One notice at $hour:00, silent, only if you haven\'t played anything that day.',
        AppLanguage.ja => '$hour:00に1回だけ、無音で。その日まだ聴いていない時だけ。',
      };
  String streakNotifTitle(int n) => switch (language) {
        AppLanguage.es => 'Tu racha de $n días sigue viva',
        AppLanguage.en => 'Your $n-day streak is still alive',
        AppLanguage.ja => '$n日連続の記録はまだ続いています',
      };
  String get streakNotifBody => switch (language) {
        AppLanguage.es => 'Una canción basta para mantenerla hoy.',
        AppLanguage.en => 'One song is enough to keep it today.',
        AppLanguage.ja => '今日は1曲聴くだけでキープできます。',
      };
  String get streakChannelName => switch (language) {
        AppLanguage.es => 'Racha diaria',
        AppLanguage.en => 'Daily streak',
        AppLanguage.ja => '連続記録',
      };
  String get streakChannelDescription => switch (language) {
        AppLanguage.es => 'Un aviso suave cuando tu racha está por apagarse',
        AppLanguage.en => 'A gentle notice when your streak is about to go out',
        AppLanguage.ja => '記録が途切れそうな時のやさしいお知らせ',
      };
  String get a11yStreak => switch (language) {
        AppLanguage.es => 'Abrir tu racha diaria',
        AppLanguage.en => 'Open your daily streak',
        AppLanguage.ja => '連続記録を開く',
      };

  String get loreTitle => 'TSUKI LORE';
  String get loreSubtitle => switch (language) {
        AppLanguage.es => 'El Eco es conocimiento: cada nivel revela más de Tsuki',
        AppLanguage.en => 'Echo is knowledge: every level reveals more of Tsuki',
        AppLanguage.ja => 'エコーは知識。レベルが上がるほどツキの真実が明かされる',
      };
  String get loreButton => switch (language) {
        AppLanguage.es => 'TSUKI LORE · La historia de los seres etéreos',
        AppLanguage.en => 'TSUKI LORE · The story of the ethereal beings',
        AppLanguage.ja => 'TSUKI LORE・霊なる者の物語',
      };
  String loreChaptersOpen(int open, int total) => switch (language) {
        AppLanguage.es => '$open de $total capítulos abiertos',
        AppLanguage.en => '$open of $total chapters open',
        AppLanguage.ja => '$total章中$open章',
      };
  String loreTomo(String numeral) => switch (language) {
        AppLanguage.es => 'TOMO $numeral',
        AppLanguage.en => 'VOLUME $numeral',
        AppLanguage.ja => '第$numeral巻',
      };
  String loreChapter(String numeral) => switch (language) {
        AppLanguage.es => numeral == '0' ? 'PRÓLOGO' : 'CAPÍTULO $numeral',
        AppLanguage.en => numeral == '0' ? 'PROLOGUE' : 'CHAPTER $numeral',
        AppLanguage.ja => numeral == '0' ? '序章' : '第$numeral章',
      };
  String get loreComingSoon => switch (language) {
        AppLanguage.es => 'Próximamente',
        AppLanguage.en => 'Coming soon',
        AppLanguage.ja => '近日公開',
      };
  String get loreComingSoonHint => switch (language) {
        AppLanguage.es => 'Este tomo llegará en una próxima actualización.',
        AppLanguage.en => 'This volume arrives in a future update.',
        AppLanguage.ja => 'この巻は今後のアップデートで公開されます。',
      };
  String loreNeedMasks(int n) => switch (language) {
        AppLanguage.es => n == 1 ? 'Despierta tu primer ser etéreo' : 'Despierta $n seres etéreos',
        AppLanguage.en => n == 1 ? 'Wake your first ethereal being' : 'Wake $n ethereal beings',
        AppLanguage.ja => '面を$n枚目覚めさせる',
      };
  String loreNeedFaction(String clan) => switch (language) {
        AppLanguage.es => 'Despierta un ser de $clan',
        AppLanguage.en => 'Wake a being of $clan',
        AppLanguage.ja => '$clanの面を1枚目覚めさせる',
      };
  String get loreNeedUltra => switch (language) {
        AppLanguage.es => 'Despierta a uno de los Ocho Ultras',
        AppLanguage.en => 'Wake one of the Eight Ultras',
        AppLanguage.ja => '八つのウルトラの1つを目覚めさせる',
      };
  String loreNeedDivine(int n) => switch (language) {
        AppLanguage.es => n == 1 ? 'Despierta una Cara divina' : 'Despierta $n Caras divinas',
        AppLanguage.en => n == 1 ? 'Wake a divine Face' : 'Wake $n divine Faces',
        AppLanguage.ja => '神の面を$n枚目覚めさせる',
      };
  String get loreNeedGod => switch (language) {
        AppLanguage.es => 'Despierta a un Dios Supremo',
        AppLanguage.en => 'Wake a Supreme God',
        AppLanguage.ja => '至高神を目覚めさせる',
      };
  String get loreMembers => switch (language) {
        AppLanguage.es => 'MIEMBROS DEL CLAN',
        AppLanguage.en => 'CLAN MEMBERS',
        AppLanguage.ja => '一族の面',
      };
  String get loreLeader => switch (language) {
        AppLanguage.es => 'Líder',
        AppLanguage.en => 'Leader',
        AppLanguage.ja => '長',
      };
  String get loreRival => switch (language) {
        AppLanguage.es => 'Rival',
        AppLanguage.en => 'Rival',
        AppLanguage.ja => '宿敵',
      };
  String get loreSecret => switch (language) {
        AppLanguage.es => 'SECRETO DEL CLAN',
        AppLanguage.en => 'CLAN SECRET',
        AppLanguage.ja => '一族の秘密',
      };
  String loreSecretLocked(int have, int total) => switch (language) {
        AppLanguage.es => 'Despierta a todo el clan para conocer su secreto ($have/$total).',
        AppLanguage.en => 'Wake the whole clan to learn its secret ($have/$total).',
        AppLanguage.ja => '一族すべてを目覚めさせると秘密が明かされる（$have/$total）。',
      };
  String get loreReward => switch (language) {
        AppLanguage.es => 'MÁSCARA DEL CLAN',
        AppLanguage.en => 'CLAN MASK',
        AppLanguage.ja => '一族の面',
      };
  String get loreRewardHint => switch (language) {
        AppLanguage.es => 'Despierta a todo el clan y este ser despertará con él.',
        AppLanguage.en => 'Wake the whole clan and this being will wake with it.',
        AppLanguage.ja => '一族すべてを目覚めさせると、この面も目覚める。',
      };
  String get loreBonds => switch (language) {
        AppLanguage.es => 'VÍNCULOS',
        AppLanguage.en => 'BONDS',
        AppLanguage.ja => '絆',
      };
  String get loreBondLocked => switch (language) {
        AppLanguage.es => 'Despierta a todos estos seres para conocer su historia.',
        AppLanguage.en => 'Wake all these beings to learn their story.',
        AppLanguage.ja => 'これらの面をすべて目覚めさせると物語が明かされる。',
      };
  String get loreFaceVeiled => switch (language) {
        AppLanguage.es => 'Esta Cara aún no se ha mostrado.',
        AppLanguage.en => 'This Face has not shown itself yet.',
        AppLanguage.ja => 'この面はまだ姿を見せていない。',
      };
  String loreBondKind(String kind) => switch (language) {
        AppLanguage.es => switch (kind) {
            'rival' => 'RIVALES',
            'family' => 'FAMILIA',
            'mentor' => 'MAESTRO Y DISCÍPULO',
            'soul' => 'UNA SOLA ALMA',
            _ => 'PACTO',
          },
        AppLanguage.en => switch (kind) {
            'rival' => 'RIVALS',
            'family' => 'FAMILY',
            'mentor' => 'MASTER AND STUDENT',
            'soul' => 'ONE SOUL',
            _ => 'PACT',
          },
        AppLanguage.ja => switch (kind) {
            'rival' => '宿敵',
            'family' => '血縁',
            'mentor' => '師弟',
            'soul' => '同魂',
            _ => '盟約',
          },
      };
  String loreClanOf(String clan) => switch (language) {
        AppLanguage.es => 'Clan: $clan',
        AppLanguage.en => 'Clan: $clan',
        AppLanguage.ja => '一族：$clan',
      };

  /// "SÚPER RARA" for SR.
  String maskRarityName(MaskRarity r) => _l.maskRarityName(r.name);

  /// The tier under a being's name: its rarity, or its own kind for the
  /// divine ones and the Chosen.
  String maskTierName(OniMask m) => m.chosen
      ? _es('LA ELEGIDA', 'THE CHOSEN', '選ばれし者')
      : m.divine
          ? _es('DIVINA', 'DIVINE', '神')
          : maskRarityName(m.rarity);

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
  String get hapticsSettingTitle => _l.hapticsSettingTitle;
  String get hapticsSettingSubtitle => _l.hapticsSettingSubtitle;
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

  String get a11yLoading => _l.a11yLoading;
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
  /// A challenge, in words ("Escucha 15 canciones de rock").
  String weeklyChallengeText(WeeklyChallenge c) => c.kind == ChallengeKind.style
      ? _styleChallenge(c.style!, c.target)
      : _challengeText(c.kind, c.target);

  String _styleChallenge(MusicStyle style, int n) => switch (language) {
        AppLanguage.es => 'Escucha $n canciones de ${musicStyleName(style)}',
        AppLanguage.en => 'Listen to $n ${musicStyleName(style)} songs',
        AppLanguage.ja => '${musicStyleName(style)}を$n曲聴く',
      };

  /// A style family's name, as challenges and masks say it.
  String musicStyleName(MusicStyle s) => switch (language) {
        AppLanguage.es => switch (s) {
            MusicStyle.metal => 'metal',
            MusicStyle.rock => 'rock',
            MusicStyle.punk => 'punk',
            MusicStyle.electronic => 'electrónica',
            MusicStyle.hiphop => 'hip-hop',
            MusicStyle.pop => 'pop',
            MusicStyle.latin => 'urbano latino',
            MusicStyle.jpop => 'J-pop o anime',
            MusicStyle.kpop => 'K-pop',
            MusicStyle.lofi => 'lo-fi',
            MusicStyle.jazz => 'jazz o soul',
            MusicStyle.classical => 'clásica o instrumental',
            MusicStyle.synthwave => 'synthwave',
            MusicStyle.vocaloid => 'Vocaloid o hyperpop',
            MusicStyle.folk => 'folk',
            MusicStyle.indie => 'indie',
          },
        AppLanguage.en => switch (s) {
            MusicStyle.metal => 'metal',
            MusicStyle.rock => 'rock',
            MusicStyle.punk => 'punk',
            MusicStyle.electronic => 'electronic',
            MusicStyle.hiphop => 'hip-hop',
            MusicStyle.pop => 'pop',
            MusicStyle.latin => 'Latin urban',
            MusicStyle.jpop => 'J-pop or anime',
            MusicStyle.kpop => 'K-pop',
            MusicStyle.lofi => 'lo-fi',
            MusicStyle.jazz => 'jazz or soul',
            MusicStyle.classical => 'classical or instrumental',
            MusicStyle.synthwave => 'synthwave',
            MusicStyle.vocaloid => 'Vocaloid or hyperpop',
            MusicStyle.folk => 'folk',
            MusicStyle.indie => 'indie',
          },
        AppLanguage.ja => switch (s) {
            MusicStyle.metal => 'メタル',
            MusicStyle.rock => 'ロック',
            MusicStyle.punk => 'パンク',
            MusicStyle.electronic => 'エレクトロニック',
            MusicStyle.hiphop => 'ヒップホップ',
            MusicStyle.pop => 'ポップ',
            MusicStyle.latin => 'ラテン・アーバン',
            MusicStyle.jpop => 'J-POP・アニメ',
            MusicStyle.kpop => 'K-POP',
            MusicStyle.lofi => 'ローファイ',
            MusicStyle.jazz => 'ジャズ・ソウル',
            MusicStyle.classical => 'クラシック・インスト',
            MusicStyle.synthwave => 'シンセウェイヴ',
            MusicStyle.vocaloid => 'ボカロ・ハイパーポップ',
            MusicStyle.folk => 'フォーク',
            MusicStyle.indie => 'インディー',
          },
      };

  String _challengeText(ChallengeKind kind, int n) => switch (language) {
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
            ChallengeKind.style => 'Escucha $n canciones',
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
            ChallengeKind.style => 'Listen to $n songs',
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
            ChallengeKind.style => '$n曲聴く',
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

  /// The week's two prizes: an R for two challenges, an SR for all three.
  String weeklyPrizes(String? rMask, String? srMask) => switch (language) {
        AppLanguage.es => [
            if (rMask != null) '2 desafíos: «$rMask»',
            if (srMask != null) '3 desafíos: «$srMask»',
          ].join(' · '),
        AppLanguage.en => [
            if (rMask != null) '2 challenges: “$rMask”',
            if (srMask != null) '3 challenges: “$srMask”',
          ].join(' · '),
        AppLanguage.ja => [
            if (rMask != null) '2つ達成：「$rMask」',
            if (srMask != null) '3つ達成：「$srMask」',
          ].join('・'),
      };

  String get weeklyPrizesHint => switch (language) {
        AppLanguage.es => 'Seres etéreos que solo despiertan con los desafíos semanales.',
        AppLanguage.en => 'Ethereal beings that only wake with the weekly challenges.',
        AppLanguage.ja => '週間チャレンジ限定の面。',
      };

  String get weeklyAllCollected => switch (language) {
        AppLanguage.es => 'Ya despertaste a todos los seres semanales. ¡Sigue jugando por diversión!',
        AppLanguage.en => 'You have woken every weekly being. Keep playing for fun!',
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

  String get wrappedTopAlbumsLabel => switch (language) {
        AppLanguage.es => 'TUS ÁLBUMES',
        AppLanguage.en => 'YOUR ALBUMS',
        AppLanguage.ja => 'あなたのアルバム',
      };

  /// "8 canciones distintas" under an album.
  String wrappedAlbumSongs(int count) => switch (language) {
        AppLanguage.es => count == 1 ? '1 canción' : '$count canciones distintas',
        AppLanguage.en => count == 1 ? '1 song' : '$count different songs',
        AppLanguage.ja => '$count曲',
      };

  String get wrappedCompletedAlbums => switch (language) {
        AppLanguage.es => 'ESCUCHASTE COMPLETOS',
        AppLanguage.en => 'HEARD FROM START TO END',
        AppLanguage.ja => '全曲聴いたアルバム',
      };

  String wrappedCompletedCount(int count) => switch (language) {
        AppLanguage.es => count == 1 ? '1 álbum entero, todas sus canciones' : '$count álbumes enteros, todas sus canciones',
        AppLanguage.en => count == 1 ? '1 whole album, every song' : '$count whole albums, every song',
        AppLanguage.ja => '$count枚のアルバムを全曲',
      };

  String get wrappedStreakLabel => switch (language) {
        AppLanguage.es => 'RACHA',
        AppLanguage.en => 'STREAK',
        AppLanguage.ja => '連続',
      };

  /// "12 d" in the recap card.
  String wrappedStreakValue(int days) => switch (language) {
        AppLanguage.ja => '$days日',
        _ => '$days d',
      };

  /// "Racha más larga: 12 días seguidos, desde el 3 de octubre de 2026".
  String wrappedStreak(int days, DateTime? from) {
    final since = from == null ? null : longDate(from);
    return switch (language) {
      AppLanguage.es => 'Racha más larga: $days días seguidos${since == null ? '' : ', desde el $since'}',
      AppLanguage.en => 'Longest streak: $days days in a row${since == null ? '' : ', from $since'}',
      AppLanguage.ja => '最長$days日連続${since == null ? '' : '（$sinceから）'}',
    };
  }

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
  String get permAllow => _l.permAllow;
  String get permNotNow => _l.permNotNow;
  String get permOpenSettings => _l.permOpenSettings;
  String get permNotifTitle => _l.permNotifTitle;
  String get permNotifBody => _l.permNotifBody;
  String get permNotifBlocked => _l.permNotifBlocked;
  String get permBackgroundTitle => _l.permBackgroundTitle;
  String get permBackgroundBody => _l.permBackgroundBody;

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

  String get lyricsTranslateTo => _l.lyricsTranslateTo;

  String lyricsSameLanguage(String language) => _l.lyricsSameLanguage(language);

  String get lyricsUnknownLanguage => _l.lyricsUnknownLanguage;

  String get almostCompleteTitle => _l.almostCompleteTitle;
  String almostCompleteMissing(int count) => _l.almostCompleteMissing(count);
  String a11yAlmostComplete(String album, String artist, String missing) =>
      _l.a11yAlmostComplete(album, artist, missing);
  String becauseYouCompleted(String album) => _l.becauseYouCompleted(album);

  String get searchSuggestions => _l.searchSuggestions;
  String a11ySearchSuggestion(String query) => _l.a11ySearchSuggestion(query);
  String get didYouMeanPrefix => _l.didYouMeanPrefix;
  String a11yDidYouMean(String query) => _l.a11yDidYouMean(query);
  String get searchYourArtists => _l.searchYourArtists;
  String get exploreGenres => _l.exploreGenres;
  String get genreArtists => _l.genreArtists;
  String get genreTopTracks => _l.genreTopTracks;
  String get genreEmpty => _l.genreEmpty;
}
