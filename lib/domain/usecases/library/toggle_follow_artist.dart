import 'package:injectable/injectable.dart';

import '../../entities/artist.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/product_events.dart';

/// Follows an artist (their new releases reach the radar), or unfollows
/// them if followed. Returns whether they are followed now.
@injectable
class ToggleFollowArtist {
  const ToggleFollowArtist(this._library, {ProductEvents events = const NoProductEvents()})
      : _events = events;

  final LibraryRepository _library;
  final ProductEvents _events;

  Future<bool> call(Artist artist) async {
    if (_library.isArtistFollowed(artist.id)) {
      await _library.unfollowArtist(artist.id);
      _events.log('unfollow_artist', {'artist_id': artist.id});
      return false;
    }
    await _library.followArtist(artist);
    _events.log('follow_artist', {'artist_id': artist.id});
    return true;
  }
}
