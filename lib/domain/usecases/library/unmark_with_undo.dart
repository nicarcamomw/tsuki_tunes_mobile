import 'package:injectable/injectable.dart';

import '../../repositories/library_repository.dart';

/// Puts back what an unmark took off.
typedef UndoUnmark = Future<void> Function();

/// Takes songs (one, or a whole album) off the listened list and returns
/// how to undo it: an album unmarked by mistake comes back as it was, each
/// song with its date. Null when none of them was listened; otherwise how
/// many were unmarked and the undo.
@injectable
class UnmarkWithUndo {
  const UnmarkWithUndo(this._library);

  final LibraryRepository _library;

  Future<({int count, UndoUnmark undo})?> call(List<String> trackIds) async {
    final records = _library.listenedRecords(trackIds);
    if (records.isEmpty) return null;
    await _library.unmarkAlbumTracks([for (final r in records) r.trackId]);
    return (count: records.length, undo: () => _library.restoreListened(records));
  }
}
