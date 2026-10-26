import {createHash} from "node:crypto";
import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {maximumMinor, validCurrency, validId} from "./projection_model";

type Data = Record<string, unknown>;
type Status = "unauthenticated" | "invalid-argument" | "failed-precondition" | "already-exists" | "not-found";
export class DebtCommitmentError extends Error {
  constructor(readonly issue: string, readonly status: Status = "invalid-argument") { super(issue); }
}
function fail(issue: string, status: Status = "invalid-argument"): never { throw new DebtCommitmentError(`commitment-${issue}`, status); }
function object(value: unknown): Data { if (!value || typeof value !== "object" || Array.isArray(value)) fail("invalid-command"); return value as Data; }
function only(data: Data, keys: string[]) { if (Object.keys(data).some((key) => !keys.includes(key))) fail("unknown-field"); }
function id(value: unknown): string { if (!validId(value) || value.length > 128) fail("invalid-reference"); return value; }
function month(value: unknown): string { if (typeof value !== "string" || !/^\d{4}-(0[1-9]|1[0-2])$/.test(value)) fail("invalid-month"); return value; }
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, child]) => [key, canonical(child)]));
  return value;
}
function safeAmount(value: unknown, currency: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0 || value > maximumMinor(currency)) fail("invalid-amount");
  return value;
}
function commitmentPaused(plan: Data, monthKey: string): boolean {
  if (Array.isArray(plan.pauseRanges) && plan.pauseRanges.some((raw) => {
    if (!raw || typeof raw !== "object") return false;
    const range = raw as Data;
    return typeof range.fromMonth === "string" && monthKey >= range.fromMonth &&
      (typeof range.untilMonth !== "string" || monthKey < range.untilMonth);
  })) return true;
  return typeof plan.pausedFromMonth === "string" && monthKey >= plan.pausedFromMonth;
}

