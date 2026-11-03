import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/devices/domain/device_registry_repository.dart';
import 'package:personal_finance/features/devices/presentation/device_registry_lifecycle.dart';

class Registry extends Mock implements DeviceRegistryRepository {}

void main() {
  testWidgets('installation response after unmount never reads a disposed ref', (tester) async {
    final registry = Registry();
    final response = Completer<Either<Failure, void>>();
    when(registry.registerCurrentInstallation).thenAnswer((_) => response.future);
    getIt.registerSingleton<DeviceRegistryRepository>(registry);
    addTearDown(getIt.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(id: 'synthetic-qa', isAnonymous: false),
            ),
          ),
        ],
        child: const DeviceRegistryLifecycle(child: SizedBox()),
      ),
    );
    await tester.pump();
    await tester.pump();
    verify(registry.registerCurrentInstallation).called(1);
    await tester.pumpWidget(const SizedBox());
    response.complete(const Right(null));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
