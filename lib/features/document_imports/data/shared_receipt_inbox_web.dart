import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import '../domain/shared_receipt.dart';

class NativeSharedReceiptInbox implements SharedReceiptInbox {
  @override
  Stream<Either<Failure, SharedReceipt?>> watch() => Stream.value(const Right(null));
  @override
  Future<void> setSession(String? uid, int? generation, {bool resetting = false}) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Either<Failure, Unit>> dismiss(String id) async => const Right(unit);
}
