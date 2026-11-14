import 'dart:async';
import 'dart:math' show min;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/listened_track.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../navigation/main_tab.dart';
import '../navigation/routes.dart';
import '../state/album_track_order.dart';
import '../state/app_providers.dart';
import '../state/library_albums.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_snack.dart';
import '../widgets/artist_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/haptics.dart';
import '../widgets/listened_undo.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/track_tile.dart';
import 'main_navigation_screen.dart';
import 'shared_playlist_screen.dart' show createSharedPlaylist;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  final ScrollController _songsScroll = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  late final TabController _tabController;
  String _sortBy = 'recent';

  // The tabs, in order.
  static const _albums = 0, _songs = 1, _artists = 2, _playlists = 3;
  int _tab = _albums;

  // The song list as players take it, made again when its view changes.
  List<ListenedTrackData>? _songTracksOf;
  List<Track> _songTracks = const [];
  int _visibleCount = 50;
  final Set<String> _expandedAlbums = {};
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (_tabController.index != _tab) setState(() => _tab = _tabController.index);
      });
    NavigationEvents.onLibraryScrollToTop = scrollToTop;
    scrollController.addListener(_onScroll);
    // Reads the albums' saved song order now, so it's ready when one opens.
    ref.read(albumTrackOrderProvider);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.offset;
    if (currentScroll >= maxScroll - 200) {
      setState(() => _visibleCount += 50);
    }
  }

  @override
  void dispose() {
    if (NavigationEvents.onLibraryScrollToTop == scrollToTop) {
      NavigationEvents.onLibraryScrollToTop = null;
    }
    _tabController.dispose();
    scrollController.dispose();
    _songsScroll.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Scroll to top suave para respuesta a Double-Tap o tap activo en Library
  void scrollToTop() {
    for (final c in [scrollController, _songsScroll]) {
      if (c.hasClients) {
        c.animateTo(0, duration: AppMotion.slow, curve: Curves.easeOutCubic);
      }
    }
  }

  Future<void> _refreshData() async {
    final library = ref.read(libraryProvider);
    try {
      await library.refreshData();
      if (mounted) setState(() => _hasError = false);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    // L-01: rebuilt when the songs change (the library hands out a new
    // list then) or the followed artists do, not on every notification
    // (sync state, play counts…).
    final listenedTracks = ref.watch(libraryProvider.select((l) => l.listenedTracks));
    ref.watch(libraryProvider.select((l) => (l.followedArtists, l.followedArtists.length)));

    // Grouped, filtered and sorted only when the songs, the filter or the
    // order change (LibraryAlbumList); loading the next page reuses it.
    final albumList = ref.read(libraryAlbumsProvider);
    final totalTracks = listenedTracks.length;
    final totalAlbums = albumList.groups(listenedTracks).length;
    final albumGroups = albumList.view(
      listenedTracks,
      filter: _filterController.text,
      sortBy: _sortBy,
    );

    // Paginate
    final visible = albumGroups.take(_visibleCount).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: FittedBox(
                      // Shrinks rather than overflow on a narrow phone or with big text.
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            strings.libraryTitle.toUpperCase(),
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBright,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            ' // 04',
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.display,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Flavour, not information: screen readers skip it.
                  ExcludeSemantics(child: Text(
                    strings.libraryTelemetry,
                    style: GoogleFonts.notoSansJp(
                      fontSize: AppFontSize.micro,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentText,
                      letterSpacing: 1.2,
                    ),
                  )),
                  const SizedBox(height: 4),
                  Text(
                    strings.libraryStats(totalTracks, totalAlbums),
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w600,
                ),
                dividerHeight: 0,
                tabs: [
                  Tab(text: strings.albumsTab),
                  Tab(text: strings.tabTracks),
                  Tab(text: strings.tabArtists),
                  Tab(text: strings.playlistsTab),
                ],
              ),
            ),

            // One filter for albums, songs and artists; order and play for
            // albums and songs. Playlists have their own buttons.
            if (_tab != _playlists && (totalTracks > 0 || _tab == _artists))
              _buildControls(locale, strings, albumGroups, listenedTracks),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAlbumsTab(context, locale, strings, albumGroups, visible, totalTracks),
                  _buildSongsTab(context, locale, strings, listenedTracks),
                  _buildArtistsTab(context, locale, strings),
                  _buildPlaylistsTab(context, locale, strings),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// The filter, then (albums and songs) the order and play buttons.
  Widget _buildControls(
    LocaleProvider locale,
    AppStrings strings,
    List<LibraryAlbumGroup> albumGroups,
    List<ListenedTrackData> listenedTracks,
  ) {
    final withSongs = _tab == _albums || _tab == _songs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 4),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgMid,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _filterController,
              style: locale.getTextStyle(color: AppColors.textBright, fontSize: AppFontSize.bodyLg),
              decoration: InputDecoration(
                hintText: strings.filterHint,
                hintStyle: locale.getTextStyle(color: AppColors.textMuted, fontSize: AppFontSize.bodyLg),
                prefixIcon: Icon(Icons.filter_list,
                    color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yFilter),
                suffixIcon: _filterController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: AppColors.textSecondary, size: 16, semanticLabel: strings.a11yClearFilter),
                        tooltip: strings.a11yClearFilter,
                        onPressed: () {
                          Haptics.selection();
                          setState(() => _filterController.clear());
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (withSongs) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSortBtn('recent', strings.sortRecent, locale),
                const SizedBox(width: 8),
                _buildSortBtn('alpha', strings.sortAz, locale),
                const SizedBox(width: 8),
                _buildSortBtn('artist', strings.sortArtist, locale),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      final all = _playAllQueue(albumGroups, listenedTracks);
                      if (all.isNotEmpty) ref.read(playTracksProvider)(all);
                    },
                    icon: Icon(Icons.play_arrow, color: AppColors.accent, size: 18, semanticLabel: strings.a11yPlayAll),
                    label: Text(
                      strings.playAll,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Haptics.tap();
                      final all = _playAllQueue(albumGroups, listenedTracks);
                      if (all.isNotEmpty) ref.read(playTracksProvider)(all, shuffled: true);
                    },
                    icon: Icon(Icons.shuffle, color: AppColors.textPrimary, size: 18, semanticLabel: strings.a11yShuffleAll),
                    label: Text(
                      strings.shuffle,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // D-12: the second action is neutral; red is for "play all".
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderGlow),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "Play all" plays what the tab shows, in its order: each album in the
  /// album's own order on the albums tab, the list as it is on the songs one.
  List<Track> _playAllQueue(List<LibraryAlbumGroup> albumGroups, List<ListenedTrackData> listenedTracks) {
    if (_tab == _songs) return _songTracksFor(listenedTracks);
    final order = ref.read(albumTrackOrderProvider);
    return [
      for (final g in albumGroups)
        for (final t in order.sort(g.albumId, g.tracks)) t.toTrack(),
    ];
  }

  /// A song picked in an album: its album in order from it, then the next
  /// albums of the list. The album's order is usually known by then (it's
  /// asked for when the album opens); if not, it's waited for a moment.
  Future<void> _playFromAlbum(List<LibraryAlbumGroup> albums, int index, String trackId) async {
    final order = ref.read(albumTrackOrderProvider);
    final group = albums[index];
    if (group.albumId.isNotEmpty && order.orderOf(group.albumId) == null) {
      await order.ensure(group.albumId).timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
      if (!mounted) return;
    }
    final (:queue, :start) = libraryAlbumQueue(albums, index, trackId,
        ordered: (g) => order.sort(g.albumId, g.tracks));
    final tracks = [for (final t in queue) t.toTrack()];
    await ref.read(playTrackProvider)(tracks[start], queue: tracks);
  }

  /// Opening an album asks for its order, and the next few albums' too, so
  /// a song played from it continues into them in order.
  void _learnOrderFrom(List<LibraryAlbumGroup> albums, int index) {
    final order = ref.read(albumTrackOrderProvider);
    for (var i = index; i < min(index + 4, albums.length); i++) {
      unawaited(order.ensure(albums[i].albumId));
    }
  }

  Widget _buildAlbumsTab(
    BuildContext context,
    LocaleProvider locale,
    AppStrings strings,
    List<LibraryAlbumGroup> albumGroups,
    List<LibraryAlbumGroup> visible,
    int totalTracks,
  ) {
    return Column(
      children: [
        // Content
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            onRefresh: () {
              Haptics.threshold();
              return _refreshData();
            },
            child: totalTracks == 0
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: _hasError
                            ? ErrorState(message: strings.loadError, onRetry: _refreshData)
                            : EmptyState(
                            image: 'assets/images/oni.png',
                            artLabel: strings.a11yEmptyLibrary,
                            lore: strings.emptyLoreOni,
                            title: strings.emptyLibraryTitle,
                            message: strings.emptyLibrarySubtitle,
                            actionLabel: strings.homeEmptyAction,
                            actionSemanticLabel: strings.a11yGoToSearch,
                            onAction: () => NavigationEvents.switchTab?.call(MainTab.search),
                          ),
                      ),
                    ],
                  )
                : albumGroups.isEmpty
                    ? _noResults(locale, strings)
                    : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: visible.length < albumGroups.length
                        ? visible.length + 1
                        : visible.length,
                    itemBuilder: (context, index) {
                      if (index == visible.length) {
                        return const SkeletonTrackList(count: 2, padding: EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8));
                      }
                      return _AlbumGroupTile(
                        group: visible[index],
                        isExpanded:
                            _expandedAlbums.contains(visible[index].albumId.isNotEmpty ? visible[index].albumId : visible[index].albumTitle),
                        onToggle: () {
                          setState(() {
                            final key = visible[index].albumId.isNotEmpty ? visible[index].albumId : visible[index].albumTitle;
                            if (_expandedAlbums.contains(key)) {
                              _expandedAlbums.remove(key);
                            } else {
                              _expandedAlbums.add(key);
                              _learnOrderFrom(albumGroups, index);
                            }
                          });
                        },
                        onPlay: (trackId) => unawaited(_playFromAlbum(albumGroups, index, trackId)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  /// Nothing matches the filter.
  Widget _noResults(LocaleProvider locale, AppStrings strings) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 48, AppSpacing.page, 120),
        children: [
          Text(
            strings.noResults,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary),
          ),
        ],
      );

  List<Track> _songTracksFor(List<ListenedTrackData> listenedTracks) {
    final songs = ref.read(librarySongsProvider).view(listenedTracks, filter: _filterController.text, sortBy: _sortBy);
    if (!identical(songs, _songTracksOf)) {
      _songTracksOf = songs;
      _songTracks = List.unmodifiable([for (final t in songs) t.toTrack()]);
    }
    return _songTracks;
  }

  /// Every song, one under the other. A song plays with the ones under it
  /// after it, in the list's order.
  Widget _buildSongsTab(
    BuildContext context,
    LocaleProvider locale,
    AppStrings strings,
    List<ListenedTrackData> listenedTracks,
  ) {
    if (listenedTracks.isEmpty) {
      return EmptyState(
        image: 'assets/images/oni.png',
        artLabel: strings.a11yEmptyLibrary,
        lore: strings.emptyLoreOni,
        title: strings.emptyLibraryTitle,
        message: strings.emptyLibrarySubtitle,
        actionLabel: strings.homeEmptyAction,
        actionSemanticLabel: strings.a11yGoToSearch,
        onAction: () => NavigationEvents.switchTab?.call(MainTab.search),
      );
    }
    final tracks = _songTracksFor(listenedTracks);
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgCard,
      onRefresh: () {
        Haptics.threshold();
        return _refreshData();
      },
      child: tracks.isEmpty
          ? _noResults(locale, strings)
          : ListView.builder(
              controller: _songsScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 120),
              itemCount: tracks.length,
              itemBuilder: (context, i) => TrackTile(
                key: ValueKey('library_song_${tracks[i].id}'),
                track: tracks[i],
                queue: tracks.sublist(i, min(i + 201, tracks.length)),
              ),
            ),
    );
  }

  /// The followed artists, in a grid.
  Widget _buildArtistsTab(BuildContext context, LocaleProvider locale, AppStrings strings) {
    final filterText = _filterController.text.toLowerCase();
    final all = ref.read(libraryProvider).followedArtists;
    final artists = filterText.isEmpty
        ? all
        : all.where((a) => a.name.toLowerCase().contains(filterText)).toList();
    if (all.isEmpty) {
      return EmptyState(
        image: 'assets/images/tengu.png',
        artLabel: strings.a11yFollowArtist,
        title: strings.radarEmptyNoArtistsTitle,
        message: strings.libraryNoArtistsSubtitle,
        actionLabel: strings.homeEmptyAction,
        actionSemanticLabel: strings.a11yGoToSearch,
        onAction: () => NavigationEvents.switchTab?.call(MainTab.search),
      );
    }
    if (artists.isEmpty) return _noResults(locale, strings);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisExtent: 140,
        crossAxisSpacing: 4,
        mainAxisSpacing: 8,
      ),
      itemCount: artists.length,
      itemBuilder: (context, i) => FittedBox(
        // Shrinks rather than overflow with large text.
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: ArtistCard(key: ValueKey(artists[i].id), artist: artists[i], size: 84),
      ),
    );
  }

  Widget _buildPlaylistsTab(
    BuildContext context,
    LocaleProvider locale,
    AppStrings strings,
  ) {
    final playlists = ref.watch(playlistProvider).playlists;
    final shared = ref.watch(sharedPlaylistsProvider);
    final hasShared = shared.mine.isNotEmpty || shared.invitations.isNotEmpty;

    return Column(
      children: [
        // Create playlist buttons: mine, and one with my Bonds.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
          child: Row(
            children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () { Haptics.tap(); _showCreatePlaylistDialog(context); },
              icon: Icon(Icons.add, color: AppColors.accent, size: 18, semanticLabel: strings.a11yCreatePlaylist),
              label: Text(
                strings.createPlaylist,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
              if (shared.available) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Haptics.tap(); createSharedPlaylist(context, ref); },
                    icon: const Icon(Icons.group_add_rounded, color: AppColors.social, size: 18),
                    label: Text(
                      strings.sharedNew,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.social),
                    ),
                    // D-12: shared with Bonds is social, so purple.
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.social.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Playlist list or empty state
        Expanded(
          child: playlists.isEmpty && !hasShared
              ? EmptyState(
                  image: 'assets/images/hannya.png',
                  artLabel: strings.a11yEmptyPlaylist,
                  lore: strings.emptyLoreHannya,
                  actionLabel: strings.createPlaylist,
                  onAction: () => _showCreatePlaylistDialog(context),
                  title: strings.noPlaylistsTitle,
                  message: strings.noPlaylistsSubtitle,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    if (hasShared) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 4),
                        child: Text(strings.sharedTitle.toUpperCase(),
                            style: locale.getTextStyle(
                                fontSize: AppFontSize.micro, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 2)),
                      ),
                      for (final p in [...shared.invitations, ...shared.mine])
                        ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: p.coverUrl.isEmpty
                                  ? const ColoredBox(
                                      color: AppColors.bgMid, child: Icon(Icons.groups_rounded, color: AppColors.social))
                                  : CachedNetworkImage(
                                      imageUrl: p.coverUrl,
                                      memCacheWidth: imageCacheSize(context, 48),
                                      fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: locale.getTextStyle(
                                  fontSize: AppFontSize.title, fontWeight: FontWeight.w700, color: AppColors.textBright)),
                          subtitle: Text(
                            shared.me != null && p.isInvited(shared.me!) && !p.isMember(shared.me!)
                                ? strings.sharedInvitedBy(p.nameOf(p.owner))
                                : '${strings.sharedMembers(p.members.length)} · ${strings.trackCountLabel(p.tracks.length)}',
                            style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.groups_rounded, color: AppColors.social, size: 18),
                          onTap: () { Haptics.tap(); SharedPlaylistRoute(id: p.id).push<void>(context); },
                        ),
                      const Divider(color: AppColors.border, height: 16),
                    ],
                    for (final playlist in playlists) _PlaylistListTile(playlist: playlist),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final strings = ref.read(stringsProvider);
    final locale = ref.read(localeProvider);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          strings.newPlaylist,
          style: locale.getTextStyle(
            fontSize: AppFontSize.titleLg,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: PlaylistRepository.maxNameLength,
          style: locale.getTextStyle(
            fontSize: AppFontSize.title,
            color: AppColors.textBright,
          ),
          decoration: InputDecoration(
            hintText: strings.playlistNameHint,
            hintStyle: locale.getTextStyle(
              fontSize: AppFontSize.title,
              color: AppColors.textMuted,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              strings.cancel,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(
              strings.create,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await ref.read(createPlaylistProvider)(name);
      if (context.mounted) {
        unawaited(SemanticsService.sendAnnouncement(View.of(context), strings.playlistCreated, TextDirection.ltr));
        AppSnack.of(context).info(strings.playlistCreated);
      }
    }
  }

  Widget _buildSortBtn(String value, String label, LocaleProvider locale) {
    return Expanded(
      child: AppChip(
        label: label,
        selected: _sortBy == value,
        expand: true,
        onTap: () => setState(() => _sortBy = value),
      ),
    );
  }
}

class _AlbumGroupTile extends ConsumerStatefulWidget {
  final LibraryAlbumGroup group;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// Plays a song of the album (with the album, and the next ones, after it).
  final void Function(String trackId) onPlay;

  const _AlbumGroupTile({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
    required this.onPlay,
  });

  @override
  ConsumerState<_AlbumGroupTile> createState() => _AlbumGroupTileState();
}

class _AlbumGroupTileState extends ConsumerState<_AlbumGroupTile>
    with SingleTickerProviderStateMixin {
  LibraryAlbumGroup get group => widget.group;
  bool get isExpanded => widget.isExpanded;
  VoidCallback get onToggle => widget.onToggle;

  @override
  Widget build(BuildContext context) {
    // L-01: only the album that holds the playing song (before or after
    // a change) redraws when the song changes, not every row on screen.
    final currentTrackId = ref.watch(audioProvider.select((a) {
      final id = a.currentTrack?.id;
      return id != null && group.tracks.any((t) => t.trackId == id) ? id : null;
    }));
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    // The album's songs in its own order once known (asked for on opening).
    final order = isExpanded
        ? ref.watch(albumTrackOrderProvider.select((o) => o.orderOf(group.albumId)))
        : null;
    final songs = isExpanded ? sortByAlbum(group.tracks, order) : const <ListenedTrackData>[];
    final numbers = order == null ? null : {for (var i = 0; i < order.length; i++) order[i]: i + 1};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
            color: isExpanded
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Cover
                  ExcludeSemantics(child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: group.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                            memCacheWidth: imageCacheSize(context, (44).toDouble()),
                              imageUrl: group.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.bgMid),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppColors.bgMid),
                            )
                          : Container(color: AppColors.bgMid),
                    ),
                  )),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.albumTitle.isNotEmpty
                              ? group.albumTitle
                              : strings.unknownAlbum,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBright,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // One line that ends in "…" on a narrow phone.
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: group.artistName),
                            TextSpan(
                              text: ' · ${strings.trackCountLabel(group.tracks.length)}',
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.micro,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ]),
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.body,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // View album link
                  if (group.albumId.isNotEmpty)
                    TextButton(
                      onPressed: () { Haptics.tap();
                        final album = _buildAlbumFromGroup(group);
                        AlbumRoute(id: album.id, $extra: album).push(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        // 48 dp to touch, whatever the text's size.
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        strings.viewAlbum,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  ExcludeSemantics(
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded track list
          AnimatedSize(
            duration: AppMotion.normal,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      Container(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      ...songs.map((trackData) {
              final isCurrentTrack = currentTrackId == trackData.trackId;
              final number = numbers?[trackData.trackId];
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                onTap: () {
                  Haptics.tap();
                  widget.onPlay(trackData.trackId);
                },
                onLongPress: () {
                  Haptics.longPress();
                  showTrackActions(context, trackData.toTrack());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: isCurrentTrack ? AppColors.accentDim : null,
                  child: Row(
                    children: [
                      // Its number on the album, once the album's order is known.
                      SizedBox(
                        width: 28,
                        child: Text(
                          number?.toString() ?? '',
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: isCurrentTrack ? AppColors.accentText : AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trackData.title,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.bodyLg,
                                fontWeight: FontWeight.w500,
                                color: isCurrentTrack
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              trackData.artistName,
                              style: locale.getTextStyle(
                                fontSize: AppFontSize.caption,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.formatSeconds(trackData.duration),
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        tooltip: strings.a11yRemoveFromPlaylist,
                        icon: Icon(Icons.remove_circle_outline,
                            color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yRemoveFromPlaylist),
                        onPressed: () { Haptics.selection(); unawaited(unmarkWithUndo(context, ref, [trackData.trackId])); },
                      ),
                    ],
                  ),
                ),
              );
            }),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static Album _buildAlbumFromGroup(LibraryAlbumGroup group) {
    return Album(
      id: group.albumId,
      title: group.albumTitle,
      coverUrl: group.coverUrl,
      artistId: '',
      artistName: group.artistName,
      tracksCount: group.tracks.length,
    );
  }
}

class _PlaylistListTile extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistListTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    final strings = locale.strings;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: () { Haptics.tap();
          PlaylistRoute(id: playlist.id).push(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ExcludeSemantics(child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: playlist.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                        memCacheWidth: imageCacheSize(context, (48).toDouble()),
                          imageUrl: playlist.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.bgMid),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgMid,
                          ),
                        )
                      : Container(
                          color: AppColors.bgMid,
                        ),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.playlistMeta(
                        playlist.trackCount,
                        Formatters.formatSeconds(playlist.totalDurationSeconds),
                      ),
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20, semanticLabel: strings.a11yOpenPlaylist),
            ],
          ),
        ),
      ),
    );
  }
}
