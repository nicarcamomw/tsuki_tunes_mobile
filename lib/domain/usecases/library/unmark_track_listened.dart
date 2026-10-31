import '../../repositories/library_repository.dart';

/// Takes a song off the listened list.
class UnmarkTrackListened {
  const UnmarkTrackListened(this._library);

  final LibraryRepository _library;

  Future<void> call(String trackId) => _library.unmarkTrack(trackId);
}
