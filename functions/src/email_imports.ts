import {createHash} from "node:crypto";
import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {maximumMinor, parseOperation, validCurrency, validId} from "./projection_model";

type Data = Record<string, unknown>;
type ErrorStatus = "unauthenticated" | "permission-denied" | "invalid-argument" |
  "not-found" | "failed-precondition" | "already-exists";
export class EmailImportError extends Error {
  constructor(readonly issue: string, readonly status: ErrorStatus) {
    super(issue);
    this.name = "EmailImportError";
  }
}

export type EmailImportPolicy = {allowedUids: readonly string[]; now?: () => Date};
export type ImportDraft = {
  type: "income" | "expense" | "transfer"; amountMinor: number; currency: string;
  occurredAt: string; description: string; accountId?: string; categoryId?: string;
  sourceAccountId?: string; destinationAccountId?: string;
};
export type ImportResult = {
  candidateId: string; status: "pending" | "approved" | "discarded";
  version: number; operationId?: string;
};
type Command = {
  requestId: string; expectedGeneration: number; candidateId: string; action: "edit" | "approve" | "discard";
  expectedVersion: number; draft?: ImportDraft; duplicatesReviewed: boolean;
};

export function requireImportPilot(uid: string | undefined, policy: EmailImportPolicy): string {
  if (!uid || !validId(uid)) throw new EmailImportError("import-session-expired", "unauthenticated");
  if (!policy.allowedUids.includes(uid)) throw new EmailImportError("import-pilot-disabled", "permission-denied");
  return uid;
}

function record(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new EmailImportError("import-invalid-command", "invalid-argument");
  }
  return value as Data;
}
function only(data: Data, keys: readonly string[]): void {
  if (Object.keys(data).some((key) => !keys.includes(key))) {
    throw new EmailImportError("import-invalid-fields", "invalid-argument");
  }
}
function identifier(value: unknown): value is string {
  return validId(value) && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}
