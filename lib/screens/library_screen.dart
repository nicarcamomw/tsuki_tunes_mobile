import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../core/utils/cyber_page_route.dart';
import '../core/utils/formatters.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/app_providers.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/playlist_provider.dart';
import '../screens/album_detail_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../widgets/artist_card.dart';
import '../widgets/track_tile.dart';
import 'main_navigation_screen.dart';

class _AlbumGroupData {
  final String albumId;
  final String albumTitle;
  final String artistName;
  final String coverUrl;
  final List<ListenedTrackData> tracks;
  DateTime? latestListened;

  _AlbumGroupData({
    required this.albumId,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
    required this.tracks,
  });
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  late final TabController _tabController;
  String _sortBy = 'recent';
  int _visibleCount = 50;
  final Set<String> _expandedAlbums = {};
  bool _hasError = false;

  // Cached album grouping — rebuilt only when the source list identity changes.
  List<ListenedTrackData>? _cachedSource;
  List<_AlbumGroupData> _cachedGroups = const [];
  int _cachedTotalTracks = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    NavigationEvents.onLibraryScrollToTop = scrollToTop;
    scrollController.addListener(_onScroll);
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
    _filterController.dispose();
    super.dispose();
  }

  /// Scroll to top suave para respuesta a Double-Tap o tap activo en Library
  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _refreshData() async {
    final library = ref.read(libraryProvider);
    try {
      await library.refreshData();
      setState(() => _hasError = false);
    } catch (_) {
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final library = ref.watch(libraryProvider);
    final listenedTracks = library.listenedTracks;

    // Rebuild the album grouping only when the source list changes.
    if (!identical(listenedTracks, _cachedSource)) {
      _cachedSource = listenedTracks;
      _cachedTotalTracks = listenedTracks.length;
      final Map<String, _AlbumGroupData> albumMap = {};
      for (final t in listenedTracks) {
        final key = t.albumId.isNotEmpty ? t.albumId : t.albumTitle.isNotEmpty ? t.albumTitle : 'unknown';
        if (!albumMap.containsKey(key)) {
          albumMap[key] = _AlbumGroupData(
            albumId: t.albumId,
            albumTitle: t.albumTitle,
            artistName: t.artistName,
            coverUrl: t.coverUrl,
            tracks: [],
          );
        }
        albumMap[key]!.tracks.add(t);
        if (t.listenedAt != null) {
          final current = albumMap[key]!.latestListened;
          if (current == null || t.listenedAt!.isAfter(current)) {
            albumMap[key]!.latestListened = t.listenedAt;
          }
        }
      }
      _cachedGroups = albumMap.values.toList();
    }

    final totalTracks = _cachedTotalTracks;
    var albumGroups = List<_AlbumGroupData>.of(_cachedGroups);
    final totalAlbums = albumGroups.length;

    // Filter
    final filterText = _filterController.text.toLowerCase();
    if (filterText.isNotEmpty) {
      albumGroups = albumGroups.where((g) {
        return g.albumTitle.toLowerCase().contains(filterText) ||
            g.artistName.toLowerCase().contains(filterText);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'alpha':
        albumGroups.sort(
            (a, b) => a.albumTitle.toLowerCase().compareTo(b.albumTitle.toLowerCase()));
        break;
      case 'artist':
        albumGroups.sort(
            (a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
        break;
      case 'recent':
      default:
        albumGroups.sort((a, b) {
          final aTime = a.latestListened ?? DateTime(2000);
          final bTime = b.latestListened ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
    }

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Row(
                      children: [
                        Text(
                          strings.libraryTitle.toUpperCase(),
                          style: locale.getTextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textBright,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          ' // 03',
                          style: locale.getTextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.libraryTelemetry,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.libraryStats(totalTracks, totalAlbums),
                    style: locale.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                dividerHeight: 0,
                tabs: [
                  Tab(text: strings.albumsTab),
                  Tab(text: strings.playlistsTab),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Albums tab
                  _buildAlbumsTab(context, locale, strings, listenedTracks, albumGroups, visible, totalTracks),
                  // Playlists tab
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

  Widget _buildAlbumsTab(
    BuildContext context,
    LocaleProvider locale,
    AppStrings strings,
    List<ListenedTrackData> listenedTracks,
    List<_AlbumGroupData> albumGroups,
    List<_AlbumGroupData> visible,
    int totalTracks,
  ) {
    final filterText = _filterController.text.toLowerCase();
    final allFollowed = ref.watch(libraryProvider).followedArtists;
    final followedArtists = filterText.isEmpty
        ? allFollowed
        : allFollowed
            .where((a) => a.name.toLowerCase().contains(filterText))
            .toList();
    final showFollowed = followedArtists.isNotEmpty;

    return Column(
      children: [
        // Filter + Sort
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgMid,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _filterController,
                  style: locale.getTextStyle(
                      color: AppColors.textBright, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: strings.filterHint,
                    hintStyle: locale.getTextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.filter_list,
                        color: AppColors.textSecondary, size: 18, semanticLabel: strings.a11yFilter),
                    suffixIcon: _filterController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: AppColors.textSecondary, size: 16, semanticLabel: strings.a11yClearFilter),
                            tooltip: strings.a11yClearFilter,
                            onPressed: () {
                              setState(() => _filterController.clear());
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
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
            ],
          ),
        ),

        // Play controls
        if (totalTracks > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final allTracks = _buildAllTracks(listenedTracks);
                      if (allTracks.isNotEmpty) {
                        final audio = context.read<AudioProvider>();
                        audio.playTrack(allTracks.first, newQueue: allTracks);
                      }
                    },
                    icon: Icon(Icons.play_arrow, color: AppColors.accent, size: 18, semanticLabel: strings.a11yPlayAll),
                    label: Text(
                      strings.playAll,
                      style: locale.getTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final allTracks = _buildAllTracks(listenedTracks);
                      if (allTracks.isNotEmpty) {
                        final shuffled = List<Track>.from(allTracks)..shuffle();
                        final audio = context.read<AudioProvider>();
                        audio.playTrack(shuffled.first, newQueue: shuffled);
                      }
                    },
                    icon: Icon(Icons.shuffle, color: AppColors.accent, size: 18, semanticLabel: strings.a11yShuffleAll),
                    label: Text(
                      strings.shuffle,
                      style: locale.getTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            onRefresh: _refreshData,
            child: totalTracks == 0
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (showFollowed)
                        _buildFollowedArtistsSection(followedArtists, locale),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: _hasError
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
                                      const SizedBox(height: 10),
                                      Text(
                                        strings.loadError,
                                        style: locale.getTextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 14),
                                      Semantics(
                                        button: true,
                                        label: strings.retry,
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            _refreshData();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(
                                              strings.retry,
                                              style: locale.getTextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 1.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: 0.3,
                                  child: Image.asset('assets/images/tengu.png', width: 54, height: 54, semanticLabel: strings.a11yEmptyLibrary),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  strings.emptyLibraryTitle,
                                  textAlign: TextAlign.center,
                                  style: locale.getTextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strings.emptyLibrarySubtitle,
                                  textAlign: TextAlign.center,
                                  style: locale.getTextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 16),
                                Semantics(
                                  button: true,
                                  label: strings.a11yGoToSearch,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      NavigationEvents.switchTab?.call(1);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.accent.withValues(alpha: 0.6),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        strings.homeEmptyAction,
                                        style: locale.getTextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.accent,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: (showFollowed ? 1 : 0) +
                        (visible.length < albumGroups.length
                            ? visible.length + 1
                            : visible.length),
                    itemBuilder: (context, index) {
                      if (showFollowed) {
                        if (index == 0) {
                          return _buildFollowedArtistsSection(
                              followedArtists, locale);
                        }
                        index--;
                      }
                      if (index == visible.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        );
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
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(
    BuildContext context,
    LocaleProvider locale,
    AppStrings strings,
  ) {
    final playlists = ref.watch(playlistProvider).playlists;

    return Column(
      children: [
        // Create playlist button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: Icon(Icons.add, color: AppColors.accent, size: 18, semanticLabel: strings.a11yCreatePlaylist),
              label: Text(
                strings.createPlaylist,
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Playlist list or empty state
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.3,
                          child: Image.asset('assets/images/tengu.png', width: 54, height: 54, semanticLabel: strings.a11yEmptyPlaylist),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.noPlaylistsTitle,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.noPlaylistsSubtitle,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return _PlaylistListTile(playlist: playlist);
                  },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          strings.newPlaylist,
          style: locale.getTextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: PlaylistProvider.maxNameLength,
          style: locale.getTextStyle(
            fontSize: 14,
            color: AppColors.textBright,
          ),
          decoration: InputDecoration(
            hintText: strings.playlistNameHint,
            hintStyle: locale.getTextStyle(
              fontSize: 14,
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
                fontSize: 12,
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty && context.mounted) {
      final provider = ref.read(playlistProvider);
      await provider.createPlaylist(name);
      if (context.mounted) {
        unawaited(SemanticsService.sendAnnouncement(View.of(context), strings.playlistCreated, TextDirection.ltr));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.playlistCreated,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<Track> _buildAllTracks(List<ListenedTrackData> listened) {
    return listened
        .map((td) => Track(
              id: td.trackId,
              title: td.title,
              artistId: '',
              artistName: td.artistName,
              albumId: td.albumId,
              albumTitle: td.albumTitle,
              coverUrl: td.coverUrl,
              previewUrl: td.previewUrl,
              durationSeconds: td.duration,
            ))
        .toList();
  }

  Widget _buildFollowedArtistsSection(
      List<Artist> artists, LocaleProvider locale) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded,
                    size: 16, color: AppColors.accent, semanticLabel: locale.strings.a11yFollowArtist),
                const SizedBox(width: 8),
                Text(
                  locale.strings.followedArtistsTitle,
                  style: locale.getTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${artists.length}',
                  style: locale.getTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: artists.length,
              itemBuilder: (context, index) => ArtistCard(
                key: ValueKey(artists[index].id),
                artist: artists[index],
                size: 84,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBtn(String value, String label, LocaleProvider locale) {
    final isSelected = _sortBy == value;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: isSelected,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _sortBy = value);
          },
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.bgMid,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.textBright : AppColors.textSecondary,
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _AlbumGroupTile extends ConsumerStatefulWidget {
  final _AlbumGroupData group;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _AlbumGroupTile({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  ConsumerState<_AlbumGroupTile> createState() => _AlbumGroupTileState();
}

class _AlbumGroupTileState extends ConsumerState<_AlbumGroupTile>
    with SingleTickerProviderStateMixin {
  _AlbumGroupData get group => widget.group;
  bool get isExpanded => widget.isExpanded;
  VoidCallback get onToggle => widget.onToggle;

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioProvider>();
    final currentTrackId =
        context.select<AudioProvider, String?>((a) => a.currentTrack?.id);
    final library = ref.read(libraryProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: isExpanded
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Cover
                  ExcludeSemantics(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBright,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.artistName,
                                style: locale.getTextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              ' · ${strings.trackCountLabel(group.tracks.length)}',
                              style: locale.getTextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // View album link
                  if (group.albumId.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        final album = _buildAlbumFromGroup(group);
                        appNavigatorKey.currentState?.push(
                          CyberPageRoute(
                            builder: (_) => AlbumDetailScreen(album: album),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        strings.viewAlbum,
                        style: locale.getTextStyle(
                          fontSize: 10,
                          color: AppColors.accent,
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      Container(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      ...group.tracks.map((trackData) {
              final isCurrentTrack = currentTrackId == trackData.trackId;
              return InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  final queue = group.tracks
                      .map((td) => Track(
                            id: td.trackId,
                            title: td.title,
                            artistId: '',
                            artistName: td.artistName,
                            albumId: td.albumId,
                            albumTitle: td.albumTitle,
                            coverUrl: td.coverUrl,
                            previewUrl: td.previewUrl,
                            durationSeconds: td.duration,
                          ))
                      .toList();
                  final track = queue.firstWhere(
                      (t) => t.id == trackData.trackId,
                      orElse: () => queue.first);
                  audio.playTrack(track, newQueue: queue);
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  final track = Track(
                    id: trackData.trackId,
                    title: trackData.title,
                    artistId: '',
                    artistName: trackData.artistName,
                    albumId: trackData.albumId,
                    albumTitle: trackData.albumTitle,
                    coverUrl: trackData.coverUrl,
                    previewUrl: trackData.previewUrl,
                    durationSeconds: trackData.duration,
                  );
                  showTrackActions(context, track);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: isCurrentTrack ? AppColors.accentDim : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trackData.title,
                              style: locale.getTextStyle(
                                fontSize: 13,
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
                                fontSize: 11,
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
                          fontSize: 10,
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
                        onPressed: () =>
                            library.unmarkTrack(trackData.trackId),
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

  static Album _buildAlbumFromGroup(_AlbumGroupData group) {
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
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          appNavigatorKey.currentState?.push(
            CyberPageRoute(
              builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ExcludeSemantics(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
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
                        fontSize: 14,
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
                        fontSize: 11,
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
