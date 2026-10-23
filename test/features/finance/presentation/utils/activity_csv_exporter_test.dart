import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_account.dart';
import 'package:personal_finance/features/finance/domain/entities/finance_category.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';
import 'package:personal_finance/features/finance/presentation/utils/activity_csv_exporter.dart';

void main() {
  const labels = ActivityCsvLabels(
    date: 'Fecha y hora',
    type: 'Tipo',
    description: 'Descripción',
    account: 'Cuenta(s)',
    category: 'Categoría',
    amount: 'Importe',
    currency: 'Moneda',
    status: 'Estado',
    income: 'Ingreso',
    expense: 'Gasto',
    transfer: 'Transferencia',
    pending: 'Pendiente',
    confirmed: 'Confirmado',
    rejected: 'Rechazado',
    unknownAccount: 'Cuenta desconocida',
    unknownCategory: 'Categoría desconocida',
    paymentType: 'Tipo de pago',
    cardPayment: 'Pago de tarjeta',
    loanPayment: 'Pago de crédito',
  );

  FinancialOperation operation({
    required String id,
    required OperationType type,
    required OperationStatus status,
    required String description,
    int amount = 1250,
    String? accountId,
    String? categoryId,
    String? sourceAccountId,
    String? destinationAccountId,
  }) => FinancialOperation(
    id: id,
    type: type,
    amountMinor: amount,
    currency: 'COP',
    monthKey: '2026-10',
    occurredAt: DateTime(2026, 10, 21, 14, 5),
    status: status,
    idempotencyKey: id,
    description: description,
    accountId: accountId,
    categoryId: categoryId,
    sourceAccountId: sourceAccountId,
    destinationAccountId: destinationAccountId,
  );

  test('exports pending and transfers, escaping localized text and formulas', () {
    final csv = ActivityCsvExporter.export(
      operations: [
        operation(
          id: 'pending',
          type: OperationType.expense,
          status: OperationStatus.pending,
          description: '=SUM(A1:A2), "mercado"\nmañana',
          accountId: 'cash',
          categoryId: 'food',
        ),
        operation(
          id: 'transfer',
          type: OperationType.transfer,
          status: OperationStatus.confirmed,
          description: 'Mover dinero',
          sourceAccountId: 'cash',
          destinationAccountId: 'bank',
          amount: 900,
        ),
        operation(
          id: 'rejected',
          type: OperationType.income,
          status: OperationStatus.rejected,
          description: 'No exportar',
        ),
      ],
      accounts: const [
        FinanceAccount(id: 'cash', name: 'Efectivo', type: 'cash'),
        FinanceAccount(id: 'bank', name: 'Banco, ahorro', type: 'savings'),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          type: CategoryType.expense,
          customName: 'Comida',
          icon: 'food',
          sortOrder: 0,
          isSystem: true,
          isArchived: false,
        ),
      ],
      labels: labels,
    );

    expect(csv, startsWith('\uFEFF"Fecha y hora","Tipo"'));
    expect(csv, contains('"\'=SUM(A1:A2), ""mercado""\nmañana"'));
    expect(csv, contains('"Efectivo → Banco, ahorro"'));
    expect(csv, contains('"Pendiente"'));
    expect(csv, contains('"Transferencia"'));
    expect(csv, contains('"Tipo de pago"'));
    expect(csv, contains('"","900","COP","Confirmado"'));
    final local = DateTime(2026, 10, 21, 14, 5).toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final offsetLabel =
        '$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    expect(csv, contains('"${local.toIso8601String()}$offsetLabel"'));
    expect(csv, isNot(contains('No exportar')));
  });

  test('returns a valid header-only CSV for an empty result', () {
    final csv = ActivityCsvExporter.export(
      operations: const [],
      accounts: const [],
      categories: const [],
      labels: labels,
    );
    expect(
      csv,
      '\uFEFF"Fecha y hora","Tipo","Descripción","Cuenta(s)","Categoría","Importe","Moneda","Estado","Previous balance","Target balance","Difference","Command","Principal change","Charges change","Reversal of","Tipo de pago"\r\n',
    );
  });

  test('identifies debt payment components without changing their accounting type', () {
    final csv = ActivityCsvExporter.export(
      operations: [
        FinancialOperation(
          id: 'payment',
          type: OperationType.transfer,
          amountMinor: 45000,
          currency: 'COP',
          monthKey: '2026-10',
          occurredAt: DateTime(2026, 10, 21),
          status: OperationStatus.confirmed,
          idempotencyKey: 'payment',
          debtCommandId: 'command-1',
          debtAccountId: 'card',
          debtKind: 'pay',
        ),
      ],
      accounts: const [
        FinanceAccount(id: 'card', name: 'Same name', type: 'creditCard', nature: 'debt'),
      ],
      categories: const [],
      labels: labels,
    );
    expect(csv, contains('"Transferencia"'));
    expect(csv, contains('"Pago de tarjeta"'));
  });
}
