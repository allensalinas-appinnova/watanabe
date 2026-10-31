import {createHash} from "node:crypto";
import {FieldValue, type DocumentReference, type Firestore, type Transaction} from "firebase-admin/firestore";
import {validId, validMonth, type Operation} from "./projection_model";

type Data = Record<string, unknown>;
export type PlanningSource = {kind: "expense" | "debt"; monthKey: string; budgetId?: string; itemId?: string; commitmentId?: string};
type Action = "completeExpense" | "dismiss" | "snooze" | "resume";
type Command = PlanningSource & {action: Action; requestId: string; expectedGeneration: number; expectedVersion: number; remindOn?: string};
export class PlanningFollowUpError extends Error {
  constructor(readonly issue: string, readonly status: "unauthenticated" | "invalid-argument" | "not-found" | "failed-precondition" | "already-exists" = "invalid-argument") { super(`planning-${issue}`); this.issue = `planning-${issue}`; }
}
function fail(issue: string, status?: PlanningFollowUpError["status"]): never { throw new PlanningFollowUpError(issue, status); }
export function planningSourceId(source: PlanningSource): string {
  return createHash("sha256").update(JSON.stringify(source.kind === "expense" ?
    [source.kind, source.budgetId, source.itemId, source.monthKey] : [source.kind, source.commitmentId, source.monthKey])).digest("hex");
}
export function planningEntryId(source: PlanningSource): string {
  return source.kind === "expense" ? `budget:${source.budgetId}:${source.itemId}` : `debt:${source.commitmentId}:${source.monthKey}`;
}
function parse(input: unknown): Command {
  if (!input || typeof input !== "object" || Array.isArray(input)) fail("invalid-command");
  const data = input as Data;
  if (Object.keys(data).some((key) => !["action", "requestId", "expectedGeneration", "expectedVersion", "kind", "budgetId", "itemId", "commitmentId", "monthKey", "remindOn"].includes(key)) ||
      !["completeExpense", "dismiss", "snooze", "resume"].includes(String(data.action)) ||
      typeof data.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId) ||
      !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      !Number.isSafeInteger(data.expectedVersion) || Number(data.expectedVersion) < 0 || !validMonth(data.monthKey) ||
      !["expense", "debt"].includes(String(data.kind))) fail("invalid-command");
  const source = data.kind === "expense" ? {kind: "expense" as const, budgetId: data.budgetId, itemId: data.itemId} : {kind: "debt" as const, commitmentId: data.commitmentId};
  if (data.kind === "expense" ? !validId(data.budgetId) || !validId(data.itemId) || data.commitmentId !== undefined :
    !validId(data.commitmentId) || data.budgetId !== undefined || data.itemId !== undefined || data.action === "completeExpense") fail("invalid-source");
  if (Object.values(source).some((value) => typeof value === "string" && value.length > 512)) fail("invalid-source");
  if (data.action === "snooze" ? typeof data.remindOn !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(data.remindOn) : data.remindOn !== undefined) fail("invalid-reminder-date");
  return {...source, monthKey: data.monthKey, action: data.action, requestId: data.requestId,
    expectedGeneration: data.expectedGeneration, expectedVersion: data.expectedVersion,
    ...(data.action === "snooze" ? {remindOn: data.remindOn} : {})} as Command;
}
function dateInZone(now: Date, zone: unknown): string {
  if (typeof zone !== "string") fail("invalid-time-zone", "failed-precondition");
  try {
    const parts = new Intl.DateTimeFormat("en", {timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit"}).formatToParts(now);
    return ["year", "month", "day"].map((key) => parts.find((part) => part.type === key)!.value).join("-");
  } catch { return fail("invalid-time-zone", "failed-precondition"); }
}
function validDate(value: string): boolean {
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}
function eligibleExpense(data: Data, generation: number): boolean {
  return data.type === "expense" && data.status === "confirmed" && (data.projectionDirection ?? 1) === 1 &&
    data.reversalOf === undefined && (data.dataGeneration ?? 0) === generation;
}
export function hasEligibleExpense(records: Map<string, Data>, generation: number): boolean {
  const reversed = new Set([...records.values()].filter((data) => data.status === "confirmed" && data.projectionDirection === -1).map((data) => data.reversalOf));
  return [...records].some(([id, data]) => eligibleExpense(data, generation) && !reversed.has(id));
}

/** Reads before any projection writes. The returned closure only updates follow-up state. */
export async function preparePlanningReopen(tx: Transaction, root: DocumentReference,
  changes: Array<{operationId?: string; previous?: Operation; current?: Operation}>): Promise<() => void> {
  const sources = new Map<string, PlanningSource>();
  for (const change of changes) for (const data of [change.previous, change.current]) {
    if (data?.budgetId && data.budgetItemId && data.type === "expense") {
      const source: PlanningSource = {kind: "expense", budgetId: data.budgetId, itemId: data.budgetItemId, monthKey: data.monthKey};
      sources.set(planningSourceId(source), source);
    }
  }
  const writes: Array<() => void> = [];
  for (const [id, source] of sources) {
    const ref = root.collection("planningFollowUps").doc(id);
    const followUp = (await tx.get(ref)).data();
    if (followUp?.state !== "completed") continue;
    const documents = await tx.get(root.collection("operations").where("budgetId", "==", source.budgetId));
    const records = new Map(documents.docs.map((doc) => [doc.id, doc.data()]));
    for (const change of changes) {
      const before = change.previous as Data | undefined, after = change.current as Data | undefined;
      const operationId = change.operationId ?? after?.idempotencyKey ?? before?.idempotencyKey;
      if (typeof operationId !== "string") continue;
      if (before) records.delete(operationId);
      if (after) records.set(operationId, after);
    }
    const relevant = new Map([...records].filter(([, data]) => data.budgetId === source.budgetId && data.budgetItemId === source.itemId));
    if (!hasEligibleExpense(relevant, Number(followUp.dataGeneration ?? 0))) {
      writes.push(() => tx.update(ref, {state: "open", reason: "record-changed", remindOn: null,
        version: Number(followUp.version) + 1, updatedAt: FieldValue.serverTimestamp()}));
    }
  }
  return () => { for (const write of writes) write(); };
}

/** Reminder decisions never write cash, debt, budgets, operations, or projections. */
export async function mutatePlanningFollowUp(db: Firestore, uid: string | undefined, input: unknown, now = new Date()) {
  if (!uid || !validId(uid)) fail("session-expired", "unauthenticated");
  const command = parse(input);
  const digest = createHash("sha256").update(JSON.stringify(command)).digest("hex");
  const root = db.doc(`users/${uid}`);
  const ref = root.collection("planningFollowUps").doc(planningSourceId(command));
  const receiptRef = root.collection("planningFollowUpCommands").doc(command.requestId);
  return db.runTransaction(async (tx) => {
    const profile = (await tx.get(root)).data();
    if (!profile || profile.resetStatus === "resetting") fail("profile-unavailable", "failed-precondition");
    const generation = Number(profile.dataGeneration ?? 0);
    if (generation !== command.expectedGeneration) fail("stale-generation", "failed-precondition");
    const [receipt, prior] = await Promise.all([tx.get(receiptRef), tx.get(ref)]);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) fail("request-conflict", "already-exists");
      return receipt.data()!.result;
    }
    const version = Number(prior.data()?.version ?? 0);
    if (version !== command.expectedVersion) fail("state-changed", "failed-precondition");
    if (command.kind === "expense") {
      const budgetRef = root.collection("budgets").doc(command.budgetId!);
      const [budgetSnap, itemSnap] = await Promise.all([tx.get(budgetRef), tx.get(budgetRef.collection("items").doc(command.itemId!))]);
      const budget = budgetSnap.data(), item = itemSnap.data();
      if (!budget || !item || budget.monthKey !== command.monthKey || budget.flowType !== "expense" ||
          budget.status !== "active" || item.status === "archived" || Number(budget.dataGeneration ?? 0) !== generation) fail("entry-unavailable", "failed-precondition");
      if (command.action === "completeExpense") {
        const operations = await tx.get(root.collection("operations").where("budgetId", "==", command.budgetId));
        const records = new Map(operations.docs.filter((doc) => doc.data().budgetItemId === command.itemId).map((doc) => [doc.id, doc.data()]));
        if (!hasEligibleExpense(records, generation)) fail("expense-needs-record", "failed-precondition");
      }
    } else {
      const commitmentRef = root.collection("debtCommitments").doc(command.commitmentId!);
      const [snapshot, versions, occurrence] = await Promise.all([tx.get(commitmentRef), tx.get(commitmentRef.collection("versions")),
        tx.get(commitmentRef.collection("occurrences").doc(`${command.commitmentId}_${command.monthKey}`))]);
      const current = snapshot.data();
      const applicable = versions.docs.map((doc) => doc.data()).filter((data) => String(data.effectiveFromMonth) <= command.monthKey)
        .sort((a, b) => Number(b.version) - Number(a.version));
      const plan = applicable[0] ?? (versions.empty ? current : undefined);
      const ranges = current?.pauseRanges as Array<{fromMonth: string; untilMonth?: string}> | undefined;
      const paused = ranges?.some((range) => range.fromMonth <= command.monthKey && (!range.untilMonth || command.monthKey < range.untilMonth)) ||
        typeof current?.pausedFromMonth === "string" && command.monthKey >= current.pausedFromMonth;
      if (!current || !plan || current.status !== "active" || Number(current.dataGeneration ?? 0) !== generation ||
          command.monthKey < String(plan.firstDueMonth) || plan.lastDueMonth && command.monthKey > String(plan.lastDueMonth) ||
          paused || occurrence.data()?.skipped === true || (current.skippedMonths as string[] | undefined)?.includes(command.monthKey)) fail("entry-unavailable", "failed-precondition");
    }
    if (command.action === "snooze") {
      const today = dateInZone(now, profile.timeZone);
      const last = new Date(`${today}T00:00:00Z`); last.setUTCDate(last.getUTCDate() + 28);
      if (!validDate(command.remindOn!) || command.remindOn! <= today || command.remindOn! > last.toISOString().slice(0, 10)) fail("snooze-out-of-range");
    }
    const {action, requestId: _requestId, expectedGeneration: _generation, expectedVersion: _version, ...source} = command;
    const result = {...source, entryId: planningEntryId(command), state: action === "resume" ? "open" : action === "completeExpense" ? "completed" : action === "dismiss" ? "dismissed" : "snoozed",
      remindOn: action === "snooze" ? command.remindOn : null, version: version + 1, reason: null, dataGeneration: generation};
    tx.set(ref, {...result, updatedAt: FieldValue.serverTimestamp()});
    tx.create(receiptRef, {digest, result, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}
