import '../domain/document_import.dart';

DocumentImport mapDocumentImport(String id, Map<String, dynamic> data) {
  final e = data['extraction'] is Map
      ? Map<String, dynamic>.from(data['extraction'] as Map)
      : <String, dynamic>{};
  return DocumentImport(
    analysisIssue: data['status'] != 'failed'
        ? null
        : switch (data['issue']) {
            'document-service-busy' => DocumentAnalysisIssue.serviceBusy,
            'document-analysis-timeout' => DocumentAnalysisIssue.timedOut,
            'document-analysis-failed' => DocumentAnalysisIssue.failed,
            _ => null,
          },
    id: data['importId'] as String? ?? id,
    generation: (data['dataGeneration'] as num? ?? 0).toInt(),
    version: (data['version'] as num? ?? 0).toInt(),
    phase: DocumentPhase.values.firstWhere(
      (v) => v.name == data['status'],
      orElse: () => DocumentPhase.failed,
    ),
    storagePath: data['storagePath'] as String?,
    operationId: data['operationId'] as String?,
    suggestion: DocumentSuggestion(
      amountMinor: (e['amountMinor'] as num?)?.toInt(),
      currency: e['currency'] as String?,
      date: _reviewDate(e['date']),
      description: e['description'] as String? ?? e['merchant'] as String?,
      categoryId: e['categoryId'] as String?,
      accountId: e['accountId'] as String?,
      reviewFields: Set.unmodifiable(
        e['warnings'] is List
            ? (e['warnings'] as List)
                  .map((warning) => _reviewFields[warning])
                  .whereType<DocumentReviewField>()
            : const <DocumentReviewField>[],
      ),
    ),
  );
}

const _reviewFields = {
  'amount-review': DocumentReviewField.amount,
  'currency-review': DocumentReviewField.currency,
  'date-review': DocumentReviewField.date,
  'category-review': DocumentReviewField.category,
  'account-review': DocumentReviewField.account,
};

DateTime? _reviewDate(Object? raw) {
  if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
  final date = DateTime.tryParse(raw);
  if (date == null ||
      date.year < 2000 ||
      date.year > 2100 ||
      !date.toIso8601String().startsWith(raw)) {
    return null;
  }
  return date;
}

UsageSummary mapUsage(Map<String, dynamic> data) {
  final p = Map<String, dynamic>.from(data['policy'] as Map? ?? {});
  return UsageSummary(
    dailyUsed: (data['dailyUsed'] as num? ?? 0).toInt(),
    monthlyUsed: (data['monthlyUsed'] as num? ?? 0).toInt(),
    dailyLimit: (p['dailyAnalyses'] as num? ?? 5).toInt(),
    monthlyLimit: (p['monthlyAnalyses'] as num? ?? 20).toInt(),
    attachmentBytes: (data['attachmentBytes'] as num? ?? 0).toInt(),
    attachmentLimit: (p['attachmentBytes'] as num? ?? 100000000).toInt(),
    temporaryBytes: (data['temporaryBytes'] as num? ?? 0).toInt(),
    enabled: p['enabled'] == true,
    dailyRenewsAt: DateTime.tryParse(data['dailyRenewsAt'] as String? ?? ''),
    monthlyRenewsAt: DateTime.tryParse(data['monthlyRenewsAt'] as String? ?? ''),
  );
}
