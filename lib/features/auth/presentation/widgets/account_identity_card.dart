import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/auth_user.dart';

class AccountIdentityCard extends StatelessWidget {
  const AccountIdentityCard({
    super.key,
    required this.user,
    this.onSaveAccount,
    this.onAccessMethods,
  });

  final AuthUser user;
  final VoidCallback? onSaveAccount;
  final VoidCallback? onAccessMethods;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = user.email?.trim();
    return Card(
      key: const ValueKey('settings_account_identity'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.isAnonymous ? l.settingsGuestSession : l.settingsYourAccount,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (user.isAnonymous) ...[
              Text(l.guestAccountHint),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('settings_secure_guest_account'),
                onPressed: onSaveAccount,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(l.guestSaveAccount),
              ),
            ] else ...[
              SelectableText(
                email == null || email.isEmpty ? l.settingsEmailUnavailable : email,
                key: const ValueKey('settings_account_email'),
                style: theme.textTheme.bodyLarge,
              ),
              if (user.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  l.settingsMemberSince(
                    DateFormat.yMMMMd(l.localeName).format(user.createdAt!.toLocal()),
                  ),
                  key: const ValueKey('settings_account_since'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              TextButton.icon(
                key: const ValueKey('settings_access_methods'),
                onPressed: onAccessMethods,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(l.accessMethodsTitle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
