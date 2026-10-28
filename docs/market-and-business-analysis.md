---
title: Latin America market and business analysis
summary: Updated market evidence, debt-and-coaching positioning, proposed free and paid offers, Colombia pricing tests, unit economics and store-launch decision gates.
---

# Latin America market and business analysis

Updated and external sources accessed: **2026-10-28**. Owner: Founder/Product.
Repository baseline: `3a7176844092647ca255e1f5c8817e3a87892fb2`, clean before
this documentation update. Audience: founder, product, engineering and growth.

**Business recommendation:** build a trusted financial routine for people managing
accounts, cards and loan payments; sell better planning and understanding of their
next decisions. Do not position LumioMoney as another transaction notebook or sell
the number of devices as its main benefit. The current implementation is a much
stronger foundation than the October 4 prototype, but monetization is unvalidated.

This page replaces the October 4 commercial analysis. Implementation statements
come from current code; external facts have linked primary sources. LumioMoney's
prices, packaging, segments, budgets and targets below are **proposals**, not
approved prices or measured results. No acquisition, retention, revenue or
willingness-to-pay dataset was supplied or found in the reviewed repository.
This review did not access store consoles, production user records or billing
dashboards, run the app, or requalify deployed services.

Read with [functional scope](functional-scope.md), [operation integrity](operation-commands.md),
[debts](debts.md), [Coach](coach.md) and [privacy inventory](privacy-data-inventory.md).
The [store audit](store-readiness-audit.md) is explicitly historical. Parts of the
[implementation backlog](implementation-backlog.md) and README still describe
old debt flags or completed work as future work. Use code and dated feature
contracts to establish present behavior; those older documents are not release
approval. This update changes only this business analysis.

## 1. The business to build

Proposed initial customer: a person with regular income, more than one place where
they keep money, and at least one card or loan, who struggles to coordinate
monthly payments and understand what remains after commitments. Recruit by those
behaviors rather than assuming an age, income band or app-use frequency.

The job to solve is: **“Quiero organizar mis gastos y cuotas, saber qué debo
revisar y terminar el mes sin perder el control de mi dinero.”**

The product should answer four questions:

1. Where is my money, and are these records current?
2. What have I committed to pay, and what remains unpaid?
3. Did my spending and payments follow my plan?
4. What is the next useful action I can take?

This creates a repeatable loop: **record → plan → review → decide**. Debt payments
supply a concrete recurring problem; Coach helps turn records into a habit.
People using a spreadsheet or competitor must experience less effort or a better
decision to switch. Neither feature proves demand by itself.

Proposed launch copy: **“Organiza tu dinero, tus cuotas y tu siguiente paso.”**
The stronger promise **“Sabe cuánto puedes gastar hasta tu próximo ingreso”**
must wait for a tested cash-flow projection. Today's balance and monthly budget
percentages do not establish that amount. Do not claim automatic bank connections,
automatic amortization, AI advice or guaranteed savings.

## 2. Current product and commercial gaps

“Implemented” means present in this checkout, not universally qualified on devices
or approved for stores. Evidence locators identify the relevant behavior.

