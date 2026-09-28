import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/locale_provider.dart';
import '../models/track.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';
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

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String _sortBy = 'recent';
  int _visibleCount = 50;
  final Set<String> _expandedAlbums = {};

  @override
  void initState() {
    super.initState();
    NavigationEvents.onLibraryScrollToTop = scrollToTop;
  }

  @override
  void dispose() {
    if (NavigationEvents.onLibraryScrollToTop == scrollToTop) {
      NavigationEvents.onLibraryScrollToTop = null;
    }
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

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final library = context.watch<LibraryProvider>();
    final listenedTracks = library.listenedTracks;
    final totalTracks = listenedTracks.length;

    // Group by album
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

    var albumGroups = albumMap.values.toList();
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
    final remaining = albumGroups.length - visible.length;

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        prefixIcon: const Icon(Icons.filter_list,
                            color: AppColors.textSecondary, size: 18),
                        suffixIcon: _filterController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AppColors.textSecondary, size: 16),
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

            // Content
            Expanded(
              child: totalTracks == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.library_music_outlined,
                                size: 54, color: AppColors.borderGlow),
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
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: visible.length + (remaining > 0 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return _buildShowMoreButton(remaining, locale);
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
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildShowMoreButton(int remaining, LocaleProvider locale) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: OutlinedButton(
        onPressed: () => setState(() => _visibleCount += 50),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          locale.strings.showMore(remaining),
          style: locale.getTextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildSortBtn(String value, String label, LocaleProvider locale) {
    final isSelected = _sortBy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sortBy = value),
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
    );
  }
}

class _AlbumGroupTile extends StatelessWidget {
  final _AlbumGroupData group;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _AlbumGroupTile({
    required this.group,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final library = context.watch<LibraryProvider>();
    final locale = context.watch<LocaleProvider>();
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
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: group.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: group.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.bgMid),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppColors.bgMid),
                            )
                          : Container(color: AppColors.bgMid),
                    ),
                  ),
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
                                style: GoogleFonts.plusJakartaSans(
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
                          MaterialPageRoute(
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

                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded track list
          if (isExpanded) ...[
            Container(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            ...group.tracks.map((trackData) {
              final isCurrentTrack =
                  audio.currentTrack?.id == trackData.trackId;
              return InkWell(
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
                              style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () =>
                            library.unmarkTrack(trackData.trackId),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
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
