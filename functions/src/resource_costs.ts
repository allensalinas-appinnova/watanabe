import {createHash} from "node:crypto";
import {runUserMaintenance} from "./maintenance_jobs";
import {randomUUID} from "node:crypto";
import {BigQuery} from "@google-cloud/bigquery";
import {FieldPath, Timestamp, type Firestore} from "firebase-admin/firestore";
import type {Data} from "./resource_usage";

type Component = {service: string; unit: string; amountUsd: number | null; reason: string | null; tariffId: string | null};

/** Costs are estimates of observed components, never an assertion of invoice completeness. */
export function evaluateUsageEventCost(event: Data, tariffs: Data[]) {
  const at = event.createdAt?.toDate?.().getTime();
  const components: Component[] = [];
  const units = event.units ?? {};
  const missing = (service: string, unit: string, reason: string) =>
    components.push({service, unit, amountUsd: null, reason, tariffId: null});
  function price(service: string, unit: string, quantity: unknown) {
    if (event.quality === "pending" || !Number.isFinite(at) || typeof quantity !== "number" || !Number.isFinite(quantity) || quantity < 0) {
      missing(service, unit, "measurement-unavailable"); return;
    }
    // Explicitly observed zero units do not need a price. Missing units are never zero.
    if (quantity === 0) { components.push({service, unit, amountUsd: 0, reason: null, tariffId: null}); return; }
    const region = service === "firestore" ? event.firestoreRegion : event.region;
    if (service === "firestore" && !region) {
      missing(service, unit, "resource-location-unverified"); return;
    }
    const rates = tariffs.filter(t => t.service === service && t.unit === unit && (!t.model || t.model === event.model) &&
      (!t.region || t.region === region) && (!t.storageClass || t.storageClass === event.storageClass) &&
      (!t.billingMode || t.billingMode === event.billingMode) && Date.parse(t.effectiveFrom) <= at &&
      (!t.effectiveUntil || Date.parse(t.effectiveUntil) > at));
    rates.sort((a, b) => Date.parse(b.effectiveFrom) - Date.parse(a.effectiveFrom) ||
      (Number(!!b.model) + Number(!!b.region)) - (Number(!!a.model) + Number(!!a.region)) || String(a.id ?? "").localeCompare(String(b.id ?? "")));
    const rate = rates[0];
    if (!rate || typeof rate.usdPerUnit !== "number" || !Number.isFinite(rate.usdPerUnit) || rate.usdPerUnit < 0) {
      missing(service, unit, "tariff-unavailable"); return;
    }
    const specificity = (t: Data) => Number(!!t.model) + Number(!!t.region);
    if (rates.some(t => Date.parse(t.effectiveFrom) === Date.parse(rate.effectiveFrom) &&
      specificity(t) === specificity(rate) && t.usdPerUnit !== rate.usdPerUnit)) {
      missing(service, unit, "tariff-ambiguous"); return;
    }
    const amountUsd = quantity * rate.usdPerUnit;
    if (!Number.isFinite(amountUsd)) { missing(service, unit, "measurement-invalid"); return; }
    components.push({service, unit, amountUsd, reason: null, tariffId: typeof rate.id === "string" ? rate.id : null});
  }
  switch (event.service) {
  case "ai":
    for (const unit of ["billableInputTokens", "billableOutputTokens", "cachedTokens"]) price("ai", unit, units[unit]);
    break;
  case "functions":
    price("functions", "calls", units.calls);
    // Wall time per request is not billed CPU/memory time when requests share instances.
    missing("functions", "compute", "shared-compute-unattributed");
    if ("transactionDocumentLookups" in units) price("firestore", "documentReads", units.transactionDocumentLookups);
    if ("transactionQueryReadUnits" in units) price("firestore", "documentReads", units.transactionQueryReadUnits);
    else if (units.transactionQueryResults > 0) missing("firestore", "queryReads", "legacy-query-measurement-incomplete");
    if ("committedDocumentWrites" in units && "committedDocumentDeletes" in units) {
      price("firestore", "documentWrites", units.committedDocumentWrites);
      price("firestore", "documentDeletes", units.committedDocumentDeletes);
    } else if (units.committedTransactionWrites > 0) missing("firestore", "writes", "legacy-write-measurement-incomplete");
    break;
  case "storage":
    if ("byteHours" in units) price("storage", "byteHours", units.byteHours);
    // Transport destination and operation classes are not inferred from app byte counts.
    if (Object.keys(units).some(unit => unit !== "byteHours" && units[unit] > 0)) missing("storage", "operations-and-transfer", "billing-route-unverified");
    break;
  case "firestore":
    missing("firestore", "client-observations", "advisory-not-billable-reads"); break;
  default: missing(String(event.service ?? "unknown"), "usage", "service-unpriced");
  }
  if (!components.length) missing(String(event.service ?? "unknown"), "usage", "measurement-unavailable");
  const priced = components.filter(c => c.amountUsd !== null);
  const pendingReasons = [...new Set(components.flatMap(c => c.reason ? [`${c.service}:${c.unit}:${c.reason}`] : []))].sort();
  return {components, pendingReasons, complete: pendingReasons.length === 0,
    knownSubtotalUsd: priced.length ? priced.reduce((sum, c) => sum + c.amountUsd!, 0) : null,
    tariffVersions: [...new Set(priced.flatMap(c => c.tariffId ? [c.tariffId] : []))].sort()};
}

