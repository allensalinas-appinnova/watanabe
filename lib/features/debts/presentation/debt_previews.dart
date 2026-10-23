import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/domain/entities/finance_account.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import 'debt_form_screen.dart';

@Preview(name: 'Debt creation', group: 'Debts', size: Size(390, 844))
@Preview(
  name: 'Debt creation compact enlarged',
  group: 'Debts',
  size: Size(320, 844),
  textScaleFactor: 2,
)
Widget debtCreationPreview() => ProviderScope(
  overrides: [
    authSessionProvider.overrideWith(
      (ref) => Stream.value(const AuthUser(id: 'preview', isAnonymous: true)),
    ),
    canonicalAccountsProvider(
      'preview',
    ).overrideWith((ref) => Stream.value(const <FinanceAccount>[])),
    canonicalCategoriesProvider('preview').overrideWith((ref) => Stream.value(const [])),
    canonicalUserProfileProvider('preview').overrideWith((ref) => Stream.value(null)),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const DebtFormScreen(),
  ),
);
