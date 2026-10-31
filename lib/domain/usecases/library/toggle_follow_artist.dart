import '../../entities/artist.dart';
import '../../repositories/library_repository.dart';

/// Follows an artist (their new releases reach the radar), or unfollows
/// them if followed. Returns whether they are followed now.
class ToggleFollowArtist {
  const ToggleFollowArtist(this._library);

  final LibraryRepository _library;

  Future<bool> call(Artist artist) async {
    if (_library.isArtistFollowed(artist.id)) {
      await _library.unfollowArtist(artist.id);
      return false;
    }
    await _library.followArtist(artist);
    return true;
  }
}
