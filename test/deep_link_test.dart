import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_environment.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/app_router.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/routes.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/session_gate.dart';

/// What Android sends when a link opens the app (the whole URI).
Future<void> openLink(WidgetTester tester, String link) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': link, 'state': null}),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  group('links become app locations', () {
    test('the page is the link host, the id its path', () {
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://album/123')), '/album/123');
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://artist/27')), '/artist/27');
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://playlist/abc')), '/playlist/abc');
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://track/3135556')), '/track/3135556');
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme:///album/9')), '/album/9');
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://artist/27/albums?filter=single')),
          '/artist/27/albums?filter=single');
    });

    test('other links and app locations are left alone', () {
      expect(deepLinkLocation(Uri.parse('/album/123')), isNull);
      expect(deepLinkLocation(Uri.parse('https://deezer.com/album/123')), isNull);
      expect(deepLinkLocation(Uri.parse('com.tsuki.tsukitunesmobile://spotify-callback')), isNull);
    });

    test('they match the typed routes', () {
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://album/123')), const AlbumRoute(id: '123').location);
      expect(deepLinkLocation(Uri.parse('$deepLinkScheme://track/1')), const TrackRoute(id: '1').location);
    });
  });

  group('a link through go_router', () {
    late ValueNotifier<SessionStatus> session;

    GoRouter router() => GoRouter(
          refreshListenable: session,
          redirect: (_, state) => appRedirect(session.value, state.uri),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Text('home'),
              routes: [
                GoRoute(path: 'album/:id', builder: (_, s) => Text('album ${s.pathParameters['id']}')),
              ],
            ),
            GoRoute(path: '/loading', builder: (_, __) => const Text('loading')),
            GoRoute(path: '/login', builder: (_, __) => const Text('login')),
            GoRoute(path: '/onboarding', builder: (_, __) => const Text('tutorial')),
          ],
        );

    setUp(() => session = ValueNotifier(SessionStatus.ready));

    testWidgets('opens the album it names', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await openLink(tester, '$deepLinkScheme://album/123');
      expect(find.text('album 123'), findsOneWidget);
    });

    testWidgets('signed out, it waits behind the login and opens after', (tester) async {
      session.value = SessionStatus.signedOut;
      await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
      await openLink(tester, '$deepLinkScheme://album/123');
      expect(find.text('login'), findsOneWidget);

      session.value = SessionStatus.ready;
      await tester.pumpAndSettle();
      expect(find.text('album 123'), findsOneWidget);
    });
  });
}
