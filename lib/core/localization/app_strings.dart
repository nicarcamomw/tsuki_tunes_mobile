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
        AppLanguage.es => 'SELECCIONA EL PROTOCOLO DE IDIOMA Y HUD',
        AppLanguage.en => 'SELECT LANGUAGE AND HUD PROTOCOL',
        AppLanguage.ja => '言語およびHUD表示形式の選択',
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
        AppLanguage.es => 'Marca canciones como escuchadas para ver lanzamientos personalizados',
        AppLanguage.en => 'Mark tracks as listened to see tailored releases',
        AppLanguage.ja => '楽曲を記録するとおすすめの新譜が表示されます',
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
        AppLanguage.es => 'Singles',
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

  String get noTracksFound => switch (language) {
        AppLanguage.es => 'No se encontraron canciones',
        AppLanguage.en => 'No tracks found',
        AppLanguage.ja => '楽曲が見つかりませんでした',
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
}
