# Privacy data inventory

This internal inventory describes product data practices and is not a substitute for a published privacy notice or legal review.

## App installation registry

For registered (non-anonymous) accounts, LumioMoney keeps a random, app-generated installation ID in local app preferences. The ID is not derived from hardware, an advertising identifier, an IP address, or the phone model. On a signed-in session, the app sends the ID and broad platform (`android`, `ios`, or `web`) to an authenticated server command. Firebase Auth supplies the user ID; the client cannot select another owner.

Each user-owned installation record contains the installation ID, platform, creation timestamp, last-seen timestamp, and an expiry timestamp. The server refreshes last-seen no more than once per 24 hours. Firestore TTL is configured for the `devices` collection group on `expiresAt`; records expire 90 days after last activity. TTL deletion is asynchronous, so expired records may remain briefly in storage, although the app excludes records older than 90 days from its active count. The records support aggregate product-usage understanding and do not enforce access, pricing, or device limits.

Users can remove an installation record in Settings → My devices. This removes only the registry entry; it does not revoke authentication credentials, remotely sign out the installation, or provide a security guarantee. If the app is used again, it can create the entry again. Guest-only sessions are not registered; linking a credential to a guest session starts registration for that same Firebase UID.

## Operational safeguards

- No full IP, phone model, advertising ID, email, or financial data is added to the installation record.
- Registry writes are server-only; users can read their own device records.
- Registration failure does not block sign-in or financial functionality.

## Planning follow-up choices

User-owned `planningFollowUps` records retain the planned source references,
original month, completion/dismissal/snooze state, optional reminder date,
version, data generation and timestamp. Command receipts preserve retry
identity and the normalized result. These records support the user's planning
controls; they are not analytics events and contain no account credentials.
Only the owner can read follow-up states; server commands control writes and
receipt access. Data reset recursively removes both collections. A snoozed
notification is scheduled locally after synchronization; no expense push
messages or new notification permissions are introduced.

## Internal administration portal

The private Firebase Hosting portal is restricted by server-verified Google
identity and an operator record. Its callables return an allowlisted subset of
Firebase Auth metadata, profile/onboarding state, and installation metadata;
they do not read or return accounts, operations, budgets, categories, balances,
or debt records. Portal lookups record the operator UID, action, optional target
UID, timestamp, and a 180-day expiry. Daily operational aggregates include
registered Auth users, profiles, onboarding completion, and active installation
platform/version distributions; operator and explicitly configured test UIDs
are excluded. Aggregate records expire after 400 days. These internal records
are inaccessible to app clients through Firestore rules. The portal is
diagnostic only and does not suspend users, revoke sessions, or change data.
- Retention is 90 days after the last registered activity, subject to asynchronous Firestore TTL processing.

## Receipt processing, optional identifiers and resource accounting

Users may store an institution name/country, an account suffix, and linked debit-card names/last four digits. Full account/card numbers, PIN, CVV and banking credentials are not requested. These references and receipt proposals are financial-user data and are removed by financial reset.

A registered user explicitly sends an image/PDF to server-side Google Vertex AI for one expense suggestion. The source itself may contain personal or financial information; the app explains cloud processing before transmission. It does not execute document instructions or links. Operational logs and analytics must exclude receipt contents, descriptions, filenames, extracted amounts and banking references. [Receipt imports](document-imports.md) describes review, cloud consent, private drafts and immutable attachment access.

Unconfirmed sources expire after 24 hours and are removed by hourly cleanup. Confirmed receipts remain until the user removes the attachment or resets financial data. Removing a receipt does not erase its financial movement. Local private drafts are isolated by UID/generation, retained through recoverable failures and cleared on discard/reset; expired or obsolete drafts are rejected on recovery. Signing out prevents access from another account but does not transfer a draft.

Resource accounting is retained outside the financial reset tree to support abuse prevention, operational diagnosis and future product capacity decisions. It records UID-attributed technical units, occupied bytes, server-observed storage time, failures and versioned cost estimates. Detailed events/reservations expire after 90 days; aggregate usage/cost records expire after 400 days; active object records remain while needed to account for stored files. Financial reset does not reset resource quotas. Google Cloud Billing export is stored in a private BigQuery dataset; reconciliation filters LumioMoney and does not infer that missing per-user cost is zero.

The administrative portal has audited access to usage and storage metadata, not receipt contents or financial details through the resource module. A public privacy notice and store disclosure must reflect this processing before consumer distribution; this technical inventory is not itself that public notice.
