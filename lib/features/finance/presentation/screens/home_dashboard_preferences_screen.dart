import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/finance_route_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_value_extensions.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/home_dashboard_preferences.dart';
import '../providers/canonical_finance_providers.dart';

class HomeDashboardPreferencesScreen extends ConsumerStatefulWidget {
  const HomeDashboardPreferencesScreen({super.key});

  @override
  ConsumerState<HomeDashboardPreferencesScreen> createState() =>
      _HomeDashboardPreferencesScreenState();
}

class _HomeDashboardPreferencesScreenState extends ConsumerState<HomeDashboardPreferencesScreen> {
  HomeDashboardPreferences? _draft;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull;
    if (user == null) return Scaffold(body: Center(child: Text(l10n.sessionExpired)));

    final profileState = ref.watch(canonicalUserProfileProvider(user.id));
    final profile = profileState.valueOrNull;
    final preferences =
        _draft ?? profile?.homeDashboardPreferences ?? const HomeDashboardPreferences();
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final budgets = ref.watch(canonicalBudgetsProvider((userId: user.id, monthKey: monthKey)));
    final categories = ref.watch(canonicalCategoriesProvider(user.id));

    ref.listen(canonicalUserProfileProvider(user.id), (previous, next) {
      if (!_saving && !_saveFailed && next.valueOrNull != null) {
        setState(() => _draft = next.valueOrNull!.homeDashboardPreferences);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FinanceRouteHeader(
        title: l10n.homeCustomizeTitle,
        backLabel: l10n.back,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              l10n.homeCustomizeSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (_saving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(l10n.homePreferencesSaving, style: const TextStyle(color: AppColors.muted)),
            ],
            if (_saveFailed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.homePreferencesSaveFailed,
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('home_preferences_retry'),
                  onPressed: () => _save(user.id, preferences),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _section(context, l10n.homeWidgetsSection),
            for (final widget in HomeDashboardWidget.values)
              SwitchListTile.adaptive(
                key: ValueKey('home_widget_${widget.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(_widgetLabel(l10n, widget)),
                value: preferences.shows(widget),
                onChanged: _saving
                    ? null
                    : (value) {
                        final visible = {...preferences.visibleWidgets};
                        if (value) {
                          visible.add(widget.id);
                        } else {
                          visible.remove(widget.id);
                        }
                        _save(user.id, preferences.copyWith(visibleWidgets: visible));
                      },
              ),
            const Divider(height: 28),
            _section(context, l10n.homeBudgetCardsSection),
            budgets.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => Text(l10n.genericError),
              data: (items) {
                final active = items.where((item) => item.status == 'active').toList();
                if (active.isEmpty) return Text(l10n.homeNoBudgetCards);
                return Column(
                  children: [
                    for (final budget in active)
                      SwitchListTile.adaptive(
                        key: ValueKey('home_budget_${budget.categoryId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(_categoryName(categories.valueOrNull ?? const [], budget)),
                        subtitle: Text(budget.currency),
                        value: preferences.showsBudget(budget.categoryId),
                        onChanged: _saving
                            ? null
                            : (visible) {
                                final hidden = {...preferences.hiddenBudgetCategoryIds};
                                if (visible) {
                                  hidden.remove(budget.categoryId);
                                } else {
                                  hidden.add(budget.categoryId);
                                }
                                _save(
                                  user.id,
                                  preferences.copyWith(hiddenBudgetCategoryIds: hidden),
                                );
                              },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  String _widgetLabel(AppLocalizations l10n, HomeDashboardWidget widget) => switch (widget) {
    HomeDashboardWidget.totalBalance => l10n.homeWidgetTotalBalance,
    HomeDashboardWidget.incomeSummary => l10n.homeWidgetIncome,
    HomeDashboardWidget.expenseSummary => l10n.homeWidgetExpense,
    HomeDashboardWidget.expenseBudgetRatio => l10n.homeWidgetExpenseBudget,
    HomeDashboardWidget.incomeBudgetRatio => l10n.homeWidgetIncomeBudget,
    HomeDashboardWidget.recentActivity => l10n.homeWidgetRecentActivity,
    HomeDashboardWidget.coachNextStep => l10n.coachHomeWidget,
  };

  String _categoryName(List<FinanceCategory> categories, Budget budget) {
    for (final category in categories) {
      if (category.id == budget.categoryId) return category.customName ?? category.id;
    }
    return budget.categoryId;
  }

  Future<void> _save(String userId, HomeDashboardPreferences preferences) async {
    setState(() {
      _draft = preferences;
      _saving = true;
      _saveFailed = false;
    });
    final result = await ref
        .read(canonicalFinanceRepositoryProvider)
        .updateHomeDashboardPreferences(userId, preferences);
    if (!mounted) return;
    result.match(
      (_) => setState(() {
        _saving = false;
        _saveFailed = true;
      }),
      (_) => setState(() {
        _saving = false;
        _saveFailed = false;
      }),
    );
  }
}
