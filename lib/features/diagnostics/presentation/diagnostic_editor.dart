import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../../core/utils/request_id.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../domain/diagnostic_engine.dart';
import '../domain/diagnostic_record.dart';
import '../domain/diagnostic_repository.dart';
import 'diagnostic_providers.dart';

class DiagnosticSetupScreen extends ConsumerStatefulWidget {
  const DiagnosticSetupScreen({super.key});
  @override
  ConsumerState<DiagnosticSetupScreen> createState() => _DiagnosticSetupScreenState();
}

class _DiagnosticSetupScreenState extends ConsumerState<DiagnosticSetupScreen> {
  String kind = 'context';
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).diagnosticText;
    final uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context).sessionExpired)));
    }
    final state = ref.watch(diagnosticSnapshotProvider(uid));
    return Scaffold(
      appBar: AppBar(title: Text(t('configure'))),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(diagnosticSnapshotProvider(uid)),
            child: Text(t('retry')),
          ),
        ),
        data: (snapshot) {
          final records = snapshot.input.records.where((r) => r.kind == kind).toList();
          void edit(DiagnosticRecord? record) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DiagnosticRecordEditor(
                uid: uid,
                snapshot: snapshot,
                record:
                    record ??
                    DiagnosticRecord(kind == 'context' ? 'context' : newRequestId(), kind, {}),
              ),
            ),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t('formHint')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('diagnostic_kind'),
                initialValue: kind,
                isExpanded: true,
                items: [
                  for (final k in diagnosticSchemas.keys)
                    DropdownMenuItem(value: k, child: Text(t(k))),
                ],
                onChanged: (k) => setState(() => kind = k!),
              ),
              const SizedBox(height: 16),
              for (final record in records)
                Card(
                  child: ListTile(
                    title: Text(
                      record.text('name').isNotEmpty
                          ? record.text('name')
                          : record.text('accountId').isNotEmpty
                          ? snapshot.input.accounts
                                    .where((a) => a.id == record.text('accountId'))
                                    .firstOrNull
                                    ?.name ??
                                record.text('accountId')
                          : t(kind),
                    ),
                    subtitle: Text(
                      record.kind == 'context'
                          ? record.text('verifiedOn')
                          : [
                              record.text('currency'),
                              record.text('referenceDate'),
                            ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => edit(record),
                  ),
                ),
              if (kind != 'context' || records.isEmpty)
                FilledButton.icon(
                  key: const ValueKey('diagnostic_add'),
                  onPressed: () => edit(null),
                  icon: const Icon(Icons.add),
                  label: Text(t('add')),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DiagnosticRecordEditor extends ConsumerStatefulWidget {
  const DiagnosticRecordEditor({
    super.key,
    required this.uid,
    required this.snapshot,
    required this.record,
  });
  final String uid;
  final DiagnosticSnapshot snapshot;
  final DiagnosticRecord record;
  @override
  ConsumerState<DiagnosticRecordEditor> createState() => _DiagnosticRecordEditorState();
}

class _DiagnosticRecordEditorState extends ConsumerState<DiagnosticRecordEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final choices = <String, String>{};
  bool saving = false, failed = false;
  String? payloadDigest, requestId;
  int? generation;
  @override
  void initState() {
    super.initState();
    generation = ref.read(canonicalUserProfileProvider(widget.uid)).valueOrNull?.dataGeneration;
    for (final field in diagnosticSchemas[widget.record.kind]!) {
      final value = widget.record.values[field.key];
      if ([
        DiagnosticFieldKind.choice,
        DiagnosticFieldKind.account,
        DiagnosticFieldKind.category,
        DiagnosticFieldKind.goal,
        DiagnosticFieldKind.plan,
      ].contains(field.kind)) {
        if (value is String) choices[field.key] = value;
      } else {
        var text = value?.toString() ?? '';
        if ((field.kind == DiagnosticFieldKind.money || field.key == 'rateBps') && value is num) {
          final currency = widget.record.text('currency');
          text = field.key != 'rateBps' && MoneyParser.zeroDecimalCurrencies.contains(currency)
              ? value.toInt().toString()
              : (value / 100).toStringAsFixed(2);
        }
        if (field.key == 'currency' && text.isEmpty) {
          text =
              ref.read(canonicalUserProfileProvider(widget.uid)).valueOrNull?.defaultCurrency ??
              'COP';
        }
        controllers[field.key] = TextEditingController(text: text);
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool delete = false}) async {
    if (saving || (!delete && !form.currentState!.validate())) return;
    if (generation == null ||
        ref.read(authSessionProvider).valueOrNull?.id != widget.uid ||
        ref.read(canonicalUserProfileProvider(widget.uid)).valueOrNull?.dataGeneration !=
            generation) {
      setState(() => failed = true);
      return;
    }
    final values = <String, Object>{...choices};
    try {
      final currency = controllers['currency']?.text.trim().toUpperCase() ?? '';
      for (final field in diagnosticSchemas[widget.record.kind]!) {
        if (!controllers.containsKey(field.key)) continue;
        final text = controllers[field.key]!.text.trim();
        if (text.isEmpty) continue;
        values[field.key] = switch (field.kind) {
          DiagnosticFieldKind.integer =>
            field.key == 'rateBps'
                ? MoneyParser.minorUnits(text, 'USD', allowZero: true)
                : int.parse(text),
          DiagnosticFieldKind.money => MoneyParser.minorUnits(text, currency, allowZero: true),
          _ => field.key == 'currency' ? text.toUpperCase() : text,
        };
      }
    } on FormatException {
      setState(() => failed = true);
      return;
    }
    final digest = jsonEncode([delete, values]);
    if (payloadDigest != digest) {
      payloadDigest = digest;
      requestId = newRequestId();
    }
    setState(() {
      saving = true;
      failed = false;
    });
    final result = await ref
        .read(diagnosticRepositoryProvider)
        .save(
          widget.uid,
          DiagnosticRecord(widget.record.id, widget.record.kind, values),
          generation: generation!,
          revision: widget.snapshot.revisions[widget.record.id] ?? 0,
          requestId: requestId!,
          delete: delete,
        );
    if (!mounted) return;
    setState(() {
      saving = false;
      failed = result.isLeft();
    });
    if (result.isRight() && ref.read(authSessionProvider).valueOrNull?.id == widget.uid) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).diagnosticText;
    if (ref.watch(authSessionProvider).valueOrNull?.id != widget.uid) {
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context).sessionExpired)));
    }
    generation ??= ref.watch(canonicalUserProfileProvider(widget.uid)).valueOrNull?.dataGeneration;
    final categories = ref.watch(canonicalCategoriesProvider(widget.uid)).valueOrNull ?? [];
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: Text(t(widget.record.kind))),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failed)
                  Text(
                    t('saveError'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (saving) const LinearProgressIndicator(),
                FilledButton(
                  key: const ValueKey('diagnostic_save'),
                  onPressed: saving ? null : save,
                  child: Text(t('save')),
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t('formHint')),
              const SizedBox(height: 16),
              for (final field in diagnosticSchemas[widget.record.kind]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Builder(
                    builder: (context) {
                      if (field.key == 'itemId') return const SizedBox.shrink();
                      if (field.key == 'budgetId') {
                        final plans = widget.snapshot.input.plan
                            .where((p) => p.budgetId != null)
                            .toList();
                        final selected = plans
                            .where(
                              (p) =>
                                  p.budgetId == controllers['budgetId']?.text &&
                                  p.itemId == controllers['itemId']?.text,
                            )
                            .firstOrNull;
                        return DropdownButtonFormField<String>(
                          initialValue: selected?.id ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(labelText: t('itemOverride')),
                          items: [
                            DropdownMenuItem(value: '', child: Text(t('unknown'))),
                            for (final p in plans)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${diagnosticDate(p.date)} · ${p.title}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (id) {
                                  final selected = plans.where((p) => p.id == id).firstOrNull;
                                  controllers['budgetId']!.text = selected?.budgetId ?? '';
                                  controllers['itemId']!.text = selected?.itemId ?? '';
                                },
                        );
                      }
                      final options = <String, String>{};
                      switch (field.kind) {
                        case DiagnosticFieldKind.choice:
                          for (final v in field.options) {
                            options[v] = t(v);
                          }
                        case DiagnosticFieldKind.account:
                          for (final a in widget.snapshot.input.accounts.where(
                            (a) => a.status == 'active',
                          )) {
                            options[a.id] = '${a.name} · ${a.currency}';
                          }
                        case DiagnosticFieldKind.category:
                          for (final c in categories.where((c) => !c.isArchived)) {
                            options[c.id] = c.customName ?? c.id;
                          }
                        case DiagnosticFieldKind.goal:
                          for (final g in widget.snapshot.input.records.where(
                            (r) => r.kind == 'goal',
                          )) {
                            options[g.id] = '${g.text('name')} · ${g.text('currency')}';
                          }
                        case DiagnosticFieldKind.plan:
                          for (final p in widget.snapshot.input.plan) {
                            options[p.id] = '${diagnosticDate(p.date)} · ${p.title}';
                          }
                        default:
                          break;
                      }
                      if ([
                        DiagnosticFieldKind.choice,
                        DiagnosticFieldKind.account,
                        DiagnosticFieldKind.category,
                        DiagnosticFieldKind.goal,
                        DiagnosticFieldKind.plan,
                      ].contains(field.kind)) {
                        if (choices[field.key] != null &&
                            !options.containsKey(choices[field.key])) {
                          options[choices[field.key]!] = choices[field.key]!;
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey('diagnostic_${field.key}'),
                          initialValue: choices[field.key] ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '${t(field.key)}${field.required ? ' *' : ''}',
                          ),
                          items: [
                            DropdownMenuItem(value: '', child: Text(t('unknown'))),
                            for (final e in options.entries)
                              DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (v) {
                                  if (v == null || v.isEmpty) {
                                    choices.remove(field.key);
                                  } else {
                                    choices[field.key] = v;
                                  }
                                },
                          validator: (v) =>
                              field.required && (v == null || v.isEmpty) ? t('invalid') : null,
                        );
                      }
                      return TextFormField(
                        key: ValueKey('diagnostic_${field.key}'),
                        controller: controllers[field.key],
                        enabled: !saving,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: '${t(field.key)}${field.required ? ' *' : ''}',
                          counterText: '',
                        ),
                        keyboardType:
                            [
                              DiagnosticFieldKind.integer,
                              DiagnosticFieldKind.money,
                            ].contains(field.kind)
                            ? const TextInputType.numberWithOptions(decimal: true)
                            : TextInputType.text,
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return field.required ? t('invalid') : null;
                          if (field.kind == DiagnosticFieldKind.integer &&
                              field.key != 'rateBps' &&
                              (int.tryParse(text) == null ||
                                  int.parse(text) < 0 ||
                                  (field.key.endsWith('Percent') && int.parse(text) > 100))) {
                            return t('invalid');
                          }
                          if (field.kind == DiagnosticFieldKind.date &&
                              (DateTime.tryParse(text) == null ||
                                  diagnosticDate(DateTime.parse(text)) != text)) {
                            return t('invalid');
                          }
                          if (field.kind == DiagnosticFieldKind.months &&
                              text
                                  .split(',')
                                  .any(
                                    (m) => !RegExp(r'^20\d{2}-(0[1-9]|1[0-2])$').hasMatch(m.trim()),
                                  )) {
                            return t('invalid');
                          }
                          if (field.key == 'currency' &&
                              !RegExp(r'^[A-Z]{3}$').hasMatch(text.toUpperCase())) {
                            return t('invalid');
                          }
                          if (field.kind == DiagnosticFieldKind.money || field.key == 'rateBps') {
                            try {
                              MoneyParser.minorUnits(
                                text,
                                field.key == 'rateBps'
                                    ? 'USD'
                                    : controllers['currency']?.text.trim().toUpperCase() ?? '',
                                allowZero: true,
                              );
                            } on FormatException {
                              return t('invalid');
                            }
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ),
              if (widget.snapshot.revisions.containsKey(widget.record.id))
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(t('confirmDelete')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(t('cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(t('delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) await save(delete: true);
                        },
                  child: Text(t('delete')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDiagnosticAssociation(
  BuildContext context,
  WidgetRef ref,
  String uid,
  DiagnosticSnapshot snapshot,
  String operationId,
) async {
  final operation = snapshot.input.operations.where((o) => o.id == operationId).firstOrNull;
  if (operation == null) return;
  final t = AppLocalizations.of(context).diagnosticText;
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(t('linkMovement')),
      children: [
        for (final entry in snapshot.input.plan.where(
          (p) =>
              p.budgetId != null &&
              p.currency == operation.currency &&
              p.categoryId == operation.categoryId &&
              p.monthKey == operation.monthKey &&
              p.kind.name == operation.type.name,
        ))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.id),
            child: Text(
              '${entry.title} · ${CurrencyFormatter.formatMinor(entry.plannedMinor, entry.currency, locale: Localizations.localeOf(context).toString())}',
            ),
          ),
        SimpleDialogOption(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
      ],
    ),
  );
  if (selected == null ||
      !context.mounted ||
      ref.read(authSessionProvider).valueOrNull?.id != uid) {
    return;
  }
  final entry = snapshot.input.plan.firstWhere((p) => p.id == selected);
  final result = await ref
      .read(canonicalFinanceRepositoryProvider)
      .setOperationBudgetItem(
        uid,
        operationId: operationId,
        expectedRevision: operation.revision,
        budgetId: entry.budgetId,
        itemId: entry.itemId,
        requestId: newRequestId(),
      );
  if (!context.mounted) return;
  if (result.isLeft()) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('saveError'))));
  }
}
