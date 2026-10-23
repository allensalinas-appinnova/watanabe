import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/financial_operation.dart';
import '../providers/canonical_finance_providers.dart';
import 'canonical_operation_form_screen.dart';

class OperationEditRouteScreen extends ConsumerWidget {
  const OperationEditRouteScreen({required this.operationId, this.initialOperation, super.key});
  final String operationId;
  final FinancialOperation? initialOperation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialOperation != null) {
      return CanonicalOperationFormScreen(initialOperation: initialOperation);
    }
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.sessionExpired)));
    }
    final request = (userId: uid, operationId: operationId);
    final result = ref.watch(canonicalOperationByIdProvider(request));
    return result.when(
      loading: () => Scaffold(
        appBar: FinanceRouteHeader(
          title: l10n.operationEditTitle,
          backLabel: l10n.back,
          onBack: () => popOrGo(context, '/activity'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          _error(context, l10n, () => ref.invalidate(canonicalOperationByIdProvider(request))),
      data: (operation) => operation == null
          ? _error(context, l10n, () => ref.invalidate(canonicalOperationByIdProvider(request)))
          : CanonicalOperationFormScreen(initialOperation: operation),
    );
  }

  Widget _error(BuildContext context, AppLocalizations l10n, VoidCallback retry) => Scaffold(
    appBar: FinanceRouteHeader(
      title: l10n.operationEditTitle,
      backLabel: l10n.back,
      onBack: () => popOrGo(context, '/activity'),
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.genericError),
          TextButton(onPressed: retry, child: Text(l10n.retry)),
        ],
      ),
    ),
  );
}
