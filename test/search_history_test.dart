import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/search_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = MockClient((_) async => http.Response('{"data":[]}', 200));

  test('a query typed in pauses is saved once, as typed in the end', () async {
    SharedPreferences.setMockInitialValues({'search_history': ['metallica']});
    final search = SearchProvider();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await http.runWithClient(() async {
      for (final q in ['bad', 'bad bun', 'bad bunny', 'bad bunn']) {
        await search.search(q);
      }
    }, () => client);

    expect(search.searchHistory, ['bad bunn', 'metallica']);
  });
}
