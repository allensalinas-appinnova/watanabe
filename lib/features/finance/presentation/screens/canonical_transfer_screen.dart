import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/repositories/canonical_finance_repository.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalTransferScreen extends ConsumerStatefulWidget {
  const CanonicalTransferScreen({super.key});
  @override
  ConsumerState<CanonicalTransferScreen> createState() => _CanonicalTransferScreenState();
}

class _CanonicalTransferScreenState extends ConsumerState<CanonicalTransferScreen> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String? source;
  String? destination;
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Inicia sesión')));
    final accounts =
        ref.watch(canonicalAccountsProvider(user.id)).valueOrNull ?? const <FinanceAccount>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir dinero')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: source,
            decoration: const InputDecoration(labelText: 'Cuenta origen'),
            items: accounts
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.name} (${item.currency})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => source = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: destination,
            decoration: const InputDecoration(labelText: 'Cuenta destino'),
            items: accounts
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.name} (${item.currency})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => destination = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Nota opcional'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : () => _save(user.id, accounts),
            child: saving
                ? const CircularProgressIndicator()
                : const Text('Confirmar transferencia'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String userId, List<FinanceAccount> accounts) async {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    FinanceAccount? from;
    FinanceAccount? to;
    for (final account in accounts) {
      if (account.id == source) from = account;
      if (account.id == destination) to = account;
    }
    if (value == null ||
        value <= 0 ||
        from == null ||
        to == null ||
        source == destination ||
        from.currency != to.currency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona cuentas distintas con la misma moneda y un monto válido.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(canonicalActionsProvider)
          .createTransfer(
            userId,
            TransferDraft(
              amountMinor: (value * 100).round(),
              currency: from.currency,
              sourceAccountId: source!,
              destinationAccountId: destination!,
              occurredAt: DateTime.now().toUtc(),
              monthKey: _currentMonthKey(),
              description: note.text,
              idempotencyKey: '${DateTime.now().microsecondsSinceEpoch}_transfer',
            ),
          );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }
}
