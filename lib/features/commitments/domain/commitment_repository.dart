import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import 'debt_commitment.dart';

abstract interface class CommitmentRepository {
  Stream<List<DebtCommitment>> watch(String userId);
  Stream<List<DebtCommitmentPaymentLink>> watchPayments(String userId);
  Future<Either<Failure, String>> execute(String userId, Map<String, Object?> command);
}

class DebtCommitmentPaymentLink {
  const DebtCommitmentPaymentLink({
    required this.paymentId,
    required this.commitmentId,
    required this.monthKey,
    required this.amountMinor,
  });
  final String paymentId;
  final String commitmentId;
  final String monthKey;
  final int amountMinor;
}
