class Artist {
  final String id;
  final String name;
  final String pictureUrl;
  final String? pictureSmall;
  final String? pictureMedium;
  final String? pictureBig;
  final String? pictureXl;
  final int fansCount;
  final int albumsCount;

  Artist({
    required this.id,
    required this.name,
    required this.pictureUrl,
    this.pictureSmall,
    this.pictureMedium,
    this.pictureBig,
    this.pictureXl,
    this.fansCount = 0,
    this.albumsCount = 0,
  });

  String getBestImage({String size = 'big'}) {
    switch (size) {
      case 'xl':
        return pictureXl ?? pictureBig ?? pictureUrl;
      case 'big':
        return pictureBig ?? pictureUrl;
      case 'medium':
        return pictureMedium ?? pictureUrl;
      case 'small':
        return pictureSmall ?? pictureMedium ?? pictureUrl;
      default:
        return pictureUrl;
    }
  }

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Artist',
      pictureUrl: json['picture_big'] ??
          json['picture_medium'] ??
          json['picture'] ??
          '',
      pictureSmall: json['picture_small'],
      pictureMedium: json['picture_medium'],
      pictureBig: json['picture_big'],
      pictureXl: json['picture_xl'],
      fansCount: json['nb_fan'] is int ? json['nb_fan'] : 0,
      albumsCount: json['nb_album'] is int ? json['nb_album'] : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pictureUrl': pictureUrl,
      'pictureSmall': pictureSmall,
      'pictureMedium': pictureMedium,
      'pictureBig': pictureBig,
      'pictureXl': pictureXl,
      'fansCount': fansCount,
      'albumsCount': albumsCount,
    };
  }

  factory Artist.fromStorage(Map<String, dynamic> map) {
    return Artist(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unknown Artist',
      pictureUrl: map['pictureUrl'] ?? '',
      pictureSmall: map['pictureSmall'],
      pictureMedium: map['pictureMedium'],
      pictureBig: map['pictureBig'],
      pictureXl: map['pictureXl'],
      fansCount: map['fansCount'] ?? 0,
      albumsCount: map['albumsCount'] ?? 0,
    );
  }
}
