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

  String get crossfadeTitle => switch (language) {
        AppLanguage.es => 'CROSSFADE PROGRESIVO',
        AppLanguage.en => 'SMOOTH CROSSFADE',
        AppLanguage.ja => 'クロスフェード',
      };

  String get crossfadeSubtitle => switch (language) {
        AppLanguage.es => 'Transición suave de DJ entre canciones sin silencios',
        AppLanguage.en => 'Smooth DJ mix transitions between songs without gaps',
        AppLanguage.ja => '曲間の無音をなくしDJのようにスムーズにつなぐ',
      };

  String get crossfadeOff => switch (language) {
        AppLanguage.es => 'Desactivado',
        AppLanguage.en => 'Disabled',
        AppLanguage.ja => 'オフ',
      };

  String get crossfadeDJ => switch (language) {
        AppLanguage.es => 'DJ',
        AppLanguage.en => 'DJ',
        AppLanguage.ja => 'DJ',
      };

  String get crossfadeMax => switch (language) {
        AppLanguage.es => 'Máx',
        AppLanguage.en => 'Max',
        AppLanguage.ja => '最大',
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
        AppLanguage.es => 'BORRAR CACHÉ DE AUDIO',
        AppLanguage.en => 'CLEAR AUDIO CACHE',
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

  // --- Lyrics Translation ---
  String get translateButton => switch (language) {
        AppLanguage.es => '訳',
        AppLanguage.en => '訳',
        AppLanguage.ja => '訳',
      };

  String get translateTooltip => switch (language) {
        AppLanguage.es => 'Traducir letras',
        AppLanguage.en => 'Translate lyrics',
        AppLanguage.ja => '歌詞を翻訳',
      };

  String get translationHide => switch (language) {
        AppLanguage.es => 'Ocultar traducción',
        AppLanguage.en => 'Hide translation',
        AppLanguage.ja => '翻訳を非表示',
      };

  String get translating => switch (language) {
        AppLanguage.es => '// TRADUCIENDO...',
        AppLanguage.en => '// TRANSLATING...',
        AppLanguage.ja => '// 翻訳中...',
      };

  String get translationError => switch (language) {
        AppLanguage.es => 'Error al traducir. Reintenta.',
        AppLanguage.en => 'Translation failed. Retry.',
        AppLanguage.ja => '翻訳に失敗しました。再試行してください。',
      };

  String get downloadingModel => switch (language) {
        AppLanguage.es => '// DESCARGANDO MODELO DE IDIOMA...',
        AppLanguage.en => '// DOWNLOADING LANGUAGE MODEL...',
        AppLanguage.ja => '// 言語モデルをダウンロード中...',
      };

  String get downloadModelTitle => switch (language) {
        AppLanguage.es => 'Descargar modelo de idioma',
        AppLanguage.en => 'Download language model',
        AppLanguage.ja => '言語モデルをダウンロード',
      };

  String downloadModelDesc(String size) => switch (language) {
        AppLanguage.es => 'Se necesita descargar ~$size MB de datos. Solo se hace una vez y después funciona sin internet.',
        AppLanguage.en => 'Need to download ~$size MB of data. This only happens once, then works offline.',
        AppLanguage.ja => '約${size}MBのデータダウンロードが必要です。一度だけで、以降はオフラインで動作します。',
      };

  String get downloadModelConfirm => switch (language) {
        AppLanguage.es => 'DESCARGAR',
        AppLanguage.en => 'DOWNLOAD',
        AppLanguage.ja => 'ダウンロード',
      };

  String get translatedTag => switch (language) {
        AppLanguage.es => 'TRADUCIDO OFFLINE',
        AppLanguage.en => 'TRANSLATED OFFLINE',
        AppLanguage.ja => 'オフライン翻訳済み',
      };

  String get a11yTranslate => switch (language) {
        AppLanguage.es => 'Traducir letras',
        AppLanguage.en => 'Translate lyrics',
        AppLanguage.ja => '歌詞を翻訳',
      };

  String get a11yHideTranslation => switch (language) {
        AppLanguage.es => 'Ocultar traducción',
        AppLanguage.en => 'Hide translation',
        AppLanguage.ja => '翻訳を非表示',
      };

  // --- Lyrics Search ---
  String get tabByLyrics => switch (language) {
        AppLanguage.es => 'Por Letra',
        AppLanguage.en => 'By Lyrics',
        AppLanguage.ja => '歌詞検索',
      };

  String get lyricsSearchHint => switch (language) {
        AppLanguage.es => 'Escribe un fragmento de letra...',
        AppLanguage.en => 'Type a lyrics fragment...',
        AppLanguage.ja => '歌詞の一部を入力...',
      };

  String get lyricsSearchEmpty => switch (language) {
        AppLanguage.es => 'BUSCA POR FRAGMENTO DE LETRA',
        AppLanguage.en => 'SEARCH BY LYRICS FRAGMENT',
        AppLanguage.ja => '歌詞の一部で検索',
      };

  String get lyricsSearchEmptySubtitle => switch (language) {
        AppLanguage.es => '"No me acuerdo del nombre pero dice..."',
        AppLanguage.en => '"I don\'t remember the name but it goes..."',
        AppLanguage.ja => '「曲名は忘れたけど歌詞は...」',
      };

  String lyricsSearchResults(int count) => switch (language) {
        AppLanguage.es => '$count resultados por letra',
        AppLanguage.en => '$count lyrics results',
        AppLanguage.ja => '歌詞検索 $count 件',
      };

  String get lyricsSearchError => switch (language) {
        AppLanguage.es => 'Error al buscar por letra. Revisa tu conexión.',
        AppLanguage.en => 'Lyrics search failed. Check your connection.',
        AppLanguage.ja => '歌詞検索に失敗しました。接続を確認してください。',
      };

  String get lyricsSearchNoResults => switch (language) {
        AppLanguage.es => 'No se encontraron canciones con esa letra',
        AppLanguage.en => 'No songs found with those lyrics',
        AppLanguage.ja => 'その歌詞に一致する曲が見つかりません',
      };

  String get a11yLyricsSearch => switch (language) {
        AppLanguage.es => 'Buscar por letra',
        AppLanguage.en => 'Search by lyrics',
        AppLanguage.ja => '歌詞で検索',
      };

  // --- Tsuki Wrapped ---
  String get wrappedTitle => switch (language) {
        AppLanguage.es => 'TSUKI WRAPPED',
        AppLanguage.en => 'TSUKI WRAPPED',
        AppLanguage.ja => 'TSUKI WRAPPED',
      };

  String wrappedYear(int year) => switch (language) {
        AppLanguage.es => 'TU AÑO $year EN MÚSICA',
        AppLanguage.en => 'YOUR $year IN MUSIC',
        AppLanguage.ja => '${year}年の音楽まとめ',
      };

  String get wrappedIntroSlide => switch (language) {
        AppLanguage.es => '¿Preparado para revivir tu año?',
        AppLanguage.en => 'Ready to relive your year?',
        AppLanguage.ja => '今年を振り返る準備はいい？',
      };

  String get wrappedTopTracks => switch (language) {
        AppLanguage.es => 'TUS CANCIONES FAVORITAS',
        AppLanguage.en => 'YOUR TOP TRACKS',
        AppLanguage.ja => 'あなたのトップ楽曲',
      };

  String get wrappedTopArtists => switch (language) {
        AppLanguage.es => 'TUS ARTISTAS FAVORITOS',
        AppLanguage.en => 'YOUR TOP ARTISTS',
        AppLanguage.ja => 'あなたのトップアーティスト',
      };

  String get wrappedListeningTime => switch (language) {
        AppLanguage.es => 'TIEMPO DE ESCUCHA',
        AppLanguage.en => 'LISTENING TIME',
        AppLanguage.ja => '再生時間',
      };

  String wrappedMinutes(int minutes) => switch (language) {
        AppLanguage.es => '$minutes minutos',
        AppLanguage.en => '$minutes minutes',
        AppLanguage.ja => '$minutes 分',
      };

  String wrappedHours(int hours) => switch (language) {
        AppLanguage.es => '$hours horas',
        AppLanguage.en => '$hours hours',
        AppLanguage.ja => '$hours 時間',
      };

  String wrappedTotalTracks(int count) => switch (language) {
        AppLanguage.es => '$count reproducciones',
        AppLanguage.en => '$count plays',
        AppLanguage.ja => '$count 回再生',
      };

  String wrappedUniqueCount(int tracks, int artists) => switch (language) {
        AppLanguage.es => '$tracks canciones únicas · $artists artistas',
        AppLanguage.en => '$tracks unique tracks · $artists artists',
        AppLanguage.ja => '$tracks 曲 · $artists アーティスト',
      };

  String get wrappedFavoriteHour => switch (language) {
        AppLanguage.es => 'TU HORA FAVORITA',
        AppLanguage.en => 'YOUR FAVORITE HOUR',
        AppLanguage.ja => 'お気に入りの時間帯',
      };

  String wrappedHourLabel(int hour) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return switch (language) {
      AppLanguage.es => '${h12}:00 $amPm',
      AppLanguage.en => '${h12}:00 $amPm',
      AppLanguage.ja => '$hour:00',
    };
  }

  String get wrappedFunFacts => switch (language) {
        AppLanguage.es => 'DATOS CURIOSOS',
        AppLanguage.en => 'FUN FACTS',
        AppLanguage.ja => 'おもしろデータ',
      };

  String wrappedFactLateNight(String title, String artist) => switch (language) {
        AppLanguage.es => 'Tu canción del 3 AM fue "$title" de $artist 🌙',
        AppLanguage.en => 'Your 3 AM song was "$title" by $artist 🌙',
        AppLanguage.ja => '深夜3時の曲は $artist の「$title」🌙',
      };

  String wrappedFactMarathon(String date, int count) => switch (language) {
        AppLanguage.es => 'Tu día maratón: $count canciones el $date 🔥',
        AppLanguage.en => 'Your marathon day: $count tracks on $date 🔥',
        AppLanguage.ja => 'マラソンデー: ${date}に$count曲再生 🔥',
      };

  String wrappedFactLoyal(String artist, int count) => switch (language) {
        AppLanguage.es => 'Fan incondicional de $artist con $count reproducciones 💎',
        AppLanguage.en => 'Devoted fan of $artist with $count plays 💎',
        AppLanguage.ja => '$artist の熱狂的ファン — $count回再生 💎',
      };

  String wrappedFactDawn(int count) => switch (language) {
        AppLanguage.es => 'Escuchaste $count canciones al amanecer (5-7 AM) 🌅',
        AppLanguage.en => 'You listened to $count tracks at dawn (5-7 AM) 🌅',
        AppLanguage.ja => '夜明け(5〜7時)に$count曲再生 🌅',
      };

  String wrappedFactOneHit(String title, String artist, int count) => switch (language) {
        AppLanguage.es => '"$title" de $artist en repeat: $count veces 🔄',
        AppLanguage.en => '"$title" by $artist on repeat: $count times 🔄',
        AppLanguage.ja => '$artist の「$title」を$count回リピート 🔄',
      };

  String wrappedFactNightOwl(int pct) => switch (language) {
        AppLanguage.es => 'El $pct% de tu música fue de noche. ¿Dormiste bien? 😴',
        AppLanguage.en => '$pct% of your music was at night. Did you sleep well? 😴',
        AppLanguage.ja => '音楽の$pct%が夜間再生。ちゃんと寝てる？ 😴',
      };

  String wrappedFactEarlyBird(int pct) => switch (language) {
        AppLanguage.es => 'El $pct% de tu música fue tempranito. ¡Madrugador! 🐦',
        AppLanguage.en => '$pct% of your music was early morning. Early bird! 🐦',
        AppLanguage.ja => '音楽の$pct%が早朝再生。早起きさん！ 🐦',
      };

  String wrappedFactWeekend(int weekendAvg, int weekdayAvg) => switch (language) {
        AppLanguage.es => 'Fin de semana pro: ~$weekendAvg canciones/día vs ~$weekdayAvg entre semana 🎉',
        AppLanguage.en => 'Weekend warrior: ~$weekendAvg tracks/day vs ~$weekdayAvg on weekdays 🎉',
        AppLanguage.ja => '週末の音楽好き: 1日平均$weekendAvg曲 vs 平日$weekdayAvg曲 🎉',
      };

  String wrappedPlays(int count) => switch (language) {
        AppLanguage.es => '$count reproducciones',
        AppLanguage.en => '$count plays',
        AppLanguage.ja => '$count 回再生',
      };

  String get wrappedOutro => switch (language) {
        AppLanguage.es => 'NOS VEMOS EL PRÓXIMO AÑO',
        AppLanguage.en => 'SEE YOU NEXT YEAR',
        AppLanguage.ja => 'また来年',
      };

  String get wrappedOutroSubtitle => switch (language) {
        AppLanguage.es => 'Sigue escuchando. El sistema recuerda todo.',
        AppLanguage.en => 'Keep listening. The system remembers everything.',
        AppLanguage.ja => '聴き続けよう。システムはすべて記録している。',
      };

  String get wrappedShare => switch (language) {
        AppLanguage.es => 'COMPARTIR',
        AppLanguage.en => 'SHARE',
        AppLanguage.ja => 'シェア',
      };

  String get wrappedNoData => switch (language) {
        AppLanguage.es => 'No hay datos suficientes para este año',
        AppLanguage.en => 'Not enough data for this year',
        AppLanguage.ja => 'この年のデータが不十分です',
      };

  String get wrappedNoDataSubtitle => switch (language) {
        AppLanguage.es => 'Escucha más canciones para desbloquear tu Wrapped',
        AppLanguage.en => 'Listen to more tracks to unlock your Wrapped',
        AppLanguage.ja => 'もっと曲を聴いて Wrapped をアンロックしよう',
      };

  String get wrappedViewYourWrapped => switch (language) {
        AppLanguage.es => 'VER TU WRAPPED',
        AppLanguage.en => 'VIEW YOUR WRAPPED',
        AppLanguage.ja => 'WRAPPED を見る',
      };

  String get a11yWrapped => switch (language) {
        AppLanguage.es => 'Tsuki Wrapped resumen anual',
        AppLanguage.en => 'Tsuki Wrapped annual summary',
        AppLanguage.ja => 'Tsuki Wrapped 年間まとめ',
      };

  String get a11yShareSlide => switch (language) {
        AppLanguage.es => 'Compartir esta diapositiva',
        AppLanguage.en => 'Share this slide',
        AppLanguage.ja => 'このスライドをシェア',
      };

  String get a11yNextSlide => switch (language) {
        AppLanguage.es => 'Siguiente diapositiva',
        AppLanguage.en => 'Next slide',
        AppLanguage.ja => '次のスライド',
      };

  String get a11yPreviousSlide => switch (language) {
        AppLanguage.es => 'Diapositiva anterior',
        AppLanguage.en => 'Previous slide',
        AppLanguage.ja => '前のスライド',
      };

  // --- Listening Clock ---
  String get clockTitle => switch (language) {
        AppLanguage.es => 'RELOJ DE ESCUCHA',
        AppLanguage.en => 'LISTENING CLOCK',
        AppLanguage.ja => 'リスニングクロック',
      };

  String get clockRadar => switch (language) {
        AppLanguage.es => 'RADAR DE ACTIVIDAD',
        AppLanguage.en => 'ACTIVITY RADAR',
        AppLanguage.ja => 'アクティビティレーダー',
      };

  String get clockDailyActivity => switch (language) {
        AppLanguage.es => 'ACTIVIDAD DIARIA',
        AppLanguage.en => 'DAILY ACTIVITY',
        AppLanguage.ja => 'デイリーアクティビティ',
      };

  String clockPeakHour(String hour, int count) => switch (language) {
        AppLanguage.es => 'Hora pico: $hour — $count reproducciones',
        AppLanguage.en => 'Peak hour: $hour — $count plays',
        AppLanguage.ja => 'ピークアワー: $hour — $count回再生',
      };

  String clockTotalYear(int count) => switch (language) {
        AppLanguage.es => '◈ $count REPRODUCCIONES ESTE AÑO // CLOCK.SYS',
        AppLanguage.en => '◈ $count PLAYS THIS YEAR // CLOCK.SYS',
        AppLanguage.ja => '◈ 今年$count回再生 // CLOCK.SYS',
      };

  String get clockNoData => switch (language) {
        AppLanguage.es => 'Sin datos de escucha',
        AppLanguage.en => 'No listening data',
        AppLanguage.ja => 'リスニングデータなし',
      };

  String get clockNoDataSubtitle => switch (language) {
        AppLanguage.es => 'Escucha música para activar el radar',
        AppLanguage.en => 'Listen to music to activate the radar',
        AppLanguage.ja => '音楽を聴いてレーダーを起動しよう',
      };

  String get clockViewClock => switch (language) {
        AppLanguage.es => 'VER RADAR',
        AppLanguage.en => 'VIEW RADAR',
        AppLanguage.ja => 'レーダーを見る',
      };

  String get a11yClock => switch (language) {
        AppLanguage.es => 'Reloj de escucha y radar de actividad',
        AppLanguage.en => 'Listening clock and activity radar',
        AppLanguage.ja => 'リスニングクロックとアクティビティレーダー',
      };

  // --- Rabbit Hole (Artist Graph) ---
  String get rabbitHoleTitle => switch (language) {
        AppLanguage.es => 'MADRIGUERA',
        AppLanguage.en => 'RABBIT HOLE',
        AppLanguage.ja => 'ラビットホール',
      };

  String get rabbitHoleSubtitle => switch (language) {
        AppLanguage.es => 'Explora artistas relacionados',
        AppLanguage.en => 'Explore related artists',
        AppLanguage.ja => '関連アーティストを探索',
      };

  String get rabbitHoleLoading => switch (language) {
        AppLanguage.es => 'TEJIENDO LA RED...',
        AppLanguage.en => 'WEAVING THE WEB...',
        AppLanguage.ja => 'ウェブを構築中...',
      };

  String get rabbitHoleTapToExpand => switch (language) {
        AppLanguage.es => 'TOCA PARA EXPANDIR',
        AppLanguage.en => 'TAP TO EXPAND',
        AppLanguage.ja => 'タップして展開',
      };

  String rabbitHoleConnections(int count) => switch (language) {
        AppLanguage.es => '$count CONEXIONES',
        AppLanguage.en => '$count CONNECTIONS',
        AppLanguage.ja => '$count 件の接続',
      };

  String get rabbitHoleDeadEnd => switch (language) {
        AppLanguage.es => 'CALLEJÓN SIN SALIDA · TOCA PARA REINTENTAR',
        AppLanguage.en => 'DEAD END · TAP TO RETRY',
        AppLanguage.ja => '行き止まり · タップで再試行',
      };

  String get rabbitHoleMaxReached => switch (language) {
        AppLanguage.es =>
          'La red llegó a su límite. Reinicia desde este artista para seguir bajando.',
        AppLanguage.en =>
          'The web is full. Restart from this artist to keep digging.',
        AppLanguage.ja => 'ネットワークが上限に達しました。このアーティストから再開して探索を続けましょう。',
      };

  String get rabbitHoleRestartHere => switch (language) {
        AppLanguage.es => 'REINICIAR AQUÍ',
        AppLanguage.en => 'RESTART HERE',
        AppLanguage.ja => 'ここから再開',
      };

  String get rabbitHoleOpenArtist => switch (language) {
        AppLanguage.es => 'VER ARTISTA',
        AppLanguage.en => 'VIEW ARTIST',
        AppLanguage.ja => 'アーティスト',
      };

  String get rabbitHoleFitAll => switch (language) {
        AppLanguage.es => 'Ver toda la red',
        AppLanguage.en => 'Fit whole web',
        AppLanguage.ja => '全体を表示',
      };

  String get rabbitHoleHint => switch (language) {
        AppLanguage.es =>
          'Toca un nodo para expandir · Mantén y arrastra para moverlo · Pellizca para hacer zoom',
        AppLanguage.en =>
          'Tap a node to expand · Hold and drag to move it · Pinch to zoom',
        AppLanguage.ja => 'ノードをタップで展開 · 長押しでドラッグ · ピンチでズーム',
      };

  String get rabbitHoleEmpty => switch (language) {
        AppLanguage.es => 'SIN CONEXIONES',
        AppLanguage.en => 'NO CONNECTIONS',
        AppLanguage.ja => '接続なし',
      };

  String get rabbitHoleEmptySubtitle => switch (language) {
        AppLanguage.es =>
          'No encontramos artistas relacionados. Revisa tu conexión e inténtalo de nuevo.',
        AppLanguage.en =>
          "We couldn't find related artists. Check your connection and try again.",
        AppLanguage.ja => '関連アーティストが見つかりませんでした。接続を確認して再試行してください。',
      };

  String get rabbitHoleRecenter => switch (language) {
        AppLanguage.es => 'Recentrar',
        AppLanguage.en => 'Recenter',
        AppLanguage.ja => '中心に戻す',
      };

  String rabbitHoleNodes(int count) => switch (language) {
        AppLanguage.es => '$count NODOS',
        AppLanguage.en => '$count NODES',
        AppLanguage.ja => '$count ノード',
      };

  String rabbitHoleDepth(int count) => switch (language) {
        AppLanguage.es => 'PROFUNDIDAD $count',
        AppLanguage.en => 'DEPTH $count',
        AppLanguage.ja => '深さ $count',
      };

  String get rabbitHoleViewGraph => switch (language) {
        AppLanguage.es => 'EXPLORAR',
        AppLanguage.en => 'EXPLORE',
        AppLanguage.ja => '探索する',
      };

  String get a11yRabbitHole => switch (language) {
        AppLanguage.es =>
          'Madriguera de conejo: grafo interactivo de artistas relacionados',
        AppLanguage.en =>
          'Rabbit hole: interactive graph of related artists',
        AppLanguage.ja => 'ラビットホール：関連アーティストのインタラクティブグラフ',
      };

  // --- Release Radar ---
  String get radarTitle => switch (language) {
        AppLanguage.es => 'RADAR DE LANZAMIENTOS',
        AppLanguage.en => 'RELEASE RADAR',
        AppLanguage.ja => 'リリースレーダー',
      };

  String radarWatching(int count) => switch (language) {
        AppLanguage.es => count == 1 ? '1 artista vigilado' : '$count artistas vigilados',
        AppLanguage.en => count == 1 ? '1 artist watched' : '$count artists watched',
        AppLanguage.ja => '$count 組のアーティストを監視中',
      };

  String radarNewCount(int count) => switch (language) {
        AppLanguage.es => count == 1 ? '1 LANZAMIENTO NUEVO' : '$count LANZAMIENTOS NUEVOS',
        AppLanguage.en => count == 1 ? '1 NEW RELEASE' : '$count NEW RELEASES',
        AppLanguage.ja => '新着 $count 件',
      };

  String get radarSectionNew => switch (language) {
        AppLanguage.es => 'NUEVO PARA TI',
        AppLanguage.en => 'NEW FOR YOU',
        AppLanguage.ja => 'あなたへの新着',
      };

  String get radarSectionRecent => switch (language) {
        AppLanguage.es => 'ÚLTIMOS 60 DÍAS',
        AppLanguage.en => 'LAST 60 DAYS',
        AppLanguage.ja => '過去60日間',
      };

  String get radarNotifyToggle => switch (language) {
        AppLanguage.es => 'Avisarme de lanzamientos',
        AppLanguage.en => 'Notify me about releases',
        AppLanguage.ja => 'リリースを通知する',
      };

  String get radarNotifyToggleSubtitle => switch (language) {
        AppLanguage.es => 'Una revisión al día en segundo plano',
        AppLanguage.en => 'One background check per day',
        AppLanguage.ja => '1日1回バックグラウンドで確認',
      };

  String get radarPermissionDenied => switch (language) {
        AppLanguage.es => 'Las notificaciones están desactivadas para Tsuki Tunes.',
        AppLanguage.en => 'Notifications are turned off for Tsuki Tunes.',
        AppLanguage.ja => 'Tsuki Tunesの通知がオフになっています。',
      };

  String get radarPermissionAction => switch (language) {
        AppLanguage.es => 'ACTIVAR',
        AppLanguage.en => 'TURN ON',
        AppLanguage.ja => 'オンにする',
      };

  String get radarPermissionSettingsHint => switch (language) {
        AppLanguage.es =>
          'Actívalas en Ajustes › Aplicaciones › Tsuki Tunes › Notificaciones.',
        AppLanguage.en =>
          'Turn them on in Settings › Apps › Tsuki Tunes › Notifications.',
        AppLanguage.ja => '設定 › アプリ › Tsuki Tunes › 通知 でオンにしてください。',
      };

  String get radarCheckNow => switch (language) {
        AppLanguage.es => 'Revisar ahora',
        AppLanguage.en => 'Check now',
        AppLanguage.ja => '今すぐ確認',
      };

  String get radarChecking => switch (language) {
        AppLanguage.es => 'ESCANEANDO...',
        AppLanguage.en => 'SCANNING...',
        AppLanguage.ja => 'スキャン中...',
      };

  String radarLastCheck(Duration? ago) {
    if (ago == null) {
      return switch (language) {
        AppLanguage.es => 'Aún sin revisar',
        AppLanguage.en => 'Not checked yet',
        AppLanguage.ja => '未確認',
      };
    }
    final String span;
    if (ago.inMinutes < 1) {
      span = switch (language) {
        AppLanguage.es => 'justo ahora',
        AppLanguage.en => 'just now',
        AppLanguage.ja => 'たった今',
      };
      return switch (language) {
        AppLanguage.es => 'Última revisión: $span',
        AppLanguage.en => 'Last checked $span',
        AppLanguage.ja => '最終確認：$span',
      };
    } else if (ago.inHours < 1) {
      span = switch (language) {
        AppLanguage.es => 'hace ${ago.inMinutes} min',
        AppLanguage.en => '${ago.inMinutes} min ago',
        AppLanguage.ja => '${ago.inMinutes}分前',
      };
    } else if (ago.inDays < 1) {
      span = switch (language) {
        AppLanguage.es => 'hace ${ago.inHours} h',
        AppLanguage.en => '${ago.inHours} h ago',
        AppLanguage.ja => '${ago.inHours}時間前',
      };
    } else {
      span = switch (language) {
        AppLanguage.es => ago.inDays == 1 ? 'hace 1 día' : 'hace ${ago.inDays} días',
        AppLanguage.en => ago.inDays == 1 ? '1 day ago' : '${ago.inDays} days ago',
        AppLanguage.ja => '${ago.inDays}日前',
      };
    }
    return switch (language) {
      AppLanguage.es => 'Última revisión: $span',
      AppLanguage.en => 'Last checked $span',
      AppLanguage.ja => '最終確認：$span',
    };
  }

  String get radarEmptyNoArtistsTitle => switch (language) {
        AppLanguage.es => 'SIGUE ARTISTAS',
        AppLanguage.en => 'FOLLOW SOME ARTISTS',
        AppLanguage.ja => 'アーティストをフォロー',
      };

  String get radarEmptyNoArtists => switch (language) {
        AppLanguage.es =>
          'El radar vigila a los artistas que sigues y te avisa cuando sacan algo nuevo. Toca SEGUIR en el perfil de un artista.',
        AppLanguage.en =>
          'The radar watches the artists you follow and tells you when they drop something new. Tap FOLLOW on an artist page.',
        AppLanguage.ja => 'レーダーはフォロー中のアーティストを監視し、新作が出たらお知らせします。アーティストページで「フォロー」をタップしてください。',
      };

  String get radarEmptyNoReleasesTitle => switch (language) {
        AppLanguage.es => 'SIN LANZAMIENTOS RECIENTES',
        AppLanguage.en => 'NO RECENT RELEASES',
        AppLanguage.ja => '最近のリリースなし',
      };

  String get radarEmptyNoReleases => switch (language) {
        AppLanguage.es =>
          'Tus artistas no sacaron nada en los últimos 60 días. Te avisaremos en cuanto lo hagan.',
        AppLanguage.en =>
          "Your artists haven't released anything in the last 60 days. We'll let you know as soon as they do.",
        AppLanguage.ja => '過去60日間に新しいリリースはありません。リリースされたらすぐにお知らせします。',
      };

  String get radarIosNote => switch (language) {
        AppLanguage.es =>
          'En iPhone, iOS decide cuándo ejecutar la revisión en segundo plano. Abrir la app también busca lanzamientos.',
        AppLanguage.en =>
          'On iPhone, iOS decides when the background check runs. Opening the app also looks for releases.',
        AppLanguage.ja => 'iPhoneでは、バックグラウンド確認のタイミングはiOSが決定します。アプリを開いたときにも確認します。',
      };

  String radarType(String recordType) => switch (recordType) {
        'single' => 'SINGLE',
        'ep' => 'EP',
        _ => switch (language) {
            AppLanguage.es => 'ÁLBUM',
            AppLanguage.en => 'ALBUM',
            AppLanguage.ja => 'アルバム',
          },
      };

  String radarReleasedAgo(int days) {
    if (days < 0) {
      return switch (language) {
        AppLanguage.es => 'PRÓXIMAMENTE',
        AppLanguage.en => 'UPCOMING',
        AppLanguage.ja => '近日公開',
      };
    }
    return switch (language) {
      AppLanguage.es => days == 0 ? 'HOY' : days == 1 ? 'AYER' : 'HACE $days DÍAS',
      AppLanguage.en => days == 0 ? 'TODAY' : days == 1 ? 'YESTERDAY' : '$days DAYS AGO',
      AppLanguage.ja => days == 0 ? '今日' : days == 1 ? '昨日' : '$days日前',
    };
  }

  String radarNotifSingle(String artist, String recordType) => switch (language) {
        AppLanguage.es => switch (recordType) {
            'single' => '🔥 $artist sacó un single nuevo',
            'ep' => '🔥 $artist sacó un EP nuevo',
            _ => '🔥 $artist sacó un álbum nuevo',
          },
        AppLanguage.en => switch (recordType) {
            'single' => '🔥 $artist dropped a new single',
            'ep' => '🔥 $artist dropped a new EP',
            _ => '🔥 $artist dropped a new album',
          },
        AppLanguage.ja => switch (recordType) {
            'single' => '🔥 $artistが新しいシングルをリリース',
            'ep' => '🔥 $artistが新しいEPをリリース',
            _ => '🔥 $artistが新しいアルバムをリリース',
          },
      };

  String radarNotifMany(int count) => switch (language) {
        AppLanguage.es => '🔥 $count lanzamientos nuevos',
        AppLanguage.en => '🔥 $count new releases',
        AppLanguage.ja => '🔥 新着リリース $count 件',
      };

  String radarNotifManyBody(List<String> artists) {
    final shown = artists.take(2).toList();
    final rest = artists.length - shown.length;
    final names = shown.join(', ');
    if (rest <= 0) {
      if (shown.length < 2) return names;
      return switch (language) {
        AppLanguage.es => '${shown[0]} y ${shown[1]}',
        AppLanguage.en => '${shown[0]} and ${shown[1]}',
        AppLanguage.ja => '${shown[0]}、${shown[1]}',
      };
    }
    return switch (language) {
      AppLanguage.es => '$names y $rest más',
      AppLanguage.en => '$names and $rest more',
      AppLanguage.ja => '$names 他$rest組',
    };
  }

  String get radarChannelName => switch (language) {
        AppLanguage.es => 'Radar de lanzamientos',
        AppLanguage.en => 'Release radar',
        AppLanguage.ja => 'リリースレーダー',
      };

  String get radarChannelDescription => switch (language) {
        AppLanguage.es => 'Avisos cuando los artistas que sigues sacan música nueva',
        AppLanguage.en => 'Alerts when artists you follow release new music',
        AppLanguage.ja => 'フォロー中のアーティストの新曲をお知らせ',
      };

  String radarFollowSnack(String artist) => switch (language) {
        AppLanguage.es => 'Te avisaremos cuando $artist saque algo nuevo',
        AppLanguage.en => "We'll let you know when $artist releases something new",
        AppLanguage.ja => '$artistの新作が出たらお知らせします',
      };

  String get a11yRadar => switch (language) {
        AppLanguage.es => 'Radar de lanzamientos de los artistas que sigues',
        AppLanguage.en => 'Release radar for the artists you follow',
        AppLanguage.ja => 'フォロー中のアーティストのリリースレーダー',
      };

  // --- Song Radio ---
  String get radioStart => switch (language) {
        AppLanguage.es => 'Iniciar radio',
        AppLanguage.en => 'Start radio',
        AppLanguage.ja => 'ラジオを開始',
      };

  String radioStarted(String title) => switch (language) {
        AppLanguage.es => 'Radio de «$title» en marcha',
        AppLanguage.en => '“$title” radio is on',
        AppLanguage.ja => '「$title」のラジオを開始しました',
      };

  String get radioNoResults => switch (language) {
        AppLanguage.es => 'No encontramos canciones parecidas. Prueba con otra.',
        AppLanguage.en => "Couldn't find similar songs. Try another one.",
        AppLanguage.ja => '似た曲が見つかりませんでした。別の曲でお試しください。',
      };

  String get radioLabel => switch (language) {
        AppLanguage.es => 'RADIO',
        AppLanguage.en => 'RADIO',
        AppLanguage.ja => 'ラジオ',
      };

  String radioBasedOn(String title) => switch (language) {
        AppLanguage.es => 'Basada en «$title»',
        AppLanguage.en => 'Based on “$title”',
        AppLanguage.ja => '「$title」から',
      };

  String radioReasonLastFm(String title) => switch (language) {
        AppLanguage.es => 'Parecida a «$title»',
        AppLanguage.en => 'Similar to “$title”',
        AppLanguage.ja => '「$title」に似た曲',
      };

  String radioReasonDeezer(String artist) => switch (language) {
        AppLanguage.es => 'Radio de $artist',
        AppLanguage.en => '$artist radio',
        AppLanguage.ja => '$artistのラジオ',
      };

  String get radioLoadingMore => switch (language) {
        AppLanguage.es => 'Buscando más canciones...',
        AppLanguage.en => 'Finding more songs...',
        AppLanguage.ja => '曲を探しています...',
      };

  String get radioInfinite => switch (language) {
        AppLanguage.es => 'La radio sigue: siempre habrá otra canción',
        AppLanguage.en => 'The radio keeps going: there’s always another song',
        AppLanguage.ja => 'ラジオは続きます。次の曲が必ずあります',
      };

  String get radioOffline => switch (language) {
        AppLanguage.es => 'Sin conexión: la radio seguirá cuando vuelva la red',
        AppLanguage.en => 'Offline: the radio resumes when you reconnect',
        AppLanguage.ja => 'オフライン：接続が戻るとラジオが再開します',
      };

  String get radioExhausted => switch (language) {
        AppLanguage.es => 'Se acabaron las ideas por aquí. Prueba «Más como esta» o cambia el estilo.',
        AppLanguage.en => 'Ran out of ideas here. Try “More like this” or change the style.',
        AppLanguage.ja => 'ここで候補が尽きました。「似た曲をもっと」かスタイル変更をお試しください。',
      };

  String get radioModeTitle => switch (language) {
        AppLanguage.es => 'ESTILO DE RADIO',
        AppLanguage.en => 'RADIO STYLE',
        AppLanguage.ja => 'ラジオのスタイル',
      };

  String get radioModeFamiliar => switch (language) {
        AppLanguage.es => 'Fiel',
        AppLanguage.en => 'Familiar',
        AppLanguage.ja => '定番',
      };

  String get radioModeFamiliarDesc => switch (language) {
        AppLanguage.es => 'Se queda cerca de la canción original.',
        AppLanguage.en => 'Stays close to the original song.',
        AppLanguage.ja => '元の曲の近くにとどまります。',
      };

  String get radioModeBalanced => switch (language) {
        AppLanguage.es => 'Equilibrada',
        AppLanguage.en => 'Balanced',
        AppLanguage.ja => 'バランス',
      };

  String get radioModeBalancedDesc => switch (language) {
        AppLanguage.es => 'Mezcla canciones parecidas con descubrimientos.',
        AppLanguage.en => 'Mixes close matches with discoveries.',
        AppLanguage.ja => '似た曲と新しい発見をミックスします。',
      };

  String get radioModeAdventurous => switch (language) {
        AppLanguage.es => 'Aventurera',
        AppLanguage.en => 'Adventurous',
        AppLanguage.ja => '冒険',
      };

  String get radioModeAdventurousDesc => switch (language) {
        AppLanguage.es => 'Se aleja canción a canción y descubre artistas nuevos.',
        AppLanguage.en => 'Drifts song by song toward new artists.',
        AppLanguage.ja => '曲ごとに離れていき、新しいアーティストを発見します。',
      };

  String get radioMoreLikeThis => switch (language) {
        AppLanguage.es => 'Más como esta',
        AppLanguage.en => 'More like this',
        AppLanguage.ja => '似た曲をもっと',
      };

  String get radioLessLikeThis => switch (language) {
        AppLanguage.es => 'Menos de esto',
        AppLanguage.en => 'Less like this',
        AppLanguage.ja => 'これは控えめに',
      };

  String get radioMoreSnack => switch (language) {
        AppLanguage.es => 'La radio irá más por este lado',
        AppLanguage.en => 'The radio will lean this way',
        AppLanguage.ja => 'この方向の曲を増やします',
      };

  String radioLessSnack(String artist) => switch (language) {
        AppLanguage.es => 'No pondremos más $artist en esta radio',
        AppLanguage.en => "We won't play $artist on this radio again",
        AppLanguage.ja => 'このラジオでは$artistを再生しません',
      };

  String get radioStop => switch (language) {
        AppLanguage.es => 'Detener radio',
        AppLanguage.en => 'Stop radio',
        AppLanguage.ja => 'ラジオを停止',
      };

  String get radioStopped => switch (language) {
        AppLanguage.es => 'Radio detenida. La cola se queda como está.',
        AppLanguage.en => 'Radio stopped. Your queue stays as it is.',
        AppLanguage.ja => 'ラジオを停止しました。キューはそのままです。',
      };

  String get radioSourcesBoth => switch (language) {
        AppLanguage.es => 'Fuentes: Last.fm + Deezer',
        AppLanguage.en => 'Sources: Last.fm + Deezer',
        AppLanguage.ja => 'ソース：Last.fm + Deezer',
      };

  String get radioSourcesDeezerOnly => switch (language) {
        AppLanguage.es => 'Fuente: Deezer (Last.fm no está configurado)',
        AppLanguage.en => 'Source: Deezer (Last.fm is not configured)',
        AppLanguage.ja => 'ソース：Deezer（Last.fm未設定）',
      };

  String get radioLearnHint => switch (language) {
        AppLanguage.es =>
          'Aprende de ti: si saltas un artista dos veces deja de ponerlo, y lo que escuchas entero guía lo que viene.',
        AppLanguage.en =>
          'It learns from you: skip an artist twice and it stops playing them; songs you finish steer what comes next.',
        AppLanguage.ja => 'あなたから学習します。同じアーティストを2回スキップすると再生しなくなり、最後まで聴いた曲が次の選曲を導きます。',
      };

  String get radioTune => switch (language) {
        AppLanguage.es => 'AJUSTAR',
        AppLanguage.en => 'TUNE',
        AppLanguage.ja => '調整',
      };

  String get a11yRadio => switch (language) {
        AppLanguage.es => 'Radio de la canción',
        AppLanguage.en => 'Song radio',
        AppLanguage.ja => '曲のラジオ',
      };

  // --- Dates ---
  static const List<String> _monthsEs = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  static const List<String> _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "26 oct 2025" / "Oct 26, 2025" / "2025年10月26日".
  String shortDate(DateTime d) => switch (language) {
        AppLanguage.es => '${d.day} ${_monthsEs[d.month - 1]} ${d.year}',
        AppLanguage.en => '${_monthsEn[d.month - 1]} ${d.day}, ${d.year}',
        AppLanguage.ja => '${d.year}年${d.month}月${d.day}日',
      };

  /// [weekday] uses DateTime's 1 (Monday) .. 7 (Sunday).
  String weekdayName(int weekday) {
    const es = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const en = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const ja = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
    final i = weekday < 1 ? 0 : (weekday > 7 ? 6 : weekday - 1);
    return switch (language) {
      AppLanguage.es => es[i],
      AppLanguage.en => en[i],
      AppLanguage.ja => ja[i],
    };
  }

  // --- Wrapped: play log vs discoveries ---
  String get wrappedTopDiscoveries => switch (language) {
        AppLanguage.es => 'DESCUBRIMIENTOS DEL AÑO',
        AppLanguage.en => 'DISCOVERIES OF THE YEAR',
        AppLanguage.ja => '今年の発見',
      };

  String wrappedDiscoveredSongs(int count) => switch (language) {
        AppLanguage.es => count == 1 ? '1 canción descubierta' : '$count canciones descubiertas',
        AppLanguage.en => count == 1 ? '1 song discovered' : '$count songs discovered',
        AppLanguage.ja => '$count 曲を発見',
      };

  String get wrappedNewMusicTime => switch (language) {
        AppLanguage.es => 'MÚSICA NUEVA',
        AppLanguage.en => 'NEW MUSIC',
        AppLanguage.ja => '新しい音楽',
      };

  String wrappedFactMarathonDiscovery(String date, int count) => switch (language) {
        AppLanguage.es => 'Tu día de descubrimientos: $count canciones nuevas el $date 🔥',
        AppLanguage.en => 'Your discovery day: $count new songs on $date 🔥',
        AppLanguage.ja => '発見の日: ${date}に$count曲の新曲 🔥',
      };

  String wrappedFactLoyalDiscovery(String artist, int count) => switch (language) {
        AppLanguage.es => 'Fan incondicional de $artist: descubriste $count de sus canciones 💎',
        AppLanguage.en => 'Devoted fan of $artist: you discovered $count of their songs 💎',
        AppLanguage.ja => '$artist の熱狂的ファン — $count曲を発見 💎',
      };

  String get wrappedBasedOnDiscoveries => switch (language) {
        AppLanguage.es =>
          'Basado en las canciones que marcaste como escuchadas. Desde ahora Tsuki cuenta cada reproducción para tu próximo Wrapped.',
        AppLanguage.en =>
          'Based on the songs you marked as listened. From now on Tsuki counts every play for your next Wrapped.',
        AppLanguage.ja => '「聴いた」とマークした曲に基づいています。これからは次のWrappedのために毎回の再生を記録します。',
      };

  String wrappedPlaysSince(String date) => switch (language) {
        AppLanguage.es => 'Basado en tus reproducciones desde el $date',
        AppLanguage.en => 'Based on your plays since $date',
        AppLanguage.ja => '$date以降の再生に基づいています',
      };

  // --- Time Machine ---
  String get timeMachineTitle => switch (language) {
        AppLanguage.es => 'MÁQUINA DEL TIEMPO',
        AppLanguage.en => 'TIME MACHINE',
        AppLanguage.ja => 'タイムマシン',
      };

  String get timeMachineYearAgo => switch (language) {
        AppLanguage.es => 'Hace 1 año',
        AppLanguage.en => '1 year ago',
        AppLanguage.ja => '1年前',
      };

  String get timeMachineSixMonthsAgo => switch (language) {
        AppLanguage.es => 'Hace 6 meses',
        AppLanguage.en => '6 months ago',
        AppLanguage.ja => '6か月前',
      };

  String get timeMachineMonthAgo => switch (language) {
        AppLanguage.es => 'Hace 1 mes',
        AppLanguage.en => '1 month ago',
        AppLanguage.ja => '1か月前',
      };

  String get timeMachineWeekAgo => switch (language) {
        AppLanguage.es => 'Hace 1 semana',
        AppLanguage.en => '1 week ago',
        AppLanguage.ja => '1週間前',
      };

  String get timeMachineRandom => switch (language) {
        AppLanguage.es => 'Día al azar',
        AppLanguage.en => 'Random day',
        AppLanguage.ja => 'ランダムな日',
      };

  String get timeMachineRewinding => switch (language) {
        AppLanguage.es => 'REBOBINANDO...',
        AppLanguage.en => 'REWINDING...',
        AppLanguage.ja => '巻き戻し中...',
      };

  String get timeMachineKindPlays => switch (language) {
        AppLanguage.es => 'REPRODUCCIONES',
        AppLanguage.en => 'PLAYS',
        AppLanguage.ja => '再生',
      };

  String get timeMachineKindDiscoveries => switch (language) {
        AppLanguage.es => 'DESCUBRIMIENTOS',
        AppLanguage.en => 'DISCOVERIES',
        AppLanguage.ja => '発見',
      };

  String get timeMachineExactDay => switch (language) {
        AppLanguage.es => 'ESE DÍA',
        AppLanguage.en => 'THAT DAY',
        AppLanguage.ja => 'その日',
      };

  String get timeMachineThatWeek => switch (language) {
        AppLanguage.es => 'ESA SEMANA',
        AppLanguage.en => 'THAT WEEK',
        AppLanguage.ja => 'その週',
      };

  String get timeMachineHeadlineRepeat => switch (language) {
        AppLanguage.es => 'No parabas de escuchar esto 👀',
        AppLanguage.en => "You couldn't stop playing this 👀",
        AppLanguage.ja => 'これをずっと聴いていました 👀',
      };

  String get timeMachineHeadlinePlayed => switch (language) {
        AppLanguage.es => 'Esto estabas escuchando',
        AppLanguage.en => 'This is what you were playing',
        AppLanguage.ja => 'この曲を聴いていました',
      };

  String get timeMachineHeadlineDiscovered => switch (language) {
        AppLanguage.es => 'Esto descubriste',
        AppLanguage.en => 'This is what you discovered',
        AppLanguage.ja => 'この曲を発見しました',
      };

  String timeMachineTimes(int count, bool exactDay) => switch (language) {
        AppLanguage.es => count == 1
            ? (exactDay ? 'Una vez ese día' : 'Una vez esa semana')
            : (exactDay ? '$count veces ese día' : '$count veces esa semana'),
        AppLanguage.en => count == 1
            ? (exactDay ? 'Once that day' : 'Once that week')
            : (exactDay ? '$count times that day' : '$count times that week'),
        AppLanguage.ja => exactDay ? 'その日に$count回' : 'その週に$count回',
      };

  String timeMachineDiscoveredAt(String time) => switch (language) {
        AppLanguage.es => 'Descubierta a las $time',
        AppLanguage.en => 'Discovered at $time',
        AppLanguage.ja => '$timeに発見',
      };

  String timeMachineDiscoveredOn(String weekday) => switch (language) {
        AppLanguage.es => 'Descubierta el $weekday',
        AppLanguage.en => 'Discovered on $weekday',
        AppLanguage.ja => '$weekdayに発見',
      };

  String get timeMachinePlay => switch (language) {
        AppLanguage.es => 'REPRODUCIR ESTE RECUERDO',
        AppLanguage.en => 'PLAY THIS MEMORY',
        AppLanguage.ja => 'この思い出を再生',
      };

  String get timeMachinePlaying => switch (language) {
        AppLanguage.es => 'Reproduciendo tu recuerdo',
        AppLanguage.en => 'Playing your memory',
        AppLanguage.ja => '思い出を再生中',
      };

  String get timeMachinePlayFailed => switch (language) {
        AppLanguage.es => 'No pudimos cargar estas canciones. Revisa tu conexión.',
        AppLanguage.en => "Couldn't load these songs. Check your connection.",
        AppLanguage.ja => '曲を読み込めませんでした。接続を確認してください。',
      };

  String get timeMachineNothingTitle => switch (language) {
        AppLanguage.es => 'NADA POR AQUÍ',
        AppLanguage.en => 'NOTHING HERE',
        AppLanguage.ja => '何もありません',
      };

  String get timeMachineNothing => switch (language) {
        AppLanguage.es => 'No hay historial de esos días. Prueba otra fecha o viaja a un día al azar.',
        AppLanguage.en => 'No history for those days. Try another date or travel to a random day.',
        AppLanguage.ja => 'その頃の履歴はありません。別の日付かランダムな日をお試しください。',
      };

  String get timeMachineNoHistory => switch (language) {
        AppLanguage.es => 'Aún no hay días con historial para viajar.',
        AppLanguage.en => 'There are no days with history to travel to yet.',
        AppLanguage.ja => '移動できる履歴の日がまだありません。',
      };

  String timeMachineCountingSince(String date) => switch (language) {
        AppLanguage.es =>
          'Tsuki cuenta cada reproducción desde el $date. A partir de ahí, los recuerdos muestran lo que tenías en repeat.',
        AppLanguage.en =>
          'Tsuki has counted every play since $date. From then on, memories show what you had on repeat.',
        AppLanguage.ja => 'Tsukiは$dateから毎回の再生を記録しています。それ以降の思い出ではリピートしていた曲が表示されます。',
      };

  String get timeMachineCountingStarts => switch (language) {
        AppLanguage.es =>
          'Desde hoy Tsuki cuenta cada reproducción: con el tiempo verás lo que tenías en repeat, no solo lo que descubriste.',
        AppLanguage.en =>
          'From today Tsuki counts every play: over time you’ll see what you had on repeat, not just what you discovered.',
        AppLanguage.ja => '今日から毎回の再生を記録します。いずれ発見した曲だけでなく、リピートしていた曲も表示されます。',
      };

  String get timeMachineNotifyToggle => switch (language) {
        AppLanguage.es => 'Recuerdos ocasionales',
        AppLanguage.en => 'Occasional memories',
        AppLanguage.ja => 'ときどき思い出を通知',
      };

  String get timeMachineNotifyToggleSubtitle => switch (language) {
        AppLanguage.es => 'Como mucho uno por semana, solo de días memorables',
        AppLanguage.en => 'At most one a week, only from memorable days',
        AppLanguage.ja => '最大週1回、印象的な日だけ',
      };

  String timeMachineNotifRepeat(String title) => switch (language) {
        AppLanguage.es => 'Hace 1 año no parabas de escuchar «$title» 👀',
        AppLanguage.en => 'A year ago you couldn’t stop playing “$title” 👀',
        AppLanguage.ja => '1年前、「$title」をずっと聴いていました 👀',
      };

  String timeMachineNotifRepeatBody(String artist, int count) => switch (language) {
        AppLanguage.es => '$artist · $count reproducciones',
        AppLanguage.en => '$artist · $count plays',
        AppLanguage.ja => '$artist · $count回再生',
      };

  String timeMachineNotifPlayed(String title) => switch (language) {
        AppLanguage.es => 'Hace 1 año sonaba «$title» 👀',
        AppLanguage.en => 'A year ago “$title” was playing 👀',
        AppLanguage.ja => '1年前は「$title」を聴いていました 👀',
      };

  String timeMachineNotifDiscovered(String title) => switch (language) {
        AppLanguage.es => 'Hace 1 año descubriste «$title» 👀',
        AppLanguage.en => 'A year ago you discovered “$title” 👀',
        AppLanguage.ja => '1年前、「$title」を発見しました 👀',
      };

  String get timeMachineChannelName => switch (language) {
        AppLanguage.es => 'Máquina del tiempo',
        AppLanguage.en => 'Time Machine',
        AppLanguage.ja => 'タイムマシン',
      };

  String get timeMachineChannelDescription => switch (language) {
        AppLanguage.es => 'Recuerdos de lo que escuchabas hace un año',
        AppLanguage.en => 'Memories of what you were listening to a year ago',
        AppLanguage.ja => '1年前に聴いていた曲の思い出',
      };

  String get timeMachineCardEmpty => switch (language) {
        AppLanguage.es => '¿Qué escuchabas hace un año?',
        AppLanguage.en => 'What were you listening to a year ago?',
        AppLanguage.ja => '1年前は何を聴いていた？',
      };

  String timeMachineCardTeaser(String title) => switch (language) {
        AppLanguage.es => 'Hace 1 año: «$title»',
        AppLanguage.en => 'A year ago: “$title”',
        AppLanguage.ja => '1年前:「$title」',
      };

  String timeMachineCardTeaserRepeat(String title) => switch (language) {
        AppLanguage.es => 'Hace 1 año: «$title» en repeat',
        AppLanguage.en => 'A year ago: “$title” on repeat',
        AppLanguage.ja => '1年前:「$title」をリピート',
      };

  String get a11yTimeMachine => switch (language) {
        AppLanguage.es => 'Máquina del tiempo: lo que escuchabas hace un año',
        AppLanguage.en => 'Time Machine: what you were listening to a year ago',
        AppLanguage.ja => 'タイムマシン：1年前に聴いていた曲',
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
