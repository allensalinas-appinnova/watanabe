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

### Observed Storage capacity

`storage_capacity.ts::observeStorageCapacity` records an independent checkpoint per object/generation at `resourceUsage/{uid}/storageCapacityMeters/{objectMeterId}`. These records contain observed bytes, bucket, location, actual object storage class and observation timestamps; no receipt contents or filenames are added to cost events. They survive financial reset as technical accounting records. Live checkpoints remain while needed; closed checkpoints expire after 90 days through TTL.

The bucket/location pair comes from deployment-verified `RESOURCE_STORAGE_BUCKET` and `RESOURCE_STORAGE_LOCATION`. The class comes from that object's provider metadata, never the bucket's default class. First observations establish a baseline without valuing earlier time. Later observations emit byte-hour intervals separately for each UTC day/month. A class/location/size change makes the intervening gap pending rather than applying the prior or new tariff to an unknown interval. Missing deletion metadata may reuse the last observed scope when closing a previously metered object.

Object-ledger transactions still own occupied bytes and reservation changes. Capacity observation is a separate idempotent transaction; it never changes quotas, financial records, import state or physical files. A failed observer can retry after the object transition has committed. Concurrent or older observations do not duplicate an interval. Deleted object records cannot reopen a closed meter. Daily inventory closes meters for confirmed deletions; a missing listing entry now requires a direct provider existence check before being treated as deleted, avoiding a race with uploads after the listing snapshot.

Transactions process at most 31 days at once and at most eight chunks per observation; longer outages preserve the checkpoint and resume on a subsequent observation. This bounds transaction writes. Timing is based on server observations, not a claim of exact provider billing seconds or invisible class changes between observations.

New whole-user occupancy-time events are marked `costAggregation=diagnostic-only` and excluded by `estimateUserCosts`; `excludedDiagnosticEvents` records this exclusion. Classified object intervals are priced once. Legacy aggregate events remain unclassified rather than being retroactively priced. `storage_classifiedByteHours` and `storage_unclassifiedByteHours` are separate technical breakdowns; they must not be added to the original whole-user `storage_byteHours` as extra consumption. A classified interval can still lack a matching tariff, for example an unreviewed storage class.

The portal exposes the latest capacity observation timestamp. Positive costs below one millionth USD show a less-than indicator instead of appearing free after rounding. The usage metadata remains visible only through the existing authorized endpoints.

`GCLOUD_PROJECT=lumiomoney node functions/tool/observe_resource_storage.mjs` explicitly observes already-tracked live files using provider metadata. It does not analyze documents, download receipt contents, delete files, repair occupied totals or change quotas. `configure_resource_billing_ttl.mjs --collection-group=storageCapacityMeters --apply` enables expiry of closed checkpoints; the tool permits only the two reviewed technical collection groups, not financial collections.

### Component estimates and attribution

`resource_costs.ts::evaluateUsageEventCost` evaluates each observed component independently. Explicit zero units require no tariff; absent, negative or non-finite measurements remain pending. The latest applicable tariff is used, with a more specific model/region preferred for equal start dates. Conflicting rates with equal precedence remain pending. Only tariff IDs actually used are recorded.

Monthly `costs` and daily `costDays` include known subtotals by billing service, pending reason counts, fully/partially priced event counts, component coverage, update time and `methodVersion: 2`. A complete event total remains null while any component is pending. Neither complete event coverage nor component coverage proves that the entire provider invoice is measured.

Callable observations now distinguish committed document writes from deletes. Empty transaction queries contribute one estimated document read; index-entry reads and direct SDK calls remain outside this observation. These Firestore components are attributed to `firestore`, even when observed during a Functions request. Legacy mixed write counters are not retroactively assumed to be writes. Client advisory read counts remain unpriced.

Firestore pricing uses an explicit `firestoreRegion` on the event, not the callable region. The wrapper stamps this from `RESOURCE_FIRESTORE_LOCATION`. A missing location keeps positive Firestore units pending. The reviewed request-based Functions rate also requires `RESOURCE_FUNCTIONS_BILLING_MODE=request-based`; missing or different modes do not match it. Storage capacity rates require the observed region and object storage class; the default bucket class alone does not prove the class of every retained object.

Request wall duration is not multiplied by assumed CPU/memory allocations. Shared compute remains pending. App-served bytes are not priced as Storage internet egress: operation classes and transfer routes must be verified first. No new live tariffs are installed by the estimator. Unsupported components require reviewed measurements and versioned tariffs before they can be valued.

