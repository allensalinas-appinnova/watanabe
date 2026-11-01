import {createHash} from "node:crypto";
import {FieldValue, Timestamp, type Firestore, type Transaction} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export type Data = Record<string, any>;
export const DEFAULT_DOCUMENT_POLICY = Object.freeze({enabled: false, dailyAnalyses: 5, monthlyAnalyses: 20,
  attachmentBytes: 100_000_000, temporaryBytes: 20_000_000, temporaryFiles: 2,
  imageBytes: 5_000_000, pdfBytes: 10_000_000, pdfPages: 3});
export type DocumentPolicy = {enabled: boolean; dailyAnalyses: number; monthlyAnalyses: number; attachmentBytes: number;
  temporaryBytes: number; temporaryFiles: number; imageBytes: number; pdfBytes: number; pdfPages: number};
export const eventId = (s: string) => createHash("sha256").update(s).digest("hex");
export function periods(now = new Date()) { return {day: now.toISOString().slice(0, 10), month: now.toISOString().slice(0, 7)}; }
export async function documentPolicy(db: Firestore): Promise<DocumentPolicy> {
  const row = (await db.doc("servicePolicies/documentImports").get()).data() ?? {};
  const result = {...DEFAULT_DOCUMENT_POLICY} as Record<string, any>;
  for (const key of Object.keys(result)) {
    if (key === "enabled") result[key] = row[key] === true;
    else if (Number.isSafeInteger(row[key]) && row[key] > 0) result[key] = row[key];
  }
  return result as DocumentPolicy;
}

/** This ledger intentionally survives the financial reset. No filenames or financial values. */
export async function recordUsage(db: Firestore, uid: string, key: string, service: string,
  units: Record<string, number>, quality: "measured" | "estimated" | "pending" = "measured", details: Data = {}) {
  const id = eventId(`${uid}:${key}`);
  const now = new Date(); const {day, month} = periods(now);
  await db.runTransaction(async tx => {
    const ref = db.doc(`resourceUsage/${uid}/events/${id}`);
    if ((await tx.get(ref)).exists) return;
    const deltas: Data = {};
    for (const [name, value] of Object.entries(units)) {
      if (!Number.isFinite(value)) throw new Error("invalid-usage-unit");
      deltas[`${service}_${name}`] = FieldValue.increment(value);
    }
    tx.create(ref, {service, units, quality, ...details, createdAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromMillis(now.getTime() + 90 * 86400000)});
    tx.set(db.doc(`resourceUsage/${uid}`), {lastMeteredAt: Timestamp.fromDate(now)}, {merge: true});
    for (const period of [`day_${day}`, `month_${month}`]) tx.set(db.doc(`resourceUsage/${uid}/periods/${period}`),
      {...deltas, updatedAt: Timestamp.fromDate(now), expiresAt: Timestamp.fromMillis(now.getTime() + 400 * 86400000)}, {merge: true});
  });
}

export async function usageSummary(db: Firestore, uid: string) {
  const {day, month} = periods();
  const [policy, storage, daily, monthly, costs] = await Promise.all([
    documentPolicy(db), db.doc(`resourceUsage/${uid}`).get(),
    db.doc(`resourceUsage/${uid}/periods/day_${day}`).get(), db.doc(`resourceUsage/${uid}/periods/month_${month}`).get(),
    db.doc(`resourceUsage/${uid}/costs/${month}`).get(),
  ]);
  const nextDay = new Date(`${day}T00:00:00Z`); nextDay.setUTCDate(nextDay.getUTCDate() + 1);
  const nextMonth = new Date(`${month}-01T00:00:00Z`); nextMonth.setUTCMonth(nextMonth.getUTCMonth() + 1);
  const data = storage.data() ?? {};
  return {policy, dailyUsed: daily.get("documentAnalyses") ?? 0, monthlyUsed: monthly.get("documentAnalyses") ?? 0,
    dailyRenewsAt: nextDay.toISOString(), monthlyRenewsAt: nextMonth.toISOString(),
    attachmentBytes: data.attachmentBytes ?? 0, temporaryBytes: data.temporaryBytes ?? 0,
    attachmentFiles: data.attachmentFiles ?? 0, temporaryFiles: data.temporaryFiles ?? 0,
    reservedBytes: data.reservedBytes ?? 0, deletionPendingBytes: data.deletionPendingBytes ?? 0,
    daily: daily.data() ?? null, monthly: monthly.data() ?? null,
    cost: costs.data() ?? {quality: "pending", amountUsd: null, reason: "billing-not-reconciled"},
    coverage: {ai: "Tokens reportados por el proveedor; coste de fallos sin tokens pendiente", storage: data.inventoryAt ? "Bytes inventariados y tiempo por transiciones observadas" : "Inventario pendiente",
      firestore: "Resultados del cliente parciales y estimados; no equivalen a lecturas facturadas", functions: "Intentos y duración de callables; CPU, memoria y tareas compartidas sin atribución completa", downloads: "Bytes servidos por la app; no equivalen al tráfico facturado del proveedor"},
    updatedAt: (data.updatedAt as Timestamp | undefined)?.toDate().toISOString() ?? null,
    inventoryAt: (data.inventoryAt as Timestamp | undefined)?.toDate().toISOString() ?? null};
}

