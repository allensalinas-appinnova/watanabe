import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/async_value_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/canonical_finance_providers.dart';

class CanonicalOnboardingScreen extends ConsumerStatefulWidget {
  const CanonicalOnboardingScreen({super.key});
  @override
  ConsumerState<CanonicalOnboardingScreen> createState() => _CanonicalOnboardingScreenState();
}

class _CanonicalOnboardingScreenState extends ConsumerState<CanonicalOnboardingScreen> {
  final account = TextEditingController();
  String locale = 'es';
  String country = 'CO';
  String currency = 'COP';
  bool saving = false;
  @override
  void dispose() {
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configura ClearBudget')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const LinearProgressIndicator(value: .5),
        const SizedBox(height: 24),
        const Text(
          'Personaliza tu experiencia',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: locale,
          decoration: const InputDecoration(labelText: 'Idioma'),
          items: const [
            DropdownMenuItem(value: 'es', child: Text('Español')),
            DropdownMenuItem(value: 'pt', child: Text('Português')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) => setState(() => locale = value ?? 'es'),
        ),
        DropdownButtonFormField<String>(
          initialValue: country,
          decoration: const InputDecoration(labelText: 'País'),
          items: const [
            DropdownMenuItem(value: 'CO', child: Text('Colombia')),
            DropdownMenuItem(value: 'MX', child: Text('México')),
            DropdownMenuItem(value: 'BR', child: Text('Brasil')),
          ],
          onChanged: (value) => setState(() => country = value ?? 'CO'),
        ),
        DropdownButtonFormField<String>(
          initialValue: currency,
          decoration: const InputDecoration(labelText: 'Moneda base'),
          items: const [
            DropdownMenuItem(value: 'COP', child: Text('COP')),
            DropdownMenuItem(value: 'MXN', child: Text('MXN')),
            DropdownMenuItem(value: 'BRL', child: Text('BRL')),
          ],
          onChanged: (value) => setState(() => currency = value ?? 'COP'),
        ),
        TextField(
          controller: account,
          decoration: const InputDecoration(labelText: 'Nombre de tu primera cuenta'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: saving ? null : _complete,
          child: saving ? const CircularProgressIndicator() : const Text('Comenzar'),
        ),
      ],
    ),
  );

  Future<void> _complete() async {
    final user = ref.read(authSessionProvider).valueOrNull;
    if (user == null || account.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await ref.read(bootstrapCategoriesProvider)(
        user.id,
        locale: locale,
        countryCode: country,
        timeZone: 'America/Bogota',
        defaultCurrency: currency,
      );
      await ref
          .read(canonicalActionsProvider)
          .createAccount(
            user.id,
            name: account.text,
            type: 'cash',
            currency: currency,
            openingBalanceMinor: 0,
          );
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