## Jobs and retention

`cleanupDocumentImports` runs hourly: release abandoned analysis leases, remove expired 24-hour proposals and retry attachment deletion. `reconcileResourceUsage` runs daily at 04:00 UTC: inventory objects, reconcile absent/orphan files, integrate storage time, estimate current/previous-month costs, and compare Cloud Billing service totals.

Detailed events, completed reservations and deleted-object tombstones expire after 90 days. Period/cost aggregates expire after 400 days using Firestore TTL, which is asynchronous. Active object ledger entries remain while files exist. Global tariff/policy records remain operational configuration. The private BigQuery billing export uses 400-day partition expiration; the table itself does not expire, so recent exports remain available as older partitions age out.

Cloud Billing standard export is enabled for account BA_Innovation_Labs into `lumiomoney.lumio_billing`. Export can include other projects billed to the same account, but the reconciliation query always filters `project.id = lumiomoney`. It caps each query at 1 GB scanned and reads seven days. Provider data can arrive later; `billing-export-awaiting-data` is a pending status rather than an empty successful reconciliation.

The portal displays usage, limits, bytes, attempt/failure units, cost coverage, inventory freshness and per-service provider totals versus known user subtotals. Differences include shared resources, credits and missing measurements; they are not automatically charged to users. The portal cannot view receipt contents or financial records through this feature.

`resource_costs.ts::groupBillingRows` groups provider products by UTC day, normalized measured service and currency **before** comparing user subtotals. The query covers the previous seven complete UTC days, excluding today, so a rolling partial day is not compared with a full-day user estimate. For example, Cloud Functions and Cloud Run rows share one Functions comparison, avoiding duplicate attribution. Unknown services remain separate. Non-USD rows use each row's exported `currency_conversion_rate` before aggregation: `(cost + credits) / rate`. Missing, zero or invalid rates keep the comparison pending. If one day/service contains multiple billing currencies, user estimates are not attributed repeatedly to each currency. Credits, including negative net totals, remain in the provider amount. The portal retains both the original currency and the converted USD amount. See [Cloud Billing standard export fields](https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage).

Each reconciliation writes rows under a unique `runId` and publishes that ID only after the run completes. `adminResourceUsage` reads only rows of the published successful run. A query failure or empty export hides previous rows rather than presenting stale values as a fresh comparison. The portal exposes the last successful query time; provider data may still arrive late. Snapshot rows carry a 400-day `expiresAt`; collection-group TTL for `services` must be active before relying on automatic removal. Orphaned rows from interrupted runs are not presented as current data.

### Local qualification and release boundary

The cost changes are client/server implementation, not proof of deployment or of current Cloud Billing export availability. Relevant checks:

- `npm --prefix functions run build` and `npm --prefix admin_portal run build`.
- `node --test functions/test/resource_costs_test.mjs`: zero/missing units, partial costs, tariff versions, service separation and billing grouping.
- `bash tool/run_document_tests.sh`: document imports, persisted daily/monthly estimates, reconciliation snapshots, observations and Firestore/Storage access rules, exclusively in `demo-clearbudget`.
- `node --test admin_portal/test/resource_cost_labels_test.mjs`: readable pending-reason labels and unknown-reason fallback.

The estimator uses configured tariffs; local qualification does not publish Functions/Hosting or write financial data. Verify live export freshness and reviewed tariff coverage separately before treating cost estimates as a monetization input.

### Reviewed configuration (2026-11-02)

A read-only production check confirmed Firestore **Standard, `nam5`**, bucket **`us-central1`, default `STANDARD`**, and request-based billing on the document-import Cloud Run service. BigQuery returned project-filtered billing rows, including Vertex AI, in **COP**. The export includes its own conversion rates; it is no longer awaiting its first data. The deployed reconciliation status still reported `billing-export-awaiting-data` at this check, so export availability must not be confused with a successfully refreshed dashboard.

`resource_tariffs.ts::REVIEWED_RESOURCE_TARIFFS` contains eight candidate versions, effective 2026-11-02 through 2026-12-31 UTC:

