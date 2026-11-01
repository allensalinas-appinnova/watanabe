import {createHash, randomUUID} from "node:crypto";
import {FieldValue, Timestamp, type Firestore, type Transaction, type DocumentReference} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError} from "firebase-functions/v2/https";
import {documentPolicy, eventId, recordUsage, releaseAnalysis, reserveAnalysis, type Data} from "./resource_usage";
import {maximumMinor, validCurrency} from "./projection_model";

export type Extraction = {supported: boolean; amountMinor?: number; currency?: string; date?: string;
  merchant?: string; description?: string; categoryId?: string; accountId?: string;
  accountHint?: {kind: "account" | "debitCard" | "creditCard"; lastFour?: string; institution?: string};
  warnings?: string[]};
export type DocumentAnalyzer = (bytes: Buffer, mime: string, context: Data) => Promise<{extraction: Extraction; usage: Record<string, number>; model: string}>;
const ident = (v: unknown): v is string => typeof v === "string" && /^[\w-]{8,100}$/.test(v);
function issue(name: string): never { throw new HttpsError("failed-precondition", name); }
function publicImport(id: string, data: Data) {
  return {importId: id, status: data.status, version: data.version, dataGeneration: data.dataGeneration,
    ...(data.storagePath ? {storagePath: data.storagePath} : {}), storageUploaded: data.storageUploaded === true,
    ...(data.extraction ? {extraction: data.extraction} : {}), ...(data.operationId ? {operationId: data.operationId} : {})};
}
export async function readyProfile(tx: Transaction, root: DocumentReference, generation: unknown) {
  const p = (await tx.get(root)).data();
  if (!p || p.resetStatus === "resetting" || (p.dataGeneration ?? 0) !== generation) issue("stale-data-generation");
  return p!;
}

/** Partial identifiers are compared deterministically; model-selected account IDs are ignored. */
export function suggestDocumentAccount(extraction: Extraction, accounts: Data[], instruments: Data[]): string | null {
  const hint = extraction.accountHint;
  if (!hint?.lastFour || !/^\d{4}$/.test(hint.lastFour) || !extraction.currency) return null;
  const normalized = (s: unknown) => String(s ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
  const matching = accounts.filter(a => a.status === "active" && a.currency === extraction.currency &&
    (!hint.institution || normalized(a.institutionName ?? a.creditor) === normalized(hint.institution)) &&
    (hint.kind === "creditCard" ? a.nature === "debt" && a.type === "creditCard" && a.lastFour === hint.lastFour :
      (a.nature ?? "money") === "money" && (hint.kind === "account" ? a.accountLastFour === hint.lastFour :
        instruments.some(i => i.status === "active" && i.accountId === a.id && i.lastFour === hint.lastFour))));
  return matching.length === 1 ? matching[0].id as string : null;
}

export function validateExtraction(value: Extraction, categories: Data[], accounts: Data[], instruments: Data[]): Extraction {
  const warnings = new Set<string>();
  const result: Extraction = {supported: value?.supported === true};
  if (validCurrency(value?.currency)) result.currency = value.currency;
  else warnings.add("currency-review");
  if (result.currency && Number.isSafeInteger(value?.amountMinor) && Number(value.amountMinor) > 0 &&
    Number(value.amountMinor) <= maximumMinor(result.currency)) result.amountMinor = value.amountMinor;
  else warnings.add("amount-review");
  if (typeof value?.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value.date) &&
    Number.isFinite(Date.parse(`${value.date}T12:00:00Z`)) &&
    new Date(`${value.date}T12:00:00Z`).toISOString().slice(0, 10) === value.date) result.date = value.date;
  else warnings.add("date-review");
  for (const key of ["merchant", "description"] as const) if (typeof value?.[key] === "string") result[key] = value[key]!.replace(/[\u0000-\u001f<>]/g, "").replace(/\b(?:\d[ -]?){8,}\b/g, "••••").slice(0, key === "merchant" ? 120 : 500);
  if (categories.some(c => c.id === value?.categoryId && c.type === "expense" && !c.isArchived)) result.categoryId = value.categoryId;
  else warnings.add("category-review");
  const accountId = suggestDocumentAccount(value, accounts, instruments);
  if (accountId) result.accountId = accountId; else warnings.add("account-review");
  result.warnings = [...warnings];
  return result;
}

