import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/async_value_extensions.dart';
import '../../../core/utils/request_id.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../finance/presentation/providers/canonical_finance_providers.dart';
import '../domain/payment_instrument.dart';

final paymentInstrumentRepositoryProvider = Provider<PaymentInstrumentRepository>((ref) => getIt());
final paymentInstrumentsProvider =
    StreamProvider.family<List<PaymentInstrument>, ({String uid, String accountId})>(
      (ref, key) => ref.watch(paymentInstrumentRepositoryProvider).watch(key.uid, key.accountId),
    );

class PaymentInstrumentsScreen extends ConsumerWidget {
  const PaymentInstrumentsScreen({super.key, required this.accountId});
  final String accountId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), uid = ref.watch(authSessionProvider).valueOrNull?.id;
    final generation = uid == null
        ? null
        : ref.watch(canonicalUserProfileProvider(uid)).valueOrNull?.dataGeneration;
    return Scaffold(
      appBar: AppBar(title: Text(l.paymentInstruments)),
      floatingActionButton: generation == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/accounts/$accountId/instruments/new'),
              icon: const Icon(Icons.add),
              label: Text(l.instrumentAdd),
            ),
      body: uid == null
          ? Center(child: Text(l.sessionExpired))
          : ref
                .watch(paymentInstrumentsProvider((uid: uid, accountId: accountId)))
                .when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(
                        paymentInstrumentsProvider((uid: uid, accountId: accountId)),
                      ),
                      child: Text(l.retry),
                    ),
                  ),
                  data: (rows) => ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    children: [
                      Text(l.instrumentExplanation),
                      const SizedBox(height: 16),
                      if (rows.where((i) => i.status == 'active').isEmpty) Text(l.instrumentEmpty),
                      for (final i in rows.where((i) => i.status == 'active'))
                        ListTile(
                          leading: const Icon(Icons.credit_card_outlined),
                          title: Text(i.name),
                          subtitle: Text('•••• ${i.lastFour}'),
                          onTap: () =>
                              context.push('/accounts/$accountId/instruments/${i.id}', extra: i),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class PaymentInstrumentEditScreen extends ConsumerStatefulWidget {
  const PaymentInstrumentEditScreen({super.key, required this.accountId, this.initial});
  final String accountId;
  final PaymentInstrument? initial;
  @override
  ConsumerState<PaymentInstrumentEditScreen> createState() => _InstrumentEditState();
}

class _InstrumentEditState extends ConsumerState<PaymentInstrumentEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _ending = TextEditingController(text: widget.initial?.lastFour ?? '');
  InstrumentCommand? _pending;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _ending.dispose();
    super.dispose();
  }

  Future<void> _save(InstrumentAction action) async {
    if (_saving || !_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context), uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null) return;
    final generation = ref.read(canonicalUserProfileProvider(uid)).valueOrNull?.dataGeneration;
    if (generation == null) return;
    final prior = _pending;
    if (prior == null ||
        prior.action != action ||
        prior.name != _name.text.trim() ||
        prior.lastFour != _ending.text) {
      _pending = InstrumentCommand(
        requestId: newRequestId(),
        generation: prior?.generation ?? generation,
        version: widget.initial?.version ?? 0,
        action: action,
        accountId: widget.accountId,
        instrumentId: widget.initial?.id,
        name: _name.text.trim(),
        lastFour: _ending.text,
      );
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(paymentInstrumentRepositoryProvider).execute(_pending!);
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _saving = false;
        _error = l.instrumentSaveFailed;
      }),
      (_) => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.paymentInstruments)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l.instrumentExplanation),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 120,
              decoration: InputDecoration(labelText: l.instrumentName),
              validator: (v) => v == null || v.trim().isEmpty ? l.identityInvalid : null,
            ),
            TextFormField(
              controller: _ending,
              enabled: !_saving,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.instrumentLastFour),
              validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '') ? null : l.identityInvalid,
            ),
            if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () => _save(
                      widget.initial == null ? InstrumentAction.create : InstrumentAction.update,
                    ),
              child: Text(l.save),
            ),
            if (widget.initial != null)
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            scrollable: true,
                            title: Text(l.instrumentRemove),
                            content: Text(l.instrumentRemoveExplanation),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(l.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(l.archive),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) await _save(InstrumentAction.archive);
                      },
                child: Text(l.instrumentRemove),
              ),
          ],
        ),
      ),
    );
  }
}

class PaymentInstrumentEditRoute extends ConsumerWidget {
  const PaymentInstrumentEditRoute({
    super.key,
    required this.accountId,
    required this.instrumentId,
  });
  final String accountId, instrumentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), uid = ref.watch(authSessionProvider).valueOrNull?.id;
    if (uid == null) return Scaffold(body: Center(child: Text(l.sessionExpired)));
    return ref
        .watch(paymentInstrumentsProvider((uid: uid, accountId: accountId)))
        .when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: Text(l.paymentInstruments)),
            body: Center(child: Text(l.genericError)),
          ),
          data: (rows) {
            final item = rows.where((i) => i.id == instrumentId).firstOrNull;
            return item == null
                ? Scaffold(
                    appBar: AppBar(title: Text(l.paymentInstruments)),
                    body: Center(child: Text(l.genericError)),
                  )
                : PaymentInstrumentEditScreen(
                    key: ValueKey(item.id),
                    accountId: accountId,
                    initial: item,
                  );
          },
        );
  }
}
