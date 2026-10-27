import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'device_installation.dart';

abstract interface class DeviceRegistryRepository {
  Stream<List<DeviceInstallation>> watchInstallations(String userId);
  Future<Either<Failure, void>> registerCurrentInstallation();
  Future<Either<Failure, void>> removeInstallation(String installationId);
}
