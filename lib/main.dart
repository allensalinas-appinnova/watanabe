import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/environment/app_environment.dart';
import 'core/di/injection.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/firebase_observability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.fromDartDefine();
  final useEmulators = const bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  environment.validate(useEmulators: useEmulators, isRelease: kReleaseMode);
  await FirebaseBootstrap.initialize(
    environment,
    useEmulators: useEmulators,
    emulatorHost: const String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    ),
  );
  FirebaseObservability(environment).installErrorHandlers();
  await configureDependencies();

  runApp(const ProviderScope(child: PersonalFinanceApp()));
}
