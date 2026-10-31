import '../../entities/album.dart';
import '../../repositories/library_repository.dart';

/// Marks every song of an album as listened. Only the missing ones are
/// written, and the album's song count is recorded with them so it counts
/// as completed (Deezer's count, or the songs loaded when it has none).
class MarkAlbum {
  const MarkAlbum(this._library);

  final LibraryRepository _library;

  Future<void> call(Album album) async {
    final missing = album.tracks.where((t) => !_library.isTrackListened(t.id)).toList();
    if (missing.isEmpty) return;
    await _library.markAlbumTracks(
      missing,
      albumId: album.id,
      totalTracks: album.tracksCount > 0 ? album.tracksCount : album.tracks.length,
    );
  }
}
