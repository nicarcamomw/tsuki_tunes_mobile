import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/library_repository.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_track_listened.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_track_listened.dart';

import 'helpers/fake_library_repository.dart';
import 'helpers/get_it_fakes.dart';

const _song = Track(
  id: 't1',
  title: 'Song',
  artistId: 'a',
  artistName: 'Artist',
  albumId: 'alb',
  albumTitle: 'Album',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a use case from get_it runs on the fake repository put in its place', () async {
    final library = FakeLibraryRepository();
    useFake<LibraryRepository>(library);

    expect(await getIt<ToggleTrackListened>()(_song), isTrue);
    expect(library.isTrackListened('t1'), isTrue);

    await getIt<MarkTrackListened>()(_song);
    expect(library.markCalls, [
      ['t1'],
    ], reason: 'already listened: nothing written twice');
  });

  test('the next test starts from the real registrations again', () {
    expect(getIt<LibraryRepository>(), isNot(isA<FakeLibraryRepository>()));
  });
}
