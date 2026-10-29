import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {maximumMinor, validCurrency} from "./projection_model";

type Data = Record<string, unknown>;
type Field = {type: string; required: boolean; options: string[]};
const schemas: Record<string, Record<string, Field>> = {
  "context": {
    "dependents": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "incomeStability": {
      "type": "choice",
      "required": false,
      "options": [
        "stable",
        "variable",
        "unknown"
      ]
    },
    "sharedExpensePercent": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "accountsComplete": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no",
        "unknown"
      ]
    },
    "debtsComplete": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no",
        "unknown"
      ]
    },
    "verifiedOn": {
      "type": "date",
      "required": false,
      "options": []
    },
    "completeMonths": {
      "type": "months",
      "required": false,
      "options": []
    },
    "confirmedPlanMonths": {
      "type": "months",
      "required": false,
      "options": []
    },
    "emergencyMonths": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "currency": {
      "type": "text",
      "required": false,
      "options": []
    },
    "grossIncomeMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "riskCapacity": {
      "type": "choice",
      "required": false,
      "options": [
        "low",
        "medium",
        "high",
        "unknown"
      ]
    },
    "riskTolerance": {
      "type": "choice",
      "required": false,
      "options": [
        "low",
        "medium",
        "high",
        "unknown"
      ]
    }
  },
  "account": {
    "accountId": {
      "type": "account",
      "required": true,
      "options": []
    },
    "availability": {
      "type": "choice",
      "required": false,
      "options": [
        "immediate",
        "restricted",
        "unknown"
      ]
    },
    "excluded": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no"
      ]
    },
    "reason": {
      "type": "text",
      "required": false,
      "options": []
    },
    "verifiedOn": {
      "type": "date",
      "required": false,
      "options": []
    }
  },
  "classification": {
    "categoryId": {
      "type": "category",
      "required": true,
      "options": []
    },
    "budgetId": {
      "type": "text",
      "required": false,
      "options": []
    },
    "itemId": {
      "type": "text",
      "required": false,
      "options": []
    },
    "essential": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no",
        "unknown"
      ]
    },
    "fixed": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no",
        "unknown"
      ]
    },
    "recurring": {
      "type": "choice",
      "required": false,
      "options": [
        "yes",
        "no",
        "unknown"
      ]
    }
  },
  "plan": {
    "entryId": {
      "type": "plan",
      "required": true,
      "options": []
    },
    "accountId": {
      "type": "account",
      "required": true,
      "options": []
    },
    "effect": {
      "type": "choice",
      "required": true,
      "options": [
        "cash",
        "card",
        "none"
      ]
    }
  },
  "reserve": {
    "name": {
      "type": "text",
      "required": true,
      "options": []
    },
    "accountId": {
      "type": "account",
      "required": true,
      "options": []
    },
    "currency": {
      "type": "text",
      "required": true,
      "options": []
    },
    "amountMinor": {
      "type": "money",
      "required": true,
      "options": []
    },
    "purpose": {
      "type": "choice",
      "required": true,
      "options": [
        "emergency",
        "obligation",
        "goal"
      ]
    },
    "goalId": {
      "type": "goal",
      "required": false,
      "options": []
    },
    "entryId": {
      "type": "plan",
      "required": false,
      "options": []
    }
  },
  "goal": {
    "entryId": {"type": "plan", "required": false, "options": []},
    "name": {
      "type": "text",
      "required": true,
      "options": []
    },
    "kind": {
      "type": "choice",
      "required": true,
      "options": [
        "goal",
        "provision",
        "retirement",
        "tax"
      ]
    },
    "currency": {
      "type": "text",
      "required": true,
      "options": []
    },
    "amountMinor": {
      "type": "money",
      "required": true,
      "options": []
    },
    "dueDate": {
      "type": "date",
      "required": true,
      "options": []
    },
    "priority": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "monthlyContributionMinor": {
      "type": "money",
      "required": false,
      "options": []
    }
  },
  "debt": {
    "accountId": {
      "type": "account",
      "required": true,
      "options": []
    },
    "currency": {
      "type": "text",
      "required": true,
      "options": []
    },
    "referenceDate": {
      "type": "date",
      "required": true,
      "options": []
    },
    "rateBps": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "ratePeriod": {
      "type": "choice",
      "required": false,
      "options": [
        "monthlyEffective",
        "annualEffective"
      ]
    },
    "rateMode": {
      "type": "choice",
      "required": false,
      "options": [
        "fixed",
        "variable"
      ]
    },
    "remainingMonths": {
      "type": "integer",
      "required": false,
      "options": []
    },
    "dueDate": {
      "type": "date",
      "required": false,
      "options": []
    },
    "installmentMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "statementMonth": {
      "type": "months",
      "required": false,
      "options": []
    },
    "minimumPaymentMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "interestFreePaymentMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "prepaymentTerms": {
      "type": "text",
      "required": false,
      "options": []
    },
    "prepaymentCostMinor": {
      "type": "money",
      "required": false,
      "options": []
    }
  },
  "asset": {
    "goalId": {"type": "goal", "required": false, "options": []},
    "name": {
      "type": "text",
      "required": true,
      "options": []
    },
    "currency": {
      "type": "text",
      "required": true,
      "options": []
    },
    "amountMinor": {
      "type": "money",
      "required": true,
      "options": []
    },
    "referenceDate": {
      "type": "date",
      "required": true,
      "options": []
    },
    "ownershipPercent": {
      "type": "integer",
      "required": true,
      "options": []
    },
    "availability": {
      "type": "choice",
      "required": true,
      "options": [
        "immediate",
        "restricted"
      ]
    },
    "assetClass": {
      "type": "choice",
      "required": true,
      "options": [
        "property",
        "vehicle",
        "equity",
        "fixedIncome",
        "receivable",
        "other"
      ]
    },
    "obligation": {
      "type": "choice",
      "required": true,
      "options": [
        "yes",
        "no"
      ]
    },
    "accountId": {
      "type": "account",
      "required": false,
      "options": []
    },
    "dueDate": {
      "type": "date",
      "required": false,
      "options": []
    }
  },
  "coverage": {
    "name": {
      "type": "text",
      "required": true,
      "options": []
    },
    "currency": {
      "type": "text",
      "required": true,
      "options": []
    },
    "amountMinor": {
      "type": "money",
      "required": true,
      "options": []
    },
    "deductibleMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "needMinor": {
      "type": "money",
      "required": false,
      "options": []
    },
    "beneficiaries": {
      "type": "text",
      "required": false,
      "options": []
    },
    "dueDate": {
      "type": "date",
      "required": true,
      "options": []
    }
  }
};
const fail = (issue: string): never => { throw new HttpsError("invalid-argument", issue, {issue}); };
const object = (v: unknown): Data => {
  if (!v || typeof v !== "object" || Array.isArray(v)) return fail("diagnostic-invalid-input");
  return v as Data;
};
const id = (v: unknown): string => {
  if (typeof v !== "string" || !/^[A-Za-z0-9_-]{1,256}$/.test(v)) return fail("diagnostic-invalid-reference");
  return v;
};
const validDate = (v: string): boolean => /^\d{4}-\d{2}-\d{2}$/.test(v) &&
  Number(v.slice(0, 4)) >= 1900 && Number(v.slice(0, 4)) <= 2200 &&
  !Number.isNaN(Date.parse(v)) && new Date(v).toISOString().slice(0, 10) === v;