export function importDigest(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

// No date, currency or amount is inferred from email headers or account balances.
export function parseImportDraft(value: unknown, now: Date): ImportDraft {
  const data = record(value);
  only(data, ["type", "amountMinor", "currency", "occurredAt", "description", "accountId",
    "categoryId", "sourceAccountId", "destinationAccountId"]);
  if (!validCurrency(data.currency) || typeof data.amountMinor !== "number" ||
      !Number.isSafeInteger(data.amountMinor) || data.amountMinor <= 0 ||
      data.amountMinor > maximumMinor(data.currency)) {
    throw new EmailImportError("import-invalid-amount", "invalid-argument");
  }
  if (typeof data.description !== "string" || data.description.length > 500 ||
      /[\u0000-\u0008\u000b\u000c\u000e-\u001f<>]/u.test(data.description)) {
    throw new EmailImportError("import-invalid-description", "invalid-argument");
  }
  if (typeof data.occurredAt !== "string" ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(data.occurredAt)) {
    throw new EmailImportError("import-invalid-date", "invalid-argument");
  }
  const date = new Date(data.occurredAt);
  if (!Number.isFinite(date.getTime()) || date.toISOString().replace(".000Z", "Z") !==
      data.occurredAt.replace(".000Z", "Z") || date.getTime() < Date.UTC(2000, 0, 1) ||
      date.getTime() > now.getTime()) {
    throw new EmailImportError("import-invalid-date", "invalid-argument");
  }
  const shared = {amountMinor: data.amountMinor, currency: data.currency,
    occurredAt: date.toISOString(), description: data.description.trim()};
  if (data.type === "transfer") {
    if (!identifier(data.sourceAccountId) || !identifier(data.destinationAccountId) ||
        data.sourceAccountId === data.destinationAccountId || data.accountId !== undefined ||
        data.categoryId !== undefined) {
      throw new EmailImportError("import-invalid-transfer", "invalid-argument");
    }
    return {...shared, type: "transfer", sourceAccountId: data.sourceAccountId,
      destinationAccountId: data.destinationAccountId};
  }
  if (!["income", "expense"].includes(String(data.type)) || !identifier(data.accountId) ||
      !identifier(data.categoryId) || data.sourceAccountId !== undefined ||
      data.destinationAccountId !== undefined) {
    throw new EmailImportError("import-incomplete-movement", "invalid-argument");
  }
  return {...shared, type: data.type as "income" | "expense", accountId: data.accountId,
    categoryId: data.categoryId};
}

function command(value: unknown, now: Date): Command {
  const data = record(value);
  only(data, ["requestId", "expectedGeneration", "candidateId", "action", "expectedVersion", "draft", "duplicatesReviewed"]);
  if (!identifier(data.requestId) || data.requestId.length < 8 || !identifier(data.candidateId) ||
      !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      !["edit", "approve", "discard"].includes(String(data.action)) ||
      !Number.isSafeInteger(data.expectedVersion) || Number(data.expectedVersion) < 1 ||
      (data.duplicatesReviewed !== undefined && typeof data.duplicatesReviewed !== "boolean")) {
    throw new EmailImportError("import-invalid-command", "invalid-argument");
  }
  if (data.action === "discard" && data.draft !== undefined) {
    throw new EmailImportError("import-invalid-fields", "invalid-argument");
  }
  const draft = data.action === "discard" ? undefined : parseImportDraft(data.draft, now);
  return {requestId: data.requestId, expectedGeneration: Number(data.expectedGeneration), candidateId: data.candidateId,
    action: data.action as Command["action"], expectedVersion: Number(data.expectedVersion),
    ...(draft ? {draft} : {}), duplicatesReviewed: data.duplicatesReviewed === true};
}

function currentMonth(date: Date, timeZone: unknown): string {
  if (typeof timeZone !== "string") throw new EmailImportError("import-profile-timezone", "failed-precondition");
  try {
    const parts = new Intl.DateTimeFormat("en", {timeZone, year: "numeric", month: "2-digit"}).formatToParts(date);
    return `${parts.find((part) => part.type === "year")!.value}-${parts.find((part) => part.type === "month")!.value}`;
  } catch {
    throw new EmailImportError("import-profile-timezone", "failed-precondition");
  }
}

/** Server-only boundary; candidates and receipts never enter the financial outbox. */
export async function executeEmailImportCommand(
  db: Firestore, sessionUid: string | undefined, payload: unknown, policy: EmailImportPolicy,
): Promise<ImportResult> {
  const uid = requireImportPilot(sessionUid, policy);
  const now = policy.now?.() ?? new Date();
  const input = command(payload, now);
  const digest = importDigest(input);
  const root = db.doc(`users/${uid}`);
  const receiptRef = root.collection("emailImportCommands").doc(input.requestId);
  const candidateRef = root.collection("emailImportCandidates").doc(input.candidateId);
  return db.runTransaction(async (tx) => {
    const profileSnapshot = await tx.get(root);
    const profile = profileSnapshot.data();
    if (!profile) throw new EmailImportError("import-profile-missing", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (profile.resetStatus === "resetting") throw new EmailImportError("import-user-resetting", "failed-precondition");
    if (generation !== input.expectedGeneration) throw new EmailImportError("import-stale-generation", "failed-precondition");
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new EmailImportError("import-request-conflict", "already-exists");
      return receipt.data()!.result as ImportResult;
    }
    const snapshot = await tx.get(candidateRef);
    const candidate = snapshot.data();
    if (!candidate) throw new EmailImportError("import-candidate-missing", "not-found");
    // A separate request racing with an identical approval may return the existing result.
    const approvalDigest = input.draft ? importDigest(input.draft) : null;
    if (candidate.status === "approved" && input.action === "approve" &&
        candidate.approvalDigest === approvalDigest && typeof candidate.operationId === "string") {
      const result: ImportResult = {candidateId: snapshot.id, status: "approved",
        version: Number(candidate.version), operationId: candidate.operationId};
      tx.create(receiptRef, {digest, result, createdAt: FieldValue.serverTimestamp()});
      return result;
    }
    if (candidate.status !== "pending") throw new EmailImportError("import-candidate-resolved", "failed-precondition");
    if (!(candidate.expiresAt instanceof Timestamp) || candidate.expiresAt.toMillis() <= now.getTime()) {
      throw new EmailImportError("import-candidate-expired", "failed-precondition");
    }
    if (candidate.version !== input.expectedVersion) throw new EmailImportError("import-candidate-stale", "failed-precondition");
    const version = input.expectedVersion + 1;
    const timestamp = FieldValue.serverTimestamp();
    let result: ImportResult = {candidateId: snapshot.id, status: "pending", version};
    if (input.action === "approve") {
      const draft = input.draft!;
      const occurredAt = new Date(draft.occurredAt);
      const operationId = `email_${snapshot.id}`;
      const operationRef = root.collection("operations").doc(operationId);
      if (typeof candidate.sourceKey !== "string" || !/^[a-f0-9]{64}$/.test(candidate.sourceKey)) {
        throw new EmailImportError("import-invalid-source", "failed-precondition");
      }
      const sourceRef = root.collection("emailImportSources").doc(candidate.sourceKey);
      const bankReference = candidate.bankReferenceKey;
      const referenceRef = typeof bankReference === "string" && /^[a-f0-9]{64}$/.test(bankReference) ?
        root.collection("emailImportReferences").doc(bankReference) : null;
      const accountIds = draft.type === "transfer" ?
        [draft.sourceAccountId!, draft.destinationAccountId!] : [draft.accountId!];
      const [existing, source, reference, category, ...accounts] = await Promise.all([
        tx.get(operationRef), tx.get(sourceRef), referenceRef ? tx.get(referenceRef) : Promise.resolve(null),
        draft.categoryId ? tx.get(root.collection("categories").doc(draft.categoryId)) : Promise.resolve(null),
        ...accountIds.map((id) => tx.get(root.collection("accounts").doc(id))),
      ]);
      if (existing.exists || source.data()?.operationId || reference?.data()?.operationId) {
        throw new EmailImportError("import-source-already-approved", "already-exists");
      }
      if (accounts.some((account) => !account?.exists || account.data()?.nature === "debt" || account.data()?.status !== "active" ||
          account.data()?.currency !== draft.currency)) {
        throw new EmailImportError("import-account-incompatible", "failed-precondition");
      }
      if (draft.type !== "transfer" && (!category?.exists || category.data()?.isArchived === true ||
          category.data()?.type !== draft.type)) {
        throw new EmailImportError("import-category-incompatible", "failed-precondition");
      }
      // Query afresh, rather than trusting stale warnings from extraction. Limit
      // scanning to a two-day window; a saturated window always needs review.
      const matches = await tx.get(root.collection("operations")
        .where("occurredAt", ">=", Timestamp.fromMillis(occurredAt.getTime() - 86400000))
        .where("occurredAt", "<=", Timestamp.fromMillis(occurredAt.getTime() + 86400000)).limit(201));
      const duplicate = matches.size > 200 || matches.docs.some((row) => {
        const other = row.data();
        return other.status === "confirmed" && other.type === draft.type &&
          other.amountMinor === draft.amountMinor && other.currency === draft.currency &&
          (draft.type === "transfer" ? other.sourceAccountId === draft.sourceAccountId &&
            other.destinationAccountId === draft.destinationAccountId : other.accountId === draft.accountId);
      });
      if (duplicate && !input.duplicatesReviewed) {
        throw new EmailImportError("import-duplicate-review-required", "failed-precondition");
      }
      const operation = {...draft, occurredAt: Timestamp.fromDate(occurredAt),
        monthKey: currentMonth(occurredAt, profile.timeZone), status: "confirmed",
        dataGeneration: generation,
        idempotencyKey: operationId, createdAt: timestamp, updatedAt: timestamp};
      parseOperation(operation);
      tx.create(operationRef, operation);
      const signs = draft.type === "transfer" ? [-1, 1] : [draft.type === "income" ? 1 : -1];
      accountIds.forEach((accountId, index) => {
        const entryId = `${operationId}_${index}`;
        const entry = {operationId, accountId, deltaMinor: signs[index] * draft.amountMinor,
          currency: draft.currency, occurredAt: Timestamp.fromDate(occurredAt), dataGeneration: generation};
        tx.create(root.collection("ledgerEntries").doc(entryId), entry);
        tx.create(operationRef.collection("entries").doc(entryId), entry);
      });
      const marker = {operationId, approvedAt: timestamp};
      tx.set(sourceRef, marker);
      if (referenceRef) tx.set(referenceRef, marker);
      result = {...result, status: "approved", operationId};
      tx.update(candidateRef, {status: "approved", version, operationId, approvalDigest,
        updatedAt: timestamp, draft: FieldValue.delete(), evidence: FieldValue.delete()});
    } else if (input.action === "edit") {
      tx.update(candidateRef, {draft: input.draft, version, updatedAt: timestamp});
    } else {
      result = {...result, status: "discarded"};
      tx.update(candidateRef, {status: "discarded", version, updatedAt: timestamp,
        draft: FieldValue.delete(), evidence: FieldValue.delete()});
    }
    tx.create(receiptRef, {digest, result, createdAt: timestamp});
    return result;
  });
}

/** Workers call this after extraction; there is deliberately no client ingestion API. */
export async function stageEmailImportCandidate(db: Firestore, uid: string, input: {
  mailboxKey: string; messageId: string; bank: "bancolombia" | "davivienda";
  formatVersion: string; suggestion: Data; evidence: string; bankReferenceKey?: string;
}, now = new Date()): Promise<string> {
  if (!validId(uid) || !/^[a-f0-9]{64}$/.test(input.mailboxKey) ||
      !/^[A-Za-z0-9_-]{1,256}$/.test(input.messageId) ||
      !["bancolombia", "davivienda"].includes(input.bank) ||
      !/^[A-Za-z0-9_-]{1,64}$/.test(input.formatVersion) ||
      typeof input.evidence !== "string" || input.evidence.length > 600 ||
      /[<>\u0000-\u001f]/u.test(input.evidence) ||
      (input.bankReferenceKey !== undefined && !/^[a-f0-9]{64}$/.test(input.bankReferenceKey))) {
    throw new EmailImportError("import-invalid-source", "invalid-argument");
  }
  // Suggestions may be incomplete but must never contain HTML or arbitrary keys.
  only(input.suggestion, ["type", "amountMinor", "currency", "occurredAt", "description",
    "accountId", "categoryId", "sourceAccountId", "destinationAccountId"]);
  for (const [key, value] of Object.entries(input.suggestion)) {
    if (key === "amountMinor") {
      if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0 || value > 100_000_000_000) {
        throw new EmailImportError("import-invalid-source", "invalid-argument");
      }
    } else if (typeof value !== "string" || value.length > 500 || /[<>\u0000-\u001f]/u.test(value)) {
      throw new EmailImportError("import-invalid-source", "invalid-argument");
    }
  }
  const sourceKey = importDigest([input.mailboxKey, input.messageId]);
  const root = db.doc(`users/${uid}`);
  const candidateRef = root.collection("emailImportCandidates").doc(sourceKey);
  await db.runTransaction(async (tx) => {
    const [candidate, marker] = await Promise.all([tx.get(candidateRef),
      tx.get(root.collection("emailImportSources").doc(sourceKey))]);
    if (candidate.exists || marker.exists) return;
    const timestamp = FieldValue.serverTimestamp();
    tx.create(candidateRef, {sourceKey, bank: input.bank, formatVersion: input.formatVersion,
      status: "pending", version: 1, draft: input.suggestion, evidence: input.evidence,
      ...(input.bankReferenceKey ? {bankReferenceKey: input.bankReferenceKey} : {}),
      expiresAt: Timestamp.fromMillis(now.getTime() + 30 * 86400000),
      createdAt: timestamp, updatedAt: timestamp});
  });
  return sourceKey;
}

