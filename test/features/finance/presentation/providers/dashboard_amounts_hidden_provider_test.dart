import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/di/injection.dart';
import 'package:personal_finance/features/finance/presentation/providers/canonical_finance_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists the dashboard privacy preference on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    if (getIt.isRegistered<SharedPreferences>()) {
      await getIt.unregister<SharedPreferences>();
    }
    getIt.registerSingleton<SharedPreferences>(preferences);
    addTearDown(() => getIt.unregister<SharedPreferences>());

    final firstContainer = ProviderContainer();
    expect(firstContainer.read(dashboardAmountsHiddenProvider), isFalse);
    await firstContainer.read(dashboardAmountsHiddenProvider.notifier).setHidden(true);
    firstContainer.dispose();

    final restoredContainer = ProviderContainer();
    addTearDown(restoredContainer.dispose);
    expect(restoredContainer.read(dashboardAmountsHiddenProvider), isTrue);
  });
}
