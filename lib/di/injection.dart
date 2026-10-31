import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The app's service locator. It owns the data and domain layers (data
/// sources, repositories, use cases); Riverpod keeps the UI state and takes
/// those objects from here.
final getIt = GetIt.instance;

/// Registers everything annotated with @injectable / @lazySingleton /
/// @module. Called once in main(), before any widget or provider.
/// After adding or changing an annotation: dart run build_runner build -d
@InjectableInit()
void configureDependencies() => getIt.init();