/** Compatibility entry point: partial subtotals must not masquerade as complete event costs. */
export function priceUsageEvent(event: Data, tariffs: Data[]) {
  const cost = evaluateUsageEventCost(event, tariffs);
  return cost.complete ? cost.knownSubtotalUsd : null;
}

export async function estimateUserCosts(db: Firestore, month = new Date().toISOString().slice(0, 7), options: {asOf?: Date; budgetMs?: number; afterPage?: (uid: string) => Promise<void>} = {}) {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw new Error("cost-month-invalid");
  const tariffs = (await db.collection("resourceTariffs").get()).docs.map(d => ({...d.data(), id: d.id}));
  const tariffDigest = createHash("sha256").update(JSON.stringify(tariffs)).digest("hex");
  await runUserMaintenance(db, `costs_${month}`, async (uid, lease, deadline) => {
    const subject = db.doc(`resourceUsage/${uid}`), stateRef = subject.collection("maintenance").doc(`costs_${month}`);
    const aggregate = () => ({totalEvents: 0, excludedDiagnosticEvents: 0, pricedEvents: 0, partiallyPricedEvents: 0, pricedComponents: 0, totalComponents: 0,
      knownSubtotalUsd: null as number | null, byService: {} as Record<string, number>,
      pendingReasons: {} as Record<string, number>, tariffVersions: [] as string[]});
    const previous = (await stateRef.get()).data();
    const resumable = previous?.runId === lease.runId && previous?.tariffDigest === tariffDigest;
    const monthly = resumable ? previous.monthly as ReturnType<typeof aggregate> : aggregate();
    const days: Record<string, ReturnType<typeof aggregate>> = resumable ? previous.days : {};
    let cursor = resumable ? previous.cursor : null;
    while (Date.now() < deadline) {
      let query = subject.collection("events").where("createdAt", ">=", Timestamp.fromDate(new Date(`${month}-01T00:00:00Z`)))
        .where("createdAt", "<", Timestamp.fromDate(new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 1))))
        .where("createdAt", "<=", lease.cutoff).orderBy("createdAt").orderBy(FieldPath.documentId()).limit(250);
      if (cursor) query = query.startAfter(cursor.at, cursor.id);
      const events = await query.get();
      for (const event of events.docs) {
        const data = event.data(), cost = evaluateUsageEventCost(data, tariffs), day = data.createdAt.toDate().toISOString().slice(0, 10);
        const daily = days[day] ??= aggregate();
        if (data.costAggregation === "diagnostic-only") { monthly.excludedDiagnosticEvents++; daily.excludedDiagnosticEvents++; continue; }
        for (const target of [monthly, daily]) {
          target.totalEvents++; target.pricedEvents += Number(cost.complete);
          target.partiallyPricedEvents += Number(!cost.complete && cost.knownSubtotalUsd !== null);
          target.totalComponents += cost.components.length;
          for (const c of cost.components) if (c.amountUsd !== null) {
            target.pricedComponents++; target.knownSubtotalUsd = (target.knownSubtotalUsd ?? 0) + c.amountUsd;
            target.byService[c.service] = (target.byService[c.service] ?? 0) + c.amountUsd;
          }
          for (const reason of cost.pendingReasons) target.pendingReasons[reason] = (target.pendingReasons[reason] ?? 0) + 1;
          target.tariffVersions = [...new Set([...target.tariffVersions, ...cost.tariffVersions])].sort();
        }
      }
      const last = events.docs.at(-1); if (last) cursor = {at: last.get("createdAt"), id: last.id};
      const complete = events.size < 250;
      await db.runTransaction(async tx => {
        await lease.assert(tx);
        if ((await tx.get(db.doc(`accountDeletions/${uid}`))).exists || !(await tx.get(subject)).exists) return;
        if (!complete) {
          tx.set(stateRef, {runId: lease.runId, tariffDigest, monthly, days, cursor, updatedAt: Timestamp.now()});
          tx.set(subject, {costRefreshStatus: "running", costRefreshStartedAt: lease.cutoff}, {merge: true});
          return;
        }
        const expiry = Timestamp.fromMillis(Date.now() + 400 * 86400000);
        const finish = (value: ReturnType<typeof aggregate>) => ({...value,
          quality: value.totalEvents > 0 && value.pricedEvents === value.totalEvents ? "estimated" : "pending",
          amountUsd: value.totalEvents > 0 && value.pricedEvents === value.totalEvents ? value.knownSubtotalUsd : null,
          coverage: value.totalEvents ? value.pricedEvents / value.totalEvents : null,
          componentCoverage: value.totalComponents ? value.pricedComponents / value.totalComponents : null,
          runId: lease.runId, through: lease.cutoff, methodVersion: 2, updatedAt: Timestamp.now(), expiresAt: expiry});
        for (const [day, daily] of Object.entries(days)) tx.set(subject.collection("costDays").doc(day), {...finish(daily), day});
        tx.set(subject.collection("costs").doc(month), finish(monthly));
        tx.set(subject, {costRefreshStatus: "complete"}, {merge: true});
        tx.delete(stateRef);
      });
      await options.afterPage?.(uid);
      if (complete) return true;
    }
    return false;
  }, options.budgetMs ?? 360000, Timestamp.fromDate(options.asOf ?? new Date()));
}

