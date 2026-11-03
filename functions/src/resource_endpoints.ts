import {assertAccountActive} from "./account_deletion";
import {randomUUID} from "node:crypto";
import {getStorage} from "firebase-admin/storage";
import {getFirestore as unmeteredFirestore} from "firebase-admin/firestore";
import {meteredFirestore as getFirestore, newServerObservation, observeServerResources} from "./resource_observation";
import {onCall, HttpsError, type CallableOptions, type CallableRequest} from "firebase-functions/v2/https";
import {onObjectFinalized, onObjectDeleted} from "firebase-functions/v2/storage";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {analyzeReceipt} from "./document_ai";
import {analyzeDocumentImport, prepareDocumentImport, trackDocumentObject} from "./document_imports";
import {cleanupExpiredDocuments, deleteAttachment, discardDocument, inventoryDocumentStorage, readAttachment} from "./document_storage";
import {mutatePaymentInstrument as instrumentCommand} from "./account_identity";
import {recordUsage, registeredUid, usageSummary} from "./resource_usage";
import {estimateUserCosts, reconcileProjectBilling} from "./resource_costs";

export function resourceOnCall(name: string, options: CallableOptions, handler: (request: CallableRequest<any>) => any) {
  return onCall(options, async request => {
    const started = Date.now(); const attemptId = randomUUID(); let failed = false;
    const stats = newServerObservation();
    try {
      if (request.auth) await assertAccountActive(unmeteredFirestore(), request.auth.uid);
      return await observeServerResources(stats, () => Promise.resolve(handler(request))); }
    catch (error) { failed = true; throw error; }
    finally {
      if (request.auth) await recordUsage(unmeteredFirestore(), request.auth.uid, `function:${attemptId}`, "functions",
        {calls: 1, durationMs: Date.now() - started, failures: failed ? 1 : 0, transactionAttempts: stats.transactionAttempts,
          transactionDocumentLookups: stats.documentLookups, transactionQueryResults: stats.queryDocumentResults, transactionQueryReadUnits: stats.queryReadUnits,
          committedTransactionWrites: stats.committedWrites, committedDocumentWrites: stats.committedDocumentWrites,
          committedDocumentDeletes: stats.committedDocumentDeletes}, "estimated", {feature: name,
          ...(process.env.RESOURCE_FIRESTORE_LOCATION ? {firestoreRegion: process.env.RESOURCE_FIRESTORE_LOCATION} : {}),
          ...(process.env.RESOURCE_FUNCTIONS_BILLING_MODE ? {billingMode: process.env.RESOURCE_FUNCTIONS_BILLING_MODE} : {}),
          ...(typeof options.region === "string" ? {region: options.region} : {})})
        .catch(() => console.warn(JSON.stringify({issue: "resource-metering-unavailable", feature: name})));
    }
  });
}

