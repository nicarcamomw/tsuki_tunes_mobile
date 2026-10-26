class WrappedTrackEntry {
  final String trackId;
  final String title;
  final String artistName;
  final String albumTitle;
  final String coverUrl;
  final int playCount;
  final int totalSeconds;

  const WrappedTrackEntry({
    required this.trackId,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.coverUrl,
    required this.playCount,
    required this.totalSeconds,
  });

  factory WrappedTrackEntry.fromJson(Map<String, dynamic> json) {
    return WrappedTrackEntry(
      trackId: json['trackId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumTitle: json['albumTitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      playCount: json['playCount'] as int? ?? 0,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'coverUrl': coverUrl,
        'playCount': playCount,
        'totalSeconds': totalSeconds,
      };
}

class WrappedArtistEntry {
  final String name;
  final int playCount;
  final int totalSeconds;
  final String? coverUrl;

  const WrappedArtistEntry({
    required this.name,
    required this.playCount,
    required this.totalSeconds,
    this.coverUrl,
  });

  factory WrappedArtistEntry.fromJson(Map<String, dynamic> json) {
    return WrappedArtistEntry(
      name: json['name'] as String? ?? '',
      playCount: json['playCount'] as int? ?? 0,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
      coverUrl: json['coverUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'playCount': playCount,
        'totalSeconds': totalSeconds,
        'coverUrl': coverUrl,
      };
}

class WrappedFunFact {
  final String key;
  final Map<String, dynamic> data;

  const WrappedFunFact({
    required this.key,
    required this.data,
  });

  factory WrappedFunFact.fromJson(Map<String, dynamic> json) {
    return WrappedFunFact(
      key: json['key'] as String? ?? '',
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'data': data,
      };
}

class WrappedData {
  final int year;
  final List<WrappedTrackEntry> topTracks;
  final List<WrappedArtistEntry> topArtists;
  final int totalMinutesListened;
  final int totalTracksPlayed;
  final int uniqueTracksCount;
  final int uniqueArtistsCount;
  final int favoriteHour;
  final Map<int, int> hourDistribution;
  final List<WrappedFunFact> funFacts;
  final DateTime generatedAt;

  const WrappedData({
    required this.year,
    required this.topTracks,
    required this.topArtists,
    required this.totalMinutesListened,
    required this.totalTracksPlayed,
    required this.uniqueTracksCount,
    required this.uniqueArtistsCount,
    required this.favoriteHour,
    required this.hourDistribution,
    required this.funFacts,
    required this.generatedAt,
  });

  bool get isEmpty => totalTracksPlayed == 0;

  factory WrappedData.fromJson(Map<String, dynamic> json) {
    return WrappedData(
      year: json['year'] as int? ?? 0,
      topTracks: (json['topTracks'] as List?)
              ?.map((e) =>
                  WrappedTrackEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      topArtists: (json['topArtists'] as List?)
              ?.map((e) =>
                  WrappedArtistEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      totalMinutesListened: json['totalMinutesListened'] as int? ?? 0,
      totalTracksPlayed: json['totalTracksPlayed'] as int? ?? 0,
      uniqueTracksCount: json['uniqueTracksCount'] as int? ?? 0,
      uniqueArtistsCount: json['uniqueArtistsCount'] as int? ?? 0,
      favoriteHour: json['favoriteHour'] as int? ?? 0,
      hourDistribution: (json['hourDistribution'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k.toString()), v as int)) ??
          {},
      funFacts: (json['funFacts'] as List?)
              ?.map((e) =>
                  WrappedFunFact.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'topTracks': topTracks.map((e) => e.toJson()).toList(),
        'topArtists': topArtists.map((e) => e.toJson()).toList(),
        'totalMinutesListened': totalMinutesListened,
        'totalTracksPlayed': totalTracksPlayed,
        'uniqueTracksCount': uniqueTracksCount,
        'uniqueArtistsCount': uniqueArtistsCount,
        'favoriteHour': favoriteHour,
        'hourDistribution':
            hourDistribution.map((k, v) => MapEntry(k.toString(), v)),
        'funFacts': funFacts.map((e) => e.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}
