import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';

Track createTestTrack({required String id, required String previewUrl}) {
  return Track(
    id: id,
    title: 'Test Track $id',
    artistId: 'artist_$id',
    artistName: 'Artist $id',
    albumId: 'album_$id',
    albumTitle: 'Album $id',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: previewUrl,
    durationSeconds: 30,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async => {},
    );
  });

  group('Playback Error Classification Tests', () {
    late AudioProvider audioProvider;

    setUp(() {
      audioProvider = AudioProvider();
    });

    test('classifies track with empty previewUrl as no_preview_available', () {
      final track = createTestTrack(id: '1', previewUrl: '');
      final result = audioProvider.classifyPlaybackError(
        Exception('Generic error'),
        track,
      );
      expect(result, equals(PlaybackError.noPreview));
    });

    test('classifies track with whitespace previewUrl as no_preview_available', () {
      final track = createTestTrack(id: '2', previewUrl: '   ');
      final result = audioProvider.classifyPlaybackError(
        Exception('Generic error'),
        track,
      );
      expect(result, equals(PlaybackError.noPreview));
    });

    test('classifies error containing preview unavailable text as no_preview_available', () {
      final track = createTestTrack(id: '3', previewUrl: 'https://example.com/audio.mp3');
      final result = audioProvider.classifyPlaybackError(
        Exception('Audio preview is unavailable for this track'),
        track,
      );
      expect(result, equals(PlaybackError.noPreview));
    });

    test('classifies SocketException as network_error', () {
      final track = createTestTrack(id: '4', previewUrl: 'https://example.com/audio.mp3');
      final result = audioProvider.classifyPlaybackError(
        const SocketException('Failed host lookup: cdn.example.com'),
        track,
      );
      expect(result, equals(PlaybackError.network));
    });

    test('classifies TimeoutException as network_error', () {
      final track = createTestTrack(id: '5', previewUrl: 'https://example.com/audio.mp3');
      final result = audioProvider.classifyPlaybackError(
        TimeoutException('Connection timed out'),
        track,
      );
      expect(result, equals(PlaybackError.network));
    });

    test('classifies message with network/connection error string as network_error', () {
      final track = createTestTrack(id: '6', previewUrl: 'https://example.com/audio.mp3');
      final result = audioProvider.classifyPlaybackError(
        Exception('HttpException: Connection reset by peer'),
        track,
      );
      expect(result, equals(PlaybackError.network));
    });

    test('classifies format/codec/demux errors as format_unsupported', () {
      final track = createTestTrack(id: '7', previewUrl: 'https://example.com/audio.mp3');
      
      expect(
        audioProvider.classifyPlaybackError(
          Exception('MediaCodecVideoRenderer / audio codec unsupported'),
          track,
        ),
        equals(PlaybackError.formatUnsupported),
      );

      expect(
        audioProvider.classifyPlaybackError(
          Exception('UnrecognizedInputFormatException: None of the available extractors could read the stream'),
          track,
        ),
        equals(PlaybackError.formatUnsupported),
      );
    });

    test('classifies unhandled generic error as fallback playback_error', () {
      final track = createTestTrack(id: '8', previewUrl: 'https://example.com/audio.mp3');
      final result = audioProvider.classifyPlaybackError(
        Exception('Unexpected state encountered'),
        track,
      );
      expect(result, equals(PlaybackError.generic));
    });
  });

  group('Localized Playback Error Strings Tests', () {
    test('provides distinct messages for each language', () {
      for (final lang in AppLanguage.values) {
        final strings = AppStrings.of(lang);

        expect(strings.playbackError.isNotEmpty, isTrue);
        expect(strings.playbackNoPreview.isNotEmpty, isTrue);
        expect(strings.playbackNetworkError.isNotEmpty, isTrue);
        expect(strings.playbackFormatUnsupported.isNotEmpty, isTrue);

        // Ensure each differentiated message is distinct within the same locale
        final messages = {
          strings.playbackError,
          strings.playbackNoPreview,
          strings.playbackNetworkError,
          strings.playbackFormatUnsupported,
        };
        expect(messages.length, equals(4),
            reason: 'All error messages in ${lang.code} should be distinct');
      }
    });

    test('validates Spanish strings', () {
      final es = AppStrings.of(AppLanguage.es);
      expect(es.playbackNoPreview, contains('vista previa'));
      expect(es.playbackNetworkError, contains('conexión'));
      expect(es.playbackFormatUnsupported, contains('no compatible'));
    });

    test('validates English strings', () {
      final en = AppStrings.of(AppLanguage.en);
      expect(en.playbackNoPreview, contains('preview is unavailable'));
      expect(en.playbackNetworkError, contains('Network error'));
      expect(en.playbackFormatUnsupported, contains('not supported'));
    });

    test('validates Japanese strings', () {
      final ja = AppStrings.of(AppLanguage.ja);
      expect(ja.playbackNoPreview, contains('プレビュー'));
      expect(ja.playbackNetworkError, contains('ネットワーク'));
      expect(ja.playbackFormatUnsupported, contains('サポートされていない'));
    });
  });
}