export async function prepareDocumentImport(db: Firestore, uid: string, p: Data) {
  const policy = await documentPolicy(db);
  if (!policy.enabled) issue("document-analysis-disabled");
  if (!ident(p.requestId) || !Number.isSafeInteger(p.expectedGeneration) || !Number.isSafeInteger(p.size) || p.size <= 0 ||
    !["image/jpeg", "image/png", "image/webp", "application/pdf"].includes(p.contentType) ||
    !/^[a-f0-9]{64}$/.test(String(p.sha256)) || p.size > (p.contentType === "application/pdf" ? policy.pdfBytes : policy.imageBytes)) {
    throw new HttpsError("invalid-argument", "document-file-invalid");
  }
  const root = db.doc(`users/${uid}`), ref = root.collection("documentImports").doc(p.requestId);
  const storagePath = `users/${uid}/documentImports/${p.expectedGeneration}/${p.requestId}/source`;
  const digest = eventId(JSON.stringify({generation: p.expectedGeneration, size: p.size, sha256: p.sha256, contentType: p.contentType}));
  return db.runTransaction(async tx => {
    await readyProfile(tx, root, p.expectedGeneration);
    const [prior, usage, duplicate] = await Promise.all([tx.get(ref), tx.get(db.doc(`resourceUsage/${uid}`)),
      tx.get(root.collection("documentSources").doc(`${p.expectedGeneration}_${p.sha256}`))]);
    if (prior.exists) {
      if (prior.get("digest") !== digest) throw new HttpsError("already-exists", "request-conflict");
      if (prior.get("status") === "discarded" || prior.get("status") === "expired") issue("document-expired");
      return publicImport(ref.id, prior.data()!);
    }
    if (duplicate.exists) return {importId: duplicate.get("importId"), operationId: duplicate.get("operationId"), status: "duplicate"};
    const u = usage.data() ?? {};
    if ((u.attachmentBytes ?? 0) + (u.attachmentReservedBytes ?? 0) + p.size > policy.attachmentBytes) throw new HttpsError("resource-exhausted", "document-storage-quota");
    if ((u.temporaryBytes ?? 0) + (u.reservedBytes ?? 0) + p.size > policy.temporaryBytes ||
      (u.temporaryFiles ?? 0) + (u.reservedFiles ?? 0) >= policy.temporaryFiles) throw new HttpsError("resource-exhausted", "document-temporary-quota");
    const data = {digest, dataGeneration: p.expectedGeneration, size: p.size, sha256: p.sha256,
      contentType: p.contentType, storagePath, status: "prepared", version: 1, storageUploaded: false,
      expiresAt: Timestamp.fromMillis(Date.now() + 86400000), createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
    tx.create(ref, data);
    tx.set(db.doc(`resourceUsage/${uid}`), {reservedBytes: FieldValue.increment(p.size), reservedFiles: FieldValue.increment(1),
      attachmentReservedBytes: FieldValue.increment(p.size), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return publicImport(ref.id, data);
  });
}

export async function trackDocumentObject(db: Firestore, object: {name?: string; bucket?: string; generation?: string | number; size?: string | number}, deleted: boolean) {
  const match = /^users\/([^/]+)\/documentImports\/(\d+)\/([\w-]+)\/source$/.exec(object.name ?? "");
  if (!match || !object.generation) return;
  const [, uid, generation, importId] = match;
  const ref = db.doc(`resourceUsage/${uid}/objects/${eventId(`${object.name}:${object.generation}`)}`);
  const proposalRef = db.doc(`users/${uid}/documentImports/${importId}`);
  await db.runTransaction(async tx => {
    const usageRef = db.doc(`resourceUsage/${uid}`);
    const [prior, proposal, usage] = await Promise.all([tx.get(ref), tx.get(proposalRef), tx.get(usageRef)]);
    const previous = prior.data();
    if (previous?.deleted || (!deleted && previous)) return;
    const size = Number(object.size ?? previous?.bytes ?? 0);
    if (!Number.isSafeInteger(size) || size < 0) return;
    const retained = previous?.retained ?? (proposal.get("status") === "approved");
    const meterNow = Date.now(), lastMeterAt = usage.get("storageMeteredAt")?.toMillis() ?? meterNow;
    const occupied = (usage.get("attachmentBytes") ?? 0) + (usage.get("temporaryBytes") ?? 0);
    const d: Data = {updatedAt: FieldValue.serverTimestamp(), storageMeteredAt: Timestamp.fromMillis(meterNow),
      storageByteMilliseconds: (usage.get("storageByteMilliseconds") ?? 0) + occupied * Math.max(0,meterNow-lastMeterAt)};
    const bucketName = retained ? "attachment" : "temporary";
    if (deleted && previous) {
      d[`${bucketName}Bytes`] = FieldValue.increment(-size); d[`${bucketName}Files`] = FieldValue.increment(-1);
    } else if (!deleted) {
      d[`${bucketName}Bytes`] = FieldValue.increment(size); d[`${bucketName}Files`] = FieldValue.increment(1);
    }
    if (proposal.exists && !["discarded", "expired"].includes(proposal.get("status")) && proposal.get("dataGeneration") === Number(generation) && !proposal.get("storageUploaded")) {
      d.reservedBytes = FieldValue.increment(-proposal.get("size")); d.reservedFiles = FieldValue.increment(-1);
      tx.update(proposalRef, {storageUploaded: true, objectGeneration: object.generation, objectMeterId: ref.id});
    }
    tx.set(ref, {bytes: size, retained, deleted, storagePath: object.name, bucket: object.bucket ?? previous?.bucket ?? null,
      objectGeneration: object.generation, updatedAt: FieldValue.serverTimestamp(),
      ...(deleted ? {expiresAt: Timestamp.fromMillis(Date.now() + 90 * 86400000)} : {})});
    tx.set(db.doc(`resourceUsage/${uid}`), d, {merge: true});
  });
  await recordUsage(db, uid, `storage:${deleted ? "delete" : "upload"}:${object.name}:${object.generation}`, "storage",
    deleted ? {deletions: 1} : {uploads: 1, uploadedBytes: Number(object.size ?? 0)});
}

export async function analyzeDocumentImport(db: Firestore, uid: string, p: Data, analyzer: DocumentAnalyzer) {
  if (!ident(p.importId)) throw new HttpsError("invalid-argument", "document-invalid");
  const policy = await documentPolicy(db); if (!policy.enabled) issue("document-analysis-disabled");
  const root = db.doc(`users/${uid}`), ref = root.collection("documentImports").doc(p.importId);
  await db.runTransaction(tx => readyProfile(tx, root, p.expectedGeneration));
  const initial = await ref.get();
  if (!initial.exists || initial.get("dataGeneration") !== p.expectedGeneration) issue("stale-data-generation");
  if (["ready", "unsupported", "approved", "analyzing"].includes(initial.get("status"))) {
    if (initial.get("status") === "analyzing" && initial.get("leaseUntil")?.toMillis() < Date.now()) {
      await releaseAnalysis(db, uid, ref.id, initial.get("attemptId"));
    } else return publicImport(ref.id, initial.data()!);
  }
  const source = getStorage().bucket().file(initial.get("storagePath"));
  const [metadata] = await source.getMetadata();
  // Firebase uploads may mint a bearer download token. Revoke it before analysis
  // so retained attachments are only served by the authenticated metered endpoint.
  if (metadata.metadata?.firebaseStorageDownloadTokens) {
    await source.setMetadata({metadata: {...metadata.metadata, firebaseStorageDownloadTokens: null}});
  }
  if (Number(metadata.size) !== initial.get("size") || metadata.contentType !== initial.get("contentType")) issue("document-file-invalid");
  const [bytes] = await source.download();
  await recordUsage(db, uid, `source-read:${randomUUID()}`, "storage", {internalReads: 1, internalReadBytes: bytes.length});
  if (createHash("sha256").update(bytes).digest("hex") !== initial.get("sha256")) issue("document-file-invalid");
  const mime = initial.get("contentType");
  const valid = mime === "application/pdf" ? bytes.subarray(0, 5).toString() === "%PDF-" : mime === "image/jpeg" ? bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 :
    mime === "image/png" ? bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) : bytes.subarray(0,4).toString() === "RIFF" && bytes.subarray(8,12).toString() === "WEBP";
  if (!valid) issue("document-file-invalid");
  if (mime === "application/pdf") {
    try {
      const {PDFDocument} = await import("pdf-lib");
      const pdf = await PDFDocument.load(bytes);
      if (pdf.getPageCount() < 1 || pdf.getPageCount() > policy.pdfPages) issue("document-pdf-pages");
    } catch { issue("document-pdf-invalid"); }
  }
  if (mime !== "application/pdf") {
    try {
      const sharp = (await import("sharp")).default;
      await sharp(bytes, {limitInputPixels: 40_000_000, failOn: "warning"}).stats();
    } catch { issue("document-file-invalid"); }
  }
  await trackDocumentObject(db, metadata, false);
  const attemptId = randomUUID();
  const claim = await db.runTransaction(async tx => {
    const profile = await readyProfile(tx, root, p.expectedGeneration);
    const row = await tx.get(ref);
    if (["ready", "unsupported", "approved", "analyzing"].includes(row.get("status"))) return false;
    if (!["prepared", "failed"].includes(row.get("status")) || row.get("expiresAt").toMillis() <= Date.now()) issue("document-expired");
    const reservation = await reserveAnalysis(tx, db, uid, policy, new Date(), attemptId, ref.id);
    reservation.write();
    tx.update(ref, {status: "analyzing", attemptId, quotaDay: reservation.day, quotaMonth: reservation.month,
      leaseUntil: Timestamp.fromMillis(Date.now() + 150000), updatedAt: FieldValue.serverTimestamp(), locale: profile.locale ?? "es"});
    return {locale: profile.locale ?? "es"};
  });
  if (!claim) return publicImport(ref.id, (await ref.get()).data()!);
  const startedAt = Date.now();
  try {
    const [categories, accounts, instruments] = await Promise.all([root.collection("categories").get(), root.collection("accounts").get(), root.collection("paymentInstruments").get()]);
    const rows = (s: typeof categories): Data[] => s.docs.map(d => ({...d.data(), id: d.id}));
    const response = await analyzer(bytes, mime, {categories: rows(categories).filter(c => c.type === "expense" && !c.isArchived).map(c => ({id: c.id, name: c.name})),
      locale: claim.locale});
    await recordUsage(db, uid, `analysis:${attemptId}`, "ai", {...response.usage,
        ...(typeof response.usage.inputTokens === "number" ? {billableInputTokens: Math.max(0, response.usage.inputTokens - (response.usage.cachedTokens ?? 0))} : {}),
        ...(typeof response.usage.outputTokens === "number" ? {billableOutputTokens: response.usage.outputTokens + (response.usage.thinkingTokens ?? 0)} : {}),
        cachedTokens: response.usage.cachedTokens ?? 0, attempts: 1, durationMs: Date.now() - startedAt},
      Object.keys(response.usage).length ? "measured" : "pending", {model: response.model, region: process.env.DOCUMENT_AI_LOCATION ?? "global", outcome: "success"});
    const extraction = validateExtraction(response.extraction, rows(categories), rows(accounts), rows(instruments));
    await db.runTransaction(async tx => {
      await readyProfile(tx, root, p.expectedGeneration);
      const row = await tx.get(ref);
      if (row.get("attemptId") !== attemptId || row.get("status") !== "analyzing") issue("document-analysis-stale");
      tx.update(ref, {status: extraction.supported ? "ready" : "unsupported", extraction,
        version: FieldValue.increment(1), leaseUntil: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()});
      tx.update(db.doc(`resourceUsage/${uid}/analysisReservations/${attemptId}`), {state: "completed", leaseUntil: FieldValue.delete()});
    });
    return publicImport(ref.id, (await ref.get()).data()!);
  } catch (error) {
    await recordUsage(db, uid, `analysis:${attemptId}`, "ai", {attempts: 1, failures: 1, durationMs: Date.now() - startedAt}, "pending", {outcome: "failure"});
    await releaseAnalysis(db, uid, ref.id, attemptId);
    throw new HttpsError("unavailable", "document-analysis-failed");
  }
}

/** Reads everything before callers write financial projections. */
export async function prepareDocumentApproval(tx: Transaction, root: DocumentReference, payload: Data,
  operationId: string, operation: Data): Promise<() => void> {
  if (payload.documentImportId === undefined) return () => {};
  if (!ident(payload.documentImportId) || payload.confirmedPerformed !== true) issue("document-review-required");
  const ref = root.collection("documentImports").doc(payload.documentImportId);
  const row = await tx.get(ref); const d = row.data();
  if (!d || d.dataGeneration !== operation.dataGeneration || d.status !== "ready" || !d.storageUploaded ||
    d.version !== payload.documentImportVersion || d.expiresAt.toMillis() <= Date.now() ||
    operation.type !== "expense" || (operation.debtKind && operation.debtKind !== "purchase")) issue("document-review-stale");
  const sourceRef = root.collection("documentSources").doc(`${d.dataGeneration}_${d.sha256}`);
  if ((await tx.get(sourceRef)).exists) throw new HttpsError("already-exists", "document-already-imported");
  const policy = await documentPolicy(root.firestore);
  const usageRef = root.firestore.doc(`resourceUsage/${root.id}`);
  const usage = await tx.get(usageRef);
  if ((usage.get("attachmentBytes") ?? 0) + d.size > policy.attachmentBytes) throw new HttpsError("resource-exhausted", "document-storage-quota");
  const possible = await tx.get(root.collection("operations").where("amountMinor", "==", operation.amountMinor)
    .where("currency", "==", operation.currency).where("accountId", "==", operation.accountId)
    .where("occurredAt", ">=", Timestamp.fromMillis(operation.occurredAt.toMillis() - 86400000))
    .where("occurredAt", "<=", Timestamp.fromMillis(operation.occurredAt.toMillis() + 86400000)).limit(10));
  let duplicate = false;
  for (const candidate of possible.docs) {
    const x = candidate.data();
    if (x.status !== "confirmed" || x.type !== "expense" || x.projectionDirection === -1) continue;
    const reversals = await tx.get(root.collection("operations").where("reversalOf", "==", candidate.id).limit(1));
    if (reversals.empty) duplicate = true;
  }
  if (duplicate && payload.duplicatesReviewed !== true) issue("document-possible-duplicate");
  const objectRef = root.firestore.doc(`resourceUsage/${root.id}/objects/${d.objectMeterId}`);
  const object = await tx.get(objectRef);
  if (!object.exists || object.get("deleted")) issue("document-file-missing");
  operation.documentImportId = ref.id;
  operation.attachmentId = ref.id;
  return () => {
    tx.update(ref, {status: "approved", operationId, expiresAt: FieldValue.delete(), approvedAt: FieldValue.serverTimestamp(), version: FieldValue.increment(1)});
    tx.create(sourceRef, {importId: ref.id, operationId, createdAt: FieldValue.serverTimestamp()});
    tx.create(root.collection("attachments").doc(ref.id), {operationId, dataGeneration: d.dataGeneration,
      storagePath: d.storagePath, objectGeneration: d.objectGeneration, contentType: d.contentType, size: d.size,
      status: "active", version: 1, createdAt: FieldValue.serverTimestamp()});
    tx.update(objectRef, {retained: true});
    tx.set(usageRef, {attachmentBytes: FieldValue.increment(d.size), attachmentFiles: FieldValue.increment(1),
      temporaryBytes: FieldValue.increment(-d.size), temporaryFiles: FieldValue.increment(-1),
      attachmentReservedBytes: FieldValue.increment(-d.size), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  };
}
