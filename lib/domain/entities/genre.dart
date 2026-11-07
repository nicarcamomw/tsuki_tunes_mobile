/// A Deezer music genre, for exploring from the search screen.
class Genre {
  final String id;
  final String name;
  final String pictureUrl;

  const Genre({required this.id, required this.name, this.pictureUrl = ''});

  factory Genre.fromDeezer(Map<String, dynamic> json) => Genre(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
        pictureUrl: (json['picture_medium'] ?? json['picture_big'] ??
                json['picture'] ?? '')
            .toString(),
      );
}