// Callable responses are intentionally used instead of Firestore client reads:
// email evidence must not enter the app's persistent Firestore cache.
export async function listEmailImportCandidates(db: Firestore, sessionUid: string | undefined,
  payload: unknown, policy: EmailImportPolicy): Promise<{candidates: Data[]; nextCursor: string | null}> {
  const uid = requireImportPilot(sessionUid, policy);
  const input = record(payload);
  only(input, ["cursor"]);
  if (input.cursor !== undefined && !identifier(input.cursor)) {
    throw new EmailImportError("import-invalid-cursor", "invalid-argument");
  }
  const collection = db.collection(`users/${uid}/emailImportCandidates`);
  const base = collection.orderBy("__name__").limit(50);
  const page = await (typeof input.cursor === "string" ? base.startAfter(input.cursor) : base).get();
  const now = (policy.now?.() ?? new Date()).getTime();
  const candidates = page.docs.flatMap((snapshot) => {
    const data = snapshot.data();
    if (data.status !== "pending" || !(data.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() <= now) return [];
    return [{id: snapshot.id, status: "pending", version: data.version, bank: data.bank,
      formatVersion: data.formatVersion, draft: data.draft, evidence: data.evidence,
      expiresAt: data.expiresAt.toDate().toISOString()}];
  });
  return {candidates, nextCursor: page.size === 50 ? page.docs.at(-1)!.id : null};
}
