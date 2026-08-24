class Contributor {
  final String id;
  final String name;
  final String? role;

  Contributor({required this.id, required this.name, this.role});

  factory Contributor.fromJson(Map<String, dynamic> json) {
    return Contributor(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}

class Track {
  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String albumId;
  final String albumTitle;
  final String coverUrl;
  final String previewUrl;
  final int durationSeconds;
  final int? rank;
  final bool isExplicit;
  final List<Contributor> contributors;
  final String? link;

  Track({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumTitle,
    required this.coverUrl,
    required this.previewUrl,
    required this.durationSeconds,
    this.rank,
    this.isExplicit = false,
    this.contributors = const [],
    this.link,
  });

  String get fullArtistName {
    if (contributors.length > 1) {
      return contributors.map((c) => c.name).join(', ');
    }
    return artistName;
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final artistJson =
        json['artist'] is Map<String, dynamic> ? json['artist'] : null;
    final albumJson =
        json['album'] is Map<String, dynamic> ? json['album'] : null;

    final String cover = albumJson?['cover_medium'] ??
        albumJson?['cover_big'] ??
        albumJson?['cover'] ??
        json['album_cover'] ??
        json['cover_medium'] ??
        '';

    List<Contributor> contribs = [];
    if (json['contributors'] is List) {
      contribs = (json['contributors'] as List)
          .map((c) => Contributor.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    String resolvedArtistName =
        artistJson?['name'] ?? json['artist_name'] ?? 'Unknown Artist';
    if (contribs.length > 1) {
      resolvedArtistName = contribs.map((c) => c.name).join(', ');
    }

    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['title_short'] ?? 'Unknown Track',
      artistId:
          artistJson?['id']?.toString() ?? json['artist_id']?.toString() ?? '',
      artistName: resolvedArtistName,
      albumId:
          albumJson?['id']?.toString() ?? json['album_id']?.toString() ?? '',
      albumTitle: albumJson?['title'] ?? json['album_title'] ?? '',
      coverUrl: cover,
      previewUrl: json['preview'] ?? '',
      durationSeconds: json['duration'] is int ? json['duration'] : 30,
      rank: json['rank'] is int ? json['rank'] : null,
      isExplicit: json['explicit_lyrics'] == true,
      contributors: contribs,
      link: json['link'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artistId': artistId,
      'artistName': artistName,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'coverUrl': coverUrl,
      'previewUrl': previewUrl,
      'durationSeconds': durationSeconds,
      'rank': rank,
      'isExplicit': isExplicit,
      'contributors': contributors.map((c) => c.toJson()).toList(),
      'link': link,
    };
  }

  factory Track.fromStorage(Map<String, dynamic> map) {
    List<Contributor> contribs = [];
    if (map['contributors'] is List) {
      contribs = (map['contributors'] as List)
          .map((c) => Contributor.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    return Track(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? 'Unknown Track',
      artistId: map['artistId']?.toString() ?? '',
      artistName: map['artistName'] ?? 'Unknown Artist',
      albumId: map['albumId']?.toString() ?? '',
      albumTitle: map['albumTitle'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      previewUrl: map['previewUrl'] ?? '',
      durationSeconds: map['durationSeconds'] ?? 30,
      rank: map['rank'],
      isExplicit: map['isExplicit'] == true,
      contributors: contribs,
      link: map['link'],
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artistId,
    String? artistName,
    String? albumId,
    String? albumTitle,
    String? coverUrl,
    String? previewUrl,
    int? durationSeconds,
    int? rank,
    bool? isExplicit,
    List<Contributor>? contributors,
    String? link,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rank: rank ?? this.rank,
      isExplicit: isExplicit ?? this.isExplicit,
      contributors: contributors ?? this.contributors,
      link: link ?? this.link,
    );
  }
}
