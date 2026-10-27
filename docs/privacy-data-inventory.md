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
- Retention is 90 days after the last registered activity, subject to asynchronous Firestore TTL processing.
