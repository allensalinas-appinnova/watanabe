import 'dart:async';
import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';
import 'document_import.dart';

class SharedReceipt {
  const SharedReceipt({
    required this.id,
    required this.file,
    required this.receivedAt,
    this.ownerId,
    this.generation,
  });
  final String id;
  final DocumentFile file;
  final DateTime receivedAt;
  final String? ownerId;
  final int? generation;
  bool isExpired(DateTime now) => !now.isBefore(receivedAt.add(const Duration(hours: 24)));
  bool matches(String uid, int value) => ownerId == null || (ownerId == uid && generation == value);
}

abstract interface class SharedReceiptInbox {
  Stream<Either<Failure, SharedReceipt?>> watch();
  Future<void> setSession(String? uid, int? generation, {bool resetting = false});
  Future<void> refresh();
  Future<Either<Failure, Unit>> dismiss(String id);
}

/// Adopts a privately staged receipt; it never uploads, analyzes or posts money.
class AdoptSharedReceipt {
  const AdoptSharedReceipt(this.repository, {required this.now});
  final DocumentImportRepository repository;
  final DateTime Function() now;
  Future<Either<Failure, Unit>> call(
    SharedReceipt receipt, {
    required String uid,
    required int generation,
    bool replace = false,
  }) async {
    if (receipt.isExpired(now()) || !receipt.matches(uid, generation)) {
      return const Left(UnknownFailure('shared-receipt-stale'));
    }
    final loaded = await repository.loadDraft(uid, generation);
    if (loaded.isLeft()) return Left(loaded.getLeft().toNullable()!);
    final old = loaded.getOrElse((_) => null);
    if (old?.importId == receipt.id) return const Right(unit);
    if (old != null) {
      if (!replace) return const Left(UnknownFailure('shared-receipt-conflict'));
      try {
        if (old.review['serverAttempted'] == true) {
          final proposal = await repository
              .watch(uid, old.importId)
              .first
              .timeout(const Duration(seconds: 8));
          if (proposal?.phase != DocumentPhase.approved &&
              proposal?.phase != DocumentPhase.duplicate) {
            final discarded = await repository.discard(old.importId, old.generation);
            if (discarded.isLeft()) return Left(discarded.getLeft().toNullable()!);
          }
        }
      } catch (_) {
        return const Left(UnknownFailure('shared-receipt-retry'));
      }
    }
    return repository.saveDraft(
      uid,
      DocumentDraft(file: receipt.file, importId: receipt.id, generation: generation),
    );
  }
}