export function validateDiagnosticRecord(kind: string, input: unknown): Data {
  if (!Object.hasOwn(schemas, kind)) return fail("diagnostic-invalid-kind");
  const data = object(input);
  const schema = schemas[kind];
  if (Object.keys(data).some(k => !Object.hasOwn(schema, k))) return fail("diagnostic-invalid-field");
  for (const [key, field] of Object.entries(schema)) {
    const value = data[key];
    if (value === undefined) {
      if (field.required) return fail("diagnostic-required-field");
      continue;
    }
    if (["integer", "money"].includes(field.type)) {
      if (!Number.isSafeInteger(value) || Number(value) < 0 || Number(value) > 1e11) return fail("diagnostic-invalid-number");
      if (field.type === "money" && (!validCurrency(data.currency) || Number(value) > maximumMinor(data.currency as string))) return fail("diagnostic-invalid-money");
      if (key.endsWith("Percent") && Number(value) > 100) return fail("diagnostic-invalid-percent");
      if (["dependents", "remainingMonths", "emergencyMonths"].includes(key) && Number(value) > 1200) return fail("diagnostic-invalid-number");
    } else {
      if (typeof value !== "string" || !value.trim() || value.length > 500) return fail("diagnostic-invalid-text");
      if (key === "currency" && !validCurrency(value)) return fail("diagnostic-invalid-money");
      if (field.type === "choice" && !field.options.includes(value)) return fail("diagnostic-invalid-choice");
      if (field.type === "date" && !validDate(value)) return fail("diagnostic-invalid-date");
      if (field.type === "months") {
        const months = value.split(",").map(s => s.trim());
        if (months.length > 24 || months.some(m => !/^20\d{2}-(0[1-9]|1[0-2])$/.test(m)) ||
          (key === "statementMonth" && months.length !== 1)) return fail("diagnostic-invalid-months");
      }
      if (["account", "category", "goal"].includes(field.type) || ["budgetId", "itemId"].includes(key)) id(value);
      if (field.type === "plan" && !/^(budget:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+|debt:[A-Za-z0-9_-]+:20\d{2}-(0[1-9]|1[0-2]))$/.test(value)) return fail("diagnostic-invalid-reference");
    }
  }
  if (kind === "account" && data.excluded === "yes" && !data.reason) return fail("diagnostic-exclusion-reason");
  if (kind === "classification" && Boolean(data.budgetId) !== Boolean(data.itemId)) return fail("diagnostic-invalid-reference");
  if (kind === "reserve") {
    if (data.purpose === "goal" && !data.goalId) return fail("diagnostic-required-field");
    if ((data.purpose === "emergency" && (data.goalId || data.entryId)) || (data.goalId && data.entryId)) return fail("diagnostic-single-purpose");
    if (Number(data.amountMinor) <= 0) return fail("diagnostic-invalid-money");
  }
  return data;
}

