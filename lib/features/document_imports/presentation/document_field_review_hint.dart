import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/document_import.dart';

class DocumentFieldReviewHint extends StatelessWidget {
  const DocumentFieldReviewHint({
    required this.field,
    required this.status,
    this.detail,
    super.key,
  });

  final DocumentReviewField field;
  final DocumentReviewStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = switch (status) {
      DocumentReviewStatus.suggested => l.documentFieldSuggested,
      DocumentReviewStatus.needsReview => l.documentFieldNeedsReview,
      DocumentReviewStatus.userProvided => l.documentFieldUserProvided,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              status == DocumentReviewStatus.needsReview
                  ? Icons.info_outline
                  : status == DocumentReviewStatus.userProvided
                  ? Icons.edit_outlined
                  : Icons.auto_awesome_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              detail == null ? label : '$label · $detail',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
