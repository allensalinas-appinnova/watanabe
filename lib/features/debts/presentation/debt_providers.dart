import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection.dart';
import '../domain/debt_repository.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) => getIt<DebtRepository>());
