import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/domain/entities/auth_user.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/devices/domain/device_installation.dart';
import 'package:personal_finance/features/devices/domain/device_registry_repository.dart';
import 'package:personal_finance/features/devices/presentation/device_providers.dart';
import 'package:personal_finance/features/devices/presentation/my_devices_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

class _DeviceRegistryRepository implements DeviceRegistryRepository {
  int removals = 0;

  @override
  Future<Either<Failure, void>> registerCurrentInstallation() async => const Right(null);

  @override
  Future<Either<Failure, void>> removeInstallation(String installationId) async {
    removals++;
    return const Right(null);
  }

  @override
  Stream<List<DeviceInstallation>> watchInstallations(String userId) => Stream.value([
    DeviceInstallation(
      id: 'a0f9b5ee-e74a-4c08-8e1f-542d70847d55',
      platform: 'ios',
      createdAt: DateTime(2026, 10, 1),
      lastSeenAt: DateTime(2026, 10, 27, 9),
    ),
  ]);
}

void main() {
  testWidgets('shows active installation count and explains registry removal', (tester) async {
    final repository = _DeviceRegistryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'registered-uid', isAnonymous: false)),
          ),
          deviceRegistryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyDevicesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Instalaciones activas: 1'), findsOneWidget);
    expect(find.text('iPhone o iPad'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No cierra la sesión de forma remota'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();
    expect(repository.removals, 1);
    expect(find.text('Instalación quitada de la lista.'), findsOneWidget);
  });
}