| Capability and evidence | Current boundary | Business implication |
| --- | --- | --- |
| Navigation: `lib/core/routing/app_router.dart`, `StatefulShellRoute.indexedStack` | Home, Activity, Accounts, Plan and Coach exist | Supports management and a routine, beyond tracking |
| Money, budgets and export: `CanonicalFinanceRepository`, `ActivityReport.fromOperations` | Income/expense, transfers, budgets, separate currency totals and filtered CSV exist | Essential trust and portability; ordinary CRUD is weak premium differentiation |
| Financial commands: `executeOperationCommand`, local outbox sync | Transactions and idempotent retries exist; rules cutoff is published, while compatible client distribution/adoption remain pending in the dated operation contract | Complete the client rollout and verify balances before charging |
| Debt: `executeDebtCommand`, `executeDebtCommitmentCommand`, `DebtCommitmentOccurrence` | Cards, loans, monthly commitments and later allocation of unallocated payments; no automatic interest/amortization | A credible product wedge; qualify the full journey and comprehension |
| Coach: `CoachRoutine`, `CoachRepository` | Daily/weekly routines and local mobile reminders; no conversational adviser | A useful foundation; advanced interpretation is additional product work |
| Guest continuity: `FirebaseAuthRemoteDataSource.linkEmailPassword` and `linkGoogle` | Credential linking uses the current session identity; conflicts need handling | Reach value before registration, then protect the account before purchase |
| Installations: `executeDeviceRegistryCommand`, `DeviceRegistryLifecycle` | Random IDs, daily activity refresh and 90-day window for registered accounts; no access limits | Measurement, not physical-device counts, concurrent sessions or willingness to pay |
| Operations: `FirebaseObservability.allowedEventNames`, `getAdminOverview` | Selected creation/sync events and a read-only portal exist; no commercial funnel or revenue cohorts | Extend narrowly for activation, retention, purchases and costs |
| Gmail: `parseBankEmail`, `docs/email-imports.md` | Parser/approval groundwork only; no connected mailbox search/mobile import flow | Exclude from the paid launch promise |
| Commerce and deletion: `pubspec.yaml`, `AuthRepository`, `resetUserData` | No purchase SDK/entitlement lifecycle or end-user Auth-account deletion flow found; reset preserves Auth | Billing and account deletion are separate work before a paid store launch |

Evidence paths: `lib/features/finance/domain/`, `lib/features/auth/`,
`lib/features/commitments/domain/`, `lib/features/coach/domain/`,
`lib/features/devices/`, `lib/core/firebase/firebase_observability.dart`, and
`functions/src/{operation_commands,debt_commands,debt_commitments,device_registry,admin_portal}.ts`.
Relevant tests include `integration_test/debt_commitment_flow_test.dart`,
`integration_test/guest_account_upgrade_test.dart`,
`functions/test/operation_commands_test.mjs` and the Coach tests under `test/`.
Their presence is evidence of coverage intent; this review did not rerun them or
turn repository test results into production acceptance.

## 3. Market opportunity and geographic focus

