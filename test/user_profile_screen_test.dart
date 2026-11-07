import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_environment.dart';
import 'package:tsuki_tunes_mobile/domain/entities/public_profile.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/profile_repository.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/app_router.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/routes.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/user_profile_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/profile_controller.dart';

import 'helpers/test_scope.dart';

class _Repo implements ProfileRepository {
  @override
  Future<PublicProfile?> getProfile(String uid) async => null;
  @override
  Stream<PublicProfile?> watchProfile(String uid) => const Stream.empty();
  @override
  Future<void> saveMyProfile(PublicProfile profile) async {}
}

ProfileController _mine() => ProfileController(
      repository: _Repo(),
      changes: ChangeNotifier(),
      uid: () => 'me',
      displayName: () => 'Nico',
      photoUrl: () => null,
      maskId: () => null,
      libraryLoaded: () => true,
      listenedTrackArtists: () => [
        ['Tool'],
        ['Tool'],
        ['SOAD'],
      ],
      albumsCompleted: () => 1,
      knownArtists: () => const [],
    );

void main() {
  testWidgets('your profile shows your numbers, top artists and the switch', (tester) async {
    final controller = _mine();
    await tester.pumpWidget(TestScope(
      overrides: [profileControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: UserProfileScreen(uid: 'me')),
    ));
    await tester.pump();

    expect(find.text('Nico'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // songs
    expect(find.text('Tool'), findsOneWidget);
    expect(find.text('2 canciones'), findsOneWidget);
    expect(find.text('PERFIL PÚBLICO'), findsOneWidget);
    expect(find.text('Solo tú y tus Lazos lo ven'), findsOneWidget);
    // Private: nothing to share yet.
    final share = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(share.onPressed, isNull);
  });

  testWidgets('someone else\'s private profile says so', (tester) async {
    final controller = _mine();
    await tester.pumpWidget(TestScope(
      overrides: [
        profileControllerProvider.overrideWith((ref) => controller),
        publicProfileProvider('other').overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: UserProfileScreen(uid: 'other')),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('ESTE PERFIL ES PRIVADO O NO EXISTE'), findsOneWidget);
  });

  test('profile links lead to the profile route', () {
    expect(const UserProfileRoute(uid: 'u1').location, '/user/u1');
    expect(deepLinkLocation(Uri.parse('$deepLinkScheme://user/u1')), '/user/u1');
  });
}
