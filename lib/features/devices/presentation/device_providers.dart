import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../../core/error/failure.dart';
import '../domain/device_installation.dart';
import '../domain/device_registry_repository.dart';

final deviceRegistryRepositoryProvider = Provider<DeviceRegistryRepository>((ref) => getIt());

final deviceInstallationsProvider = StreamProvider.family<List<DeviceInstallation>, String>(
  (ref, userId) => ref.watch(deviceRegistryRepositoryProvider).watchInstallations(userId),
);

class DeviceRemovalController extends Notifier<Failure?> {
  @override
  Failure? build() => null;

  Future<bool> remove(String installationId) async {
    state = null;
    final result = await ref
        .read(deviceRegistryRepositoryProvider)
        .removeInstallation(installationId);
    return result.match((failure) {
      state = failure;
      return false;
    }, (_) => true);
  }
}

final deviceRemovalControllerProvider = NotifierProvider<DeviceRemovalController, Failure?>(
  DeviceRemovalController.new,
);
