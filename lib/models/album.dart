import 'track.dart';

class Album {
  final String id;
  final String title;
  final String coverUrl;
  final String? coverXl;
  final String artistId;
  final String artistName;
  final String releaseDate;
  final String recordType;
  final int fansCount;
  final int tracksCount;
  final String? link;
  final List<Track> tracks;

  Album({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.coverXl,
    required this.artistId,
    required this.artistName,
    this.releaseDate = '',
    this.recordType = 'album',
    this.fansCount = 0,
    this.tracksCount = 0,
    this.link,
    this.tracks = const [],
  });

  String get year {
    if (releaseDate.length >= 4) return releaseDate.substring(0, 4);
    return '';
  }

  int get totalDurationSeconds {
    if (tracks.isEmpty) return 0;
    return tracks.fold(0, (sum, t) => sum + t.durationSeconds);
  }

  static String getAlbumTypeLabel(String? type) {
    switch (type) {
      case 'album':
        return 'Álbum';
      case 'single':
        return 'Sencillo';
      case 'ep':
        return 'EP';
      case 'compile':
        return 'Compilación';
      default:
        return 'Álbum';
    }
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    final artistJson =
        json['artist'] is Map<String, dynamic> ? json['artist'] : null;

    List<Track> parsedTracks = [];
    if (json['tracks'] != null && json['tracks']['data'] is List) {
      final List list = json['tracks']['data'];
      parsedTracks = list.map((t) {
        final trackMap = Map<String, dynamic>.from(t as Map);
        trackMap['album_cover'] = json['cover_medium'] ?? json['cover_big'];
        trackMap['album_title'] = json['title'];
        trackMap['artist_name'] =
            trackMap['artist']?['name'] ?? artistJson?['name'];
        trackMap['album_id'] = json['id']?.toString();
        return Track.fromJson(trackMap);
      }).toList();
    }

    return Album(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Album',
      coverUrl: json['cover_big'] ?? json['cover_medium'] ?? json['cover'] ?? '',
      coverXl: json['cover_xl'],
      artistId: artistJson?['id']?.toString() ?? '',
      artistName: artistJson?['name'] ?? 'Unknown Artist',
      releaseDate: json['release_date'] ?? '',
      recordType: json['record_type'] ?? 'album',
      fansCount: json['fans'] is int ? json['fans'] : 0,
      tracksCount:
          json['nb_tracks'] is int ? json['nb_tracks'] : parsedTracks.length,
      link: json['link'],
      tracks: parsedTracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'coverXl': coverXl,
      'artistId': artistId,
      'artistName': artistName,
      'releaseDate': releaseDate,
      'recordType': recordType,
      'fansCount': fansCount,
      'tracksCount': tracksCount,
      'link': link,
    };
  }
}
