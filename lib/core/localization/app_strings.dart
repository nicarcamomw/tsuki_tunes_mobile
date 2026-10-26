import '../../models/oni_mask.dart';
import '../../services/ambient_sound_generator.dart';
import '../../services/moon_calculator.dart';
import 'app_language.dart';

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  static AppStrings of(AppLanguage language) => AppStrings(language);

  // --- Bottom Navigation ---
  String get navHome => language.navHome;
  String get navSearch => language.navSearch;
  String get navLibrary => language.navLibrary;

  String navHudSubtitle(int index) {
    if (language == AppLanguage.ja) {
      return switch (index) {
        0 => 'SYS.01 // HOME',
        1 => 'NET.02 // SCAN',
        _ => 'MEM.03 // VAULT',
      };
    }
    return switch (index) {
      0 => 'ホーム // 01',
      1 => '探索 // 02',
      _ => '保管庫 // 03',
    };
  }

  // --- Telemetría Militar Cyberpunk ---
  String get homeTelemetry => switch (language) {
        AppLanguage.es => '◈ 軍事通信 // TSUKI.SYS.01',
        AppLanguage.en => '◈ NEURAL LINK // TSUKI.SYS.01',
        AppLanguage.ja => '◈ サイバー端末 // TSUKI.SYS.01',
      };

  String get searchTelemetry => switch (language) {
        AppLanguage.es => '◈ 探索 // FREQ.SCAN.02',
        AppLanguage.en => '◈ NEURAL SCAN // FREQ.02',
        AppLanguage.ja => '◈ 周波数探索 // SCAN.02',
      };

  String get libraryTelemetry => switch (language) {
        AppLanguage.es => '◈ 保管庫 // DATA.VAULT.03',
        AppLanguage.en => '◈ DATA VAULT // ARCHIVE.03',
        AppLanguage.ja => '◈ 音声保管庫 // VAULT.03',
      };

  // --- Home Screen ---
  String get homeHeader => switch (language) {
        AppLanguage.es => 'INICIO // 01',
        AppLanguage.en => 'HOME // 01',
        AppLanguage.ja => 'ホーム // 01',
      };

  String get statsTracks => switch (language) {
        AppLanguage.es => 'CANCIONES',
        AppLanguage.en => 'TRACKS',
        AppLanguage.ja => '楽曲',
      };

  String get statsArtists => switch (language) {
        AppLanguage.es => 'ARTISTAS',
        AppLanguage.en => 'ARTISTS',
        AppLanguage.ja => 'アーティスト',
      };

  String get statsAlbums => switch (language) {
        AppLanguage.es => 'ÁLBUMES',
        AppLanguage.en => 'ALBUMS',
        AppLanguage.ja => 'アルバム',
      };

  String get statsTopArtist => switch (language) {
        AppLanguage.es => 'ARTISTA TOP',
        AppLanguage.en => 'TOP ARTIST',
        AppLanguage.ja => '代表アーティスト',
      };

  String get topArtistsTitle => switch (language) {
        AppLanguage.es => 'TOP ARTISTAS MÁS ESCUCHADOS',
        AppLanguage.en => 'MOST PLAYED ARTISTS',
        AppLanguage.ja => '高頻度再生アーティスト',
      };

  String get latestReleasesTitle => switch (language) {
        AppLanguage.es => 'ÚLTIMOS LANZAMIENTOS PARA TI',
        AppLanguage.en => 'LATEST RELEASES FOR YOU',
        AppLanguage.ja => 'あなたへの最新リリース',
      };

  String get recommendedTitle => switch (language) {
        AppLanguage.es => 'RECOMENDACIONES DEL SISTEMA',
        AppLanguage.en => 'SYSTEM RECOMMENDATIONS',
        AppLanguage.ja => 'システム推薦カタログ',
      };

  // --- Search Screen ---
  String get searchTitle => switch (language) {
        AppLanguage.es => 'Buscar',
        AppLanguage.en => 'Search',
        AppLanguage.ja => '探索',
      };

  String get searchSubtitle => switch (language) {
        AppLanguage.es => 'Artistas, álbumes y canciones',
        AppLanguage.en => 'Artists, albums and songs',
        AppLanguage.ja => 'アーティスト・アルバム・楽曲',
      };

  String get recentSearches => switch (language) {
        AppLanguage.es => 'BÚSQUEDAS RECIENTES',
        AppLanguage.en => 'RECENT SEARCHES',
        AppLanguage.ja => '最近の検索',
      };

  String get clearHistory => switch (language) {
        AppLanguage.es => 'LIMPIAR',
        AppLanguage.en => 'CLEAR',
        AppLanguage.ja => 'クリア',
      };

  String get searchHint => switch (language) {
        AppLanguage.es => '¿Qué quieres escuchar?',
        AppLanguage.en => 'What do you want to hear?',
        AppLanguage.ja => '何を聴きますか？',
      };

  String get tabAll => switch (language) {
        AppLanguage.es => 'Todo',
        AppLanguage.en => 'All',
        AppLanguage.ja => 'すべて',
      };

  String get tabArtists => switch (language) {
        AppLanguage.es => 'Artistas',
        AppLanguage.en => 'Artists',
        AppLanguage.ja => 'アーティスト',
      };

  String get tabAlbums => switch (language) {
        AppLanguage.es => 'Álbumes',
        AppLanguage.en => 'Albums',
        AppLanguage.ja => 'アルバム',
      };

  String get tabTracks => switch (language) {
        AppLanguage.es => 'Canciones',
        AppLanguage.en => 'Tracks',
        AppLanguage.ja => '楽曲',
      };

  String get tabFavorites => switch (language) {
        AppLanguage.es => 'Favoritos',
        AppLanguage.en => 'Favorites',
        AppLanguage.ja => 'お気に入り',
      };

  String get emptyStateTitle => switch (language) {
        AppLanguage.es => 'EXPLORA LA BASE DE DATOS',
        AppLanguage.en => 'EXPLORE THE DATABASE',
        AppLanguage.ja => 'データベース探索',
      };

  String get emptyStateSubtitle => switch (language) {
        AppLanguage.es => 'Escribe el nombre de un artista, canción o álbum',
        AppLanguage.en => 'Type the name of an artist, song or album',
        AppLanguage.ja => 'アーティスト、曲名、アルバムを入力してください',
      };

  String noResultsFor(String query) => switch (language) {
        AppLanguage.es => 'No se encontraron resultados para "$query"',
        AppLanguage.en => 'No results found for "$query"',
        AppLanguage.ja => '「$query」に一致する結果が見つかりませんでした',
      };

  String get noResults => switch (language) {
        AppLanguage.es => 'No se encontraron resultados',
        AppLanguage.en => 'No results found',
        AppLanguage.ja => '結果が見つかりませんでした',
      };

  String get confirm => switch (language) {
        AppLanguage.es => 'CONFIRMAR',
        AppLanguage.en => 'CONFIRM',
        AppLanguage.ja => '確認',
      };

  // --- Library Screen ---
  String get libraryTitle => switch (language) {
        AppLanguage.es => 'Mi Biblioteca',
        AppLanguage.en => 'My Library',
        AppLanguage.ja => 'コレクション',
      };

  String get librarySubtitle => switch (language) {
        AppLanguage.es => 'Álbumes y canciones escuchadas',
        AppLanguage.en => 'Albums and tracks listened',
        AppLanguage.ja => '聴取済みアルバムと楽曲',
      };

  String libraryStats(int tracks, int albums) => switch (language) {
        AppLanguage.es => '$tracks canciones en $albums álbumes',
        AppLanguage.en => '$tracks tracks in $albums albums',
        AppLanguage.ja => '$albums 枚のアルバム・$tracks 曲',
      };

  String showMore(int remaining) => switch (language) {
        AppLanguage.es => 'VER MÁS ($remaining restantes)',
        AppLanguage.en => 'VIEW MORE ($remaining remaining)',
        AppLanguage.ja => 'さらに表示 (他 $remaining 件)',
      };

  String get filterHint => switch (language) {
        AppLanguage.es => 'Filtrar álbum o artista...',
        AppLanguage.en => 'Filter album or artist...',
        AppLanguage.ja => 'アルバム・アーティストを絞り込み...',
      };

  String get sortRecent => switch (language) {
        AppLanguage.es => 'Más recientes',
        AppLanguage.en => 'Most recent',
        AppLanguage.ja => '最新順',
      };

  String get sortAz => switch (language) {
        AppLanguage.es => 'A - Z',
        AppLanguage.en => 'A - Z',
        AppLanguage.ja => '五十音順 (A-Z)',
      };

  String get sortArtist => switch (language) {
        AppLanguage.es => 'Por Artista',
        AppLanguage.en => 'By Artist',
        AppLanguage.ja => 'アーティスト別',
      };

  String get listenedTracksLabel => switch (language) {
        AppLanguage.es => 'Temas Escuchados',
        AppLanguage.en => 'Tracks Listened',
        AppLanguage.ja => '聴取済み楽曲',
      };

  String get albumsLabel => switch (language) {
        AppLanguage.es => 'Álbumes',
        AppLanguage.en => 'Albums',
        AppLanguage.ja => 'アルバム',
      };

  String get followedArtistsTitle => switch (language) {
        AppLanguage.es => 'ARTISTAS SEGUIDOS',
        AppLanguage.en => 'FOLLOWED ARTISTS',
        AppLanguage.ja => 'フォロー中のアーティスト',
      };

  String get emptyLibraryTitle => switch (language) {
        AppLanguage.es => 'AÚN NO TIENES CANCIONES MARCADAS',
        AppLanguage.en => 'NO TRACKS MARKED YET',
        AppLanguage.ja => '聴取済み楽曲がありません',
      };

  String get emptyLibrarySubtitle => switch (language) {
        AppLanguage.es => 'Reproduce o marca canciones en el buscador o los álbumes para construir tu biblioteca personal.',
        AppLanguage.en => 'Play or check tracks in search or albums to build your personal library.',
        AppLanguage.ja => '検索やアルバムから楽曲を再生・記録して、独自のコレクションを構築しましょう。',
      };

  // --- Expanded Player ---
  String get playingFrom => switch (language) {
        AppLanguage.es => 'REPRODUCIENDO DESDE',
        AppLanguage.en => 'PLAYING FROM',
        AppLanguage.ja => '再生中 // 音源',
      };

  String queueTitle(int count) => switch (language) {
        AppLanguage.es => 'SIGUIENTES // COLA ($count)',
        AppLanguage.en => 'UP NEXT // QUEUE ($count)',
        AppLanguage.ja => '次を再生 // キュー ($count)',
      };

  // --- Profile & Settings Modal ---
  String get profileTitle => switch (language) {
        AppLanguage.es => 'PERFIL // SISTEMA',
        AppLanguage.en => 'PROFILE // SYSTEM',
        AppLanguage.ja => 'プロフィール // 設定',
      };

  String get settingsPlaybackSection => switch (language) {
        AppLanguage.es => 'REPRODUCCIÓN',
        AppLanguage.en => 'PLAYBACK',
        AppLanguage.ja => '再生',
      };

  String get settingsStorageSection => switch (language) {
        AppLanguage.es => 'ALMACENAMIENTO',
        AppLanguage.en => 'STORAGE',
        AppLanguage.ja => 'ストレージ',
      };

  String get settingsGeneralSection => switch (language) {
        AppLanguage.es => 'GENERAL',
        AppLanguage.en => 'GENERAL',
        AppLanguage.ja => '一般',
      };

  // --- Oni masks ---
  String get masksTitle => switch (language) {
        AppLanguage.es => 'MÁSCARAS ONI',
        AppLanguage.en => 'ONI MASKS',
        AppLanguage.ja => '鬼の面',
      };

  String masksCount(int unlocked, int total) => '$unlocked / $total';

  String get masksNoneYet => switch (language) {
        AppLanguage.es => 'Aún sin máscara',
        AppLanguage.en => 'No mask yet',
        AppLanguage.ja => 'まだ面がありません',
      };

  String get masksEquippedHint => switch (language) {
        AppLanguage.es => 'Tu máscara equipada marca tus canciones escuchadas y aparece en tu perfil.',
        AppLanguage.en => 'Your equipped mask marks your listened songs and shows on your profile.',
        AppLanguage.ja => '装備中の面は聴いた曲の印になり、プロフィールにも表示されます。',
      };

  String get maskSecretName => switch (language) {
        AppLanguage.es => '???',
        AppLanguage.en => '???',
        AppLanguage.ja => '？？？',
      };

  String get maskSecretHint => switch (language) {
        AppLanguage.es => 'Máscara secreta. Nadie sabe cómo conseguirla… todavía.',
        AppLanguage.en => 'Secret mask. Nobody knows how to get it… yet.',
        AppLanguage.ja => '秘密の面。手に入れ方は誰も知らない…まだ。',
      };

  String get maskEquip => switch (language) {
        AppLanguage.es => 'EQUIPAR',
        AppLanguage.en => 'EQUIP',
        AppLanguage.ja => '装備する',
      };

  String get maskEquipped => switch (language) {
        AppLanguage.es => 'EQUIPADA',
        AppLanguage.en => 'EQUIPPED',
        AppLanguage.ja => '装備中',
      };

  String maskUnlockedOn(String date) => switch (language) {
        AppLanguage.es => 'Desbloqueada el $date',
        AppLanguage.en => 'Unlocked on $date',
        AppLanguage.ja => '$date に解放',
      };

  String get maskUnlockedTitle => switch (language) {
        AppLanguage.es => 'MÁSCARA DESBLOQUEADA',
        AppLanguage.en => 'MASK UNLOCKED',
        AppLanguage.ja => '面を解放',
      };

  String maskRarity(MaskRarity r) => switch (language) {
        AppLanguage.es => switch (r) {
            MaskRarity.common => 'COMÚN',
            MaskRarity.rare => 'RARA',
            MaskRarity.epic => 'ÉPICA',
            MaskRarity.secret => 'SECRETA',
            MaskRarity.legendary => 'LEGENDARIA',
          },
        AppLanguage.en => switch (r) {
            MaskRarity.common => 'COMMON',
            MaskRarity.rare => 'RARE',
            MaskRarity.epic => 'EPIC',
            MaskRarity.secret => 'SECRET',
            MaskRarity.legendary => 'LEGENDARY',
          },
        AppLanguage.ja => switch (r) {
            MaskRarity.common => '並',
            MaskRarity.rare => '希少',
            MaskRarity.epic => '極',
            MaskRarity.secret => '秘',
            MaskRarity.legendary => '伝説',
          },
      };

  String get masksProfileRow => switch (language) {
        AppLanguage.es => 'Colección de máscaras',
        AppLanguage.en => 'Mask collection',
        AppLanguage.ja => '面のコレクション',
      };

  // --- Moon ---
  String moonPhaseName(MoonPhaseName name) => switch (language) {
        AppLanguage.es => switch (name) {
            MoonPhaseName.newMoon => 'Luna nueva',
            MoonPhaseName.waxingCrescent => 'Luna creciente',
            MoonPhaseName.firstQuarter => 'Cuarto creciente',
            MoonPhaseName.waxingGibbous => 'Gibosa creciente',
            MoonPhaseName.fullMoon => 'Luna llena',
            MoonPhaseName.waningGibbous => 'Gibosa menguante',
            MoonPhaseName.lastQuarter => 'Cuarto menguante',
            MoonPhaseName.waningCrescent => 'Luna menguante',
          },
        AppLanguage.en => switch (name) {
            MoonPhaseName.newMoon => 'New moon',
            MoonPhaseName.waxingCrescent => 'Waxing crescent',
            MoonPhaseName.firstQuarter => 'First quarter',
            MoonPhaseName.waxingGibbous => 'Waxing gibbous',
            MoonPhaseName.fullMoon => 'Full moon',
            MoonPhaseName.waningGibbous => 'Waning gibbous',
            MoonPhaseName.lastQuarter => 'Last quarter',
            MoonPhaseName.waningCrescent => 'Waning crescent',
          },
        AppLanguage.ja => switch (name) {
            MoonPhaseName.newMoon => '新月',
            MoonPhaseName.waxingCrescent => '三日月',
            MoonPhaseName.firstQuarter => '上弦の月',
            MoonPhaseName.waxingGibbous => '十三夜月',
            MoonPhaseName.fullMoon => '満月',
            MoonPhaseName.waningGibbous => '寝待月',
            MoonPhaseName.lastQuarter => '下弦の月',
            MoonPhaseName.waningCrescent => '有明月',
          },
      };

  String moonEventName(MoonPhaseKind kind) => moonPhaseName(switch (kind) {
        MoonPhaseKind.newMoon => MoonPhaseName.newMoon,
        MoonPhaseKind.firstQuarter => MoonPhaseName.firstQuarter,
        MoonPhaseKind.fullMoon => MoonPhaseName.fullMoon,
        MoonPhaseKind.lastQuarter => MoonPhaseName.lastQuarter,
      });

  String get moonTonightTitle => switch (language) {
        AppLanguage.es => 'LA LUNA DE ESTA NOCHE',
        AppLanguage.en => "TONIGHT'S MOON",
        AppLanguage.ja => '今夜の月',
      };

  String moonIlluminated(int percent) => switch (language) {
        AppLanguage.es => '$percent% iluminada',
        AppLanguage.en => '$percent% illuminated',
        AppLanguage.ja => '輝面比 $percent%',
      };

  String moonAge(int day) => switch (language) {
        AppLanguage.es => 'Día $day del ciclo lunar',
        AppLanguage.en => 'Day $day of the lunar cycle',
        AppLanguage.ja => '月齢 $day',
      };

  String get moonFullTonight => switch (language) {
        AppLanguage.es => 'Luna llena esta noche 🌕',
        AppLanguage.en => 'Full moon tonight 🌕',
        AppLanguage.ja => '今夜は満月 🌕',
      };

  /// Countdown phrase: [days] when ≥ 1, otherwise [hours].
  String moonUntilFull({int? days, int? hours}) => switch (language) {
        AppLanguage.es => days != null
            ? (days == 1 ? 'Falta 1 día para luna llena 🌕' : 'Faltan $days días para luna llena 🌕')
            : (hours == 1 ? 'Falta 1 hora para luna llena 🌕' : 'Faltan $hours horas para luna llena 🌕'),
        AppLanguage.en => days != null
            ? (days == 1 ? '1 day until full moon 🌕' : '$days days until full moon 🌕')
            : (hours == 1 ? '1 hour until full moon 🌕' : '$hours hours until full moon 🌕'),
        AppLanguage.ja => days != null ? '満月まであと$days日 🌕' : '満月まであと$hours時間 🌕',
      };

  String get moonCycleTitle => switch (language) {
        AppLanguage.es => 'CICLO LUNAR · 8 FASES',
        AppLanguage.en => 'LUNAR CYCLE · 8 PHASES',
        AppLanguage.ja => '月の満ち欠け · 8相',
      };

  String get moonToday => switch (language) {
        AppLanguage.es => 'HOY',
        AppLanguage.en => 'TODAY',
        AppLanguage.ja => '今日',
      };

  String get moonUpcomingTitle => switch (language) {
        AppLanguage.es => 'PRÓXIMAS FASES',
        AppLanguage.en => 'UPCOMING PHASES',
        AppLanguage.ja => '次の月相',
      };

  String get moonMixTitle => switch (language) {
        AppLanguage.es => 'MIX DE LUNA LLENA',
        AppLanguage.en => 'FULL MOON MIX',
        AppLanguage.ja => '満月ミックス',
      };

  String moonMixUnlocked(int count) => switch (language) {
        AppLanguage.es => 'Tus $count canciones más escuchadas de este ciclo lunar',
        AppLanguage.en => 'Your $count most played songs of this lunar cycle',
        AppLanguage.ja => 'この月の周期で最も聴いた$count曲',
      };

  String moonMixLocked(String when) => switch (language) {
        AppLanguage.es => 'Se desbloquea con la luna llena · $when',
        AppLanguage.en => 'Unlocks at the full moon · $when',
        AppLanguage.ja => '満月で解放 · $when',
      };

  String moonMixProgress(int count) => switch (language) {
        AppLanguage.es => count == 0
            ? 'Escucha música este ciclo para llenarlo'
            : 'Ya llevas $count ${count == 1 ? 'canción' : 'canciones'} en este ciclo',
        AppLanguage.en => count == 0
            ? 'Listen to music this cycle to fill it'
            : '$count ${count == 1 ? 'song' : 'songs'} so far this cycle',
        AppLanguage.ja => count == 0 ? 'この周期に音楽を聴いて満たそう' : 'この周期で$count曲',
      };

  String get moonMixEmpty => switch (language) {
        AppLanguage.es => 'Este ciclo no escuchaste música todavía. ¡El próximo mix te espera!',
        AppLanguage.en => "You haven't listened to anything this cycle yet. Next mix awaits!",
        AppLanguage.ja => 'この周期はまだ何も聴いていません。次のミックスをお楽しみに！',
      };

  String get moonMixPlay => switch (language) {
        AppLanguage.es => 'REPRODUCIR',
        AppLanguage.en => 'PLAY',
        AppLanguage.ja => '再生',
      };

  String get moonMixSave => switch (language) {
        AppLanguage.es => 'GUARDAR PLAYLIST',
        AppLanguage.en => 'SAVE PLAYLIST',
        AppLanguage.ja => 'プレイリストに保存',
      };

  String moonMixPlaylistName(String date) => switch (language) {
        AppLanguage.es => '🌕 Luna llena · $date',
        AppLanguage.en => '🌕 Full moon · $date',
        AppLanguage.ja => '🌕 満月 · $date',
      };

  String get moonMixSaved => switch (language) {
        AppLanguage.es => 'Mix guardado en tus playlists 🌕',
        AppLanguage.en => 'Mix saved to your playlists 🌕',
        AppLanguage.ja => 'ミックスをプレイリストに保存しました 🌕',
      };

  String get moonMixSaveFailed => switch (language) {
        AppLanguage.es => 'No se pudo guardar. Inicia sesión e inténtalo de nuevo.',
        AppLanguage.en => "Couldn't save. Sign in and try again.",
        AppLanguage.ja => '保存できませんでした。ログインして再試行してください。',
      };

  String get moonEclipseNow => switch (language) {
        AppLanguage.es => 'ECLIPSE LUNAR EN CURSO',
        AppLanguage.en => 'LUNAR ECLIPSE IN PROGRESS',
        AppLanguage.ja => '月食進行中',
      };

  String moonEclipseKind(LunarEclipseKind kind) => switch (language) {
        AppLanguage.es => switch (kind) {
            LunarEclipseKind.total => 'total',
            LunarEclipseKind.partial => 'parcial',
            LunarEclipseKind.penumbral => 'penumbral',
          },
        AppLanguage.en => switch (kind) {
            LunarEclipseKind.total => 'total',
            LunarEclipseKind.partial => 'partial',
            LunarEclipseKind.penumbral => 'penumbral',
          },
        AppLanguage.ja => switch (kind) {
            LunarEclipseKind.total => '皆既',
            LunarEclipseKind.partial => '部分',
            LunarEclipseKind.penumbral => '半影',
          },
      };

  String moonNextEclipse(String date, LunarEclipseKind kind) => switch (language) {
        AppLanguage.es => 'Próximo eclipse lunar: $date · ${moonEclipseKind(kind)}',
        AppLanguage.en => 'Next lunar eclipse: $date · ${moonEclipseKind(kind)}',
        AppLanguage.ja => '次の月食：$date · ${moonEclipseKind(kind)}月食',
      };

  String get moonAtmosphereTitle => switch (language) {
        AppLanguage.es => 'Atmósfera lunar',
        AppLanguage.en => 'Lunar atmosphere',
        AppLanguage.ja => '月のアトモスフィア',
      };

  String get moonAtmosphereSubtitle => switch (language) {
        AppLanguage.es => 'La app cambia de luz con la luna real de cada noche',
        AppLanguage.en => 'The app follows the real Moon each night',
        AppLanguage.ja => '毎晩の実際の月に合わせて光が変わる',
      };

  String get a11yMoon => switch (language) {
        AppLanguage.es => 'Fase lunar',
        AppLanguage.en => 'Moon phase',
        AppLanguage.ja => '月相',
      };

  String shortDate(DateTime d) {
    const es = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return switch (language) {
      AppLanguage.es => '${d.day} ${es[d.month - 1]}',
      AppLanguage.en => '${en[d.month - 1]} ${d.day}',
      AppLanguage.ja => '${d.month}月${d.day}日',
    };
  }

  String longDate(DateTime d) => switch (language) {
        AppLanguage.ja => '${d.year}年${shortDate(d)}',
        AppLanguage.en => '${shortDate(d)}, ${d.year}',
        AppLanguage.es => '${shortDate(d)} ${d.year}',
      };

  // --- Ambient mixer ---
  String get ambientTitle => switch (language) {
        AppLanguage.es => 'AMBIENTE',
        AppLanguage.en => 'AMBIENT',
        AppLanguage.ja => 'アンビエント',
      };

  String get ambientSubtitle => switch (language) {
        AppLanguage.es => 'Suena encima de tu música, también de Spotify',
        AppLanguage.en => 'Plays on top of your music, Spotify included',
        AppLanguage.ja => '音楽の上に重ねて再生（Spotifyも対応）',
      };

  String ambientName(AmbientSound sound) => switch (language) {
        AppLanguage.es => switch (sound) {
            AmbientSound.rain => 'Lluvia',
            AmbientSound.storm => 'Tormenta',
            AmbientSound.waves => 'Olas',
            AmbientSound.fire => 'Fogata',
            AmbientSound.wind => 'Viento',
            AmbientSound.night => 'Noche',
            AmbientSound.brownNoise => 'Ruido marrón',
          },
        AppLanguage.en => switch (sound) {
            AmbientSound.rain => 'Rain',
            AmbientSound.storm => 'Storm',
            AmbientSound.waves => 'Waves',
            AmbientSound.fire => 'Campfire',
            AmbientSound.wind => 'Wind',
            AmbientSound.night => 'Night',
            AmbientSound.brownNoise => 'Brown noise',
          },
        AppLanguage.ja => switch (sound) {
            AmbientSound.rain => '雨',
            AmbientSound.storm => '嵐',
            AmbientSound.waves => '波',
            AmbientSound.fire => '焚き火',
            AmbientSound.wind => '風',
            AmbientSound.night => '夜',
            AmbientSound.brownNoise => 'ブラウンノイズ',
          },
      };

  String get ambientAfterTimerTitle => switch (language) {
        AppLanguage.es => 'Cuando termine el temporizador',
        AppLanguage.en => 'When the sleep timer ends',
        AppLanguage.ja => 'スリープタイマー終了後',
      };

  String ambientAfterTimerOption(int minutes) => switch (language) {
        AppLanguage.es => minutes == 0
            ? 'Apagar con la música'
            : minutes < 0
                ? 'No apagar'
                : 'Seguir $minutes min',
        AppLanguage.en => minutes == 0
            ? 'Stop with the music'
            : minutes < 0
                ? 'Keep playing'
                : 'Keep $minutes min',
        AppLanguage.ja => minutes == 0
            ? '音楽と一緒に停止'
            : minutes < 0
                ? '止めない'
                : 'あと$minutes分',
      };

  String ambientStopsIn(String time) => switch (language) {
        AppLanguage.es => 'Se apaga en $time',
        AppLanguage.en => 'Stops in $time',
        AppLanguage.ja => '$time 後に停止',
      };

  String get ambientStopAll => switch (language) {
        AppLanguage.es => 'APAGAR TODO',
        AppLanguage.en => 'STOP ALL',
        AppLanguage.ja => 'すべて停止',
      };

  String get ambientPause => switch (language) {
        AppLanguage.es => 'PAUSAR',
        AppLanguage.en => 'PAUSE',
        AppLanguage.ja => '一時停止',
      };

  String get ambientResume => switch (language) {
        AppLanguage.es => 'REANUDAR',
        AppLanguage.en => 'RESUME',
        AppLanguage.ja => '再開',
      };

  String get ambientHint => switch (language) {
        AppLanguage.es => 'Combínalo con el temporizador para dormir: la música se apaga suave y la lluvia sigue.',
        AppLanguage.en => 'Pair it with the sleep timer: the music fades out and the rain keeps going.',
        AppLanguage.ja => 'スリープタイマーと組み合わせると、音楽はフェードアウトし雨音は続きます。',
      };

  String get homeAmbientCardSubtitle => switch (language) {
        AppLanguage.es => 'Lluvia, olas, fogata…',
        AppLanguage.en => 'Rain, waves, campfire…',
        AppLanguage.ja => '雨・波・焚き火…',
      };

  String ambientPlayingCount(int count) => switch (language) {
        AppLanguage.es => '$count sonando',
        AppLanguage.en => '$count playing',
        AppLanguage.ja => '$count 再生中',
      };

  // --- Guess the song ---
  String get guessTitle => switch (language) {
        AppLanguage.es => 'ADIVINA LA CANCIÓN',
        AppLanguage.en => 'GUESS THE SONG',
        AppLanguage.ja => '曲当てクイズ',
      };

  String get guessModeDaily => switch (language) {
        AppLanguage.es => 'Reto diario',
        AppLanguage.en => 'Daily',
        AppLanguage.ja => 'デイリー',
      };

  String get guessModeLibrary => switch (language) {
        AppLanguage.es => 'Mis canciones',
        AppLanguage.en => 'My songs',
        AppLanguage.ja => 'マイソング',
      };

  String get guessModeArtist => switch (language) {
        AppLanguage.es => 'Artista',
        AppLanguage.en => 'Artist',
        AppLanguage.ja => 'アーティスト',
      };

  String get guessPickArtist => switch (language) {
        AppLanguage.es => 'Elige un artista y adivina su discografía',
        AppLanguage.en => 'Pick an artist and guess their discography',
        AppLanguage.ja => 'アーティストを選んで曲を当てよう',
      };

  String get guessArtistSearchHint => switch (language) {
        AppLanguage.es => 'Busca un artista…',
        AppLanguage.en => 'Search an artist…',
        AppLanguage.ja => 'アーティストを検索…',
      };

  String get guessYourArtists => switch (language) {
        AppLanguage.es => 'TUS ARTISTAS',
        AppLanguage.en => 'YOUR ARTISTS',
        AppLanguage.ja => 'あなたのアーティスト',
      };

  String get guessArtistChange => switch (language) {
        AppLanguage.es => 'CAMBIAR',
        AppLanguage.en => 'CHANGE',
        AppLanguage.ja => '変更',
      };

  String get guessArtistTooFew => switch (language) {
        AppLanguage.es => 'Este artista no tiene suficientes canciones para jugar. Prueba con otro.',
        AppLanguage.en => "This artist doesn't have enough songs to play. Try another one.",
        AppLanguage.ja => 'このアーティストは曲が足りません。別のアーティストを試してください。',
      };

  String get guessModeChart => switch (language) {
        AppLanguage.es => 'Top mundial',
        AppLanguage.en => 'Global top',
        AppLanguage.ja => 'グローバルTOP',
      };

  String get guessHowTo => switch (language) {
        AppLanguage.es => 'Escucha el fragmento y adivina la canción. Cada fallo o salto desbloquea más segundos.',
        AppLanguage.en => 'Listen to the clip and guess the song. Every miss or skip unlocks more seconds.',
        AppLanguage.ja => 'クリップを聴いて曲を当てよう。外すかスキップすると再生時間が延びます。',
      };

  String get guessSearchHint => switch (language) {
        AppLanguage.es => 'Escribe tu respuesta…',
        AppLanguage.en => 'Type your guess…',
        AppLanguage.ja => '曲名を入力…',
      };

  String guessSkip(int seconds) => switch (language) {
        AppLanguage.es => 'SALTAR (+${seconds}s)',
        AppLanguage.en => 'SKIP (+${seconds}s)',
        AppLanguage.ja => 'スキップ（+$seconds秒）',
      };

  String get guessGiveUp => switch (language) {
        AppLanguage.es => 'RENDIRSE',
        AppLanguage.en => 'GIVE UP',
        AppLanguage.ja => 'ギブアップ',
      };

  String get guessTapToPlay => switch (language) {
        AppLanguage.es => 'Reproducir fragmento',
        AppLanguage.en => 'Play clip',
        AppLanguage.ja => 'クリップを再生',
      };

  String get guessAttemptSkipped => switch (language) {
        AppLanguage.es => 'Saltado',
        AppLanguage.en => 'Skipped',
        AppLanguage.ja => 'スキップ',
      };

  String get guessRightArtist => switch (language) {
        AppLanguage.es => 'artista correcto',
        AppLanguage.en => 'right artist',
        AppLanguage.ja => 'アーティストは正解',
      };

  String guessWonIn(int attempts) => switch (language) {
        AppLanguage.es => attempts == 1 ? '¡Al primer segundo! 🤯' : '¡Lo adivinaste en $attempts intentos!',
        AppLanguage.en => attempts == 1 ? 'First second! 🤯' : 'Got it in $attempts tries!',
        AppLanguage.ja => attempts == 1 ? '1秒で正解！🤯' : '$attempts回目で正解！',
      };

  String get guessLost => switch (language) {
        AppLanguage.es => 'Era esta canción',
        AppLanguage.en => 'It was this song',
        AppLanguage.ja => '正解はこの曲',
      };

  String get guessListenFull => switch (language) {
        AppLanguage.es => 'ESCUCHAR',
        AppLanguage.en => 'PLAY',
        AppLanguage.ja => '再生',
      };

  String get guessShare => switch (language) {
        AppLanguage.es => 'COPIAR RESULTADO',
        AppLanguage.en => 'COPY RESULT',
        AppLanguage.ja => '結果をコピー',
      };

  String get guessCopied => switch (language) {
        AppLanguage.es => 'Resultado copiado, ¡pégalo donde quieras!',
        AppLanguage.en => 'Result copied, paste it anywhere!',
        AppLanguage.ja => '結果をコピーしました！',
      };

  String get guessNext => switch (language) {
        AppLanguage.es => 'SIGUIENTE',
        AppLanguage.en => 'NEXT',
        AppLanguage.ja => '次へ',
      };

  String guessNextDailyIn(String time) => switch (language) {
        AppLanguage.es => 'Próximo reto en $time',
        AppLanguage.en => 'Next challenge in $time',
        AppLanguage.ja => '次のチャレンジまで $time',
      };

  String get guessStatsTitle => switch (language) {
        AppLanguage.es => 'ESTADÍSTICAS',
        AppLanguage.en => 'STATS',
        AppLanguage.ja => '統計',
      };

  String get guessStatsPlayed => switch (language) {
        AppLanguage.es => 'Jugados',
        AppLanguage.en => 'Played',
        AppLanguage.ja => 'プレイ',
      };

  String get guessStatsWinRate => switch (language) {
        AppLanguage.es => '% Victorias',
        AppLanguage.en => 'Win %',
        AppLanguage.ja => '勝率',
      };

  String get guessStatsStreak => switch (language) {
        AppLanguage.es => 'Racha',
        AppLanguage.en => 'Streak',
        AppLanguage.ja => '連続',
      };

  String get guessStatsMaxStreak => switch (language) {
        AppLanguage.es => 'Mejor racha',
        AppLanguage.en => 'Best streak',
        AppLanguage.ja => '最高連続',
      };

  String get guessStatsDistribution => switch (language) {
        AppLanguage.es => 'INTENTOS PARA ADIVINAR',
        AppLanguage.en => 'GUESS DISTRIBUTION',
        AppLanguage.ja => '正解までの回数',
      };

  String guessSessionStreak(int n, int best) => switch (language) {
        AppLanguage.es => 'Racha $n · Récord $best',
        AppLanguage.en => 'Streak $n · Best $best',
        AppLanguage.ja => '連続 $n · 最高 $best',
      };

  String get guessLibraryTooSmall => switch (language) {
        AppLanguage.es => 'Guarda o escucha más canciones para jugar con tu biblioteca. Por ahora juegas con el top mundial.',
        AppLanguage.en => 'Save or play more songs to use your library. For now you play with the global top.',
        AppLanguage.ja => 'ライブラリで遊ぶには曲をもっと保存・再生してください。今はグローバルTOPで遊べます。',
      };

  String get guessLoadError => switch (language) {
        AppLanguage.es => 'No se pudo cargar la canción',
        AppLanguage.en => "Couldn't load the song",
        AppLanguage.ja => '曲を読み込めませんでした',
      };

  String get guessNoResults => switch (language) {
        AppLanguage.es => 'Sin resultados',
        AppLanguage.en => 'No results',
        AppLanguage.ja => '結果なし',
      };

  String guessShareHeader(int day) => switch (language) {
        AppLanguage.es => 'Tsuki Tunes 🌙 Reto #$day',
        AppLanguage.en => 'Tsuki Tunes 🌙 Challenge #$day',
        AppLanguage.ja => 'Tsuki Tunes 🌙 チャレンジ #$day',
      };

  String get guessDailyDone => switch (language) {
        AppLanguage.es => 'Reto de hoy completado ✓',
        AppLanguage.en => "Today's challenge done ✓",
        AppLanguage.ja => '本日のチャレンジ完了 ✓',
      };

  String get crossfadeTitle => switch (language) {
        AppLanguage.es => 'Crossfade',
        AppLanguage.en => 'Crossfade',
        AppLanguage.ja => 'クロスフェード',
      };

  String get crossfadeSubtitle => switch (language) {
        AppLanguage.es => 'Transición suave entre canciones',
        AppLanguage.en => 'Smooth transition between songs',
        AppLanguage.ja => '曲間をスムーズにつなぐ',
      };

  String get autoMarkTitle => switch (language) {
        AppLanguage.es => 'Marcar al escuchar',
        AppLanguage.en => 'Mark when listened',
        AppLanguage.ja => '再生で既聴にする',
      };

  String get autoMarkSubtitle => switch (language) {
        AppLanguage.es => 'Marca la canción al llegar al 80%',
        AppLanguage.en => 'Marks the track at 80% played',
        AppLanguage.ja => '80%再生で既聴マーク',
      };

  String get precacheWifiTitle => switch (language) {
        AppLanguage.es => 'Precarga solo con Wi-Fi',
        AppLanguage.en => 'Preload on Wi-Fi only',
        AppLanguage.ja => 'Wi-Fi時のみ先読み',
      };

  String get precacheWifiSubtitle => switch (language) {
        AppLanguage.es => 'Ahorra datos móviles',
        AppLanguage.en => 'Saves mobile data',
        AppLanguage.ja => 'モバイルデータを節約',
      };

  String get clearAudioCache => switch (language) {
        AppLanguage.es => 'Borrar caché de audio',
        AppLanguage.en => 'Clear audio cache',
        AppLanguage.ja => '音声キャッシュを削除',
      };

  String get audioCacheCleared => switch (language) {
        AppLanguage.es => 'Caché de audio borrada',
        AppLanguage.en => 'Audio cache cleared',
        AppLanguage.ja => '音声キャッシュを削除しました',
      };

  String crossfadeSecondsLabel(int seconds) => switch (language) {
        AppLanguage.es => '$seconds seg',
        AppLanguage.en => '${seconds}s',
        AppLanguage.ja => '$seconds 秒',
      };

  String get languageOption => switch (language) {
        AppLanguage.es => 'IDIOMA DEL SISTEMA',
        AppLanguage.en => 'SYSTEM LANGUAGE',
        AppLanguage.ja => 'システム言語',
      };

  String get languageSelectorTitle => switch (language) {
        AppLanguage.es => 'SISTEMA // IDIOMA DE INTERFAZ',
        AppLanguage.en => 'SYSTEM // INTERFACE LANGUAGE',
        AppLanguage.ja => 'システム // インターフェース言語',
      };

  String get languageSelectorSubtitle => switch (language) {
        AppLanguage.es => 'CAMBIA EL IDIOMA DE LA INTERFAZ',
        AppLanguage.en => 'CHANGE THE INTERFACE LANGUAGE',
        AppLanguage.ja => 'インターフェースの言語を変更',
      };

  String languageCardSubtitle(AppLanguage targetLang) => switch (targetLang) {
        AppLanguage.es => switch (language) {
              AppLanguage.es => 'Español (Latinoamérica) · Predeterminado',
              AppLanguage.en => 'Spanish (Latin America) · Default',
              AppLanguage.ja => 'スペイン語 (ラテンアメリカ) · 初期設定',
            },
        AppLanguage.en => switch (language) {
              AppLanguage.es => 'Inglés (Internacional) · Global',
              AppLanguage.en => 'English (International) · Global',
              AppLanguage.ja => '英語 (国際標準) · グローバル',
            },
        AppLanguage.ja => switch (language) {
              AppLanguage.es => 'Japonés (日本語) · Kanji HUD & Cyber',
              AppLanguage.en => 'Japanese (日本語) · Kanji HUD & Cyber',
              AppLanguage.ja => '日本語 (日本) · 漢字HUD & サイバースタイル',
            },
      };

  String get languageInfoNotice => switch (language) {
        AppLanguage.es => '◈ Los títulos de canciones y artistas conservan su idioma original de catálogo.',
        AppLanguage.en => '◈ Song titles and artist names retain original catalog language.',
        AppLanguage.ja => '◈ 楽曲名およびアーティスト名はカタログの原語を維持します。',
      };

  String get activeStatus => switch (language) {
        AppLanguage.es => 'ACTIVO',
        AppLanguage.en => 'ACTIVE',
        AppLanguage.ja => '有効',
      };

  String get tutorialOption => switch (language) {
        AppLanguage.es => 'VER TUTORIAL Y GUÍA',
        AppLanguage.en => 'VIEW TUTORIAL & GUIDE',
        AppLanguage.ja => 'チュートリアル・ガイド',
      };

  String get logoutOption => switch (language) {
        AppLanguage.es => 'CERRAR SESIÓN',
        AppLanguage.en => 'LOGOUT',
        AppLanguage.ja => 'ログアウト',
      };

  String get spotifyConnect => switch (language) {
        AppLanguage.es => 'CONECTAR',
        AppLanguage.en => 'CONNECT',
        AppLanguage.ja => '接続',
      };

  String get spotifyDisconnect => switch (language) {
        AppLanguage.es => 'DESCONECTAR',
        AppLanguage.en => 'DISCONNECT',
        AppLanguage.ja => '解除',
      };

  String get spotifyConnected => switch (language) {
        AppLanguage.es => 'Conectado',
        AppLanguage.en => 'Connected',
        AppLanguage.ja => '接続中',
      };

  String get spotifyNotConnected => switch (language) {
        AppLanguage.es => 'No conectado',
        AppLanguage.en => 'Not connected',
        AppLanguage.ja => '未接続',
      };

  String get spotifyConnecting => switch (language) {
        AppLanguage.es => 'Conectando...',
        AppLanguage.en => 'Connecting...',
        AppLanguage.ja => '接続中...',
      };

  String get spotifyDefaultUser => switch (language) {
        AppLanguage.es => 'Usuario Spotify',
        AppLanguage.en => 'Spotify User',
        AppLanguage.ja => 'Spotifyユーザー',
      };

  String get spotifyCanceledByUser => switch (language) {
        AppLanguage.es => 'Conexión cancelada por el usuario.',
        AppLanguage.en => 'Connection canceled by user.',
        AppLanguage.ja => 'ユーザーによって接続がキャンセルされました。',
      };

  // --- Stats Card Tags & Home Details ---
  String get statsListened => switch (language) {
        AppLanguage.es => 'ESCUCHADAS',
        AppLanguage.en => 'LISTENED',
        AppLanguage.ja => '再生済み',
      };

  String get statsInSystem => switch (language) {
        AppLanguage.es => 'EN SISTEMA',
        AppLanguage.en => 'IN SYSTEM',
        AppLanguage.ja => '登録済み',
      };

  String statsAffinity(dynamic score) => switch (language) {
        AppLanguage.es => 'AFINIDAD: $score',
        AppLanguage.en => 'AFFINITY: $score',
        AppLanguage.ja => '親密度: $score',
      };

  String get emptyReleases => switch (language) {
        AppLanguage.es => 'Si no hay artistas con canciones guardadas, aquí aparecerán tus lanzamientos recientes recomendados',
        AppLanguage.en => 'Once you save songs from artists, their recent releases will appear here',
        AppLanguage.ja => 'アーティストの曲を保存すると、最近のリリースがここに表示されます',
      };

  String affinityScore(dynamic score) => switch (language) {
        AppLanguage.es => 'Afinidad: $score',
        AppLanguage.en => 'Affinity: $score',
        AppLanguage.ja => '親密度: $score',
      };

  String get featured => switch (language) {
        AppLanguage.es => 'DESTACADO',
        AppLanguage.en => 'FEATURED',
        AppLanguage.ja => '注目',
      };

  // --- Spotify Status & Dialogs ---
  String spotifyActiveDevice(String device) => switch (language) {
        AppLanguage.es => 'Dispositivo activo: $device',
        AppLanguage.en => 'Active device: $device',
        AppLanguage.ja => '接続中の端末: $device',
      };

  String get spotifyPremiumActive => switch (language) {
        AppLanguage.es => 'Reproducción completa Premium activa',
        AppLanguage.en => 'Full Premium playback active',
        AppLanguage.ja => 'プレミアム再生が有効です',
      };

  String get spotifyStandardPreview => switch (language) {
        AppLanguage.es => 'Cuenta estándar: vista previa disponible',
        AppLanguage.en => 'Standard account: preview available',
        AppLanguage.ja => '通常アカウント: プレビュー再生',
      };

  String get spotifySyncSuccess => switch (language) {
        AppLanguage.es => 'Spotify sincronizado exitosamente',
        AppLanguage.en => 'Spotify synced successfully',
        AppLanguage.ja => 'Spotifyの同期が完了しました',
      };

  String get spotifyConnectError => switch (language) {
        AppLanguage.es => 'No se pudo conectar. Verifica tu cuenta en el Dashboard de Spotify.',
        AppLanguage.en => 'Could not connect. Verify your account in Spotify Dashboard.',
        AppLanguage.ja => '接続できませんでした。Spotifyダッシュボードのアカウント設定を確認してください。',
      };

  String get logoutConfirmTitle => switch (language) {
        AppLanguage.es => 'CERRAR SESIÓN',
        AppLanguage.en => 'LOGOUT',
        AppLanguage.ja => 'ログアウト',
      };

  String get logoutConfirmMessage => switch (language) {
        AppLanguage.es => '¿Estás seguro de que deseas cerrar sesión?',
        AppLanguage.en => 'Are you sure you want to log out?',
        AppLanguage.ja => 'ログアウトしてもよろしいですか？',
      };

  String get cancel => switch (language) {
        AppLanguage.es => 'CANCELAR',
        AppLanguage.en => 'CANCEL',
        AppLanguage.ja => 'キャンセル',
      };

  String get logout => switch (language) {
        AppLanguage.es => 'SALIR',
        AppLanguage.en => 'LOGOUT',
        AppLanguage.ja => 'ログアウト',
      };

  // --- Album Detail Screen ---
  String get albumDetailsTitle => switch (language) {
        AppLanguage.es => 'DETALLES DEL ÁLBUM',
        AppLanguage.en => 'ALBUM DETAILS',
        AppLanguage.ja => 'アルバム詳細',
      };

  String get allListened => switch (language) {
        AppLanguage.es => 'TODO ESCUCHADO',
        AppLanguage.en => 'ALL LISTENED',
        AppLanguage.ja => '全曲聴取済み',
      };

  String get markAll => switch (language) {
        AppLanguage.es => 'MARCAR TODO',
        AppLanguage.en => 'MARK ALL',
        AppLanguage.ja => 'すべて記録',
      };

  String get play => switch (language) {
        AppLanguage.es => 'REPRODUCIR',
        AppLanguage.en => 'PLAY',
        AppLanguage.ja => '再生',
      };

  String get playAll => switch (language) {
        AppLanguage.es => 'REPRODUCIR TODO',
        AppLanguage.en => 'PLAY ALL',
        AppLanguage.ja => 'すべて再生',
      };

  String get shuffle => switch (language) {
        AppLanguage.es => 'ALEATORIO',
        AppLanguage.en => 'SHUFFLE',
        AppLanguage.ja => 'シャッフル',
      };

  String get addToQueue => switch (language) {
        AppLanguage.es => 'Agregar a la cola',
        AppLanguage.en => 'Add to queue',
        AppLanguage.ja => 'キューに追加',
      };

  String get addedToQueue => switch (language) {
        AppLanguage.es => 'Agregado a la cola',
        AppLanguage.en => 'Added to queue',
        AppLanguage.ja => 'キューに追加しました',
      };

  String get syncing => switch (language) {
        AppLanguage.es => 'Sincronizando...',
        AppLanguage.en => 'Syncing...',
        AppLanguage.ja => '同期中...',
      };

  String get noTracksAvailable => switch (language) {
        AppLanguage.es => 'No hay canciones disponibles',
        AppLanguage.en => 'No tracks available',
        AppLanguage.ja => '楽曲がありません',
      };

  String albumMeta(String year, int count, String duration) => switch (language) {
        AppLanguage.es => '$year  ·  $count canciones  ·  $duration',
        AppLanguage.en => '$year  ·  $count tracks  ·  $duration',
        AppLanguage.ja => '$year年  ·  $count曲  ·  $duration',
      };

  String albumTypeLabel(String? type) => switch (type) {
        'album' => switch (language) {
            AppLanguage.es => 'Álbum',
            AppLanguage.en => 'Album',
            AppLanguage.ja => 'アルバム',
          },
        'single' => switch (language) {
            AppLanguage.es => 'Sencillo',
            AppLanguage.en => 'Single',
            AppLanguage.ja => 'シングル',
          },
        'ep' => 'EP',
        'compile' => switch (language) {
            AppLanguage.es => 'Compilación',
            AppLanguage.en => 'Compilation',
            AppLanguage.ja => 'コンピレーション',
          },
        _ => switch (language) {
            AppLanguage.es => 'Álbum',
            AppLanguage.en => 'Album',
            AppLanguage.ja => 'アルバム',
          },
      };

  // --- Artist Detail Screen ---
  String artistFans(String count) => switch (language) {
        AppLanguage.es => '$count fanáticos',
        AppLanguage.en => '$count fans',
        AppLanguage.ja => '$count 人のファン',
      };

  String artistDiscographyProgress(int completed, int total) =>
      switch (language) {
        AppLanguage.es => '$completed/$total lanzamientos completos',
        AppLanguage.en => '$completed/$total releases completed',
        AppLanguage.ja => '$completed/$total 作品を完了',
      };

  String artistReleases(int count) => switch (language) {
        AppLanguage.es => '$count lanzamientos',
        AppLanguage.en => '$count releases',
        AppLanguage.ja => '$count 作品',
      };

  String albumCountLabel(int count) => switch (language) {
        AppLanguage.es => '$count ${count == 1 ? "álbum" : "álbumes"}',
        AppLanguage.en => '$count ${count == 1 ? "album" : "albums"}',
        AppLanguage.ja => '$count 枚のアルバム',
      };

  String epCountLabel(int count) => switch (language) {
        AppLanguage.es => '$count ${count == 1 ? "EP" : "EPs"}',
        AppLanguage.en => '$count ${count == 1 ? "EP" : "EPs"}',
        AppLanguage.ja => '$count 作品のEP',
      };

  String singleCountLabel(int count) => switch (language) {
        AppLanguage.es => '$count ${count == 1 ? "sencillo" : "sencillos"}',
        AppLanguage.en => '$count ${count == 1 ? "single" : "singles"}',
        AppLanguage.ja => '$count 曲のシングル',
      };

  String appearsOnCountLabel(int count) => switch (language) {
        AppLanguage.es => '$count aparece en',
        AppLanguage.en => '$count appears on',
        AppLanguage.ja => '$count 件の参加作品',
      };

  String get popularTracks => switch (language) {
        AppLanguage.es => 'POPULARES',
        AppLanguage.en => 'POPULAR',
        AppLanguage.ja => '人気曲',
      };

  String get showMoreTracks => switch (language) {
        AppLanguage.es => 'Ver más',
        AppLanguage.en => 'Show more',
        AppLanguage.ja => 'さらに表示',
      };

  String get showLessTracks => switch (language) {
        AppLanguage.es => 'Ver menos',
        AppLanguage.en => 'Show less',
        AppLanguage.ja => '折りたたむ',
      };

  String get discography => switch (language) {
        AppLanguage.es => '// DISCOGRAFÍA',
        AppLanguage.en => '// DISCOGRAPHY',
        AppLanguage.ja => '// ディスコグラフィー',
      };

  String get seeMore => switch (language) {
        AppLanguage.es => 'Ver más',
        AppLanguage.en => 'See all',
        AppLanguage.ja => 'もっと見る',
      };

  String get tabSingles => switch (language) {
        AppLanguage.es => 'Sencillos',
        AppLanguage.en => 'Singles',
        AppLanguage.ja => 'シングル',
      };

  String get tabEps => switch (language) {
        AppLanguage.es => 'EPs',
        AppLanguage.en => 'EPs',
        AppLanguage.ja => 'EP',
      };

  String get tabAppearsOn => switch (language) {
        AppLanguage.es => 'Aparece en',
        AppLanguage.en => 'Appears on',
        AppLanguage.ja => '参加作品',
      };

  String get storedContentTitle => switch (language) {
        AppLanguage.es => 'CONTENIDO ALMACENADO',
        AppLanguage.en => 'STORED CONTENT',
        AppLanguage.ja => '保存済みコンテンツ',
      };

  String storedContentSongs(int count) => switch (language) {
        AppLanguage.es => '$count canciones',
        AppLanguage.en => '$count songs',
        AppLanguage.ja => '$count曲',
      };

  String storedContentFrom(String artist) => switch (language) {
        AppLanguage.es => 'De $artist',
        AppLanguage.en => 'By $artist',
        AppLanguage.ja => '$artistの曲',
      };

  String get noTracksFound => switch (language) {
        AppLanguage.es => 'No se encontraron canciones',
        AppLanguage.en => 'No tracks found',
        AppLanguage.ja => '楽曲が見つかりませんでした',
      };

  String get loadingMoreAlbums => switch (language) {
        AppLanguage.es => 'Cargando más lanzamientos...',
        AppLanguage.en => 'Loading more releases...',
        AppLanguage.ja => 'リリースを読み込み中...',
      };

  String get retryLoading => switch (language) {
        AppLanguage.es => 'Reintentar',
        AppLanguage.en => 'Retry',
        AppLanguage.ja => '再試行',
      };

  String get allAlbumsLoaded => switch (language) {
        AppLanguage.es => '// FIN DEL CATÁLOGO',
        AppLanguage.en => '// END OF CATALOG',
        AppLanguage.ja => '// カタログ終了',
      };

  String get lyrics => switch (language) {
        AppLanguage.es => 'LETRAS',
        AppLanguage.en => 'LYRICS',
        AppLanguage.ja => '歌詞',
      };

  String get lyricsLoading => switch (language) {
        AppLanguage.es => '// SINCRONIZANDO LETRAS...',
        AppLanguage.en => '// SYNCING LYRICS...',
        AppLanguage.ja => '// 歌詞を同期中...',
      };

  String get noLyricsFound => switch (language) {
        AppLanguage.es => '// LETRAS NO DISPONIBLES //',
        AppLanguage.en => '// NO LYRICS AVAILABLE //',
        AppLanguage.ja => '// 歌詞が見つかりません //',
      };

  String get instrumentalTrack => switch (language) {
        AppLanguage.es => '// PISTA INSTRUMENTAL //',
        AppLanguage.en => '// INSTRUMENTAL TRACK //',
        AppLanguage.ja => '// インストゥルメンタル //',
      };

  String get syncedTapToSeek => switch (language) {
        AppLanguage.es => 'Toca un verso para saltar',
        AppLanguage.en => 'Tap line to seek',
        AppLanguage.ja => 'タップして再生位置を移動',
      };

  // --- Telemetry & Spotify Errors in Nav ---
  String get spotifyTokenExpired => switch (language) {
        AppLanguage.es => 'ENLACE EXPIRADO // Reconecta tu cuenta de Spotify en Inicio.',
        AppLanguage.en => 'LINK EXPIRED // Reconnect your Spotify account in Home.',
        AppLanguage.ja => 'セッション失効 // ホームからSpotifyを再連携してください。',
      };

  String get spotifyPremiumRequired => switch (language) {
        AppLanguage.es => 'PLAN STANDARD // Se requiere Spotify Premium para streaming completo.',
        AppLanguage.en => 'STANDARD PLAN // Spotify Premium is required for full streaming.',
        AppLanguage.ja => 'フリープラン // フル再生にはSpotify Premiumが必要です。',
      };

  String get spotifyNoActiveDevice => switch (language) {
        AppLanguage.es => 'DISPOSITIVO INACTIVO // Abre la app de Spotify para vincular.',
        AppLanguage.en => 'DEVICE INACTIVE // Open Spotify app to link active device.',
        AppLanguage.ja => '端末未接続 // Spotifyアプリを起動して接続してください。',
      };

  String get spotifyNoConnection => switch (language) {
        AppLanguage.es => 'SIN CONEXIÓN // Reintentando enlace con el servidor de audio...',
        AppLanguage.en => 'NO CONNECTION // Retrying audio server connection...',
        AppLanguage.ja => 'オフライン // 音源サーバーへの再接続を試みています...',
      };

  String get spotifyTrackUnavailablePreview => switch (language) {
        AppLanguage.es => 'Pista no disponible en Spotify, reproduciendo vista previa',
        AppLanguage.en => 'Track unavailable on Spotify, playing preview',
        AppLanguage.ja => 'Spotifyで利用不可のため、プレビューを再生中',
      };

  String get spotifyOpenAppPrompt => switch (language) {
        AppLanguage.es => 'Abre la app de Spotify para activar la reproducción completa',
        AppLanguage.en => 'Open the Spotify app to activate full playback',
        AppLanguage.ja => 'フル再生を有効にするにはSpotifyアプリを起動してください',
      };

  String get audioStatusPrefix => switch (language) {
        AppLanguage.es => 'ESTADO AUDIO //',
        AppLanguage.en => 'AUDIO STATUS //',
        AppLanguage.ja => '音声ステータス //',
      };

  String get openSpotifyTooltip => switch (language) {
        AppLanguage.es => 'Abrir Spotify',
        AppLanguage.en => 'Open Spotify',
        AppLanguage.ja => 'Spotifyを開く',
      };

  String get errorPrefix => switch (language) {
        AppLanguage.es => 'Error',
        AppLanguage.en => 'Error',
        AppLanguage.ja => 'エラー',
      };

  // --- Artist Card & Discography ---
  String artistFansCompact(String count) => switch (language) {
        AppLanguage.es => '$count fans',
        AppLanguage.en => '$count fans',
        AppLanguage.ja => '$count ファン',
      };

  // --- Album Progress & Library Items ---
  String albumProgressListened(int listened, int total) => switch (language) {
        AppLanguage.es => '$listened/$total escuchadas',
        AppLanguage.en => '$listened/$total listened',
        AppLanguage.ja => '$listened/$total 聴取済み',
      };

  String get unknownAlbum => switch (language) {
        AppLanguage.es => 'Álbum desconocido',
        AppLanguage.en => 'Unknown Album',
        AppLanguage.ja => '未確認アルバム',
      };

  String trackCountLabel(int count) => switch (language) {
        AppLanguage.es => '$count ${count == 1 ? "canción" : "canciones"}',
        AppLanguage.en => '$count ${count == 1 ? "track" : "tracks"}',
        AppLanguage.ja => '$count 曲',
      };

  String get viewAlbum => switch (language) {
        AppLanguage.es => 'Ver álbum',
        AppLanguage.en => 'View album',
        AppLanguage.ja => 'アルバムを表示',
      };

  // --- Queue View (Expanded Player) ---
  String get queueUpNext => switch (language) {
        AppLanguage.es => 'SIGUIENTES EN LA COLA',
        AppLanguage.en => 'UP NEXT IN QUEUE',
        AppLanguage.ja => '次に再生',
      };

  String get queueClear => switch (language) {
        AppLanguage.es => 'LIMPIAR',
        AppLanguage.en => 'CLEAR',
        AppLanguage.ja => 'クリア',
      };

  String get queueClearLabel => switch (language) {
        AppLanguage.es => 'Limpiar cola',
        AppLanguage.en => 'Clear queue',
        AppLanguage.ja => 'キューをクリア',
      };

  String get queueEmpty => switch (language) {
        AppLanguage.es => 'COLA VACÍA',
        AppLanguage.en => 'QUEUE EMPTY',
        AppLanguage.ja => 'キューは空です',
      };

  String get queueEmptySubtitle => switch (language) {
        AppLanguage.es => 'Agrega canciones para continuar la sesión',
        AppLanguage.en => 'Add songs to continue the session',
        AppLanguage.ja => 'セッションを続けるには曲を追加してください',
      };

  String get queueRemoveLabel => switch (language) {
        AppLanguage.es => 'Eliminar de la cola',
        AppLanguage.en => 'Remove from queue',
        AppLanguage.ja => 'キューから削除',
      };

  String get removedFromQueue => switch (language) {
        AppLanguage.es => 'Eliminado de la cola',
        AppLanguage.en => 'Removed from queue',
        AppLanguage.ja => 'キューから削除しました',
      };

  String get lyricsFollowing => switch (language) {
        AppLanguage.es => 'SIGUIENDO CANCIÓN',
        AppLanguage.en => 'FOLLOWING SONG',
        AppLanguage.ja => '楽曲に追従中',
      };

  String get lyricsRetry => switch (language) {
        AppLanguage.es => 'REINTENTAR',
        AppLanguage.en => 'RETRY',
        AppLanguage.ja => '再試行',
      };

  // --- Track Context Menu ---
  String get goToArtist => switch (language) {
        AppLanguage.es => 'Ir al artista',
        AppLanguage.en => 'Go to artist',
        AppLanguage.ja => 'アーティストへ移動',
      };

  String get goToAlbum => switch (language) {
        AppLanguage.es => 'Ir al álbum',
        AppLanguage.en => 'Go to album',
        AppLanguage.ja => 'アルバムへ移動',
      };

  String get playNext => switch (language) {
        AppLanguage.es => 'Reproducir siguiente',
        AppLanguage.en => 'Play next',
        AppLanguage.ja => '次に再生',
      };

  String get addedPlayNext => switch (language) {
        AppLanguage.es => 'Se reproducirá a continuación',
        AppLanguage.en => 'Will play next',
        AppLanguage.ja => '次に再生されます',
      };

  // --- Mini Player ---
  String get stoppedPlayback => switch (language) {
        AppLanguage.es => 'Reproducción detenida',
        AppLanguage.en => 'Playback stopped',
        AppLanguage.ja => '再生を停止しました',
      };

  String get undo => switch (language) {
        AppLanguage.es => 'DESHACER',
        AppLanguage.en => 'UNDO',
        AppLanguage.ja => '元に戻す',
      };

  // Gesture hints
  String get swipeToRemoveHint => switch (language) {
        AppLanguage.es => 'Desliza para eliminar',
        AppLanguage.en => 'Swipe to remove',
        AppLanguage.ja => 'スワイプで削除',
      };


  // Listened toggle tooltip
  String get markAsListened => switch (language) {
        AppLanguage.es => 'Marcar como escuchada',
        AppLanguage.en => 'Mark as listened',
        AppLanguage.ja => '聴取済みにする',
      };

  String get unmarkAsListened => switch (language) {
        AppLanguage.es => 'Desmarcar como escuchada',
        AppLanguage.en => 'Unmark as listened',
        AppLanguage.ja => '聴取済みを解除',
      };

  // --- Expanded Player ---
  String get noTrackSelected => switch (language) {
        AppLanguage.es => 'No hay canción seleccionada',
        AppLanguage.en => 'No track selected',
        AppLanguage.ja => '楽曲が選択されていません',
      };

  // --- Onboarding & Guide Tutorial ---
  String get onboardingHeaderPrefix => 'TSUKI TUNES // ';

  String get onboardingHeaderGlitch => switch (language) {
        AppLanguage.es => 'GUÍA',
        AppLanguage.en => 'GUIDE',
        AppLanguage.ja => 'ガイド',
      };

  String get onboardingHeader => '$onboardingHeaderPrefix$onboardingHeaderGlitch';

  String get onboardingSkip => switch (language) {
        AppLanguage.es => 'SALTAR',
        AppLanguage.en => 'SKIP',
        AppLanguage.ja => 'スキップ',
      };

  String get onboardingNext => switch (language) {
        AppLanguage.es => 'SIGUIENTE',
        AppLanguage.en => 'NEXT',
        AppLanguage.ja => '次へ',
      };

  String get onboardingStart => switch (language) {
        AppLanguage.es => 'EMPEZAR A ESCUCHAR',
        AppLanguage.en => 'START LISTENING',
        AppLanguage.ja => '音楽を始める',
      };

  String get onboardingSlide1Badge => switch (language) {
        AppLanguage.es => 'TU COLECCIÓN • BIBLIOTECA',
        AppLanguage.en => 'YOUR COLLECTION • LIBRARY',
        AppLanguage.ja => 'コレクション • ライブラリ',
      };

  String get onboardingSlide1Title => switch (language) {
        AppLanguage.es => 'GUARDA TODA TU MÚSICA',
        AppLanguage.en => 'SAVE ALL YOUR MUSIC',
        AppLanguage.ja => 'すべての音楽を記録',
      };

  String get onboardingSlide1Desc => switch (language) {
        AppLanguage.es =>
          'Guarda tus canciones y álbumes favoritos con un toque. Mantén tu colección musical organizada en tu teléfono y accede a tus temas en cualquier momento.',
        AppLanguage.en =>
          'Save your favorite tracks and albums with a single tap. Keep your music collection organized on your device and access your songs anytime.',
        AppLanguage.ja =>
          'ワンタップでお気に入りの楽曲やアルバムを記録。お気に入りの音楽コレクションを端末内で整理し、いつでも素早くアクセスできます。',
      };

  String get onboardingPillFavorites => switch (language) {
        AppLanguage.es => 'CANCIONES FAVORITAS',
        AppLanguage.en => 'FAVORITE TRACKS',
        AppLanguage.ja => 'お気に入り楽曲',
      };

  String get onboardingPillStorage => switch (language) {
        AppLanguage.es => 'GUARDADO EN TU CUENTA',
        AppLanguage.en => 'SAVED TO YOUR ACCOUNT',
        AppLanguage.ja => 'アカウントに保存',
      };

  String get onboardingPillAlbums => switch (language) {
        AppLanguage.es => 'COLECCIÓN POR ÁLBUMES',
        AppLanguage.en => 'ALBUM COLLECTION',
        AppLanguage.ja => 'アルバム分類',
      };

  String get onboardingOniMaskHint => switch (language) {
        AppLanguage.es => 'Toca la máscara para marcar como escuchado',
        AppLanguage.en => 'Tap the mask to mark as listened',
        AppLanguage.ja => 'マスクをタップして既聴にする',
      };

  String get onboardingOniMaskNotListened => switch (language) {
        AppLanguage.es => 'SIN ESCUCHAR',
        AppLanguage.en => 'NOT LISTENED',
        AppLanguage.ja => '未聴',
      };

  String get onboardingOniMaskListened => switch (language) {
        AppLanguage.es => 'ESCUCHADO',
        AppLanguage.en => 'LISTENED',
        AppLanguage.ja => '既聴',
      };

  String get onboardingAlbumProgressHint => switch (language) {
        AppLanguage.es => 'Las portadas ganan color a medida que escuchas más canciones del álbum',
        AppLanguage.en => 'Covers gain color as you listen to more songs from the album',
        AppLanguage.ja => 'アルバムの曲を聴くほどカバーに色がつきます',
      };

  String get onboardingAlbumProgress0 => switch (language) {
        AppLanguage.es => '0%',
        AppLanguage.en => '0%',
        AppLanguage.ja => '0%',
      };

  String get onboardingAlbumProgress100 => switch (language) {
        AppLanguage.es => '100%',
        AppLanguage.en => '100%',
        AppLanguage.ja => '100%',
      };

  String get onboardingSlide2Badge => switch (language) {
        AppLanguage.es => 'EXPLORACIÓN • CATÁLOGO',
        AppLanguage.en => 'EXPLORATION • CATALOG',
        AppLanguage.ja => '探索 • カタログ',
      };

  String get onboardingSlide2Title => switch (language) {
        AppLanguage.es => 'DESCUBRE MILLONES DE TEMAS',
        AppLanguage.en => 'DISCOVER MILLIONS OF TRACKS',
        AppLanguage.ja => '数百万の楽曲を発見',
      };

  String get onboardingSlide2Desc => switch (language) {
        AppLanguage.es =>
          'Busca cualquier artista, canción o disco en segundos. Explora tendencias globales y escucha avances en alta fidelidad al instante.',
        AppLanguage.en =>
          'Search any artist, song or album in seconds. Explore global trends and preview high-fidelity audio instantly.',
        AppLanguage.ja =>
          'アーティスト、楽曲、アルバムを瞬時に検索。世界中のトレンドや高音質プレビューを今すぐ体感。',
      };

  String get onboardingPillSearch => switch (language) {
        AppLanguage.es => 'BÚSQUEDA INSTANTÁNEA',
        AppLanguage.en => 'INSTANT SEARCH',
        AppLanguage.ja => '高速検索',
      };

  String get onboardingPillTracks => switch (language) {
        AppLanguage.es => 'MÁS DE 90M DE PISTAS',
        AppLanguage.en => 'OVER 90M TRACKS',
        AppLanguage.ja => '9,000万曲以上',
      };

  String get onboardingPillPreview => switch (language) {
        AppLanguage.es => 'VISTA PREVIA HI-FI',
        AppLanguage.en => 'HI-FI PREVIEW',
        AppLanguage.ja => '高音質プレビュー',
      };

  String get onboardingSlide3Badge => switch (language) {
        AppLanguage.es => 'EXPERIENCIA • REPRODUCTOR',
        AppLanguage.en => 'EXPERIENCE • PLAYER',
        AppLanguage.ja => '音楽体験 • プレイヤー',
      };

  String get onboardingSlide3Title => switch (language) {
        AppLanguage.es => 'REPRODUCTOR INMERSIVO',
        AppLanguage.en => 'IMMERSIVE PLAYER',
        AppLanguage.ja => '没入型プレイヤー',
      };

  String get onboardingSlide3Desc => switch (language) {
        AppLanguage.es =>
          'Control total de tu música con ecualizadores dinámicos, diseño a pantalla completa y controles fluidos a 120 FPS.',
        AppLanguage.en =>
          'Full control of your audio with dynamic visualizers, full-screen HUD, and fluid 120 FPS playback controls.',
        AppLanguage.ja =>
          'ダイナミックなビジュアライザー、全画面表示、120 FPSの流麗な操作性で音楽を意のままにコントロール。',
      };

  String get onboardingPillEqualizer => switch (language) {
        AppLanguage.es => 'ECUALIZADOR REACTIVO',
        AppLanguage.en => 'REACTIVE EQUALIZER',
        AppLanguage.ja => '適応型イコライザー',
      };

  String get onboardingPillFullscreen => switch (language) {
        AppLanguage.es => 'PANTALLA COMPLETA',
        AppLanguage.en => 'FULL SCREEN',
        AppLanguage.ja => '全画面表示',
      };

  String get onboardingPillCyberHUD => switch (language) {
        AppLanguage.es => 'INTERFAZ CYBER HUD',
        AppLanguage.en => 'CYBER HUD INTERFACE',
        AppLanguage.ja => 'Cyber HUD インターフェース',
      };

  // --- Login Screen ---
  String get loginGuestExplore => switch (language) {
        AppLanguage.es => 'EXPLORAR CATÁLOGO',
        AppLanguage.en => 'EXPLORE CATALOG',
        AppLanguage.ja => 'カタログを探索',
      };

  String get guestLibraryTitle => switch (language) {
        AppLanguage.es => 'BIBLIOTECA BLOQUEADA',
        AppLanguage.en => 'LIBRARY LOCKED',
        AppLanguage.ja => 'ライブラリはロック中',
      };

  String get guestLibraryDesc => switch (language) {
        AppLanguage.es => 'Inicia sesión con Google para guardar tu música, favoritos y historial de escucha.',
        AppLanguage.en => 'Sign in with Google to save your music, favorites and listening history.',
        AppLanguage.ja => 'Googleでログインして、音楽、お気に入り、視聴履歴を保存しましょう。',
      };

  String get guestLoginAction => switch (language) {
        AppLanguage.es => 'INICIAR SESIÓN',
        AppLanguage.en => 'SIGN IN',
        AppLanguage.ja => 'ログイン',
      };

  String get loginSubtitlePrefix => switch (language) {
        AppLanguage.es => 'TU BIBLIOTECA ',
        AppLanguage.en => 'YOUR MUSIC ',
        AppLanguage.ja => 'あなたの音楽 ',
      };

  String get loginSubtitleGlitch => switch (language) {
        AppLanguage.es => 'MUSICAL',
        AppLanguage.en => 'LIBRARY',
        AppLanguage.ja => 'ライブラリ',
      };

  String get loginGoogle => switch (language) {
        AppLanguage.es => 'INGRESAR CON GOOGLE',
        AppLanguage.en => 'SIGN IN WITH GOOGLE',
        AppLanguage.ja => 'Googleでログイン',
      };

  String get loginLoading => switch (language) {
        AppLanguage.es => 'INGRESANDO...',
        AppLanguage.en => 'SIGNING IN...',
        AppLanguage.ja => 'ログイン中...',
      };

  String get loginGranted => switch (language) {
        AppLanguage.es => 'ACCESO CONCEDIDO',
        AppLanguage.en => 'ACCESS GRANTED',
        AppLanguage.ja => 'アクセス承認',
      };

  String get loginGoogleError => switch (language) {
        AppLanguage.es => 'Error al conectar con Google. Comprueba tu conexión e intenta de nuevo.',
        AppLanguage.en => 'Error connecting with Google. Check your connection and try again.',
        AppLanguage.ja => 'Googleとの接続に失敗しました。通信環境を確認して再試行してください。',
      };

  String get loginThrottled => switch (language) {
        AppLanguage.es => 'Demasiados intentos. Espera unos segundos antes de intentar de nuevo.',
        AppLanguage.en => 'Too many attempts. Wait a few seconds before trying again.',
        AppLanguage.ja => '試行回数が多すぎます。しばらく待ってから再試行してください。',
      };

  // --- Loading / Startup Screen ---
  String get loadingStatus => switch (language) {
        AppLanguage.es => 'MOTOR DE AUDIO // INICIALIZANDO...',
        AppLanguage.en => 'AUDIO ENGINE // INITIALIZING...',
        AppLanguage.ja => 'オーディオエンジン // 初期化中...',
      };

  String get loadingSubtitle => switch (language) {
        AppLanguage.es => 'REPRODUCTOR DE AUDIO CYBER',
        AppLanguage.en => 'CYBER AUDIO PLAYER',
        AppLanguage.ja => '電脳音楽プレイヤー',
      };

  // --- Error / Connectivity ---
  String get searchError => switch (language) {
        AppLanguage.es => 'Error al buscar. Revisa tu conexión.',
        AppLanguage.en => 'Search failed. Check your connection.',
        AppLanguage.ja => '検索に失敗しました。接続を確認してください。',
      };

  String get loadError => switch (language) {
        AppLanguage.es => 'No se pudieron cargar los datos. Revisa tu conexión.',
        AppLanguage.en => 'Could not load data. Check your connection.',
        AppLanguage.ja => 'データを読み込めませんでした。接続を確認してください。',
      };

  String get retry => switch (language) {
        AppLanguage.es => 'REINTENTAR',
        AppLanguage.en => 'RETRY',
        AppLanguage.ja => '再試行',
      };

  String get offline => switch (language) {
        AppLanguage.es => 'Sin conexión a internet',
        AppLanguage.en => 'No internet connection',
        AppLanguage.ja => 'インターネット接続なし',
      };

  String get playbackError => switch (language) {
        AppLanguage.es => 'Error al reproducir esta pista',
        AppLanguage.en => 'Error playing this track',
        AppLanguage.ja => 'この曲の再生に失敗しました',
      };

  String get playbackNoPreview => switch (language) {
        AppLanguage.es => 'Esta pista no tiene vista previa de audio disponible',
        AppLanguage.en => 'Audio preview is unavailable for this track',
        AppLanguage.ja => 'この曲のプレビュー音源は利用できません',
      };

  String get playbackNetworkError => switch (language) {
        AppLanguage.es => 'Error de conexión al reproducir el audio. Revisa tu internet',
        AppLanguage.en => 'Network error loading audio. Check your connection',
        AppLanguage.ja => 'オーディオの再生中にネットワークエラーが発生しました。接続を確認してください',
      };

  String get playbackFormatUnsupported => switch (language) {
        AppLanguage.es => 'Formato de audio no compatible con este dispositivo',
        AppLanguage.en => 'Audio format is not supported on this device',
        AppLanguage.ja => 'この端末ではサポートされていないオーディオ形式です',
      };

  // --- Home Screen Error & Empty States ---
  String get homeLoadError => switch (language) {
        AppLanguage.es => 'ERROR DE ENLACE // DATOS NO DISPONIBLES',
        AppLanguage.en => 'LINK ERROR // DATA UNAVAILABLE',
        AppLanguage.ja => 'リンクエラー // データ取得不可',
      };

  String get homeLoadErrorSubtitle => switch (language) {
        AppLanguage.es => 'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.',
        AppLanguage.en => 'Could not connect to the server. Check your connection and try again.',
        AppLanguage.ja => 'サーバーに接続できませんでした。接続を確認して再試行してください。',
      };

  String get homeEmptyTitle => switch (language) {
        AppLanguage.es => 'SISTEMA EN ESPERA',
        AppLanguage.en => 'SYSTEM STANDBY',
        AppLanguage.ja => 'システム待機中',
      };

  String get homeEmptySubtitle => switch (language) {
        AppLanguage.es => 'Busca y reproduce canciones para que el sistema aprenda tus gustos y personalice tu inicio.',
        AppLanguage.en => 'Search and play tracks so the system learns your taste and personalizes your home.',
        AppLanguage.ja => '楽曲を検索・再生すると、システムがあなたの好みを学習し、ホームをパーソナライズします。',
      };

  String get homeEmptyAction => switch (language) {
        AppLanguage.es => 'IR A BUSCAR',
        AppLanguage.en => 'GO TO SEARCH',
        AppLanguage.ja => '検索へ移動',
      };

  String get offlineNotice => switch (language) {
        AppLanguage.es => 'MODO OFFLINE // Conecta a internet para cargar datos',
        AppLanguage.en => 'OFFLINE MODE // Connect to the internet to load data',
        AppLanguage.ja => 'オフラインモード // データの読み込みにはインターネット接続が必要です',
      };

  String get offlineNoCache => switch (language) {
        AppLanguage.es => 'Sin conexión y este track no está en caché',
        AppLanguage.en => 'Offline and this track is not cached',
        AppLanguage.ja => 'オフラインでこのトラックはキャッシュされていません',
      };

  String get repeatOff => switch (language) {
        AppLanguage.es => 'Repetición desactivada',
        AppLanguage.en => 'Repeat off',
        AppLanguage.ja => 'リピートオフ',
      };

  String get repeatAll => switch (language) {
        AppLanguage.es => 'Repetir toda la cola',
        AppLanguage.en => 'Repeat queue',
        AppLanguage.ja => 'キュー全体をリピート',
      };

  String get repeatOne => switch (language) {
        AppLanguage.es => 'Repetir esta canción',
        AppLanguage.en => 'Repeat track',
        AppLanguage.ja => 'この曲をリピート',
      };

  // --- Sleep Timer ---
  String get sleepTimer => switch (language) {
        AppLanguage.es => 'TEMPORIZADOR',
        AppLanguage.en => 'SLEEP TIMER',
        AppLanguage.ja => 'スリープタイマー',
      };

  String get sleepTimerOff => switch (language) {
        AppLanguage.es => 'DESACTIVADO',
        AppLanguage.en => 'OFF',
        AppLanguage.ja => 'オフ',
      };

  String get sleepTimerEndOfTrack => switch (language) {
        AppLanguage.es => 'AL TERMINAR ESTA CANCIÓN',
        AppLanguage.en => 'END OF CURRENT TRACK',
        AppLanguage.ja => '現在の曲の終わりに',
      };

  String sleepTimerMinutes(int minutes) => switch (language) {
        AppLanguage.es => '$minutes MINUTOS',
        AppLanguage.en => '$minutes MINUTES',
        AppLanguage.ja => '$minutes分',
      };

  String sleepTimerRemainingLabel(String time) => switch (language) {
        AppLanguage.es => 'APAGADO EN $time',
        AppLanguage.en => 'STOPPING IN $time',
        AppLanguage.ja => '$timeで停止',
      };

  String get sleepTimerEndOfTrackShort => switch (language) {
        AppLanguage.es => 'ÚLTIMA CANCIÓN',
        AppLanguage.en => 'LAST TRACK',
        AppLanguage.ja => 'ラストトラック',
      };

  // --- Accessibility Semantic Labels ---
  String get a11yPlay => switch (language) {
        AppLanguage.es => 'Reproducir',
        AppLanguage.en => 'Play',
        AppLanguage.ja => '再生',
      };

  String get a11yPause => switch (language) {
        AppLanguage.es => 'Pausar',
        AppLanguage.en => 'Pause',
        AppLanguage.ja => '一時停止',
      };

  String get a11yStop => switch (language) {
        AppLanguage.es => 'Detener reproducción',
        AppLanguage.en => 'Stop playback',
        AppLanguage.ja => '再生を停止',
      };

  String get a11yPrevious => switch (language) {
        AppLanguage.es => 'Pista anterior',
        AppLanguage.en => 'Previous track',
        AppLanguage.ja => '前のトラック',
      };

  String get a11yNext => switch (language) {
        AppLanguage.es => 'Siguiente pista',
        AppLanguage.en => 'Next track',
        AppLanguage.ja => '次のトラック',
      };

  String get a11yShuffleOn => switch (language) {
        AppLanguage.es => 'Aleatorio activado',
        AppLanguage.en => 'Shuffle on',
        AppLanguage.ja => 'シャッフルオン',
      };

  String get a11yShuffleOff => switch (language) {
        AppLanguage.es => 'Aleatorio desactivado',
        AppLanguage.en => 'Shuffle off',
        AppLanguage.ja => 'シャッフルオフ',
      };

  String get a11yMarkListened => switch (language) {
        AppLanguage.es => 'Marcar como escuchado',
        AppLanguage.en => 'Mark track as listened',
        AppLanguage.ja => '既聴としてマーク',
      };

  String get a11yUnmarkListened => switch (language) {
        AppLanguage.es => 'Desmarcar como escuchado',
        AppLanguage.en => 'Unmark track',
        AppLanguage.ja => '既聴マークを外す',
      };

  String get a11yShowStats => switch (language) {
        AppLanguage.es => 'Mostrar estadísticas',
        AppLanguage.en => 'Show statistics',
        AppLanguage.ja => '統計を表示',
      };

  String get a11yHideStats => switch (language) {
        AppLanguage.es => 'Ocultar estadísticas',
        AppLanguage.en => 'Hide statistics',
        AppLanguage.ja => '統計を非表示',
      };

  String get a11yShowAllTracks => switch (language) {
        AppLanguage.es => 'Mostrar todas las canciones',
        AppLanguage.en => 'Show all tracks',
        AppLanguage.ja => 'すべての曲を表示',
      };

  String get a11yShowLessTracks => switch (language) {
        AppLanguage.es => 'Mostrar menos canciones',
        AppLanguage.en => 'Show fewer tracks',
        AppLanguage.ja => '曲を少なく表示',
      };

  String get a11yViewDiscography => switch (language) {
        AppLanguage.es => 'Ver discografía completa',
        AppLanguage.en => 'View full discography',
        AppLanguage.ja => 'ディスコグラフィーを見る',
      };

  String get a11yExpandStoredContent => switch (language) {
        AppLanguage.es => 'Expandir contenido guardado',
        AppLanguage.en => 'Expand stored content',
        AppLanguage.ja => '保存したコンテンツを展開',
      };

  String get a11yCollapseStoredContent => switch (language) {
        AppLanguage.es => 'Colapsar contenido guardado',
        AppLanguage.en => 'Collapse stored content',
        AppLanguage.ja => '保存したコンテンツを折りたたむ',
      };

  String get a11yLoginWithGoogle => switch (language) {
        AppLanguage.es => 'Iniciar sesión con Google',
        AppLanguage.en => 'Sign in with Google',
        AppLanguage.ja => 'Googleでログイン',
      };

  String get a11yContinueAsGuest => switch (language) {
        AppLanguage.es => 'Continuar como invitado',
        AppLanguage.en => 'Continue as guest',
        AppLanguage.ja => 'ゲストとして続ける',
      };

  String get a11ySelectLanguage => switch (language) {
        AppLanguage.es => 'Seleccionar idioma',
        AppLanguage.en => 'Select language',
        AppLanguage.ja => '言語を選択',
      };

  String get a11yRetryLyrics => switch (language) {
        AppLanguage.es => 'Reintentar carga de letra',
        AppLanguage.en => 'Retry loading lyrics',
        AppLanguage.ja => '歌詞の読み込みを再試行',
      };

  String get a11yGoToSearch => switch (language) {
        AppLanguage.es => 'Ir a búsqueda',
        AppLanguage.en => 'Go to search',
        AppLanguage.ja => '検索へ',
      };

  String get a11yCollapsePlayer => switch (language) {
        AppLanguage.es => 'Minimizar reproductor',
        AppLanguage.en => 'Minimize player',
        AppLanguage.ja => 'プレーヤーを最小化',
      };

  String get a11yOpenInSpotify => switch (language) {
        AppLanguage.es => 'Abrir en Spotify',
        AppLanguage.en => 'Open in Spotify',
        AppLanguage.ja => 'Spotifyで開く',
      };

  String get a11yPlaybackError => switch (language) {
        AppLanguage.es => 'Error de reproducción',
        AppLanguage.en => 'Playback error',
        AppLanguage.ja => '再生エラー',
      };

  String get syncError => switch (language) {
        AppLanguage.es => 'No se pudo guardar. Intenta de nuevo.',
        AppLanguage.en => 'Could not save. Try again.',
        AppLanguage.ja => '保存できませんでした。もう一度お試しください。',
      };

  String get a11ySyncError => switch (language) {
        AppLanguage.es => 'Error de sincronización',
        AppLanguage.en => 'Sync error',
        AppLanguage.ja => '同期エラー',
      };

  String get a11ySleepTimer => switch (language) {
        AppLanguage.es => 'Temporizador de sueño',
        AppLanguage.en => 'Sleep timer',
        AppLanguage.ja => 'スリープタイマー',
      };

  String get a11yQueue => switch (language) {
        AppLanguage.es => 'Cola de reproducción',
        AppLanguage.en => 'Playback queue',
        AppLanguage.ja => '再生キュー',
      };

  String get a11yClearQueue => switch (language) {
        AppLanguage.es => 'Limpiar cola',
        AppLanguage.en => 'Clear queue',
        AppLanguage.ja => 'キューをクリア',
      };

  String get a11yRemoveFromQueue => switch (language) {
        AppLanguage.es => 'Eliminar de la cola',
        AppLanguage.en => 'Remove from queue',
        AppLanguage.ja => 'キューから削除',
      };

  String get a11yNowPlaying => switch (language) {
        AppLanguage.es => 'Reproduciendo ahora',
        AppLanguage.en => 'Now playing',
        AppLanguage.ja => '再生中',
      };

  String get a11yAlbumCover => switch (language) {
        AppLanguage.es => 'Portada del álbum',
        AppLanguage.en => 'Album cover',
        AppLanguage.ja => 'アルバムカバー',
      };

  String get a11yReorder => switch (language) {
        AppLanguage.es => 'Reordenar',
        AppLanguage.en => 'Reorder',
        AppLanguage.ja => '並べ替え',
      };

  String get a11yLyrics => switch (language) {
        AppLanguage.es => 'Letras',
        AppLanguage.en => 'Lyrics',
        AppLanguage.ja => '歌詞',
      };

  String get a11yNoLyrics => switch (language) {
        AppLanguage.es => 'Sin letras disponibles',
        AppLanguage.en => 'No lyrics available',
        AppLanguage.ja => '歌詞がありません',
      };

  String get a11yVisualizer => switch (language) {
        AppLanguage.es => 'Visualizador de audio',
        AppLanguage.en => 'Audio visualizer',
        AppLanguage.ja => 'オーディオビジュアライザー',
      };

  String get a11ySyncingLyrics => switch (language) {
        AppLanguage.es => 'Sincronizando letras',
        AppLanguage.en => 'Syncing lyrics',
        AppLanguage.ja => '歌詞を同期中',
      };

  String get a11yPlayTrack => switch (language) {
        AppLanguage.es => 'Reproducir pista',
        AppLanguage.en => 'Play track',
        AppLanguage.ja => 'トラックを再生',
      };

  String get a11yArtistAvatar => switch (language) {
        AppLanguage.es => 'Foto del artista',
        AppLanguage.en => 'Artist photo',
        AppLanguage.ja => 'アーティストの写真',
      };

  String get a11ySeeAll => switch (language) {
        AppLanguage.es => 'Ver todo',
        AppLanguage.en => 'See all',
        AppLanguage.ja => 'すべて表示',
      };

  String get a11yFilter => switch (language) {
        AppLanguage.es => 'Filtrar',
        AppLanguage.en => 'Filter',
        AppLanguage.ja => 'フィルター',
      };

  String get a11yClearFilter => switch (language) {
        AppLanguage.es => 'Limpiar filtro',
        AppLanguage.en => 'Clear filter',
        AppLanguage.ja => 'フィルターをクリア',
      };

  String get a11yPlayAll => switch (language) {
        AppLanguage.es => 'Reproducir todo',
        AppLanguage.en => 'Play all',
        AppLanguage.ja => 'すべて再生',
      };

  String get a11yShuffleAll => switch (language) {
        AppLanguage.es => 'Mezclar todo',
        AppLanguage.en => 'Shuffle all',
        AppLanguage.ja => 'すべてシャッフル',
      };

  String get a11yOffline => switch (language) {
        AppLanguage.es => 'Sin conexión',
        AppLanguage.en => 'Offline',
        AppLanguage.ja => 'オフライン',
      };

  String get a11yEmptyLibrary => switch (language) {
        AppLanguage.es => 'Biblioteca vacía',
        AppLanguage.en => 'Empty library',
        AppLanguage.ja => 'ライブラリが空です',
      };

  String get a11yCreatePlaylist => switch (language) {
        AppLanguage.es => 'Crear playlist',
        AppLanguage.en => 'Create playlist',
        AppLanguage.ja => 'プレイリストを作成',
      };

  String get a11yRemoveFromPlaylist => switch (language) {
        AppLanguage.es => 'Eliminar de playlist',
        AppLanguage.en => 'Remove from playlist',
        AppLanguage.ja => 'プレイリストから削除',
      };

  String get a11yPlaylistCover => switch (language) {
        AppLanguage.es => 'Portada de playlist',
        AppLanguage.en => 'Playlist cover',
        AppLanguage.ja => 'プレイリストカバー',
      };

  String get a11yOpenPlaylist => switch (language) {
        AppLanguage.es => 'Abrir playlist',
        AppLanguage.en => 'Open playlist',
        AppLanguage.ja => 'プレイリストを開く',
      };

  String get a11yClearSearch => switch (language) {
        AppLanguage.es => 'Limpiar búsqueda',
        AppLanguage.en => 'Clear search',
        AppLanguage.ja => '検索をクリア',
      };

  String get a11ySearchEmpty => switch (language) {
        AppLanguage.es => 'Sin resultados',
        AppLanguage.en => 'No results',
        AppLanguage.ja => '結果なし',
      };

  String get a11yClearHistory => switch (language) {
        AppLanguage.es => 'Borrar historial',
        AppLanguage.en => 'Clear history',
        AppLanguage.ja => '履歴を削除',
      };

  String get a11ySearchHistory => switch (language) {
        AppLanguage.es => 'Historial de búsqueda',
        AppLanguage.en => 'Search history',
        AppLanguage.ja => '検索履歴',
      };

  String get a11yFillSearch => switch (language) {
        AppLanguage.es => 'Rellenar búsqueda',
        AppLanguage.en => 'Fill search',
        AppLanguage.ja => '検索を入力',
      };

  String get a11yBack => switch (language) {
        AppLanguage.es => 'Volver',
        AppLanguage.en => 'Go back',
        AppLanguage.ja => '戻る',
      };

  String get a11yMoreOptions => switch (language) {
        AppLanguage.es => 'Más opciones',
        AppLanguage.en => 'More options',
        AppLanguage.ja => 'その他のオプション',
      };

  String get a11yEditPlaylist => switch (language) {
        AppLanguage.es => 'Editar playlist',
        AppLanguage.en => 'Edit playlist',
        AppLanguage.ja => 'プレイリストを編集',
      };

  String get a11yDeletePlaylist => switch (language) {
        AppLanguage.es => 'Eliminar playlist',
        AppLanguage.en => 'Delete playlist',
        AppLanguage.ja => 'プレイリストを削除',
      };

  String get a11yEmptyPlaylist => switch (language) {
        AppLanguage.es => 'Playlist vacía',
        AppLanguage.en => 'Empty playlist',
        AppLanguage.ja => 'プレイリストが空です',
      };

  String get a11yRetry => switch (language) {
        AppLanguage.es => 'Reintentar',
        AppLanguage.en => 'Retry',
        AppLanguage.ja => '再試行',
      };

  String get a11yLoginError => switch (language) {
        AppLanguage.es => 'Error de inicio de sesión',
        AppLanguage.en => 'Login error',
        AppLanguage.ja => 'ログインエラー',
      };

  String get a11ySelected => switch (language) {
        AppLanguage.es => 'Seleccionado',
        AppLanguage.en => 'Selected',
        AppLanguage.ja => '選択済み',
      };

  String get a11yDeselect => switch (language) {
        AppLanguage.es => 'Deseleccionar',
        AppLanguage.en => 'Deselect',
        AppLanguage.ja => '選択解除',
      };

  String get a11yUpdateInfo => switch (language) {
        AppLanguage.es => 'Información de actualización',
        AppLanguage.en => 'Update information',
        AppLanguage.ja => 'アップデート情報',
      };

  String get a11yLoginRequired => switch (language) {
        AppLanguage.es => 'Inicio de sesión requerido',
        AppLanguage.en => 'Login required',
        AppLanguage.ja => 'ログインが必要です',
      };

  String get a11yRelatedArtists => switch (language) {
        AppLanguage.es => 'Artistas similares',
        AppLanguage.en => 'Related artists',
        AppLanguage.ja => '関連アーティスト',
      };

  String get a11yStoredContent => switch (language) {
        AppLanguage.es => 'Contenido almacenado',
        AppLanguage.en => 'Stored content',
        AppLanguage.ja => '保存済みコンテンツ',
      };

  String get a11yPlayNext => switch (language) {
        AppLanguage.es => 'Siguiente en cola',
        AppLanguage.en => 'Play next',
        AppLanguage.ja => '次に再生',
      };

  String get a11yAddToQueue => switch (language) {
        AppLanguage.es => 'Agregar a la cola',
        AppLanguage.en => 'Add to queue',
        AppLanguage.ja => 'キューに追加',
      };

  String get a11yAddToPlaylist => switch (language) {
        AppLanguage.es => 'Agregar a playlist',
        AppLanguage.en => 'Add to playlist',
        AppLanguage.ja => 'プレイリストに追加',
      };

  String get a11yGoToArtist => switch (language) {
        AppLanguage.es => 'Ir al artista',
        AppLanguage.en => 'Go to artist',
        AppLanguage.ja => 'アーティストへ',
      };

  String get a11yGoToAlbum => switch (language) {
        AppLanguage.es => 'Ir al álbum',
        AppLanguage.en => 'Go to album',
        AppLanguage.ja => 'アルバムへ',
      };

  String get a11yOpenExternal => switch (language) {
        AppLanguage.es => 'Abrir enlace externo',
        AppLanguage.en => 'Open external link',
        AppLanguage.ja => '外部リンクを開く',
      };

  String get a11yCloudStatus => switch (language) {
        AppLanguage.es => 'Estado de sincronización',
        AppLanguage.en => 'Sync status',
        AppLanguage.ja => '同期ステータス',
      };

  String get a11yClearCache => switch (language) {
        AppLanguage.es => 'Limpiar caché',
        AppLanguage.en => 'Clear cache',
        AppLanguage.ja => 'キャッシュをクリア',
      };

  String get a11yAbout => switch (language) {
        AppLanguage.es => 'Acerca de',
        AppLanguage.en => 'About',
        AppLanguage.ja => '情報',
      };

  String get a11yDebugInfo => switch (language) {
        AppLanguage.es => 'Información de depuración',
        AppLanguage.en => 'Debug info',
        AppLanguage.ja => 'デバッグ情報',
      };

  String get a11yLogout => switch (language) {
        AppLanguage.es => 'Cerrar sesión',
        AppLanguage.en => 'Sign out',
        AppLanguage.ja => 'ログアウト',
      };

  String get a11yDeleteAccount => switch (language) {
        AppLanguage.es => 'Eliminar cuenta',
        AppLanguage.en => 'Delete account',
        AppLanguage.ja => 'アカウントを削除',
      };

  String get a11yClose => switch (language) {
        AppLanguage.es => 'Cerrar',
        AppLanguage.en => 'Close',
        AppLanguage.ja => '閉じる',
      };

  String get a11yRepeatOff => switch (language) {
        AppLanguage.es => 'Repetir desactivado',
        AppLanguage.en => 'Repeat off',
        AppLanguage.ja => 'リピートオフ',
      };

  String get a11yRepeatAll => switch (language) {
        AppLanguage.es => 'Repetir todo',
        AppLanguage.en => 'Repeat all',
        AppLanguage.ja => '全曲リピート',
      };

  String get a11yRepeatOne => switch (language) {
        AppLanguage.es => 'Repetir una',
        AppLanguage.en => 'Repeat one',
        AppLanguage.ja => '一曲リピート',
      };

  String get a11yEmptyQueue => switch (language) {
        AppLanguage.es => 'Cola vacía',
        AppLanguage.en => 'Queue empty',
        AppLanguage.ja => 'キューが空です',
      };

  String get a11yFollowArtist => switch (language) {
        AppLanguage.es => 'Seguir artista',
        AppLanguage.en => 'Follow artist',
        AppLanguage.ja => 'アーティストをフォロー',
      };

  String get a11yUnfollowArtist => switch (language) {
        AppLanguage.es => 'Dejar de seguir artista',
        AppLanguage.en => 'Unfollow artist',
        AppLanguage.ja => 'アーティストのフォローを解除',
      };

  String get a11yMusicNote => switch (language) {
        AppLanguage.es => 'Nota musical',
        AppLanguage.en => 'Music note',
        AppLanguage.ja => '音符',
      };

  // --- Playlists ---
  String get playlistsTab => switch (language) {
        AppLanguage.es => 'Playlists',
        AppLanguage.en => 'Playlists',
        AppLanguage.ja => 'プレイリスト',
      };

  String get albumsTab => switch (language) {
        AppLanguage.es => 'Álbumes',
        AppLanguage.en => 'Albums',
        AppLanguage.ja => 'アルバム',
      };

  String get createPlaylist => switch (language) {
        AppLanguage.es => 'CREAR PLAYLIST',
        AppLanguage.en => 'CREATE PLAYLIST',
        AppLanguage.ja => 'プレイリスト作成',
      };

  String get newPlaylist => switch (language) {
        AppLanguage.es => 'Nueva Playlist',
        AppLanguage.en => 'New Playlist',
        AppLanguage.ja => '新規プレイリスト',
      };

  String get playlistName => switch (language) {
        AppLanguage.es => 'Nombre de la playlist',
        AppLanguage.en => 'Playlist name',
        AppLanguage.ja => 'プレイリスト名',
      };

  String get playlistNameHint => switch (language) {
        AppLanguage.es => 'Mi playlist...',
        AppLanguage.en => 'My playlist...',
        AppLanguage.ja => 'マイプレイリスト...',
      };

  String get create => switch (language) {
        AppLanguage.es => 'CREAR',
        AppLanguage.en => 'CREATE',
        AppLanguage.ja => '作成',
      };

  String get renamePlaylist => switch (language) {
        AppLanguage.es => 'Renombrar playlist',
        AppLanguage.en => 'Rename playlist',
        AppLanguage.ja => 'プレイリスト名を変更',
      };

  String get rename => switch (language) {
        AppLanguage.es => 'RENOMBRAR',
        AppLanguage.en => 'RENAME',
        AppLanguage.ja => '変更',
      };

  String get deletePlaylist => switch (language) {
        AppLanguage.es => 'Eliminar playlist',
        AppLanguage.en => 'Delete playlist',
        AppLanguage.ja => 'プレイリストを削除',
      };

  String deletePlaylistConfirm(String name) => switch (language) {
        AppLanguage.es => '¿Eliminar "$name"? Esta acción no se puede deshacer.',
        AppLanguage.en => 'Delete "$name"? This cannot be undone.',
        AppLanguage.ja => '「$name」を削除しますか？この操作は取り消せません。',
      };

  String get delete => switch (language) {
        AppLanguage.es => 'ELIMINAR',
        AppLanguage.en => 'DELETE',
        AppLanguage.ja => '削除',
      };

  String get addToPlaylist => switch (language) {
        AppLanguage.es => 'Agregar a playlist',
        AppLanguage.en => 'Add to playlist',
        AppLanguage.ja => 'プレイリストに追加',
      };

  String addedToPlaylist(String name) => switch (language) {
        AppLanguage.es => 'Agregado a "$name"',
        AppLanguage.en => 'Added to "$name"',
        AppLanguage.ja => '「$name」に追加しました',
      };

  String get trackAlreadyInPlaylist => switch (language) {
        AppLanguage.es => 'Esta canción ya está en la playlist',
        AppLanguage.en => 'This track is already in the playlist',
        AppLanguage.ja => 'この曲は既にプレイリストに追加済みです',
      };

  String get removedFromPlaylist => switch (language) {
        AppLanguage.es => 'Eliminado de la playlist',
        AppLanguage.en => 'Removed from playlist',
        AppLanguage.ja => 'プレイリストから削除しました',
      };

  String get emptyPlaylistTitle => switch (language) {
        AppLanguage.es => 'PLAYLIST VACÍA',
        AppLanguage.en => 'EMPTY PLAYLIST',
        AppLanguage.ja => 'プレイリストは空です',
      };

  String get emptyPlaylistSubtitle => switch (language) {
        AppLanguage.es => 'Agrega canciones desde el buscador o los álbumes',
        AppLanguage.en => 'Add tracks from search or albums',
        AppLanguage.ja => '検索やアルバムから楽曲を追加してください',
      };

  String get noPlaylistsTitle => switch (language) {
        AppLanguage.es => 'AÚN NO TIENES PLAYLISTS',
        AppLanguage.en => 'NO PLAYLISTS YET',
        AppLanguage.ja => 'プレイリストがありません',
      };

  String get noPlaylistsSubtitle => switch (language) {
        AppLanguage.es => 'Crea tu primera playlist y organiza tu música a tu manera',
        AppLanguage.en => 'Create your first playlist and organize your music your way',
        AppLanguage.ja => '最初のプレイリストを作成して、あなただけの音楽を整理しましょう',
      };

  String playlistMeta(int count, String duration) => switch (language) {
        AppLanguage.es => '$count canciones  ·  $duration',
        AppLanguage.en => '$count tracks  ·  $duration',
        AppLanguage.ja => '$count曲  ·  $duration',
      };

  String get playlistRenamed => switch (language) {
        AppLanguage.es => 'Playlist renombrada',
        AppLanguage.en => 'Playlist renamed',
        AppLanguage.ja => 'プレイリスト名を変更しました',
      };

  String get playlistDeleted => switch (language) {
        AppLanguage.es => 'Playlist eliminada',
        AppLanguage.en => 'Playlist deleted',
        AppLanguage.ja => 'プレイリストを削除しました',
      };

  String get playlistCreated => switch (language) {
        AppLanguage.es => 'Playlist creada',
        AppLanguage.en => 'Playlist created',
        AppLanguage.ja => 'プレイリストを作成しました',
      };

  String get selectPlaylist => switch (language) {
        AppLanguage.es => 'SELECCIONAR PLAYLIST',
        AppLanguage.en => 'SELECT PLAYLIST',
        AppLanguage.ja => 'プレイリストを選択',
      };

  // --- Similar Artists ---
  String get similarArtists => switch (language) {
        AppLanguage.es => 'ARTISTAS SIMILARES',
        AppLanguage.en => 'SIMILAR ARTISTS',
        AppLanguage.ja => '類似アーティスト',
      };

  // --- Follow Artist ---
  String get followArtist => switch (language) {
        AppLanguage.es => 'SEGUIR',
        AppLanguage.en => 'FOLLOW',
        AppLanguage.ja => 'フォロー',
      };

  String get unfollowArtist => switch (language) {
        AppLanguage.es => 'SIGUIENDO',
        AppLanguage.en => 'FOLLOWING',
        AppLanguage.ja => 'フォロー中',
      };

  String get artistFollowed => switch (language) {
        AppLanguage.es => 'Artista seguido',
        AppLanguage.en => 'Artist followed',
        AppLanguage.ja => 'アーティストをフォローしました',
      };

  String get artistUnfollowed => switch (language) {
        AppLanguage.es => 'Dejaste de seguir',
        AppLanguage.en => 'Unfollowed',
        AppLanguage.ja => 'フォロー解除しました',
      };

  String get artistCompleteTooltip => switch (language) {
        AppLanguage.es => 'Discografía completada',
        AppLanguage.en => 'Discography completed',
        AppLanguage.ja => 'ディスコグラフィー完了',
      };

  String get artistIncompleteTooltip => switch (language) {
        AppLanguage.es => 'Discografía incompleta',
        AppLanguage.en => 'Discography incomplete',
        AppLanguage.ja => 'ディスコグラフィー未完了',
      };
}
