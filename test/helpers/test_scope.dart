import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';

/// The Riverpod scope a widget test needs: the language without storage
/// (Spanish), plus any [overrides].
class TestScope extends StatelessWidget {
  const TestScope({super.key, this.overrides = const [], required this.child});

  final List<Override> overrides;
  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleProvider()),
          ...overrides,
        ],
        child: child,
      );
}
