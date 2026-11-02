import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/product_analytics.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/product_events.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/mark_track_listened.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/toggle_follow_artist.dart';

import 'helpers/fake_library_repository.dart';

class FakeAnalytics implements AnalyticsBackend {
  final events = <String>[];
  final screens = <String>[];
  bool? collecting;

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async =>
      events.add(parameters.isEmpty ? name : '$name $parameters');

  @override
  Future<void> logScreen(String name) async => screens.add(name);

  @override
  Future<void> setCollectionEnabled(bool enabled) async => collecting = enabled;
}

class RecordedEvents implements ProductEvents {
  final events = <String>[];

  @override
  void log(String name, [Map<String, Object> parameters = const {}]) =>
      events.add(parameters.isEmpty ? name : '$name $parameters');
}

/// A library where the albums in [completed] count as finished.
class CompletingLibrary extends FakeLibraryRepository {
  final completed = <String>{};

  @override
  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0}) =>
      completed.contains(albumId);
}

Track _t(String id, {String album = 'alb'}) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: album,
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

void main() {
  final analytics = ProductAnalytics.instance;
  late FakeAnalytics backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics.resetForTesting();
    backend = FakeAnalytics();
  });
  tearDown(analytics.resetForTesting);

  group('ProductAnalytics', () {
    test('events go out once attached, not before', () async {
      analytics.log('play_start');
      await analytics.attach(backend, collect: true);
      analytics.log('play_start', {'mode': 'preview'});
      analytics.screen('/album/:id');
      expect(backend.events, ['play_start {mode: preview}']);
      expect(backend.screens, ['/album/:id']);
      expect(backend.collecting, isTrue);
    });

    test('debug builds collect nothing, whatever the setting', () async {
      await analytics.attach(backend, collect: false);
      expect(backend.collecting, isFalse);
    });

    test('turned off in the settings: nothing is sent, and it stays off',
        () async {
      await analytics.attach(backend, collect: true);
      await analytics.setEnabled(false);
      analytics.log('play_start');
      expect(backend.events, isEmpty);
      expect(backend.collecting, isFalse);

      // The next launch remembers it.
      analytics.resetForTesting();
      final next = FakeAnalytics();
      await analytics.attach(next, collect: true);
      expect(analytics.enabled, isFalse);
      expect(next.collecting, isFalse);
    });
  });

  group('use cases report what people do', () {
    test('following and unfollowing an artist, by id', () async {
      final events = RecordedEvents();
      final toggle = ToggleFollowArtist(FakeLibraryRepository(), events: events);
      const artist = Artist(id: 'x', name: 'X', pictureUrl: '');
      await toggle(artist);
      await toggle(artist);
      expect(events.events,
          ['follow_artist {artist_id: x}', 'unfollow_artist {artist_id: x}']);
    });

    test('a listened song, and the album it finishes', () async {
      final events = RecordedEvents();
      final library = CompletingLibrary();
      final mark = MarkTrackListened(library, events: events);
      await mark(_t('1'));
      library.completed.add('alb');
      await mark(_t('2'));
      await mark(_t('2')); // already listened: nothing new
      expect(events.events, [
        'track_listened',
        'track_listened',
        'album_completed {album_id: alb}',
      ]);
    });
  });
}
