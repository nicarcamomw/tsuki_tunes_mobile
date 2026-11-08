import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/artist_card.dart';
import '../widgets/haptics.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/track_tile.dart';

/// A genre opened from the search screen: its best known artists and its
/// most played songs right now.
class GenreScreen extends ConsumerStatefulWidget {
  final String genreId;
  final String name;

  const GenreScreen({super.key, required this.genreId, required this.name});

  @override
  ConsumerState<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends ConsumerState<GenreScreen> {
  List<Artist> _artists = const [];
  List<Track> _tracks = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await ref.read(getGenrePageProvider)(widget.genreId);
      if (!mounted) return;
      setState(() {
        _artists = page.artists;
        _tracks = page.tracks;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[GenreScreen] load ${widget.genreId} error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textBright,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          widget.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: locale.getTextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SkeletonSwitcher(
        loading: _loading,
        skeleton: const SkeletonGenre(),
        child: _loading
          ? const SizedBox.shrink()
          : _error
              ? _buildError(locale)
              : _artists.isEmpty && _tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          strings.genreEmpty,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.only(
                          bottom: 120 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        if (_artists.isNotEmpty) ...[
                          _header(locale, strings.genreArtists),
                          SizedBox(
                            height: 155,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _artists.length,
                              itemBuilder: (context, i) =>
                                  ArtistCard(artist: _artists[i]),
                            ),
                          ),
                        ],
                        if (_tracks.isNotEmpty) ...[
                          _header(locale, strings.genreTopTracks),
                          for (var i = 0; i < _tracks.length; i++)
                            TrackTile(track: _tracks[i], index: i, queue: _tracks),
                        ],
                      ],
                    ),
      ),
    );
  }

  Widget _header(LocaleProvider locale, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: locale.getTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

  Widget _buildError(LocaleProvider locale) {
    final strings = locale.strings;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
          const SizedBox(height: 12),
          Text(
            strings.searchError,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () { Haptics.tap(); _load(); },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Text(strings.retry),
          ),
        ],
      ),
    );
  }
}
