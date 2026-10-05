import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/category_budget.dart';
import '../../domain/entities/finance_account.dart';
import '../../domain/entities/receipt_attachment.dart';
import '../../domain/repositories/finance_repository.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_components.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categories = const ['Food', 'Housing', 'Transport', 'Entertainment', 'Other'];
  String _category = 'Food';
  String? _accountId;
  DateTime _date = DateTime.now();
  ReceiptAttachment? _receiptAttachment;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(authSessionProvider)
      .when(
        loading: () => const Scaffold(body: FinanceLoadingView()),
        error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
        data: (user) {
          if (user == null) return const Scaffold(body: FinanceLoadingView());
          return ref
              .watch(financeAccountsProvider(user.id))
              .when(
                loading: () => const Scaffold(body: FinanceLoadingView()),
                error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                data: (accounts) => ref
                    .watch(financeBudgetsProvider(user.id))
                    .when(
                      loading: () => const Scaffold(body: FinanceLoadingView()),
                      error: (error, stackTrace) => Scaffold(body: FinanceErrorView(error: error)),
                      data: (budgets) => _buildForm(context, user.id, accounts, budgets),
                    ),
              );
        },
      );

  Widget _buildForm(
    BuildContext context,
    String userId,
    List<FinanceAccount> accounts,
    List<CategoryBudget> budgets,
  ) {
    if (_accountId == null && accounts.isNotEmpty) _accountId = accounts.first.id;
    final availableCategories = <String>{
      ..._categories,
      ...budgets.map((budget) => budget.category),
    }.toList();
    if (!availableCategories.contains(_category)) _category = availableCategories.first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('expense_form_screen'),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  FinanceHeader(
                    eyebrow: 'New transaction',
                    title: 'Add expense',
                    actionIcon: Icons.close,
                    actionTooltip: 'Close',
                    onAction: () => context.pop(),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FormLabel('AMOUNT'),
                          TextFormField(
                            key: const ValueKey('expense_amount_field'),
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                            decoration: const InputDecoration(
                              prefixText: r'$ ',
                              hintText: '0.00',
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.line),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.blueDark),
                              ),
                            ),
                            validator: (value) {
                              final amount = double.tryParse((value ?? '').replaceAll(',', ''));
                              return amount == null || amount <= 0
                                  ? 'Enter an amount greater than zero.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const _FormLabel('DESCRIPTION'),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const ValueKey('expense_description_field'),
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              hintText: 'What did you spend on?',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty ? 'Add a description.' : null,
                          ),
                          const SizedBox(height: 18),
                          const _FormLabel('CATEGORY'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('expense_category_field'),
                            initialValue: _category,
                            decoration: _selectorDecoration(),
                            items: [
                              for (final category in availableCategories)
                                DropdownMenuItem(value: category, child: Text(category)),
                            ],
                            onChanged: (value) => setState(() => _category = value ?? _category),
                          ),
                          const SizedBox(height: 18),
                          const _FormLabel('ACCOUNT'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('expense_account_field'),
                            initialValue: accounts.any((account) => account.id == _accountId)
                                ? _accountId
                                : null,
                            decoration: _selectorDecoration(),
                            hint: Text(
                              accounts.isEmpty ? 'Create an account first' : 'Choose an account',
                            ),
                            items: [
                              for (final account in accounts)
                                DropdownMenuItem(value: account.id, child: Text(account.name)),
                            ],
                            onChanged: (value) => setState(() => _accountId = value),
                            validator: (value) => value == null ? 'Choose an account.' : null,
                          ),
                          const SizedBox(height: 18),
                          const _FormLabel('DATE'),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            key: const ValueKey('expense_date_button'),
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_outlined, size: 17),
                            label: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                MaterialLocalizations.of(context).formatMediumDate(_date),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.navy,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.tonalIcon(
                              key: const ValueKey('expense_receipt_button'),
                              onPressed: _saving ? null : _chooseReceiptImage,
                              icon: Icon(
                                _receiptAttachment == null
                                    ? Icons.add_photo_alternate_outlined
                                    : Icons.check_circle_outline,
                              ),
                              label: Text(
                                _receiptAttachment == null
                                    ? 'Add receipt photo'
                                    : 'Receipt photo attached',
                                key: _receiptAttachment == null
                                    ? null
                                    : const ValueKey('expense_receipt_preview'),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.blueSoft,
                                foregroundColor: AppColors.blueDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const ValueKey('expense_save_button'),
                  onPressed: _saving || accounts.isEmpty ? null : () => _save(userId),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save expense'),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '✨  Smart category suggestions are on',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _selectorDecoration() => const InputDecoration(
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  );

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _chooseReceiptImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              key: const ValueKey('expense_receipt_gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              key: const ValueKey('expense_receipt_camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final attachment = await ref.read(receiptImagePickerProvider).pick(source);
      if (attachment != null && mounted) {
        setState(() => _receiptAttachment = attachment);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach the receipt: $error')),
      );
    }
  }

  Future<void> _save(String userId) async {
    if (!_formKey.currentState!.validate() || _accountId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(saveExpenseProvider)
          .call(
            userId,
            ExpenseDraft(
              description: _descriptionController.text.trim(),
              category: _category,
              accountId: _accountId!,
              amount: double.parse(_amountController.text.replaceAll(',', '')),
              date: _date,
              receiptAttachment: _receiptAttachment,
            ),
          );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    ),
  );
}
