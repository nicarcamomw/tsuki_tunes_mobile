import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_readers.dart';

part 'artist.freezed.dart';
part 'artist.g.dart';

@freezed
abstract class Artist with _$Artist {
  const Artist._();

  const factory Artist({
    @JsonKey(fromJson: jsonString) required String id,
    @JsonKey(defaultValue: 'Unknown Artist') required String name,
    @JsonKey(defaultValue: '') required String pictureUrl,
    String? pictureSmall,
    String? pictureMedium,
    String? pictureBig,
    String? pictureXl,
    @Default(0) int fansCount,
    @Default(0) int albumsCount,
  }) = _Artist;

  /// Reads the stored JSON written by [toJson].
  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

  /// Reads an artist from the Deezer API.
  factory Artist.fromDeezer(Map<String, dynamic> json) {
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
}