Colombia's SFC/Banca de las Oportunidades report for **2025**, published on
**August 24, 2026**, reports 37.9 million adults with a deposit product and
33.5 million with an active deposit product. Credit-card penetration is 23.9%
and consumer-credit penetration 19%. These credit populations overlap; do not
add them to estimate unique customers. The supply-side figures establish a
relevant context, not demand for a budgeting subscription.
[Official RIF 2025 release](https://www.superfinanciera.gov.co/publicaciones/10116222/reporte-de-inclusion-financiera-2025-avances-en-depositos-credito-cobertura-y-transacciones/).

The opportunity is coordination across products and routines. Whether people will
maintain manual records, trust the calculations and pay remains an interview/beta
question. No reliable local market share or paid-app market size was established.

The previously approved direction was **Latin America from launch**. Retain that
regional ambition and existing es/en/pt support. The new recommendation is to
**concentrate the first commercial validation cohort in Colombia**, then expand
one country at a time. This proposed change in sequencing needs founder approval;
it does not change store availability or application configuration.

| Segment | Proposed role | What to validate |
| --- | --- | --- |
| Regular-income users with cards/loans and fragmented records | First paid cohort in Colombia | Recurring planning pain, manual-entry tolerance and benefit of weekly review |
| Variable-income users | Second discovery cohort | Whether uncertainty requires a different planning method before the app helps |
| Shared households | Later opportunity | Demand for separate people/permissions; another installation of one UID is not household collaboration |
| Financial educators and communities | Recruitment/distribution partners | Retained users and real payers, without partner access to financial records |
| Microbusinesses, investors, lenders and people seeking a new loan | Outside the first offer | Different workflows and obligations; avoid widening the product around them |

Size the business from the bottom up. A serviceable market requires the
intersection of a reachable audience, compatible devices/payment methods,
coordination pain, sustained use and willingness to pay; it is currently unknown.
Do not multiply all banked adults by a subscription price. Use 10 independent
first purchases, then 100 active subscriptions, as learning milestones. A later
1,000-subscriber objective needs observed acquisition, renewal and support
capacity; it is not a forecast or a percentage of a claimed TAM.

Mexico and Brazil each need separate pricing, product-pattern, language, support
and policy assessment. Portuguese alone does not validate the Brazilian business.
Preserve separate currency totals; local-currency display is not FX accounting.

## 4. Competition and switching costs

These are public supplier/store offers accessed on the research date. Features
are supplier claims, not hands-on quality scores. Country, platform, taxes and
promotions can change the price. No checkout was completed.

| Product | Verified public offer | Consequence for LumioMoney |
| --- | --- | --- |
| Money Manager / Realbyte | Colombian iOS listing shows COP 11,900/month and COP 94,900/year for subscription items; its description identifies the subscription as Data Sync Service. Also describes manual tracking, budgets and export. [Colombia App Store](https://apps.apple.com/co/app/registro-contable-gastos/id560481810) | A direct local price anchor. Distinguish sync subscriptions from its separate remove-ads app; Android prices were not verified |
| Spendee | Premium USD 5.99/month or 35.99/year; Plus USD 1.99/month or 14.99/year; Basic free, with one cash wallet and one budget. Country prices may differ. [Official pricing](https://www.spendee.com/pricing) | A low-priced freemium alternative; wallets, charts and category limits alone are weak differentiation |
| Wallet / BudgetBakers | Free manual tier and monthly/annual/lifetime Premium; advertises planned payments, reports and bank sync. Purchase prices are shown in-app; Colombia prices were not verified. [Product](https://budgetbakers.com/en/products/wallet/), [Premium](https://support.budgetbakers.com/hc/en-us/articles/7151349344018-Everything-about-Premium) | Planning/reminders already exist elsewhere. An advertised bank count does not establish coverage of a Colombian product |
| YNAB | USD 14.99/month or 109/year plus applicable tax; 34-day direct trial; method, debt planning and sharing. Direct import lists selected US/Canada/UK/EU banks. [Official pricing](https://www.ynab.com/pricing) | A method can support premium pricing; this does not establish Colombian demand |
| Organizze / Brazil | Manual R$35/month or R$199.90/year; connected R$45/month or R$399.90/year, with connection/refresh limits. [Official plans](https://ajuda.organizze.com.br/hc/pt-br/articles/5661263190035-Conhe%C3%A7a-nossos-pre%C3%A7os-e-assinaturas) | Local routines and automation matter; connectivity is a costed product |
| Mobills / Brazil | Official offer lists R$199.90/year upfront and R$42.90/month in-app; installment pricing differs. Accounts, cards and planning form part of the offer. [Official offer](https://lp2.mobills.com.br/gerenciador-financeiro) | Regional incumbents already package broad management; avoid competing by feature count |

Other substitutes are spreadsheets, notes, bank apps and doing nothing. Ask users
to demonstrate them, including the effort of keeping records current and migrating
history. A zero purchase price does not mean zero switching cost.

**Differentiation hypothesis:** clear debt-payment semantics, honest incomplete-data
states, a useful Spanish-language routine and low-effort entry. This review did not
establish that competitors lack deferred payment allocation. Demonstrate advantage
in usability/retention rather than claiming a unique invention. Trust can strengthen
over time; a palette, generic chatbot or larger feature list is easily copied.

## 5. Product priorities that can lead to payment

### Trust and convenience first

Preserve the difference between purchase, repayment, interest, financing and
transfer. An unallocated payment reduces money while recorded debt and recognized
expenses remain incomplete; explain that plainly. Test comprehension before
presenting a reassuring result.

Onboarding should establish one real account and an understandable opening
balance, then invite the person's next relevant task. Never require fictitious
income, expenses or an invented loan breakdown to complete setup. Keep guest
entry and linking reliable. Observe returning movement entry against a proposed
median target of 15 seconds; it is not a measured current result.

### Give Coach a reason to be used

A reminder prompts an action; the service is a maintained financial routine.
Free daily/weekly reviews should help keep records accurate. Paid value should
connect the plan with what happened and an explainable next decision.

| Layer | Experience | Status and success test |
| --- | --- | --- |
| Record hygiene | Daily check-in and unresolved-payment notices | Existing foundation; users identify missing information rather than assuming notifications-off means all is well |
| Weekly understanding | Income, spending, Result and completeness by currency | Existing review; test comprehension and voluntary repeat use, not notification opens |
| Forward planning | Combine unpaid commitments, expected income dates and a chosen buffer | Proposed; validate before selling it as delivered |
| Actionable interpretation | Explain one supported observation, with act/dismiss choices | Proposed rule-based work; no invented savings or investment advice |

An available-to-spend calculation needs eligible liquid funds, unpaid commitments
in the horizon, protected amounts and a buffer, without subtracting the same
planned expense twice. Credit limits are not cash. Unknown obligations, stale
records or unallocated payments must make the estimate visibly incomplete.
Planned money is not physically reserved at a bank.

Defer conversational AI, bank aggregation, Gmail, automatic amortization,
household collaboration and investments until a measured problem warrants them.
If manual capture is the main churn reason, first test reusable entry and reviewed
CSV import. Gmail is a separate investment: `gmail.readonly` is restricted and
server processing can require verification/security assessment. Obtain actual
compliance/operating quotes before promising an automation price.
[Google scope classifications](https://developers.google.com/workspace/gmail/api/auth/scopes).

## 6. Proposed monetization and entitlement boundaries

Recommend **one usable free tier and one Pro subscription**, monthly and annual.
Continued planning/review value and service costs justify testing a subscription.
Avoid ads, financial-data sales, loan-lead commissions and lifetime cloud promises
in the first model. Employer-sponsored education could be explored later with
separate consent and no employer access to personal finances.

RevenueCat's 2026 report covers more than 115,000 subscription apps and reports
day-35 download-to-paid medians of 10.7% for hard paywalls versus 2.1% for freemium.
These are observational, cross-category data, not a Colombian finance experiment
or proof of causation. Start with freemium so users can verify this product's
value; revisit with comparable cohorts.
[Report and methodology](https://www.revenuecat.com/state-of-subscription-apps).

The following is a **packaging experiment**, not implemented restrictions:

| Capability | Free proposal | Pro proposal |
| --- | --- | --- |
| Financial integrity | Accounts, cards, loans and manual movements without an arbitrary record/account cap | Same correctness; never sell correctness or recovery |
| Monthly category budgets | Two active category budgets per month, across income/expense types | Unlimited active category budgets |
| Debt commitments | One active commitment to experience the complete loop | Multiple commitments and consolidated monthly planning |
| Coach | Daily check-in, weekly review, next step and reminder controls | Add planning comparisons/forward explanations only as delivered and validated |
| History and rights | Read/correct history, basic CSV, account protection, privacy and deletion | Included; never make data exit dependent on subscribing |
| Themes and synchronized access | Existing personalization and access from the user's installations | Included; no device-count paywall in this iteration |

Limits are candidate values. Beta features stay usable until packaging is approved
and communicated. Measure whether limits prevent the target user from experiencing
the benefit. A first Pro can build on multiple budgets/commitments; if users do not
pay for those outcomes, validate forward planning before gating more basic work.
Never advertise future reports as already included.

After expiry, preserve data and allow recording/correcting movements, allocating
past payments, paying debts, exporting and servicing existing commitments. Restrict
additional Pro setup/analysis; do not strand obligations or switch off their basic
reminders. Charge for financial planning, not an OS notification permission.

The installation registry helps platform/version support and adoption. Its
90-day count cannot prove simultaneous use, physical devices, abuse, retention
or value. Reinstalls can create another ID. Keep it separate from billing identity
and preserve its disclosed retention; device limits are not the initial paid benefit.

### Conversion experience

Offer Pro after a relevant success or a request for additional planning capacity,
with a voluntary entry in Settings. Avoid interrupting first launch, financial
saves, error recovery or a payment already being recorded. Ask guests to save
their account before purchase, preserving the same UID.

Test an explicitly selected **14-day store-managed Pro trial**. It allows weekly
reviews but does not prove monthly usefulness. Show renewal price, period, charge
date, cancellation/restore actions, terms and privacy. Distinguish a recurring
trial from an unpaid beta invitation. Provide an expiry reminder where supported.
Never present an annual monthly-equivalent as the amount charged monthly.
Trial eligibility follows store rules.

## 7. Colombia pricing experiments

Start with A, then test B with comparable eligible cohorts once experience and
packaging are stable. These hypotheses require supported local store price points;
neither offer has been configured.

| Offer | Monthly | Annual upfront | Discount versus 12 monthly payments |
| --- | --- | --- | --- |
| A: initial hypothesis | COP 9,900 | COP 79,900 | 32.7% |
| B: margin/value test | COP 12,900 | COP 99,900 | 35.5% |

The Realbyte listing is an anchor, not evidence that cheaper wins. Ask what users
currently spend or do instead, then test an actual eligible purchase. Stated
interest and paywall taps are weaker evidence than payment and renewal.

Keep features/trial consistent between prices. At beta scale, use directional
sequential cohorts and interviews rather than a decisive A/B claim from a handful
of purchases. Preserve the offer shown, storefront, platform, plan and date.
Choose by retained net contribution per eligible user, not conversion alone.
Price other countries after local research, without mechanically converting COP.

## 8. Unit economics and funding implications

These are **illustrative assumptions**, not forecasts, measured costs, Firebase
quotes or a determination of Colombian tax treatment. Replace them with actual
costs and store proceeds. Annual cash receipts, recognized MRR and profit differ;
allocate annual revenue over 12 months.

Base inputs:

- 40% monthly / 60% annual subscriber mix at A: gross recognized revenue per
  payer/month `G = 0.40 × 9,900 + 0.60 × 79,900 / 12 = COP 7,955`.
- Indirect-tax stress assumption `t = 19%`, store fee `s = 15%`, and reserve
  `r = 3%` on post-tax/post-store proceeds for refunds/adjustments. Replace
  this simplified tax ordering with settlement data; never deduct a tax twice.
- Variable costs `Cp = COP 1,200` per payer/month and `Cf = COP 150` per free
  monthly active user, including a support allocation. Count support time here
  or in fixed costs without duplication.
- Fixed monthly cost `K = COP 5,000,000`, including an explicit founder/labor
  allowance and fixed operations. Acquisition and corporate/income taxes are
  additional. All cost amounts are assumptions to replace with a ledger.

Apple's 15% assumes Small Business Program eligibility/enrollment; standard
subscription terms can leave 70% before taxes in the first year. Google publishes
15% for auto-renewing subscriptions. Model 15% and 30% fee cases rather than
assuming enrollment or identical terms.
[Apple program](https://developer.apple.com/app-store/small-business-program/),
[Apple subscriptions](https://developer.apple.com/app-store/subscriptions/),
[Google fees](https://support.google.com/googleplay/android-developer/answer/112622?ctx=topic&hl=en&topic=15867).

Let `P` be all active paid entitlements, including subscribers who did not open
the app this month, and `F` be free monthly active users. `q = P / (P + F)` is
only this model's ratio, **not** install-to-paid conversion or a standard MAU share.

```text
N = G / (1 + t) × (1 - s) × (1 - r)
Monthly contribution = P × (N - Cp) - F × Cf
Contribution per payer at fixed q = N - Cp - Cf × (1 - q) / q
Operating result before acquisition/income taxes = contribution - K
```

At A/15%, `N ≈ COP 5,512`. Round per-payer contribution to pesos; required
payers are rounded upward from unrounded calculations.

| Price / fee / q assumption | Contribution per payer/month | Payers to cover K | P + F at that scale |
| --- | ---: | ---: | ---: |
| A / 15% / 3% | COP -538 | No break-even at this ratio | Not applicable |
| A / 15% / 5% | COP 1,462 | 3,421 | 68,420 |
| A / 15% / 10% | COP 2,962 | 1,689 | 16,890 |
| A / 30% / 5% | COP 489 | 10,225 | 204,500 |
| B / 15% / 5% | COP 2,986 | 1,675 | 33,500 |

The B row holds subscriber mix, costs and q constant only for sensitivity; price
can change all three. At A/15%/5%, 100 subscribers recognize COP 795,500 gross
MRR and contribute about COP 146,168 before fixed costs. This is a useful demand
milestone, not a business already paying its founder.

A six-month payback ceiling at that ratio is approximately COP 8,770 per acquired
payer **before churn**; actual allowable CAC falls if users lapse. A hypothetical
2% install-to-paid rate implies a ceiling near COP 175 per attributable install.
These are derived limits, not achievable advertising prices. Measure cumulative
realized contribution by acquisition cohort before approving spend. Do not infer
durable LTV from `ARPU / churn` after a short beta or apply monthly churn to annual
subscriptions.

Measure reads/listeners, Functions, Storage/egress, monitoring, support minutes,
refunds and vendor fees. Bound queries/history scans; inactive free accounts and
active users have different costs. If managed billing is selected, include its
fees: RevenueCat publishes free service up to USD 2,500 monthly tracked revenue,
then 1% of tracked revenue. This optional fee is excluded from the numeric model;
no vendor is selected. [Official pricing](https://www.revenuecat.com/pricing).

Funding needed is `one-time release/discovery costs + monthly net cash burn ×
runway + contingency`, using actual rates/quotes. Protect annual receipts for
remaining service obligations; upfront cash is not fully earned that month.

## 9. Acquisition and retention experiments

Start with targeted financial education and founder-led discovery. Content themes:
planning a loan payment without knowing its breakdown, understanding why a card
payment is not a second expense, and a useful weekly review. Use synthetic
demonstrations and actual product screens.

| Channel | Bounded first experiment | Decision evidence |
| --- | --- | --- |
| Interviews / beta recruitment | Twenty Colombian interviews: 12 target users, four spreadsheet/app users and four who abandoned tracking; eight observed usability sessions | Recent incidents, workaround, comprehension, effort and consent to join beta |
| Educators / communities | Two or three small partners; one walkthrough and attributable invitation per partner | Activated users, week-4 return and retained payers; include partner fees in CAC |
| Store search / ASO | Test budget, debt-payment and routine messages with real localized screenshots | Product-page conversion, activation and payment by country/platform; search volume is unverified |
| Paid acquisition | Capped discovery test after initial retention/payment evidence | Incremental payers and contribution payback, not installs alone |

Proposed 90-day learning cap: **COP 2,000,000**, excluding development, publisher
fees, legal review and ordinary operations: COP 600,000 participant compensation,
COP 900,000 content/partner tests and COP 500,000 reserve. These are proposals,
not quotes or spend authorization. Compensation must not buy favorable reviews.
Release the reserve only against a specific uncertainty identified by prior work.

Run a 60–100-person consenting beta for at least eight weeks; separate country,
platform and source, and collect abandonment/cancellation reasons. Recruit beyond
the founder's contacts to reduce courtesy bias. This update does not contact
people, launch invitations or spend advertising money.

Notifications should serve chosen routines and unresolved tasks. Measure disabling
and dismissal, allow pause, and avoid shaming or manufacturing overdue work.
A notification open is neither financial improvement nor meaningful retention.

## 10. Metrics and decision gates

These are internal learning thresholds, **not industry benchmarks**. Report
numerators, denominators, cohort dates, country, platform, plan, channel and window
maturity. Keep guests in the funnel and join upgrades by the same UID; exclude
test/operators and do not count a data reset as a new customer. A client purchase
tap is not revenue evidence.

North-star candidate: **weekly financially reviewed users** — distinct users who
consult a successfully loaded weekly report and mark it reviewed. A genuinely
empty report can qualify; failures and notification opens cannot. Pair this with
recording and renewal to detect ritual clicks without benefit.

| Metric | Definition | Initial decision gate |
| --- | --- | --- |
| Onboarding completion | First-account setup successes / users starting onboarding | Aim ≥70%; inspect abandonment and account/opening-balance comprehension |
| Seven-day activation | Setup plus first confirmed real movement / first authenticated users, including guests, with seven full days | Aim ≥50%; below 30% in two iterations, fix capture/value first; track legitimate no-movement reviewers separately |
| Planning adoption | Activated users creating a budget/commitment within 14 days / activated users with the full window | Aim ≥40%; inspect problem fit and discoverability |
| Week-4 meaningful return | Activated users recording a confirmed movement or completing a loaded weekly review on days 22–28 / activated users with 28 full days | Aim ≥25%; below 15% in two mature cohorts, revisit value before buying traffic |
| Offer-to-paid | Distinct first successful payers / eligible activated users exposed to the same offer over 30 days | Directional target ≥5% after 100 comparable exposures; small counts are not statistical proof |
| Install-to-paid / trial-to-paid | Store-attributed first payers / attributable new installs; separately, first charges / trials with an elapsed billing decision window | Keep both separate from offer conversion and q in the cost model |
| Renewals | Successful renewals / subscriptions reaching each renewal | Separate voluntary cancellation, billing failure, refund and revocation; observe three monthly cycles before extrapolating; annual renewal stays unknown for a year |
| Financial trust/support | Unexplained mismatches, rejected commands, error recovery and support minutes | A reproducible duplicate/lost effect blocks expansion; bank-statement reconciliation is a distinct user check |
| Contribution/acquisition | Proceeds minus variable/support costs; attributable acquisition spend / new paying users | Positive contribution including free users; CAC within observed six-month contribution before scaling |

Extend the event allowlist only with needed signals: plan adoption, completed
review, upgrade result, offer exposure, trial start and verified purchase/renewal/
refund status. Use offer/experiment IDs, coarse country, platform and version where
justified; omit balances, amounts, descriptions, account/category names, email
bodies, receipts and raw identifiers from event payloads. Evaluate SDK defaults,
consent, retention and withdrawal. Declining optional analytics must not block
paid service.

The admin portal can later add aggregate cohort, subscription, billing-failure
and cost views. Current user/device counts are not a retention/revenue funnel.
Keep financial-record access separate and reconcile settlements, entitlements
and aggregate revenue events monthly.

## 11. Store and operational gates before charging

1. **Financial rollout.** Complete the compatible-client/rules sequence in
   [operation integrity](operation-commands.md). Qualify edits, retries, transfers
   and reconciliation with synthetic E2Es; Functions publication is not store
   readiness or permission to silently repair customer balances.
2. **Signed distribution and usability.** Establish release inputs, signing,
   TestFlight/Play tracks, session recovery and real-device accessibility.
   Check console/SDK requirements at submission; the historical audit does not
   prove current signing or publisher status. New personal Play accounts subject
   to Google's rule need its specified closed test before production access.
   [Google requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB).
3. **Billing lifecycle.** Use App Store/Play billing for the first mobile digital
   offer: server-verified entitlement, idempotent store notifications, restore,
   pending purchase, grace/retry, expiration, refund and revocation. Recheck
   applicable storefront exceptions before any alternate checkout.
   [Apple payment rules](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase),
   [Google payments](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en).
4. **Purchase continuity.** Bind purchases to the registered Firebase identity,
   not an installation. Test recognition across platforms for the same account
   without charging twice; management stays with the originating store. Handle
   store-account/Firebase-account conflicts explicitly. A data reset must retain
   valid subscription access; purchase restore must not restore deleted finances.
   This needs a new entitlement persistence boundary.
5. **Deletion, login and privacy.** Deliver real account deletion, not just
   `resetUserData`, plus Google's outside-app request route. Assess an equivalent
   privacy-preserving login under Apple's 4.8 while Google login is enabled;
   Sign in with Apple is the practical candidate, subject to applicable exceptions.
   Verify disclosures, support and subscription-management links.
   [Apple deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/),
   [Google deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN),
   [Apple login rules](https://developer.apple.com/app-store/review/guidelines/#login-services).
6. **Publisher, countries and support.** Confirm entity, tax/banking agreements,
   brand/domain rights, declarations, privacy labels/Data safety, support contact
   and local consumer/data review. Assess Apple's financial-services clause
   against the exact recording/planning service; do not represent the app as a
   bank, lender, investment adviser or payment executor. Google requires the
   Financial features declaration. Review applicable Colombian controller/
   processor and data-rights obligations before publication.
   [Apple business rules](https://developer.apple.com/app-store/review/guidelines/#business),
   [Google declaration](https://support.google.com/googleplay/android-developer/answer/13849271?hl=en-en),
   [Colombia Law 1581](https://cancilleria.gov.co/normograma/compilacion/docs/ley_1581_2012.htm).

A managed subscription service is reasonable for a small team if its privacy,
costs and integration effort are acceptable; native billing is also viable.
Select through a bounded comparison. Both require actual store sandbox tests,
entitlement isolation and the gates above.

## 12. Proposed 90-day delivery sequence

Time bands are prioritization, not delivery commitments; reviews and team capacity
can change the calendar. Research and reliability can proceed together, but a
paid pilot depends on the relevant store/operational gates.

| Window | Accountable role | Deliverable and decision |
| --- | --- | --- |
| Days 1–14 | Founder/Product + engineering/QA | Twenty interviews, eight observed tasks, one primary job/customer, verified release-gap list and actual cost ledger; decide whether the problem merits the next cohort |
| Days 15–42 | Product + engineering/QA | Instrumented beta with 60–100 recruits, qualified account/finance flows and useful weekly review; prioritize trust/deletion/login and capture-friction fixes |
| Days 43–70 | Founder + product/engineering | Evaluate mature week-4 cohorts; approve packaging/prices, qualify billing and a usable Pro outcome; begin a small real paid pilot after gates pass |
| Days 71–90 | Founder/Growth + product | Review purchases, early renewals, rejection reasons, support and channel quality; continue, change positioning/package, or stop paid expansion |

First seek **10 independently paying customers** with documented use, then 100
active paid subscriptions with contribution/renewal evidence. Do not promise three
renewal cycles within a pilot starting late in the 90 days; keep observing monthly
plans afterward. Annual renewal requires an actual renewal cohort.

Expansion requires four results together: no unresolved material financial defect,
meaningful repeat use, actual paid demand and viable channel economics. If users
retain but do not pay, revisit the paid outcome/price; if they pay but leave, fix
continued value; if neither happens, narrow/change the problem before integrations.
New countries and AI do not replace validation of the core loop.

## 13. Decisions and next review

| Owner | Recommended default to validate | Evidence/approval still needed |
| --- | --- | --- |
| Founder | Colombia-first commercial cohort, regional ambition retained | Revised sequencing against the previous LATAM direction and explicit store country list |
| Founder/Product | Free + one Pro, planning capacity as first paid boundary | Comprehension, retained use, purchases and final experimental limits |
| Founder | Offer A first, B later; COP 2 million learning cap | Store price points, runway/team budget and spend approval |
| Founder/Engineering | Compare managed versus native billing | Estimate, server verification, lifecycle tests and all-in vendor costs |
| Founder/Release | Publish what can be supported, with a named support/incident owner | Identity, brand rights, policy/deletion endpoints, signed builds and console approval |

Recommended next delivery: **qualify the complete debt/weekly-review journey and
recruit the problem-validation cohort while closing store trust gaps**. Use those
results to approve one paid offer. Recheck competitor prices before configuring
store products; review cohorts/costs monthly and this strategy after beta/renewal
evidence. This document creates no pricing, limits, vendor, deployment or
advertising changes by itself.
