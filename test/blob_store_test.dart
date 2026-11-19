import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/blob_store.dart';

// Large values (the play history, the saved queue) live in files of their
// own: Android rewrites the whole SharedPreferences file on every change.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('blobs');
    BlobStore.directory = () async => dir;
  });
  tearDown(() {
    BlobStore.directory = () async => null;
    dir.deleteSync(recursive: true);
  });

  test('kept in a file, not in the preferences', () async {
    SharedPreferences.setMockInitialValues({});
    await BlobStore.write('queue', '[1,2,3]');
    expect(await BlobStore.read('queue'), '[1,2,3]');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('queue'), isFalse);
    expect(dir.listSync().whereType<File>().map((f) => f.path.split('/').last), ['blob_queue.json']);
  });

  test('a value still in the preferences moves out on its first read', () async {
    SharedPreferences.setMockInitialValues({'play_log_v1': '[["a",1]]'});
    expect(await BlobStore.read('play_log_v1'), '[["a",1]]');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('play_log_v1'), isFalse);
    expect(await BlobStore.read('play_log_v1'), '[["a",1]]', reason: 'now from its file');
  });

  test('large JSON is decoded off the UI isolate, small at once, the same either way', () async {
    SharedPreferences.setMockInitialValues({});
    final big = {for (var i = 0; i < 4000; i++) 'album$i': ['t${i}a', 't${i}b']};
    await BlobStore.write('order', jsonEncode(big));
    expect(await BlobStore.readJson('order'), big);
    await BlobStore.write('small', '{"a":1}');
    expect(await BlobStore.readJson('small'), {'a': 1});
    expect(await BlobStore.readJson('missing'), isNull);
  });

  test('writes close together land in order; delete waits for them', () async {
    SharedPreferences.setMockInitialValues({});
    final writes = [for (var i = 0; i < 5; i++) BlobStore.write('q', 'v$i')];
    await Future.wait(writes);
    expect(await BlobStore.read('q'), 'v4');
    BlobStore.write('q', 'late').ignore();
    await BlobStore.delete('q');
    expect(await BlobStore.read('q'), isNull);
  });
}