function serviceKey(service: string) {
  if (/vertex|gemini|generative/i.test(service)) return "ai";
  if (/firestore/i.test(service)) return "firestore";
  if (/storage/i.test(service)) return "storage";
  if (/functions|cloud run/i.test(service)) return "functions";
  return null;
}

/** Group before attribution: multiple provider products may map to one measured service. */
export function groupBillingRows(rows: Data[]): Data[] {
  const groups = new Map<string, Data>();
  const amount = (value: unknown) => typeof value === "number" ||
    (typeof value === "string" && value.trim() !== "") ? Number(value) : NaN;
  for (const row of rows) {
    const day = String(row.day?.value ?? row.day), service = String(row.service), currency = String(row.currency);
    const key = serviceKey(service), grossCost = amount(row.grossCost), credits = amount(row.credits);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !/^[A-Z]{3}$/.test(currency) || !Number.isFinite(grossCost) || !Number.isFinite(credits)) throw new Error("billing-row-invalid");
    const id = Buffer.from(JSON.stringify([day, key ?? service, currency])).toString("base64url");
    const group = groups.get(id) ?? {id, day, service: key ?? service, measuredService: key, currency,
      grossCost: 0, credits: 0, netCostUsd: 0, conversionComplete: true, conversionRates: [], providerServices: []};
    group.grossCost += grossCost; group.credits += credits;
    const rate = currency === "USD" ? 1 : amount(row.currencyConversionRate);
    if (Number.isFinite(rate) && rate > 0) {
      group.netCostUsd += (grossCost + credits) / rate;
      group.conversionRates = [...new Set([...group.conversionRates, rate])].sort((a, b) => a - b);
    } else group.conversionComplete = false;
    group.providerServices = [...new Set([...group.providerServices, service])].sort(); groups.set(id, group);
  }
  return [...groups.values()].map(row => ({...row, netCost: row.grossCost + row.credits,
    netCostUsd: row.conversionComplete ? row.netCostUsd : null}));
}

