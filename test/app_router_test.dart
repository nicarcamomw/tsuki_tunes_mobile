import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/app_router.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/session_gate.dart';

String? go(SessionStatus status, String location, {bool guest = false}) =>
    sessionRedirect(status, Uri.parse(location), guest: guest);

void main() {
  group('the session picks the first screen', () {
    test('loading waits on the loading screen', () {
      expect(go(SessionStatus.loading, '/'), '/loading');
      expect(go(SessionStatus.loading, '/loading'), isNull);
    });

    test('signed out goes to the login, signed in leaves it', () {
      expect(go(SessionStatus.signedOut, '/'), '/login');
      expect(go(SessionStatus.signedOut, '/login'), isNull);
      expect(go(SessionStatus.ready, '/login'), '/');
      expect(go(SessionStatus.ready, '/loading'), '/');
    });

    test('a new account sees the tutorial first', () {
      expect(go(SessionStatus.onboarding, '/'), '/onboarding');
      expect(go(SessionStatus.onboarding, '/login'), '/onboarding');
      expect(go(SessionStatus.ready, '/onboarding'), '/');
    });

    test('ready stays wherever it is', () {
      expect(go(SessionStatus.ready, '/'), isNull);
      expect(go(SessionStatus.ready, '/album/123'), isNull);
    });

    test('a guest may open the login to sign in for real', () {
      expect(go(SessionStatus.ready, '/login', guest: true), isNull);
      expect(go(SessionStatus.ready, '/login'), '/');
    });
  });

  group('a link survives the way through the gates', () {
    test('it is kept while loading, through the login and the tutorial', () {
      final atLoading = go(SessionStatus.loading, '/album/123')!;
      expect(atLoading, '/loading?from=%2Falbum%2F123');

      final atLogin = go(SessionStatus.signedOut, atLoading)!;
      expect(atLogin, '/login?from=%2Falbum%2F123');

      final atTutorial = go(SessionStatus.onboarding, atLogin)!;
      expect(atTutorial, '/onboarding?from=%2Falbum%2F123');

      expect(go(SessionStatus.ready, atTutorial), '/album/123');
    });

    test('the plain home needs no from', () {
      expect(go(SessionStatus.loading, '/'), '/loading');
      expect(go(SessionStatus.ready, '/loading'), '/');
    });
  });
}
