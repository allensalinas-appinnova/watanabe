import '../domain/document_import.dart';

DocumentImport mapDocumentImport(String id, Map<String, dynamic> data) {
  final e = data['extraction'] is Map
      ? Map<String, dynamic>.from(data['extraction'] as Map)
      : <String, dynamic>{};
  return DocumentImport(
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
      date: DateTime.tryParse(e['date'] as String? ?? ''),
      description: e['description'] as String? ?? e['merchant'] as String?,
      categoryId: e['categoryId'] as String?,
      accountId: e['accountId'] as String?,
    ),
  );
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
