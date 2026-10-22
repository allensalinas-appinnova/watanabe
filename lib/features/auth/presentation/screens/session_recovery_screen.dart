import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/authenticated_route_resolver.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_providers.dart';

class SessionRecoveryScreen extends ConsumerWidget {
  const SessionRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync_problem_outlined, size: 48),
                const SizedBox(height: 16),
                Text(l10n.sessionCheckFailed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId != null) invalidateCachedUserProfile(userId);
                    context.go('/home');
                  },
                  child: Text(l10n.retry),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(l10n.sessionSignOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
