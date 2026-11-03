import type {Data} from "./resource_usage";
import type {Firestore} from "firebase-admin/firestore";

/** Reviewed list prices, not an allocation of free tiers, negotiated discounts or credits. */
export const REVIEWED_RESOURCE_TARIFFS: Data[] = [
  ...[["input", "billableInputTokens", 0.75e-6], ["output", "billableOutputTokens", 3.75e-6], ["cached", "cachedTokens", 0.075e-6]]
    .map(([suffix, unit, usdPerUnit]) => ({id: `gemini38-global-20261102-${suffix}`, service: "ai", model: "gemini-3.8-flash",
      region: "global", unit, usdPerUnit, source: "https://cloud.google.com/model-garden/pricing"})),
  ...[["documentReads", 0.06 / 100000, "369B-DC02-4DAB"], ["documentWrites", 0.18 / 100000, "0FD8-FD9E-2D84"], ["documentDeletes", 0.02 / 100000, "57BD-FBE3-CB86"]]
    .map(([unit, usdPerUnit, sku]) => ({id: `firestore-nam5-20261102-${unit}`, service: "firestore", region: "nam5", unit, usdPerUnit,
      sku, source: "https://cloudbilling.googleapis.com/v1/services/EE2C-7FAC-5E08/skus"})),
  {id: "storage-standard-uscentral1-20261102", service: "storage", region: "us-central1", storageClass: "STANDARD", unit: "byteHours",
    usdPerUnit: 0.000027397 / 2 ** 30, source: "https://cloud.google.com/storage/pricing"},
  {id: "functions-request-uscentral1-20261102", service: "functions", region: "us-central1", billingMode: "request-based", unit: "calls",
    usdPerUnit: 0.40 / 1000000, source: "https://cloud.google.com/run/pricing"},
].map(rate => ({...rate, currency: "USD", effectiveFrom: "2026-11-02T00:00:00Z", effectiveUntil: "2027-01-01T00:00:00Z",
  reviewedAt: "2026-11-02", basis: "list-price-before-free-tier-and-credits", quality: "estimated"}));

/** Immutable versions: a tool may create a missing version, never rewrite a price in place. */
export function tariffConfigurationPlan(existing: Data[], metadata: Data, now = new Date()) {
  if (REVIEWED_RESOURCE_TARIFFS.some(rate => now.getTime() < Date.parse(rate.effectiveFrom) || now.getTime() >= Date.parse(rate.effectiveUntil))) {
    throw new Error("tariff-review-expired-or-not-effective");
  }
  if (metadata.firestoreRegion !== "nam5" || metadata.firestoreEdition !== "STANDARD" ||
      metadata.bucketRegion !== "us-central1" || metadata.storageClass !== "STANDARD" || metadata.functionsBillingMode !== "request-based") {
    throw new Error("resource-topology-needs-review");
  }
  const create: Data[] = [];
  for (const rate of REVIEWED_RESOURCE_TARIFFS) {
    const saved = existing.find(t => t.id === rate.id);
    if (!saved) { create.push(rate); continue; }
    if (Object.keys(rate).some(key => saved[key] !== rate[key])) throw new Error("immutable-tariff-conflict");
  }
  return {create, unchanged: REVIEWED_RESOURCE_TARIFFS.length - create.length};
}

export async function configureReviewedResourceTariffs(db: Firestore, metadata: Data, apply = false, now = new Date()) {
  return db.runTransaction(async tx => {
    const refs = REVIEWED_RESOURCE_TARIFFS.map(t => db.doc(`resourceTariffs/${t.id}`));
    const docs = await tx.getAll(...refs);
    const plan = tariffConfigurationPlan(docs.filter(d => d.exists).map(d => ({...d.data(), id: d.id})), metadata, now);
    if (apply) for (const rate of plan.create) {
      const {id, ...data} = rate;
      tx.create(db.doc(`resourceTariffs/${id}`), data);
    }
    return plan;
  });
}