/** Only call this while all transaction reads are still allowed. Returns a write phase. */
export async function reserveAnalysis(tx: Transaction, db: Firestore, uid: string, policy: DocumentPolicy, now: Date, attemptId: string, importId: string) {
  const {day, month} = periods(now);
  const dayRef = db.doc(`resourceUsage/${uid}/periods/day_${day}`), monthRef = db.doc(`resourceUsage/${uid}/periods/month_${month}`);
  const [d, m] = await Promise.all([tx.get(dayRef), tx.get(monthRef)]);
  if ((d.get("documentAnalyses") ?? 0) >= policy.dailyAnalyses || (m.get("documentAnalyses") ?? 0) >= policy.monthlyAnalyses) {
    throw new HttpsError("resource-exhausted", "document-analysis-quota");
  }
  return {day, month, write: () => {
    tx.create(db.doc(`resourceUsage/${uid}/analysisReservations/${attemptId}`), {day, month, importId, state: "charged", leaseUntil: Timestamp.fromMillis(now.getTime() + 150000), createdAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromMillis(now.getTime() + 90 * 86400000)});
    for (const ref of [dayRef, monthRef]) tx.set(ref, {documentAnalyses: FieldValue.increment(1), updatedAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromMillis(now.getTime() + 400 * 86400000)}, {merge: true});
  }};
}

export async function releaseAnalysis(db: Firestore, uid: string, importId: string, attemptId: string) {
  await db.runTransaction(async tx => {
    const ref = db.doc(`users/${uid}/documentImports/${importId}`);
    const reservationRef = db.doc(`resourceUsage/${uid}/analysisReservations/${attemptId}`);
    const [row, reservation] = await Promise.all([tx.get(ref), tx.get(reservationRef)]);
    if (!reservation.exists || reservation.get("state") !== "charged") return;
    for (const period of [`day_${reservation.get("day")}`, `month_${reservation.get("month")}`]) {
      tx.set(db.doc(`resourceUsage/${uid}/periods/${period}`), {documentAnalyses: FieldValue.increment(-1)}, {merge: true});
    }
    tx.update(reservationRef, {state: "released", leaseUntil: FieldValue.delete()});
    if (row.exists && row.get("attemptId") === attemptId && row.get("status") === "analyzing") {
      tx.update(ref, {status: "failed", leaseUntil: FieldValue.delete(), issue: "document-analysis-failed", updatedAt: FieldValue.serverTimestamp()});
    }
  });
}

export function registeredUid(auth: {uid: string; token: Data} | undefined): string {
  if (!auth) throw new HttpsError("unauthenticated", "session-expired");
  if (auth.token.firebase?.sign_in_provider === "anonymous") throw new HttpsError("permission-denied", "registered-account-required");
  return auth.uid;
}

/** Integrates byte occupancy between observed object transitions, atomically with its usage event. */
export async function recordStorageTime(db: Firestore, uid: string, now = new Date()) {
  const {day,month} = periods(now), root=db.doc(`resourceUsage/${uid}`);
  const ref=root.collection("events").doc(eventId(`${uid}:storage-time:${day}`));
  await db.runTransaction(async tx => {
    const [usage,event]=await Promise.all([tx.get(root),tx.get(ref)]);if(event.exists)return;
    const occupied=(usage.get("attachmentBytes")??0)+(usage.get("temporaryBytes")??0);
    const at=usage.get("storageMeteredAt")?.toMillis()??now.getTime();
    const integrated=(usage.get("storageByteMilliseconds")??0)+occupied*Math.max(0,now.getTime()-at);
    const byteHours=Math.max(0,integrated-(usage.get("storageReportedByteMilliseconds")??0))/3600000;
    tx.create(ref,{service:"storage",units:{byteHours},quality:"measured",createdAt:Timestamp.fromDate(now),expiresAt:Timestamp.fromMillis(now.getTime()+90*86400000)});
    tx.set(root,{storageReportedByteMilliseconds:integrated,lastMeteredAt:Timestamp.fromDate(now)},{merge:true});
    for(const period of [`day_${day}`,`month_${month}`])tx.set(root.collection("periods").doc(period),
      {storage_byteHours:FieldValue.increment(byteHours),expiresAt:Timestamp.fromMillis(now.getTime()+400*86400000),updatedAt:Timestamp.fromDate(now)},{merge:true});
  });
}
