import 'package:flutter/material.dart';

import '../../domain/entities/financial_operation.dart';

IconData operationTypeIcon(OperationType type) => switch (type) {
  OperationType.income => Icons.south_west,
  OperationType.expense || OperationType.expenseRefund => Icons.north_east,
  OperationType.transfer => Icons.swap_horiz,
  OperationType.debtAdjustment ||
  OperationType.unallocatedDebtPayment => Icons.credit_score_outlined,
};