/** All commitment mutations are authenticated, generation checked and idempotent. */
export async function executeDebtCommitmentCommand(db: Firestore, uid: string | undefined, payload: unknown) {
  if (!uid || !validId(uid)) fail("session-expired", "unauthenticated");
  const input = object(payload);
  const requestId = id(input.requestId);
  if (!/^[A-Za-z0-9_-]{8,100}$/.test(requestId)) fail("invalid-request");
  const expectedGeneration = input.expectedGeneration;
  if (!Number.isSafeInteger(expectedGeneration) || Number(expectedGeneration) < 0) fail("generation-required", "failed-precondition");
  const digest = createHash("sha256").update(JSON.stringify(canonical(input))).digest("hex");
  const root = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const profile = (await tx.get(root)).data();
    if (!profile || profile.resetStatus === "resetting") fail("profile-unavailable", "failed-precondition");
    const generation = Number.isSafeInteger(profile.dataGeneration) ? profile.dataGeneration as number : 0;
    if (generation !== expectedGeneration) fail("stale-generation", "failed-precondition");
    const receiptRef = root.collection("debtCommitmentCommands").doc(requestId);
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()!.digest !== digest) fail("request-conflict", "already-exists");
      return receipt.data()!.result;
    }
    const action = input.action;
    const now = FieldValue.serverTimestamp();
    const commitmentId = action === "create" ? `commitment_${requestId}` : id(input.commitmentId);
    const commitmentRef = root.collection("debtCommitments").doc(commitmentId);
    const commitmentSnapshot = action === "create" ? undefined : await tx.get(commitmentRef);
    const commitment = commitmentSnapshot?.data();
    if (action !== "create" && !commitment) fail("not-found", "not-found");
    const result = {requestId, commitmentId};

    if (action === "create") {
      only(input, ["requestId", "expectedGeneration", "action", "debtAccountId", "currency", "amountMinor", "firstDueMonth", "dueDay", "lastDueMonth", "bankAccountId", "remindersEnabled"]);
      const accountId = id(input.debtAccountId), currency = input.currency;
      if (!validCurrency(currency)) fail("invalid-currency");
      const amountMinor = safeAmount(input.amountMinor, currency);
      const dueDay = input.dueDay;
      if (!Number.isSafeInteger(dueDay) || Number(dueDay) < 1 || Number(dueDay) > 31) fail("invalid-due-day");
      const firstDueMonth = month(input.firstDueMonth);
      const lastDueMonth = input.lastDueMonth == null ? null : month(input.lastDueMonth);
      if (lastDueMonth && lastDueMonth < firstDueMonth) fail("invalid-end-month");
      if (typeof input.remindersEnabled !== "boolean") fail("invalid-reminders");
      const account = (await tx.get(root.collection("accounts").doc(accountId))).data();
      if (!account || account.nature !== "debt" || account.status !== "active" || account.currency !== currency || account.type === "creditCard" && amountMinor > maximumMinor(currency)) fail("debt-incompatible", "failed-precondition");
      let bankAccountId: string | null = null;
      if (input.bankAccountId != null) {
        bankAccountId = id(input.bankAccountId);
        const bank = (await tx.get(root.collection("accounts").doc(bankAccountId))).data();
        if (!bank || bank.status !== "active" || (bank.nature !== undefined && bank.nature !== "money") || bank.currency !== currency) fail("bank-incompatible", "failed-precondition");
      }
      const data = {debtAccountId: accountId, currency, amountMinor, firstDueMonth, dueDay, lastDueMonth,
        bankAccountId, remindersEnabled: input.remindersEnabled, pausedFromMonth: null, pauseRanges: [],
        status: "active", version: 1, dataGeneration: generation, createdAt: now, updatedAt: now};
      tx.create(commitmentRef, data);
      tx.create(commitmentRef.collection("versions").doc("1"), {...data, effectiveFromMonth: firstDueMonth});
    } else if (action === "edit") {
      only(input, ["requestId", "expectedGeneration", "action", "commitmentId", "effectiveFromMonth", "amountMinor", "dueDay", "lastDueMonth", "bankAccountId", "remindersEnabled"]);
      const effectiveFromMonth = month(input.effectiveFromMonth);
      const version = Number.isSafeInteger(commitment!.version) ? Number(commitment!.version) + 1 : 2;
      const next = {
        debtAccountId: String(commitment!.debtAccountId),
        currency: input.currency ?? commitment!.currency,
        amountMinor: input.amountMinor ?? commitment!.amountMinor,
        firstDueMonth: commitment!.firstDueMonth,
        dueDay: input.dueDay ?? commitment!.dueDay,
        lastDueMonth: input.lastDueMonth === undefined ? commitment!.lastDueMonth ?? null : input.lastDueMonth === null ? null : month(input.lastDueMonth),
        bankAccountId: input.bankAccountId === undefined ? commitment!.bankAccountId ?? null : input.bankAccountId === null ? null : id(input.bankAccountId),
        remindersEnabled: input.remindersEnabled ?? commitment!.remindersEnabled ?? false,
        pausedFromMonth: commitment!.pausedFromMonth ?? null,
        pauseRanges: Array.isArray(commitment!.pauseRanges) ? commitment!.pauseRanges : [],
        status: commitment!.status, version, dataGeneration: generation,
        updatedAt: now, effectiveFromMonth,
      };
      if (!validCurrency(next.currency) || !Number.isSafeInteger(next.dueDay) || Number(next.dueDay) < 1 || Number(next.dueDay) > 31 || typeof next.remindersEnabled !== "boolean") fail("invalid-plan");
      safeAmount(next.amountMinor, next.currency);
      if (next.lastDueMonth && String(next.lastDueMonth) < String(next.firstDueMonth)) fail("invalid-end-month");
      const account = (await tx.get(root.collection("accounts").doc(next.debtAccountId))).data();
      if (!account || account.nature !== "debt" || account.status !== "active" || account.currency !== next.currency) fail("debt-incompatible", "failed-precondition");
      if (next.bankAccountId) {
        const bank = (await tx.get(root.collection("accounts").doc(String(next.bankAccountId)))).data();
        if (!bank || bank.status !== "active" || (bank.nature !== undefined && bank.nature !== "money") || bank.currency !== next.currency) fail("bank-incompatible", "failed-precondition");
      }
      tx.create(commitmentRef.collection("versions").doc(String(version)), next);
      tx.update(commitmentRef, {...next, effectiveFromMonth: FieldValue.delete(), updatedAt: now});
    } else if (action === "pause") {
      only(input, ["requestId", "expectedGeneration", "action", "commitmentId", "fromMonth", "paused"]);
      const fromMonth = month(input.fromMonth);
      if (typeof input.paused !== "boolean") fail("invalid-pause");
      const pauseRanges = Array.isArray(commitment!.pauseRanges) ? [...commitment!.pauseRanges as Data[]] : [];
      if (input.paused) {
        if (pauseRanges.some((range) => range.untilMonth == null) || commitment!.pausedFromMonth) fail("already-paused", "failed-precondition");
        pauseRanges.push({fromMonth, untilMonth: null});
        if (pauseRanges.length > 120) fail("too-many-pauses");
      } else {
        let openIndex = pauseRanges.findIndex((range) => range.untilMonth == null);
        if (openIndex < 0 && typeof commitment!.pausedFromMonth === "string") {
          pauseRanges.push({fromMonth: commitment!.pausedFromMonth, untilMonth: null});
          openIndex = pauseRanges.length - 1;
        }
        if (openIndex < 0 || fromMonth < String(pauseRanges[openIndex].fromMonth)) fail("not-paused", "failed-precondition");
        pauseRanges[openIndex] = {...pauseRanges[openIndex], untilMonth: fromMonth};
      }
      tx.update(commitmentRef, {pausedFromMonth: input.paused ? fromMonth : null, pauseRanges, updatedAt: now});
    } else if (action === "skip") {
      only(input, ["requestId", "expectedGeneration", "action", "commitmentId", "monthKey", "skipped"]);
      const monthKey = month(input.monthKey);
      if (typeof input.skipped !== "boolean") fail("invalid-skip");
      if (input.skipped) {
        const existingOccurrence = await tx.get(commitmentRef.collection("occurrences").doc(`${commitmentId}_${monthKey}`));
        if ((existingOccurrence.data()?.paymentIds as unknown[] | undefined)?.length) fail("occurrence-has-payment", "failed-precondition");
      }
      const occurrenceId = `${commitmentId}_${monthKey}`;
      const skippedMonths = new Set(Array.isArray(commitment!.skippedMonths) ? commitment!.skippedMonths as string[] : []);
      if (input.skipped) skippedMonths.add(monthKey); else skippedMonths.delete(monthKey);
      if (skippedMonths.size > 120) fail("too-many-skipped-occurrences");
      tx.set(commitmentRef.collection("occurrences").doc(occurrenceId), {monthKey, skipped: input.skipped, dataGeneration: generation, updatedAt: now}, {merge: true});
      tx.update(commitmentRef, {skippedMonths: [...skippedMonths].sort(), updatedAt: now});
    } else if (action === "linkPayment") {
      only(input, ["requestId", "expectedGeneration", "action", "commitmentId", "paymentId", "monthKey"]);
      const paymentId = id(input.paymentId), monthKey = month(input.monthKey);
      const paymentRef = root.collection("debtPayments").doc(paymentId);
      const payment = (await tx.get(paymentRef)).data();
      if (!payment || payment.debtAccountId !== commitment!.debtAccountId || payment.currency !== commitment!.currency || !["allocated", "unallocated"].includes(String(payment.status))) fail("payment-incompatible", "failed-precondition");
      const linkRef = root.collection("debtPaymentLinks").doc(paymentId);
      const existingLink = await tx.get(linkRef);
      if (existingLink.exists) fail("payment-already-linked", "already-exists");
      if (monthKey < String(commitment!.firstDueMonth) || (commitment!.lastDueMonth && monthKey > String(commitment!.lastDueMonth))) fail("occurrence-out-of-range", "failed-precondition");
      if (commitment!.status !== "active" || commitmentPaused(commitment!, monthKey)) fail("occurrence-unavailable", "failed-precondition");
      const occurrenceRef = commitmentRef.collection("occurrences").doc(`${commitmentId}_${monthKey}`);
      if ((await tx.get(occurrenceRef)).data()?.skipped === true) fail("occurrence-skipped", "failed-precondition");
      tx.create(linkRef, {paymentId, commitmentId, monthKey, amountMinor: payment.amountMinor,
        currency: payment.currency, dataGeneration: generation, createdAt: now});
      tx.set(occurrenceRef, {monthKey, paymentIds: FieldValue.arrayUnion(paymentId), updatedAt: now, dataGeneration: generation}, {merge: true});
    } else fail("invalid-action");

    tx.create(receiptRef, {digest, action, result, dataGeneration: generation, createdAt: now});
    return result;
  });
}
