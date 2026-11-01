# Resource accounting and storage

The resource ledger is separate from financial data and is not a subscription system. No price or access decision uses the installation count in this delivery.

## Ownership, periods and quota

`resourceUsage/{uid}` stores occupied/reserved bytes and operational status. Subcollections `events`, `periods`, `analysisReservations`, `objects`, `costs` and `costDays` hold idempotent events, UTC aggregates, reservations, object generations and cost estimates. Only server identities access this tree; user access goes through `getResourceUsage`, and administrators use audited `adminResourceUsage`.

Default policy at `servicePolicies/documentImports`:

| Capability | Default |
| --- | --- |
| Analysis units | 5/day and 20/month, UTC |
| Retained attachments | 100,000,000 bytes |
| Temporary reservations plus occupied files | Two files and 20,000,000 bytes |
| Images | 5,000,000 bytes |
| PDFs | 10,000,000 bytes, three pages |

Quota is reserved transactionally across devices. Unsupported but successfully analyzed documents consume a unit. Technical failures refund it once; a retried import does not consume another unit after success. Provider attempts remain in technical accounting. Financial reset removes neither quotas nor cost history. UTC renewal instants are displayed in device-local time.

## Measurement boundaries

| Resource | Observation | Precision and limits |
| --- | --- | --- |
| AI | Reported input, output, cached and reasoning tokens; each explicit attempt, duration and outcome | Reported usage is measured. Failed calls may have unknown token/cost consumption; no assumed zero |
| Storage capacity | Object generation ledger, reservations, upload/delete events, daily inventory | Occupancy and transitions are server observed. Duplicate/out-of-order delivery cannot restore a deleted generation |
| Storage time | Integral of bytes between observed object transitions | Observation times can differ from provider billing times; reconciled with export |
| Downloads/transfers | App-served bytes, source reads and upload bytes | These are not exact provider-billed egress units |
| Functions | Entered authenticated callable attempts, elapsed time, failures | CPU, memory, platform retries, unauthenticated/shared work are not fully attributable |
| Firestore | Server transaction document lookups, query results and committed write calls; batched client server-result counts | Partial and estimated for billing. Failed transaction attempts count reads but not committed writes. Direct reference writes, listener billing and index scans are not fully covered |

Never use advisory client observations as quota authority or as exact invoiced reads. The app batches observations once per minute and preserves batch IDs after lost responses. Uninstrumented work remains explicitly unknown/shared.

`resourceTariffs` contains versioned USD/unit rates by service, model, region and effective interval. AI estimates use uncached input plus cached input and response-plus-reasoning output. Missing/expired tariffs or unreported units yield `pending`, not zero. `knownSubtotalUsd` is separate from a complete total. The initial 3.8 Flash tariff expires on 2027-01-01; rates must be reviewed before then.

## Jobs and retention

`cleanupDocumentImports` runs hourly: release abandoned analysis leases, remove expired 24-hour proposals and retry attachment deletion. `reconcileResourceUsage` runs daily at 04:00 UTC: inventory objects, reconcile absent/orphan files, integrate storage time, estimate current/previous-month costs, and compare Cloud Billing service totals.

Detailed events, completed reservations and deleted-object tombstones expire after 90 days. Period/cost aggregates expire after 400 days using Firestore TTL, which is asynchronous. Active object ledger entries remain while files exist. Global tariff/policy records remain operational configuration. The private BigQuery billing export uses 400-day partition expiration; the table itself does not expire, so recent exports remain available as older partitions age out.

Cloud Billing standard export is enabled for account BA_Innovation_Labs into `lumiomoney.lumio_billing`. Export can include other projects billed to the same account, but the reconciliation query always filters `project.id = lumiomoney`. It caps each query at 1 GB scanned and reads seven days. Provider data can arrive later; `billing-export-awaiting-data` is a pending status rather than an empty successful reconciliation.

The portal displays usage, limits, bytes, attempt/failure units, cost coverage, inventory freshness and per-service provider totals versus known user subtotals. Differences include shared resources, credits and missing measurements; they are not automatically charged to users. The portal cannot view receipt contents or financial records through this feature.

## Rollout and recovery

1. Provision Storage, Vertex AI, App Check, private billing dataset and dedicated runtime roles with the reviewed scripts under `functions/tool`.
2. Keep `servicePolicies/documentImports.enabled = false` while qualifying.
3. Run `bash tool/run_document_tests.sh`, the relevant financial suites, `bash tool/run_document_e2e.sh`, Flutter analysis/tests and mobile/portal builds.
4. Deploy affected callables, object triggers, jobs, Firestore/Storage rules and declared indexes before the compatible client. Preserve existing Cloud Run IAM exception scopes; report an organization-policy block rather than silently widening it.
5. Validate authenticated access and App Check. Enable the policy only after server/client qualification. Setting `enabled=false` later stops new preparation/analysis, while operations and retained attachment read/delete remain available.
6. Watch pending reservations, deletion retries, inventory differences, failed attempts and billing freshness. Do not repair financial data from the console.

Dedicated runtime accounts: `lumio-documents` has Firestore user, Vertex user and bucket object access; `lumio-resource-jobs` has Firestore, bucket access, BigQuery job permission and read-only access to the billing dataset. Neither requires project Owner/Editor or a public bucket.
