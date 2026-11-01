import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';

class AccountIdentityFields extends StatelessWidget {
  const AccountIdentityFields({
    super.key,
    required this.institution,
    required this.country,
    required this.ending,
    this.enabled = true,
    this.showEnding = true,
  });
  final TextEditingController institution;
  final TextEditingController country;
  final TextEditingController ending;
  final bool enabled;
  final bool showEnding;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l.accountIdentityTitle),
      subtitle: Text(l.accountIdentityOptional),
      children: [
        TextFormField(
          controller: institution,
          enabled: enabled,
          maxLength: 120,
          decoration: InputDecoration(labelText: l.accountInstitution),
        ),
        TextFormField(
          controller: country,
          enabled: enabled,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.accountInstitutionCountry, hintText: 'CO'),
          validator: (v) =>
              v == null || v.trim().isEmpty || RegExp(r'^[A-Za-z]{2}$').hasMatch(v.trim())
              ? null
              : l.identityInvalid,
        ),
        if (showEnding)
          TextFormField(
            controller: ending,
            enabled: enabled,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.accountNumberEnding),
            validator: (v) =>
                v == null || v.isEmpty || RegExp(r'^\d{4}$').hasMatch(v) ? null : l.identityInvalid,
          ),
      ],
    );
  }
}
