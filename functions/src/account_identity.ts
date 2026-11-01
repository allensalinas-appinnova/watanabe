import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export type AccountIdentity = {institutionName?: string | null; institutionCountryCode?: string | null; accountLastFour?: string | null};
export function accountIdentity(input: Record<string, unknown>): AccountIdentity {
  const result: AccountIdentity = {};
  for (const key of ["institutionName", "institutionCountryCode", "accountLastFour"] as const) {
    if (!(key in input)) continue;
    const value = input[key];
    if (value === null || value === "") { result[key] = null; continue; }
    if (typeof value !== "string" || (key === "institutionName" ? value.trim().length > 120 :
      key === "institutionCountryCode" ? !/^[A-Z]{2}$/.test(value) : !/^\d{4}$/.test(value))) {
      throw new HttpsError("invalid-argument", "account-identity-invalid");
    }
    result[key] = value.trim();
  }
  return result;
}

export async function mutatePaymentInstrument(db: Firestore, uid: string | undefined, payload: unknown) {
  if (!uid) throw new HttpsError("unauthenticated", "session-expired");
  const p = payload as Record<string, unknown>;
  const allowed = ["requestId", "expectedGeneration", "action", "instrumentId", "expectedVersion", "accountId", "name", "lastFour"];
  if (!p || typeof p !== "object" || Object.keys(p).some(k => !allowed.includes(k)) ||
    typeof p.requestId !== "string" || !/^[\w-]{8,100}$/.test(p.requestId) ||
    !["create", "update", "archive"].includes(String(p.action)) || !Number.isSafeInteger(p.expectedGeneration) ||
    !Number.isSafeInteger(p.expectedVersion)) throw new HttpsError("invalid-argument", "instrument-invalid");
  const id = p.action === "create" ? p.requestId : p.instrumentId;
  if (typeof id !== "string" || !/^[\w-]{1,128}$/.test(id)) throw new HttpsError("invalid-argument", "instrument-invalid");
  const digest = createHash("sha256").update(JSON.stringify(Object.fromEntries(Object.entries(p).sort(([a], [b]) => a.localeCompare(b))))).digest("hex");
  const root = db.doc(`users/${uid}`);
  const ref = root.collection("paymentInstruments").doc(id);
  const receipt = root.collection("paymentInstrumentCommands").doc(p.requestId);
  return db.runTransaction(async tx => {
    const [profile, existing, prior] = await Promise.all([tx.get(root), tx.get(ref), tx.get(receipt)]);
    if (!profile.exists || profile.get("resetStatus") === "resetting" || (profile.get("dataGeneration") ?? 0) !== p.expectedGeneration) {
      throw new HttpsError("failed-precondition", "stale-data-generation");
    }
    if (prior.exists) {
      if (prior.get("digest") !== digest) throw new HttpsError("already-exists", "request-conflict");
      return prior.get("result");
    }
    if ((existing.get("version") ?? 0) !== p.expectedVersion || (p.action !== "create" && !existing.exists)) {
      throw new HttpsError("failed-precondition", "instrument-version-conflict");
    }
    if (existing.exists && existing.get("dataGeneration") !== p.expectedGeneration) throw new HttpsError("failed-precondition", "stale-data-generation");
    const accountId = p.accountId ?? existing.get("accountId");
    if (typeof accountId !== "string" || !/^[\w-]{1,128}$/.test(accountId)) throw new HttpsError("invalid-argument", "instrument-account-invalid");
    const account = await tx.get(root.collection("accounts").doc(accountId));
    if (!account.exists || (account.get("nature") ?? "money") !== "money" ||
      (p.action !== "archive" && account.get("status") !== "active")) throw new HttpsError("failed-precondition", "instrument-account-unavailable");
    if (p.action !== "archive" && (typeof p.name !== "string" || !p.name.trim() || p.name.length > 120 ||
      typeof p.lastFour !== "string" || !/^\d{4}$/.test(p.lastFour))) throw new HttpsError("invalid-argument", "instrument-invalid");
    const version = Number(p.expectedVersion) + 1;
    const result = {instrumentId: id, version};
    tx.set(ref, {accountId, kind: "debitCard", dataGeneration: p.expectedGeneration, version,
      ...(p.action !== "archive" ? {name: String(p.name).trim(), lastFour: p.lastFour} : {}),
      status: p.action === "archive" ? "archived" : "active", updatedAt: FieldValue.serverTimestamp(),
      ...(!existing.exists ? {createdAt: FieldValue.serverTimestamp()} : {})}, {merge: true});
    tx.create(receipt, {digest, result, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}
