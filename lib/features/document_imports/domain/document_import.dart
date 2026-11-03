import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../../../core/error/failure.dart';

enum DocumentPhase {
  prepared,
  analyzing,
  ready,
  unsupported,
  failed,
  approved,
  discarded,
  expired,
  duplicate,
}

class DocumentFile {
  const DocumentFile({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

enum DocumentReviewField { amount, currency, date, category, account, description }

enum DocumentReviewStatus { suggested, needsReview, userProvided }

class DocumentSuggestion {
  const DocumentSuggestion({
    this.amountMinor,
    this.currency,
    this.date,
    this.description,
    this.categoryId,
    this.accountId,
    this.reviewFields = const {},
  });
  final int? amountMinor;
  final String? currency, description, categoryId, accountId;
  final DateTime? date;
  final Set<DocumentReviewField> reviewFields;

  DocumentReviewStatus statusFor(
    DocumentReviewField field, {
    required bool available,
    required bool userEdited,
  }) {
    if (!available) return DocumentReviewStatus.needsReview;
    if (userEdited) return DocumentReviewStatus.userProvided;
    return reviewFields.contains(field)
        ? DocumentReviewStatus.needsReview
        : DocumentReviewStatus.suggested;
  }
}

enum DocumentAnalysisIssue { serviceBusy, timedOut, failed }

class DocumentImport {
  const DocumentImport({
    required this.id,
    required this.generation,
    required this.version,
    required this.phase,
    this.storagePath,
    this.analysisIssue,
    this.operationId,
    this.suggestion = const DocumentSuggestion(),
  });
  final String id;
  final DocumentAnalysisIssue? analysisIssue;
  final int generation, version;
  final DocumentPhase phase;
  final String? storagePath, operationId;
  final DocumentSuggestion suggestion;
}

class DocumentApproval {
  const DocumentApproval({
    required this.source,
    required this.accountId,
    required this.categoryId,
    required this.currency,
    required this.amountMinor,
    required this.occurredAt,
    required this.monthKey,
    required this.description,
    required this.creditCard,
    this.duplicatesReviewed = false,
  });
  final DocumentImport source;
  final String accountId, categoryId, currency, monthKey, description;
  final int amountMinor;
  final DateTime occurredAt;
  final bool creditCard, duplicatesReviewed;
}

class DocumentDraft {
  const DocumentDraft({
    required this.file,
    required this.importId,
    required this.generation,
    this.review = const {},
  });
  final DocumentFile file;
  final String importId;
  final int generation;
  final Map<String, Object?> review;
}

class PendingDocumentCleanup {
  const PendingDocumentCleanup({required this.importId, required this.generation});
  final String importId;
  final int generation;
}

class UsageSummary {
  const UsageSummary({
    required this.dailyUsed,
    required this.monthlyUsed,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.attachmentBytes,
    required this.attachmentLimit,
    required this.temporaryBytes,
    required this.enabled,
    this.dailyRenewsAt,
    this.monthlyRenewsAt,
  });
  final int dailyUsed,
      monthlyUsed,
      dailyLimit,
      monthlyLimit,
      attachmentBytes,
      attachmentLimit,
      temporaryBytes;
  final DateTime? dailyRenewsAt, monthlyRenewsAt;
  final bool enabled;
}

class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.operationId,
    required this.size,
    required this.contentType,
    required this.generation,
  });
  final String id, operationId, contentType;
  final int size, generation;
}

abstract interface class DocumentImportRepository {
  Future<Either<Failure, DocumentImport>> prepare(DocumentDraft draft);
  Future<Either<Failure, DocumentImport>> analyze(DocumentImport source);
  Stream<DocumentImport?> watch(String uid, String id);
  Future<Either<Failure, String>> approve(DocumentApproval approval);
  Future<Either<Failure, Unit>> discard(String importId, int generation);
  Future<Either<Failure, UsageSummary>> usage();
  Stream<List<DocumentAttachment>> attachments(
    String uid, {
    String? operationId,
    String? attachmentId,
  });
  Future<Either<Failure, DocumentFile>> readAttachment(String id);
  Future<Either<Failure, Unit>> deleteAttachment(DocumentAttachment attachment);
  Future<Either<Failure, DocumentDraft?>> loadDraft(String uid, int generation);
  Future<Either<Failure, Unit>> saveDraft(String uid, DocumentDraft draft);
  Future<Either<Failure, Unit>> replaceDraft(
    String uid,
    String expectedImportId,
    DocumentDraft draft, {
    required bool cleanupPreviousImport,
    required int previousGeneration,
  });
  Future<void> retryPendingCleanup(String uid);
  Future<void> clearDraft(String uid);
}