const runtimeAccount = process.env.FUNCTIONS_EMULATOR === "true" ? undefined : "lumio-documents@lumiomoney.iam.gserviceaccount.com";
const jobAccount = process.env.FUNCTIONS_EMULATOR === "true" ? undefined : "lumio-resource-jobs@lumiomoney.iam.gserviceaccount.com";
const secured = {serviceAccount: runtimeAccount, region: "us-central1", enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true", maxInstances: 2};
export const mutatePaymentInstrument = resourceOnCall("paymentInstrument", secured, async request =>
  instrumentCommand(getFirestore(), request.auth?.uid, request.data));
export const mutateDocumentImport = resourceOnCall("documentImport", {...secured, concurrency: 2, timeoutSeconds: 180, memory: "1GiB"}, async request => {
  const uid = registeredUid(request.auth), p = request.data;
  if (!p || !["prepare", "analyze", "discard"].includes(p.action)) throw new HttpsError("invalid-argument", "document-command-invalid");
  if (p.action === "prepare") return prepareDocumentImport(getFirestore(), uid, p);
  if (p.action === "analyze") return analyzeDocumentImport(getFirestore(), uid, p, analyzeReceipt);
  if (typeof p.importId !== "string" || !/^[\w-]{8,100}$/.test(p.importId) || !Number.isSafeInteger(p.expectedGeneration)) throw new HttpsError("invalid-argument", "document-invalid");
  await discardDocument(getFirestore(), uid, p.importId, p.expectedGeneration);
  return {status: "discarded"};
});
export const getResourceUsage = resourceOnCall("usage", secured, request => usageSummary(getFirestore(), registeredUid(request.auth)));
export const mutateAttachment = resourceOnCall("attachment", {...secured, concurrency: 4, memory: "512MiB"}, async request => {
  const uid = registeredUid(request.auth);
  if (request.data?.action === "read") return readAttachment(getFirestore(), uid, request.data);
  if (request.data?.action === "delete") return deleteAttachment(getFirestore(), uid, request.data);
  throw new HttpsError("invalid-argument", "attachment-invalid");
});
export const trackDocumentUpload = onObjectFinalized({serviceAccount: jobAccount, region: "us-central1"}, async e => {
  const file = getStorage().bucket(e.data.bucket).file(e.data.name, {generation: e.data.generation});
  const [exists] = await file.exists();
  const match = /^users\/([^/]+)\/documentImports\/(\d+)\/([\w-]+)\/source$/.exec(e.data.name);
  if (!match) return;
  const db = getFirestore(), [, uid, generation, id] = match;
  const [profile, proposal] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`users/${uid}/documentImports/${id}`).get()]);
  const orphan = !profile.exists || profile.get("resetStatus") === "resetting" || (profile.get("dataGeneration") ?? 0) !== Number(generation) ||
    !proposal.exists || ["discarded", "expired", "deleting"].includes(proposal.get("status"));
  if (exists && orphan) await file.delete({ifGenerationMatch: e.data.generation});
  await trackDocumentObject(db, e.data, !exists || orphan);
});
export const trackDocumentDelete = onObjectDeleted({serviceAccount: jobAccount, region: "us-central1"}, e => trackDocumentObject(getFirestore(), e.data, true));
export const cleanupDocumentImports = onSchedule({serviceAccount: jobAccount, maxInstances: 1, concurrency: 1, region: "us-central1", schedule: "every 60 minutes", timeoutSeconds: 540}, () => cleanupExpiredDocuments(getFirestore()));
export const reconcileResourceUsage = onSchedule({serviceAccount: jobAccount, maxInstances: 1, concurrency: 1, region: "us-central1", schedule: "every day 04:00", timeZone: "UTC", timeoutSeconds: 540, memory: "1GiB"}, async () => {
  await inventoryDocumentStorage(getFirestore());
  await estimateUserCosts(getFirestore(), undefined, {budgetMs: 120000});
  const prior = new Date(); prior.setUTCDate(1); prior.setUTCMonth(prior.getUTCMonth() - 1);
  await estimateUserCosts(getFirestore(), prior.toISOString().slice(0,7), {budgetMs: 120000});
  await reconcileProjectBilling(getFirestore());
});
export const submitUsageObservation = resourceOnCall("clientObservation", secured, async request => {
  const uid = request.auth?.uid;
  const p = request.data;
  if (!uid || !p || typeof p.batchId !== "string" || !/^[\w-]{8,100}$/.test(p.batchId) ||
    !Number.isSafeInteger(p.documentResults) || p.documentResults < 0 || p.documentResults > 100000) throw new HttpsError("invalid-argument", "usage-observation-invalid");
  await recordUsage(getFirestore(), uid, `client:${p.batchId}`, "firestore", {documentResults: p.documentResults}, "estimated",
    {source: "client-advisory-not-billable-reads"});
  return {accepted: true};
});

/** Resume interrupted jobs without starting a second complete daily scan. */
export const continueResourceMaintenance = onSchedule({serviceAccount: jobAccount, region: "us-central1", schedule: "every 15 minutes", timeoutSeconds: 540, memory: "1GiB", maxInstances: 1}, async () => {
  const db = getFirestore();
  const rows = await db.collection("maintenanceJobs").where("status", "==", "running").limit(100).get();
  if (rows.docs.some(r => r.id === "storageObjects" || r.id === "storageUsers")) await inventoryDocumentStorage(db);
  for (const row of rows.docs) if (/^costs_\d{4}-\d{2}$/.test(row.id)) await estimateUserCosts(db, row.id.slice(6), {budgetMs: 120000});
});