/** Owner is obtained exclusively from callable Auth. Supplemental records never write the ledger. */
export async function executeDiagnosticCommand(db: Firestore, uid: string | undefined, payload: unknown) {
  if (!uid) throw new HttpsError("unauthenticated", "diagnostic-session-expired");
  const command = object(payload);
  if (Object.keys(command).some(k => !["requestId", "expectedGeneration", "recordId", "kind", "values", "revision", "action"].includes(k))) fail("diagnostic-invalid-input");
  const requestId = id(command.requestId);
  const recordId = id(command.recordId);
  if (!Number.isSafeInteger(command.expectedGeneration) || !Number.isSafeInteger(command.revision) || Number(command.revision) < 0) fail("diagnostic-invalid-input");
  if (!["save", "delete"].includes(String(command.action))) fail("diagnostic-invalid-input");
  const kind = String(command.kind);
  const values = command.action === "save" ? validateDiagnosticRecord(kind, command.values) : {};
  const digest = createHash("sha256").update(JSON.stringify(command)).digest("hex");
  const root = db.doc(`users/${id(uid)}`);
  return db.runTransaction(async tx => {
    const [profile, receipt, records, accounts] = await Promise.all([
      tx.get(root), tx.get(root.collection("diagnosticCommands").doc(requestId)),
      tx.get(root.collection("diagnosticRecords")), tx.get(root.collection("accounts")),
    ]);
    const p = profile.data();
    if (!p || (p.resetStatus ?? "ready") !== "ready" || (p.operationProjectionMigration ?? "idle") === "running" || (p.dataGeneration ?? 0) !== command.expectedGeneration) throw new HttpsError("failed-precondition", "diagnostic-stale-generation");
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new HttpsError("already-exists", "diagnostic-request-conflict");
      return receipt.data()?.result;
    }
    if (records.size >= 2000 && !records.docs.some(r => r.id === recordId)) fail("diagnostic-record-limit");
    const previous = records.docs.find(d => d.id === recordId);
    if ((previous?.data().revision ?? 0) !== command.revision || (previous && previous.data().kind !== kind)) throw new HttpsError("failed-precondition", "diagnostic-revision-conflict");
    const all = records.docs.filter(d => d.id !== recordId).map(d => ({id: d.id, kind: d.data().kind as string, values: d.data().values as Data, paymentBaselineMinor: Number(d.data().paymentBaselineMinor ?? 0)}));
    const paymentCache = new Map<string, Promise<number>>();
    const paymentTotal = (entryId: string): Promise<number> => {
      if (!entryId) return Promise.resolve(0);
      const existing = paymentCache.get(entryId);
      if (existing) return existing;
      const result = (async () => {
        const parts = entryId.split(":");
        if (parts[0] === "budget") {
          const item = await tx.get(root.collection("budgets").doc(parts[1]).collection("items").doc(parts[2]));
          return Number(item.data()?.actualAmountMinor ?? 0);
        }
        const links = await tx.get(root.collection("debtPaymentLinks").where("commitmentId", "==", parts[1]).where("monthKey", "==", parts[2]));
        return links.docs.reduce((sum, link) => sum + Number(link.data().amountMinor), 0);
      })();
      paymentCache.set(entryId, result);
      return result;
    };
    const reservationEntry = (v: Data): string => String(v.entryId ?? all.find(r => r.id === v.goalId && r.kind === "goal")?.values.entryId ?? "");
    let paymentBaselineMinor = 0;
    if (command.action === "delete") {
      if (all.some(r => r.values.goalId === recordId)) fail("diagnostic-record-in-use");
    } else {
      if (kind === "context" && recordId !== "context") fail("diagnostic-invalid-reference");
      if (["account", "debt"].includes(kind) && all.some(r => r.kind === kind && r.values.accountId === values.accountId)) fail("diagnostic-duplicate-reference");
      if (kind === "classification" && all.some(r => r.kind === kind && r.values.categoryId === values.categoryId && r.values.budgetId === values.budgetId && r.values.itemId === values.itemId)) fail("diagnostic-duplicate-reference");
      if (kind === "plan" && all.some(r => r.kind === kind && r.values.entryId === values.entryId)) fail("diagnostic-duplicate-reference");
      if (values.accountId) {
        const account = accounts.docs.find(a => a.id === values.accountId)?.data();
        if (!account || account.status !== "active" || (values.currency && account.currency !== values.currency)) fail("diagnostic-invalid-account");
        if ((kind === "debt" && account!.nature !== "debt") || (kind === "reserve" && account!.nature === "debt")) fail("diagnostic-invalid-account");
        if (kind === "asset" && ((values.obligation === "yes") !== (account!.nature === "debt"))) fail("diagnostic-invalid-account");
        if (kind === "plan" && ((values.effect === "cash" && account!.nature === "debt") || (values.effect === "card" && account!.type !== "creditCard"))) fail("diagnostic-invalid-account");
        if (kind === "reserve") {
          const effective = await Promise.all(all.filter(r => r.kind === "reserve" && r.values.accountId === values.accountId).map(async r => Math.max(0, Number(r.values.amountMinor) - Math.max(0, await paymentTotal(reservationEntry(r.values)) - r.paymentBaselineMinor))));
          const reserved = effective.reduce((sum, value) => sum + value, 0);
          paymentBaselineMinor = await paymentTotal(reservationEntry(values));
          if (reserved + Number(values.amountMinor) > Number(account!.currentBalanceMinor)) fail("diagnostic-reserve-exceeds-balance");
        }
      }
      if (kind === "asset" && values.goalId && (values.accountId || values.obligation === "yes")) fail("diagnostic-single-purpose");
      if (values.goalId) {
        const goal = all.find(r => r.id === values.goalId && r.kind === "goal");
        if (!goal || goal.values.currency !== values.currency) fail("diagnostic-invalid-goal");
      }
      if (kind === "goal" && previous?.data().values?.entryId !== values.entryId && all.some(r => r.kind === "reserve" && r.values.goalId === recordId)) fail("diagnostic-record-in-use");
      if (kind === "goal" && values.entryId && !["provision", "tax"].includes(String(values.kind))) fail("diagnostic-single-purpose");
      if (kind === "goal" && values.entryId && all.some(r => r.kind === "goal" && r.values.entryId === values.entryId)) fail("diagnostic-single-purpose");
      if (kind === "goal" && all.some(r => ["reserve", "asset"].includes(r.kind) && r.values.goalId === recordId && r.values.currency !== values.currency)) fail("diagnostic-record-in-use");
      if (kind === "classification") {
        const category = await tx.get(root.collection("categories").doc(id(values.categoryId)));
        if (!category.exists) fail("diagnostic-invalid-reference");
        if (values.budgetId) {
          const budget = await tx.get(root.collection("budgets").doc(id(values.budgetId)));
          const item = await tx.get(root.collection("budgets").doc(id(values.budgetId)).collection("items").doc(id(values.itemId)));
          if (!item.exists || budget.data()?.categoryId !== values.categoryId) fail("diagnostic-invalid-reference");
        }
      }
      if (values.entryId) {
        const parts = String(values.entryId).split(":");
        const parent = await tx.get(root.collection(parts[0] === "budget" ? "budgets" : "debtCommitments").doc(parts[1]));
        if (kind === "plan") {
          const account = accounts.docs.find(a => a.id === values.accountId)?.data();
          if (account?.currency !== parent.data()?.currency) fail("diagnostic-invalid-account");
        }
        if (!parent.exists || (values.currency && parent.data()?.currency !== values.currency)) fail("diagnostic-invalid-reference");
        if (parts[0] === "budget") {
          const item = await tx.get(parent.ref.collection("items").doc(parts[2]));
          if (!item.exists) fail("diagnostic-invalid-reference");
        }
        if (kind === "reserve" && all.some(r => r.kind === "reserve" && r.values.entryId === values.entryId)) fail("diagnostic-single-purpose");
      }
    }
    const ref = root.collection("diagnosticRecords").doc(recordId);
    const revision = Number(command.revision) + 1;
    if (command.action === "delete") {
      if (kind === "asset") {
        const valuations = await tx.get(ref.collection("valuations"));
        if (valuations.size > 450) fail("diagnostic-too-many-valuations");
        for (const valuation of valuations.docs) tx.delete(valuation.ref);
      }
      tx.delete(ref);
    }
    else {
      tx.set(ref, {kind, values, revision, paymentBaselineMinor, dataGeneration: command.expectedGeneration, updatedAt: FieldValue.serverTimestamp()});
      if (kind === "asset") tx.set(ref.collection("valuations").doc(requestId), {values, revision, recordedAt: FieldValue.serverTimestamp()});
    }
    const result = {recordId, revision};
    tx.set(root.collection("diagnosticCommands").doc(requestId), {digest, result, createdAt: FieldValue.serverTimestamp()});
    return result;
  });
}
