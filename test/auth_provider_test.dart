import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaving guest mode deletes the guest\'s unreachable playlists', () async {
    SharedPreferences.setMockInitialValues({
      'guest_device_uid': 'guest_abc',
      'guest_mode_active': true,
      'tsuki_cached_playlists_guest_abc': '[{"name":"Mix"}]',
      'tsuki_cached_playlists_someone_else': '[]',
    });
    // Firebase isn't available in tests; the provider still restores the
    // guest session from prefs.
    final auth = AuthProvider();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(auth.isGuest, isTrue);

    await auth.logout();

    final prefs = await SharedPreferences.getInstance();
    expect(auth.isGuest, isFalse);
    expect(prefs.getString('tsuki_cached_playlists_guest_abc'), isNull);
    expect(prefs.getString('guest_device_uid'), isNull);
    expect(prefs.getString('tsuki_cached_playlists_someone_else'), '[]');
  });
}
