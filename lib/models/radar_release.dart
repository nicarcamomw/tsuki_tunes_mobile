import 'album.dart';

/// A recent release by a watched artist, as tracked by the release radar.
class RadarRelease {
  final String albumId;
  final String title;
  final String artistId;
  final String artistName;
  final String coverUrl;
  final String releaseDate;
  final String recordType;
  final DateTime detectedAt;

  /// True when it appeared after the artist's baseline (a genuinely new drop),
  /// false for releases that already existed when the radar started watching.
  final bool isNew;
  final bool read;

  const RadarRelease({
    required this.albumId,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.coverUrl,
    required this.releaseDate,
    required this.recordType,
    required this.detectedAt,
    required this.isNew,
    required this.read,
  });

  bool get isUnread => isNew && !read;

  DateTime? get releasedAt => DateTime.tryParse(releaseDate);

  factory RadarRelease.fromAlbum(
    Album album, {
    required String artistId,
    required String artistName,
    required DateTime detectedAt,
    required bool isNew,
  }) {
    return RadarRelease(
      albumId: album.id,
      title: album.title,
      artistId: artistId,
      artistName: artistName,
      coverUrl: album.coverUrl,
      releaseDate: album.releaseDate,
      recordType: album.recordType,
      detectedAt: detectedAt,
      isNew: isNew,
      read: !isNew,
    );
  }

  Album toAlbum() => Album(
        id: albumId,
        title: title,
        coverUrl: coverUrl,
        artistId: artistId,
        artistName: artistName,
        releaseDate: releaseDate,
        recordType: recordType,
      );

  RadarRelease copyWith({bool? read}) => RadarRelease(
        albumId: albumId,
        title: title,
        artistId: artistId,
        artistName: artistName,
        coverUrl: coverUrl,
        releaseDate: releaseDate,
        recordType: recordType,
        detectedAt: detectedAt,
        isNew: isNew,
        read: read ?? this.read,
      );

  factory RadarRelease.fromJson(Map<String, dynamic> json) => RadarRelease(
        albumId: json['albumId']?.toString() ?? '',
        title: json['title'] ?? '',
        artistId: json['artistId']?.toString() ?? '',
        artistName: json['artistName'] ?? '',
        coverUrl: json['coverUrl'] ?? '',
        releaseDate: json['releaseDate'] ?? '',
        recordType: json['recordType'] ?? 'album',
        detectedAt: DateTime.tryParse(json['detectedAt'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isNew: json['isNew'] == true,
        read: json['read'] != false,
      );

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'title': title,
        'artistId': artistId,
        'artistName': artistName,
        'coverUrl': coverUrl,
        'releaseDate': releaseDate,
        'recordType': recordType,
        'detectedAt': detectedAt.toIso8601String(),
        'isNew': isNew,
        'read': read,
      };
}