| Component | Reviewed USD list rate | Evidence |
| --- | --- | --- |
| Gemini 3.8 Flash global input / output / cached input | 0.75 / 3.75 / 0.075 per million tokens | [Google model pricing](https://cloud.google.com/model-garden/pricing) |
| Firestore Standard NAM5 reads / writes / deletes | 0.06 / 0.18 / 0.02 per 100,000 documents | Cloud Billing Catalog service `EE2C-7FAC-5E08`, SKUs `369B-DC02-4DAB`, `0FD8-FD9E-2D84`, `57BD-FBE3-CB86`, checked via authenticated read-only API |
| Standard Storage us-central1 | 0.000027397 per GiB-hour | [Storage pricing](https://cloud.google.com/storage/pricing); divide by 2^30 for byte-hours |
| Request-based Cloud Run us-central1 | 0.40 per million requests | [Cloud Run pricing](https://cloud.google.com/run/pricing) |

These are gross list-price estimates before shared free tiers, credits, discounts and unobserved overhead. They are not a customer price or an invoice. All versions expire on 2027-01-01 pending a new review; Gemini's published promotional prices end then.

Build Functions, then run the default read-only preflight:

```bash
GCLOUD_PROJECT=lumiomoney node functions/tool/review_resource_tariffs.mjs
```

It checks live topology and existing version IDs and reports the proposed creations. `--apply` is the separate mutation mode: it transactionally creates only absent versions, rejects changed existing versions, and never changes import enablement, quotas, financial data or the billing export destination. It rejects expired review intervals and unexpected topology. Existing tariffs remain intact. `configure_document_policy.mjs` is the historical bootstrap, not the reviewed-rate update tool.

For a repeatable read-only export check, run `GCLOUD_PROJECT=lumiomoney node functions/tool/read_resource_billing.mjs`. It uses the same bounded SQL as the reconciliation job and reports row coverage, currencies, latest usage day and the currently deployed reconciliation status, without reading user financial records or writing estimates. The 2026-11-02 check found 66 grouped provider rows, 61 normalized service/day rows, all in COP with valid exported conversion rates; the latest usage day was 2026-11-01. This is a dated observation, not a guarantee of subsequent freshness.

Publication procedure: apply the reviewed versions, configure runtime metadata on applicable callables, and deploy the estimator, usage endpoints and portal together. The preflight verifies billing mode for `mutatedocumentimport`; verify each other callable's mode before setting `RESOURCE_FUNCTIONS_BILLING_MODE` there, rather than inferring a project-wide mode. Refresh current/previous-month estimates and billing only after those contracts are available. A read-only export check does not perform that refresh. Historical events without their resource-location evidence remain pending; do not backfill it from the Function's location. The execution of this procedure is recorded below.

### Production release verification (2026-11-02)

The configuration above was applied and published after the read-only review:

- Eight reviewed tariff versions were created transactionally; the three historical AI versions remain intact. Repeating the review reports eight unchanged versions and no new creations.
- All 18 affected services were checked as request-based before publication. The ignored project environment file received only `RESOURCE_FIRESTORE_LOCATION=nam5` and `RESOURCE_FUNCTIONS_BILLING_MODE=request-based`; existing configuration was preserved.
- Firebase reported successful updates for the 16 metered callables (`mutateDiagnostic`, `manageDevice`, `mutateOperation`, `mutateDebt`, `mutateDebtCommitment`, `mutatePlanningFollowUp`, `mutateEmailImport`, `listEmailImports`, `mutateBudget`, `adjustAccountBalances`, `resetUserData`, `mutatePaymentInstrument`, `mutateDocumentImport`, `getResourceUsage`, `mutateAttachment`, `submitUsageObservation`), plus `reconcileResourceUsage` and `adminResourceUsage`. All 18 ready revisions were subsequently checked for the two resource metadata values.
- Firestore and Storage rules were released without changing their source. Deployed source hashes matched local SHA-256 values: Firestore `64fad4314ef318de41714ca65c15a5b4bf0a473621af72283049cf708db457f6`; Storage `7f15279d1021024ef2c3e9ddb91376bd054889586271e59c3c6f333eeafe31cf`. Resource, tariff and billing records remain inaccessible to direct client reads/writes.
- Hosting published the updated portal at `https://lumiomoney-admin.web.app/`; HTTP returned 200 and the current asset matched the local build. An existing authorized operator session successfully loaded consumption, the COP/USD reconciliation and the QA account's cost detail, technical units and pending reasons.
- `refresh_resource_costs.mjs` refreshed October/November estimates and billing at `2026-11-02T18:13:39.289Z` (13:13 Bogotá). It deliberately omits inventory/cleanup, so this refresh does not delete attachments or drafts. Two metered users received method-version-2 monthly estimates. The current billing snapshot contains 61 normalized service/day rows, all with exported currency conversion available; `available=true` and `issue=null`.
- Anonymous HTTP probes of `mutateDocumentImport`, `getResourceUsage`, `adminResourceUsage` and `mutateOperation` returned `401 UNAUTHENTICATED`. This proves rejection without a session, not a mobile Auth/App Check success test. The browser check separately confirmed authenticated administrative access.

`GCLOUD_PROJECT=lumiomoney node functions/tool/refresh_resource_costs.mjs` is the explicit write operation for technical cost summaries and billing snapshots only. It does not change user quotas or financial records. The daily scheduled job remains configured; its next scheduled execution was not forced as part of release qualification.

TTL was already active for `events`, `periods`, `analysisReservations`, `costs` and `costDays`. Enabling `services/expiresAt` was requested through `configure_resource_billing_ttl.mjs --apply`; it initially returned `CREATING` and a subsequent read-only check confirmed **`ACTIVE`**. The tool defaults to read-only status and does not resubmit an already-active or creating policy. It changes only `ttl_config`, preserving indexing configuration. Actual expiry deletion remains asynchronous and was not tested by expiring production records.

Release gates passed: Functions build; 33 document/resource tests, two Storage/Firestore import-rule tests and 27 general Firestore-rule tests in `demo-clearbudget`; portal test/build; tool syntax checks; `git diff --check`. No production analysis, financial operation or reset was executed. Unknown costs remain pending, including unmeasured shared compute and historical events without location evidence. No commit/push was performed by this release.

### Storage capacity iteration verification (2026-11-02)

- Added `storage_capacity_test.mjs` to the Emulator suite. Final results: 41 document/resource tests, two import-rule tests and 27 general Firestore-rule tests passed. The new scenarios cover baseline/no backdating, concurrency/replay, UTC/month boundaries, class changes, deletion, long outages, diagnostic exclusion and a real Storage Emulator object absent from an older listing. The rule test explicitly rejects client access to capacity checkpoints. Both portal tests and its production build passed.
- Nine affected Functions were published: `mutateDocumentImport`, `mutateAttachment`, `trackDocumentUpload`, `trackDocumentDelete`, `cleanupDocumentImports`, `reconcileResourceUsage`, `resetUserData`, `getResourceUsage`, `adminResourceUsage`. Firestore/Storage rules were republished without source changes and Hosting published the timestamp/tiny-cost display. A subsequent focused `reconcileResourceUsage` deployment included the inventory race regression fix.
- Production observation found three already-tracked live objects, all accessible through metadata without reading their contents. The first pass established baselines. The second pass produced three classified intervals. Cost refresh reported billing available and a positive known Storage subtotal. Three retained files, 1,598,675 retained bytes and four monthly analysis units were preserved; no financial operation, reset or real AI analysis was executed.
- `storageCapacityMeters/expiresAt` TTL was confirmed `ACTIVE`. Active checkpoints do not have an expiry field; only closed checkpoints become eligible for cleanup. No production records were artificially expired to test deletion.
- Production data and endpoint/hosting checks are distinct from visual QA. The integrated browser was unavailable during this iteration, so no new visual acceptance is claimed. Shared compute, network routes and historical intervals without evidence remain pending.

## Rollout and recovery

1. Provision Storage, Vertex AI, App Check, private billing dataset and dedicated runtime roles with the reviewed scripts under `functions/tool`.
2. Keep `servicePolicies/documentImports.enabled = false` while qualifying.
3. Run `bash tool/run_document_tests.sh`, the relevant financial suites, `bash tool/run_document_e2e.sh`, Flutter analysis/tests and mobile/portal builds.
4. Deploy affected callables, object triggers, jobs, Firestore/Storage rules and declared indexes before the compatible client. Preserve existing Cloud Run IAM exception scopes; report an organization-policy block rather than silently widening it.
5. Validate authenticated access and App Check. Enable the policy only after server/client qualification. Setting `enabled=false` later stops new preparation/analysis, while operations and retained attachment read/delete remain available.
6. Watch pending reservations, deletion retries, inventory differences, failed attempts and billing freshness. Do not repair financial data from the console.

Dedicated runtime accounts: `lumio-documents` has Firestore user, Vertex user and bucket object access; `lumio-resource-jobs` has Firestore, bucket access, BigQuery job permission and read-only access to the billing dataset. Neither requires project Owner/Editor or a public bucket.