type BillingQuery = (options: {query: string; params: {projectId: string}; maximumBytesBilled: string}) => Promise<[Data[]]>;
export function resourceBillingQueryOptions(table: string, projectId: string) {
  if (!/^[a-z][a-z0-9-]+\.[A-Za-z_][\w]*\.[A-Za-z_][\w]*$/.test(table)) throw new Error("billing-table-invalid");
  return {query: `SELECT DATE(usage_start_time) AS day, service.description AS service, currency,
      currency_conversion_rate AS currencyConversionRate,
      SUM(cost) AS grossCost, SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c),0)) AS credits
      FROM \`${table}\` WHERE project.id=@projectId AND usage_start_time>=TIMESTAMP(DATE_SUB(CURRENT_DATE('UTC'),INTERVAL 7 DAY))
      AND usage_start_time<TIMESTAMP(CURRENT_DATE('UTC')) GROUP BY day,service,currency,currencyConversionRate`,
    params: {projectId}, maximumBytesBilled: "1000000000"};
}
export async function reconcileProjectBilling(db: Firestore, query?: BillingQuery) {
  const table = process.env.RESOURCE_BILLING_EXPORT_TABLE ?? (await db.doc("servicePolicies/billing").get()).get("exportTable");
  const status = db.doc("resourceBilling/status");
  if (typeof table !== "string" || !/^[a-z][a-z0-9-]+\.[A-Za-z_][\w]*\.[A-Za-z_][\w]*$/.test(table)) {
    await status.set({available: false, issue: "billing-export-not-configured", updatedAt: Timestamp.now()}, {merge: true}); return;
  }
  try {
    const options = resourceBillingQueryOptions(table, process.env.GCLOUD_PROJECT ?? "lumiomoney");
    const [rows] = query ? await query(options) : await new BigQuery({projectId: options.params.projectId}).query(options);
    const groups = groupBillingRows(rows), runId = randomUUID();
    const currencies = new Map<string, Set<string>>();
    for (const row of groups) {
      const key = JSON.stringify([row.day, row.service]);
      const values = currencies.get(key) ?? new Set<string>(); values.add(row.currency); currencies.set(key, values);
    }
    const users = await db.collection("resourceUsage").get();
    const cache = new Map<string, Data[]>();
    for (const row of groups) {
      let knownSubtotalUsd = 0, pricedUsers = 0;
      const mixedCurrencies = currencies.get(JSON.stringify([row.day, row.service]))!.size > 1;
      if (row.measuredService && row.netCostUsd !== null && !mixedCurrencies) {
        if (!cache.has(row.day)) cache.set(row.day, await Promise.all(users.docs.map(async user =>
          (await user.ref.collection("costDays").doc(row.day).get()).data() ?? {})));
        for (const cost of cache.get(row.day)!) {
          const amount = cost.byService?.[row.measuredService];
          if (typeof amount === "number" && Number.isFinite(amount)) { knownSubtotalUsd += amount; pricedUsers++; }
        }
      }
      const comparable = pricedUsers > 0 && row.netCostUsd !== null && !mixedCurrencies;
      await db.doc(`resourceBilling/daily/services/${runId}_${row.id}`).set({...row, runId,
        knownSubtotalUsd: pricedUsers ? knownSubtotalUsd : null,
        unattributedDifferenceUsd: comparable ? row.netCostUsd - knownSubtotalUsd : null,
        comparisonIssue: mixedCurrencies ? "mixed-provider-currencies" : row.netCostUsd === null ? "currency-not-comparable" : pricedUsers ? null : "user-estimates-unavailable",
        quality: "provider-aggregate-with-partial-user-estimates", updatedAt: Timestamp.now(), expiresAt: Timestamp.fromMillis(Date.now() + 400 * 86400000)});
    }
    // Publish only complete runs; a partial failure must not expose a mixed snapshot.
    await status.set({available: rows.length > 0, issue: rows.length ? null : "billing-export-awaiting-data", runId,
      quality: "provider-aggregate", updatedAt: Timestamp.now(), lastSuccessfulAt: Timestamp.now(),
      attribution: "Shared resources, credits, missing measurements and provider adjustments are not assigned blindly to users."}, {merge: true});
  } catch (error) {
    await status.set({available: false, issue: (error as {code?: number}).code === 404 ? "billing-export-awaiting-data" : "billing-query-unavailable", updatedAt: Timestamp.now()}, {merge: true});
  }
}

export function tariffHealth(tariffs: Data[], now = new Date()) {
  const groups = new Map<string, Data>();
  for (const t of tariffs) {
    const from = Date.parse(t.effectiveFrom);
    if (!Number.isFinite(from) || from > now.getTime()) continue;
    const key = JSON.stringify([t.service,t.unit,t.model??null,t.region??null,t.storageClass??null,t.billingMode??null]);
    if (!groups.has(key) || Date.parse(groups.get(key)!.effectiveFrom) < from) groups.set(key,t);
  }
  const expired: string[] = [], expiring: string[] = []; let nextExpiry: number|null = null;
  for (const t of groups.values()) {
    if (!t.effectiveUntil) continue;
    const until = Date.parse(t.effectiveUntil);
    if (!Number.isFinite(until)) { expired.push(t.id); continue; }
    if (until <= now.getTime()) expired.push(t.id);
    else { nextExpiry = Math.min(nextExpiry ?? until, until); if (until - now.getTime() <= 30 * 86400000) expiring.push(t.id); }
  }
  return {state: !groups.size ? "unknown" : expired.length ? "expired" : expiring.length ? "expiring" : "ready",
    expired, expiring, nextExpiryIso: nextExpiry === null ? null : new Date(nextExpiry).toISOString(), checkedAtIso: now.toISOString()};
}
